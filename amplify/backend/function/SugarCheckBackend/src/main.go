package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/url"
	"os"
	"path"
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
	rateLimitMax    = 5
	rateLimitWindow = 60 // seconds
	presignExpiry   = 5 * time.Minute
)

// ── Structs ───────────────────────────────────────────────────────────────────

type SidecarMetadata struct {
	Brand      string  `json:"product_name"`
	Variant    string  `json:"variant_name"`
	Volume     string  `json:"volume_total"`
	Confidence float64 `json:"ai_confidence"`
	UserID     string  `json:"user_id"`
}

// PresignRequest is the body Flutter sends to /upload
type PresignRequest struct {
	UserID      string  `json:"user_id"`
	ProductName string  `json:"product_name"`
	VariantName string  `json:"variant_name"`
	VolumeTotal string  `json:"volume_total"`
	Confidence  float64 `json:"ai_confidence"`
	FileName    string  `json:"file_name"` // e.g. "primary.jpg" or "frame_0.jpg"
	ContentType string  `json:"content_type"` // "image/jpeg" or "application/json"
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

func buildStagingPath(userID, product, variant, volume, fileName string) string {
	p := normalize(product)
	v := normalize(variant)
	vol := normalize(volume)
	ts := fmt.Sprintf("%d", time.Now().UnixMilli())
	return fmt.Sprintf("public/staging/%s/%s/%s/%s/%s_%s", userID, p, v, vol, ts, fileName)
}

func isValidForCluster(m SidecarMetadata) bool {
	return m.Confidence >= 0.5 &&
		strings.TrimSpace(m.Brand) != "" &&
		strings.TrimSpace(m.Variant) != "" &&
		strings.TrimSpace(m.Volume) != ""
}

func deleteS3Object(ctx context.Context, bucket, key string) {
	_, err := s3Client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		log.Printf("⚠️  DeleteObject failed for %s: %v", key, err)
	}
}

func moveS3Object(ctx context.Context, bucket, src, dst string) error {
	copySource := url.PathEscape(fmt.Sprintf("%s/%s", bucket, src))
	_, err := s3Client.CopyObject(ctx, &s3.CopyObjectInput{
		Bucket:     aws.String(bucket),
		CopySource: aws.String(copySource),
		Key:        aws.String(dst),
	})
	if err != nil {
		return fmt.Errorf("CopyObject %s → %s: %w", src, dst, err)
	}
	deleteS3Object(ctx, bucket, src)
	return nil
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
		// Window expired — reset
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

	// Build staging S3 key
	s3Key := buildStagingPath(
		body.UserID,
		body.ProductName,
		body.VariantName,
		body.VolumeTotal,
		body.FileName,
	)

	contentType := body.ContentType
	if contentType == "" {
		contentType = "image/jpeg"
	}

	// Generate presigned PUT URL
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

// ── S3 Event Handler — clustering ─────────────────────────────────────────────

func handleS3Event(ctx context.Context, s3Event events.S3Event) error {
	for _, record := range s3Event.Records {
		bucket := record.S3.Bucket.Name
		key := record.S3.Object.Key

		if bucketName != "" && bucket != bucketName {
			log.Printf("⚠️  Skipping unexpected bucket: %s", bucket)
			continue
		}

		if !strings.HasSuffix(strings.ToLower(key), ".json") {
			continue
		}

		log.Printf("📄 Processing sidecar: %s", key)

		result, err := s3Client.GetObject(ctx, &s3.GetObjectInput{
			Bucket: aws.String(bucket),
			Key:    aws.String(key),
		})
		if err != nil {
			log.Printf("❌ GetObject failed: %v", err)
			continue
		}

		var meta SidecarMetadata
		decodeErr := json.NewDecoder(result.Body).Decode(&meta)
		result.Body.Close()

		if decodeErr != nil {
			log.Printf("❌ JSON decode failed: %v", decodeErr)
			deleteS3Object(ctx, bucket, key)
			continue
		}

		dir := path.Dir(key)
		base := strings.TrimSuffix(path.Base(key), ".json")
		imageKey := path.Join(dir, base+".jpg")

		var destImageKey, destJSONKey string

		if isValidForCluster(meta) {
			brand := normalize(meta.Brand)
			variant := normalize(meta.Variant)
			volume := normalize(meta.Volume)
			destImageKey = fmt.Sprintf("public/dataset/%s/%s/%s/%s.jpg", brand, variant, volume, base)
			destJSONKey = fmt.Sprintf("public/dataset/%s/%s/%s/%s.json", brand, variant, volume, base)
			log.Printf("✅ Auto-cluster → %s", destImageKey)
		} else {
			destImageKey = fmt.Sprintf("public/non-reviewed/%s.jpg", base)
			destJSONKey = fmt.Sprintf("public/non-reviewed/%s.json", base)
			log.Printf("🔍 Non-reviewed → confidence=%.2f", meta.Confidence)
		}

		if err := moveS3Object(ctx, bucket, imageKey, destImageKey); err != nil {
			log.Printf("❌ Move image failed: %v", err)
		}
		if err := moveS3Object(ctx, bucket, key, destJSONKey); err != nil {
			log.Printf("❌ Move JSON failed: %v", err)
		}
	}
	return nil
}

// ── Router — detect event type ────────────────────────────────────────────────

func handler(ctx context.Context, event json.RawMessage) (interface{}, error) {
	// Try API Gateway event first
	var apiReq events.APIGatewayProxyRequest
	if err := json.Unmarshal(event, &apiReq); err == nil && apiReq.HTTPMethod != "" {
		return handlePresignRequest(ctx, apiReq)
	}

	// Fall back to S3 event
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
