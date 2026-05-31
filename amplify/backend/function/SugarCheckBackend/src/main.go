package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// ── Constants ─────────────────────────────────────────────────────────────────

const (
	// Each upload session sends: 1 primary image + 1 primary JSON
	// + N silent frames (image + JSON each). With ~9 frames that's ~20 requests.
	// Allow 30 per minute to comfortably cover a full session.
	rateLimitMax    = 30
	rateLimitWindow = 60 // seconds
	presignExpiry   = 5 * time.Minute

	// Allowed staging folder — hardcoded, client cannot override
	stagingFolder = "quarantine-dataset"
)

// Allowed content types — whitelist only
var allowedContentTypes = map[string]bool{
	"image/jpeg":       true,
	"application/json": true,
}

// ── Structs ───────────────────────────────────────────────────────────────────

// PresignRequest is the body Flutter sends to /upload
type PresignRequest struct {
	UserID      string  `json:"user_id"`
	ProductName string  `json:"product_name"`
	VariantName string  `json:"variant_name"`
	VolumeTotal string  `json:"volume_total"`
	Confidence  float64 `json:"ai_confidence"`
	FileName    string  `json:"file_name"`
	ContentType string  `json:"content_type"`
}

// PresignResponse is returned to Flutter
type PresignResponse struct {
	UploadURL string `json:"upload_url"`
	S3Key     string `json:"s3_key"`
}

// ── AWS clients ───────────────────────────────────────────────────────────────

var (
	s3Client   *s3.Client
	presigner  *s3.PresignClient
	dynClient  *dynamodb.Client
	bucketName string
)

func init() {
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("❌ Failed to load AWS config: %v", err)
	}
	s3Client = s3.NewFromConfig(cfg)
	presigner = s3.NewPresignClient(s3Client)
	dynClient = dynamodb.NewFromConfig(cfg)
	bucketName = os.Getenv("S3_BUCKET_NAME")
}

// ── Helpers ───────────────────────────────────────────────────────────────────

func normalize(s string) string {
	s = strings.TrimSpace(strings.ToLower(s))
	s = strings.ReplaceAll(s, " ", "-")
	re := regexp.MustCompile(`[^a-z0-9\-]`)
	return re.ReplaceAllString(s, "")
}

func buildStagingPath(product, variant, volume, fileName string) string {
	p := normalize(product)
	v := normalize(variant)
	vol := normalize(volume)
	// path.Clean not needed — all segments are already normalized
	return fmt.Sprintf("public/%s/%s/%s/%s/%s", stagingFolder, p, v, vol, fileName)
}

// ── Rate limiting ─────────────────────────────────────────────────────────────

func isRateLimited(ctx context.Context, uuid string) (bool, error) {
	tableName := os.Getenv("RATE_LIMIT_TABLE")
	if tableName == "" {
		tableName = "SugarCheckRateLimit"
	}

	now := time.Now().Unix()
	windowStart := now - rateLimitWindow
	ttl := now + rateLimitWindow*2

	result, err := dynClient.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"uuid": &types.AttributeValueMemberS{Value: uuid},
		},
		UpdateExpression: aws.String(
			"SET #cnt = if_not_exists(#cnt, :zero) + :one, " +
				"window_start = if_not_exists(window_start, :ws), " +
				"#ttl = :ttl",
		),
		ConditionExpression: aws.String(
			"attribute_not_exists(window_start) OR window_start > :ws",
		),
		ExpressionAttributeNames: map[string]string{
			"#cnt": "count",
			"#ttl": "ttl",
		},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":zero": &types.AttributeValueMemberN{Value: "0"},
			":one":  &types.AttributeValueMemberN{Value: "1"},
			":ws":   &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", windowStart)},
			":ttl":  &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", ttl)},
		},
		ReturnValues: types.ReturnValueUpdatedNew,
	})

	if err != nil {
		// Window expired — reset counter
		_, resetErr := dynClient.PutItem(ctx, &dynamodb.PutItemInput{
			TableName: aws.String(tableName),
			Item: map[string]types.AttributeValue{
				"uuid":         &types.AttributeValueMemberS{Value: uuid},
				"count":        &types.AttributeValueMemberN{Value: "1"},
				"window_start": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", now)},
				"ttl":          &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", ttl)},
			},
		})
		if resetErr != nil {
			return false, fmt.Errorf("DynamoDB reset failed: %w", resetErr)
		}
		return false, nil
	}

	if countAttr, ok := result.Attributes["count"]; ok {
		var count int
		fmt.Sscanf(countAttr.(*types.AttributeValueMemberN).Value, "%d", &count)
		if count > rateLimitMax {
			return true, nil
		}
	}
	return false, nil
}

// ── HTTP Handler — generate presigned URL ─────────────────────────────────────

func handlePresignRequest(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	headers := map[string]string{
		"Content-Type":                "application/json",
		"Access-Control-Allow-Origin": "*",
	}

	var body PresignRequest
	if err := json.Unmarshal([]byte(req.Body), &body); err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 400, Headers: headers,
			Body: `{"error":"invalid request body"}`}, nil
	}

	if body.UserID == "" || body.FileName == "" {
		return events.APIGatewayProxyResponse{StatusCode: 400, Headers: headers,
			Body: `{"error":"user_id and file_name are required"}`}, nil
	}

	// Validate content type — whitelist only
	contentType := body.ContentType
	if contentType == "" {
		contentType = "image/jpeg"
	}
	if !allowedContentTypes[contentType] {
		log.Printf("⛔ Rejected content_type: %s from UUID: %s", contentType, body.UserID)
		return events.APIGatewayProxyResponse{StatusCode: 400, Headers: headers,
			Body: `{"error":"content_type not allowed"}`}, nil
	}

	// Rate limit check
	limited, err := isRateLimited(ctx, body.UserID)
	if err != nil {
		log.Printf("⚠️  Rate limit check error: %v", err)
	}
	if limited {
		log.Printf("[RATE_LIMIT_REJECTED] UUID: %s exceeded %d uploads/min", body.UserID, rateLimitMax)
		return events.APIGatewayProxyResponse{StatusCode: 429, Headers: headers,
			Body: `{"error":"rate limit exceeded, try again later"}`}, nil
	}

	// Build staging S3 key — folder hardcoded server-side
	s3Key := buildStagingPath(
		body.ProductName,
		body.VariantName,
		body.VolumeTotal,
		body.FileName,
	)

	presignResult, err := presigner.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(bucketName),
		Key:         aws.String(s3Key),
		ContentType: aws.String(contentType),
	}, func(o *s3.PresignOptions) {
		o.Expires = presignExpiry
	})
	if err != nil {
		log.Printf("❌ Presign failed: %v", err)
		return events.APIGatewayProxyResponse{StatusCode: 500, Headers: headers,
			Body: `{"error":"failed to generate upload URL"}`}, nil
	}

	resp := PresignResponse{
		UploadURL: presignResult.URL,
		S3Key:     s3Key,
	}
	respBytes, _ := json.Marshal(resp)

	log.Printf("✅ Presigned URL generated for %s → %s", body.UserID, s3Key)
	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Headers:    headers,
		Body:       string(respBytes),
	}, nil
}

// ── S3 Event Handler — clustering (DISABLED) ──────────────────────────────────
//
// Clustering is intentionally disabled. All uploads stay in quarantine-dataset/
// for manual review and annotation. Re-enable when the pipeline is ready.

func handleS3Event(_ context.Context, s3Event events.S3Event) error {
	for _, record := range s3Event.Records {
		log.Printf("📦 S3 event for: %s — clustering disabled, skipping", record.S3.Object.Key)
	}
	return nil
}

// ── Router ────────────────────────────────────────────────────────────────────

func handler(ctx context.Context, event json.RawMessage) (any, error) {
	var apiReq events.APIGatewayProxyRequest
	if err := json.Unmarshal(event, &apiReq); err == nil && apiReq.HTTPMethod != "" {
		return handlePresignRequest(ctx, apiReq)
	}

	var s3Event events.S3Event
	if err := json.Unmarshal(event, &s3Event); err == nil && len(s3Event.Records) > 0 {
		return nil, handleS3Event(ctx, s3Event)
	}

	log.Printf("⚠️  Unknown event type")
	return nil, nil
}

func main() {
	lambda.Start(handler)
}
