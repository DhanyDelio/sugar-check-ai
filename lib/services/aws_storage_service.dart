import 'dart:convert';
import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// AWS S3 storage service for training data upload.
///
/// S3 path structure (Physical Clustering):
///   public/datasets/[product]/[variant]/[volume]/[filename].jpg
///   public/datasets/[product]/[variant]/[volume]/[filename].json  ← sidecar
///
/// Normalization: lowercase, trim, spaces → hyphens
/// This ensures "Teh Botol" and "teh botol" map to the same S3 folder.
class AwsStorageService {
  // ── Path normalization ────────────────────────────────────────────────────

  /// Normalize a path segment: lowercase, trim, spaces → hyphens.
  /// e.g. "Teh Botol Sosro " → "teh-botol-sosro"
  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
  }

  /// Build the S3 folder path for a given product/variant/volume.
  static String _buildFolderPath({
    required String productName,
    required String variantName,
    required String volume,
  }) {
    final product = _normalize(productName.isNotEmpty ? productName : 'unknown');
    final variant = _normalize(variantName.isNotEmpty ? variantName : 'original');
    final vol     = _normalize(volume.isNotEmpty ? volume : 'unknown');
    return 'public/datasets/$product/$variant/$vol';
  }

  // ── Compression ───────────────────────────────────────────────────────────

  Future<Uint8List> _compressPrimary(Uint8List bytes) async {
    final Uint8List compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 800,
      minHeight: 800,
      quality: 45,
      format: CompressFormat.jpeg,
    );
    debugPrint("  🗄 [primary] ${bytes.lengthInBytes} → ${compressed.lengthInBytes} bytes");
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
    debugPrint("  🗄 [frame_$index] ${bytes.lengthInBytes} → ${compressed.lengthInBytes} bytes");
    return compressed;
  }

  // ── Core upload ───────────────────────────────────────────────────────────

  /// Upload a single image file to S3, return the S3 key.
  Future<String> _uploadImageToS3({
    required Uint8List imageBytes,
    required String s3Key,
  }) async {
    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/${s3Key.split('/').last}');
    await tempFile.writeAsBytes(imageBytes);

    try {
      final result = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(tempFile.path),
        path: StoragePath.fromString(s3Key),
        options: const StorageUploadFileOptions(
          metadata: {'content-type': 'image/jpeg'},
        ),
      ).result;

      debugPrint("  ☁️ S3 uploaded: ${result.uploadedItem.path}");
      return result.uploadedItem.path;
    } finally {
      await tempFile.delete();
    }
  }

  /// Upload a sidecar JSON file to S3 alongside the image.
  Future<void> _uploadSidecarJson({
    required Map<String, dynamic> metadata,
    required String s3Key, // same path as image but .json extension
  }) async {
    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/${s3Key.split('/').last}');
    await tempFile.writeAsString(jsonEncode(metadata));

    try {
      await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(tempFile.path),
        path: StoragePath.fromString(s3Key),
        options: const StorageUploadFileOptions(
          metadata: {'content-type': 'application/json'},
        ),
      ).result;

      debugPrint("  📄 Sidecar JSON uploaded: $s3Key");
    } finally {
      await tempFile.delete();
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Upload training data to S3 with smart physical clustering.
  ///
  /// Each photo gets a sidecar .json with metadata for the training pipeline.
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
    final String volumeStr = volumeTotal > 0 ? '${volumeTotal.toStringAsFixed(0)}ml' : 'unknown';

    final String folder = _buildFolderPath(
      productName: productName,
      variantName: variantName,
      volume: volumeStr,
    );

    debugPrint("☁️ S3 folder: $folder");

    // Base metadata for all sidecar JSONs
    final Map<String, dynamic> baseMetadata = {
      'product_name':    productName,
      'variant_name':    variantName,
      'volume_total':    volumeTotal,
      'sugar_content':   sugarValue.toDouble(),
      'ai_confidence':   aiConfidence,
      'ai_product_name': aiProductName,
      'user_corrected':  isHighPriority,
      'user_id':         cleanUserId,
      'is_processed':    false,
      'timestamp':       timestamp,
    };

    // 1. Compress + upload primary image with sidecar
    debugPrint("☁️ Uploading primary image...");
    final Uint8List primaryBytes = await _compressPrimary(primaryImage);
    final String primaryKey = '$folder/${timestamp}_primary.jpg';
    final String primaryJsonKey = '$folder/${timestamp}_primary.json';

    final String uploadedKey = await _uploadImageToS3(
      imageBytes: primaryBytes,
      s3Key: primaryKey,
    );

    await _uploadSidecarJson(
      metadata: {...baseMetadata, 'frame_type': 'primary'},
      s3Key: primaryJsonKey,
    );

    // 2. Compress + upload silent frames in parallel with sidecar
    debugPrint("☁️ Uploading ${silentFramesList.length} silent frames...");

    // Compress all frames in parallel first
    final List<Uint8List> compressedFrames = await Future.wait(
      silentFramesList.asMap().entries.map(
        (e) => _compressSilentFrame(e.value, e.key),
      ),
    );

    // Upload all frames + sidecars in parallel
    await Future.wait(
      compressedFrames.asMap().entries.map((entry) async {
        final int i = entry.key;
        final String frameKey = '$folder/${timestamp}_frame_$i.jpg';
        final String frameJsonKey = '$folder/${timestamp}_frame_$i.json';

        await _uploadImageToS3(imageBytes: entry.value, s3Key: frameKey);
        await _uploadSidecarJson(
          metadata: {...baseMetadata, 'frame_type': 'silent_frame', 'frame_index': i},
          s3Key: frameJsonKey,
        );
      }),
    );

    debugPrint("🚀 S3 upload complete! folder: $folder");
    return uploadedKey;
  }
}
