import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

/// AWS Storage Service — Flutter → API Gateway → Go Lambda → S3
///
/// Flow:
///   1. Flutter sends metadata to Go Lambda via API Gateway POST /upload
///   2. Go validates UUID rate limit, generates presigned S3 PUT URL
///   3. Flutter uploads file directly to S3 via presigned URL
///   4. S3 event triggers Go Lambda for clustering
class AwsStorageService {
  static String get _apiUrl => dotenv.env['API_GATEWAY_URL'] ?? '';

  // ── Compression ───────────────────────────────────────────────────────────

  Future<Uint8List> _compressPrimary(Uint8List bytes) async {
    final Uint8List compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 800,
      minHeight: 800,
      quality: 45,
      format: CompressFormat.jpeg,
    );
    debugPrint(
      "  🗜 [primary] ${bytes.lengthInBytes} → ${compressed.lengthInBytes} bytes",
    );
    return compressed;
  }

  Future<Uint8List> _compressSilentFrame(Uint8List bytes, int index) async {
    final Uint8List compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 400,
      minHeight: 400,
      quality: 30,
      format: CompressFormat.jpeg,
    );
    debugPrint(
      "  🗜 [frame_$index] ${bytes.lengthInBytes} → ${compressed.lengthInBytes} bytes",
    );
    return compressed;
  }

  // ── Presigned URL request ─────────────────────────────────────────────────

  /// Request a presigned S3 PUT URL from Go Lambda via API Gateway.
  /// Returns {upload_url, s3_key} or throws on rate limit / error.
  Future<Map<String, String>> _requestPresignedUrl({
    required String userId,
    required String productName,
    required String variantName,
    required String volumeTotal,
    required double aiConfidence,
    required String fileName,
    required String contentType,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/upload'),
      headers: {'Content-Type': 'application/json', 'x-user-id': userId},
      body: jsonEncode({
        'user_id': userId,
        'product_name': productName,
        'variant_name': variantName,
        'volume_total': volumeTotal,
        'ai_confidence': aiConfidence,
        'file_name': fileName,
        'content_type': contentType,
        'staging_folder': 'quarantine-dataset', // all uploads go here first
      }),
    );

    if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded — try again in a minute');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Presign request failed: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> body = jsonDecode(response.body);
    return {
      'upload_url': body['upload_url'] as String,
      's3_key': body['s3_key'] as String,
    };
  }

  // ── Direct S3 upload via presigned URL ────────────────────────────────────

  Future<String> _uploadViaPresignedUrl({
    required Uint8List bytes,
    required String presignedUrl,
    required String contentType,
  }) async {
    final uploadResponse = await http.put(
      Uri.parse(presignedUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );

    if (uploadResponse.statusCode != 200) {
      throw Exception('S3 upload failed: ${uploadResponse.statusCode}');
    }

    debugPrint("  ☁️ Uploaded via presigned URL");
    return presignedUrl.split('?').first; // return clean S3 URL
  }

  // ── Sidecar JSON upload ───────────────────────────────────────────────────

  Future<void> _uploadSidecarJson({
    required Map<String, dynamic> metadata,
    required String userId,
    required String productName,
    required String variantName,
    required String volumeTotal,
    required double aiConfidence,
    required String fileName,
  }) async {
    final presign = await _requestPresignedUrl(
      userId: userId,
      productName: productName,
      variantName: variantName,
      volumeTotal: volumeTotal,
      aiConfidence: aiConfidence,
      fileName: fileName,
      contentType: 'application/json',
    );

    final Uint8List jsonBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(metadata)),
    );

    await _uploadViaPresignedUrl(
      bytes: jsonBytes,
      presignedUrl: presign['upload_url']!,
      contentType: 'application/json',
    );

    debugPrint("  📄 Sidecar JSON uploaded: ${presign['s3_key']}");
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Upload training data via Go Lambda presigned URL flow.
  /// Returns the S3 key of the primary image.
  Future<String> uploadTrainingData({
    required Uint8List primaryImage,
    required List<Uint8List> silentFramesList,
    required int sugarValue,
    required String productName,
    required String variantName,
    required double volumeTotal,
    required String userId,
    bool isHighPriority = false,
    double aiConfidence = 0,
    String aiProductName = '',
  }) async {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String cleanUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final String volumeStr = volumeTotal > 0
        ? '${volumeTotal.toStringAsFixed(0)}ml'
        : 'unknown';

    debugPrint("☁️ Starting upload via API Gateway → S3");

    final Map<String, dynamic> baseMetadata = {
      'product_name': productName,
      'variant_name': variantName,
      'volume_total': volumeTotal,
      'sugar_content': sugarValue.toDouble(),
      'ai_confidence': aiConfidence,
      'ai_product_name': aiProductName,
      'user_corrected': isHighPriority,
      'user_id': cleanUserId,
      'is_processed': false,
      'timestamp': timestamp,
    };

    // 1. Compress primary
    debugPrint("☁️ Compressing primary image...");
    final Uint8List primaryBytes = await _compressPrimary(primaryImage);
    final String primaryFileName = '${timestamp}_primary.jpg';

    // 2. Request presigned URL for primary image
    final presign = await _requestPresignedUrl(
      userId: cleanUserId,
      productName: productName,
      variantName: variantName,
      volumeTotal: volumeStr,
      aiConfidence: aiConfidence,
      fileName: primaryFileName,
      contentType: 'image/jpeg',
    );

    // 3. Upload primary image
    final String primaryUrl = await _uploadViaPresignedUrl(
      bytes: primaryBytes,
      presignedUrl: presign['upload_url']!,
      contentType: 'image/jpeg',
    );
    debugPrint("✅ Primary uploaded: ${presign['s3_key']}");

    // 4. Upload primary sidecar JSON
    await _uploadSidecarJson(
      metadata: {...baseMetadata, 'frame_type': 'primary'},
      userId: cleanUserId,
      productName: productName,
      variantName: variantName,
      volumeTotal: volumeStr,
      aiConfidence: aiConfidence,
      fileName: '${timestamp}_primary.json',
    );

    // 5. Compress + upload silent frames in parallel
    debugPrint("☁️ Uploading ${silentFramesList.length} silent frames...");
    final List<Uint8List> compressedFrames = await Future.wait(
      silentFramesList.asMap().entries.map(
        (e) => _compressSilentFrame(e.value, e.key),
      ),
    );

    await Future.wait(
      compressedFrames.asMap().entries.map((entry) async {
        final int i = entry.key;
        final framePresign = await _requestPresignedUrl(
          userId: cleanUserId,
          productName: productName,
          variantName: variantName,
          volumeTotal: volumeStr,
          aiConfidence: aiConfidence,
          fileName: '${timestamp}_frame_$i.jpg',
          contentType: 'image/jpeg',
        );
        await _uploadViaPresignedUrl(
          bytes: entry.value,
          presignedUrl: framePresign['upload_url']!,
          contentType: 'image/jpeg',
        );
        await _uploadSidecarJson(
          metadata: {
            ...baseMetadata,
            'frame_type': 'silent_frame',
            'frame_index': i,
          },
          userId: cleanUserId,
          productName: productName,
          variantName: variantName,
          volumeTotal: volumeStr,
          aiConfidence: aiConfidence,
          fileName: '${timestamp}_frame_$i.json',
        );
      }),
    );

    debugPrint("🚀 All uploads complete via API Gateway!");
    return primaryUrl;
  }
}
