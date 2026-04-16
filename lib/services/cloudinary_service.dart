import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/raw/upload';

  /// Compress primary image to 800px width, quality 45
  Future<String> _compressPrimary(Uint8List imageBytes) async {
    final Uint8List? result = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: 800,
      minHeight: 800,
      quality: 45,
      format: CompressFormat.jpeg,
    );
    final Uint8List compressed = result ?? imageBytes;
    debugPrint("  🗜 [primary] ${imageBytes.lengthInBytes} → ${compressed.lengthInBytes} bytes");
    return base64Encode(compressed);
  }

  /// Compress silent frame to 400px width, quality 30.
  /// Smaller size is acceptable since these are used for training variety, not primary detection.
  Future<String> _compressSilentFrame(Uint8List imageBytes, int index) async {
    final Uint8List? result = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: 400,
      minHeight: 400,
      quality: 30,
      format: CompressFormat.jpeg,
    );
    final Uint8List compressed = result ?? imageBytes;
    debugPrint("  🗜 [frame_$index] ${imageBytes.lengthInBytes} → ${compressed.lengthInBytes} bytes");
    return base64Encode(compressed);
  }

  /// Upload a JSON payload to Cloudinary as a raw file
  Future<String> _uploadJson({
    required Map<String, dynamic> jsonData,
    required String publicId,
    required String folder,
  }) async {
    final String jsonString = jsonEncode(jsonData);
    final String base64Json = base64Encode(utf8.encode(jsonString));

    final response = await http.post(
      Uri.parse(_uploadUrl),
      body: {
        'file': 'data:application/json;base64,$base64Json',
        'upload_preset': _uploadPreset,
        'folder': folder,
        'public_id': publicId,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed [$publicId]: ${response.body}');
    }

    final Map<String, dynamic> res = jsonDecode(response.body);
    final String url = res['secure_url'] as String;
    debugPrint("  ☁️ Uploaded: $url");
    return url;
  }

  /// Upload a complete training data package to Cloudinary as a single JSON file.
  ///
  /// Structure: metadata + [image_base64_list] where index 0 is the primary image
  /// and the rest are silent frames captured in the background.
  ///
  /// [is_processed] = false signals the Python pipeline to process this entry.
  Future<void> uploadTrainingData({
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
    try {
      final String cleanUserId =
          userId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final String timestamp =
          DateTime.now().millisecondsSinceEpoch.toString();

      // 1. Compress and encode primary image
      debugPrint("☁️ Compressing primary image...");
      final String primaryBase64 = await _compressPrimary(primaryImage);
      debugPrint("✅ Primary encoded (${primaryBase64.length} chars)");

      // 2. Compress and encode silent frames sequentially
      debugPrint("☁️ Compressing ${silentFramesList.length} silent frame(s)...");
      final List<String> imageBase64List = [primaryBase64];

      for (int i = 0; i < silentFramesList.length; i++) {
        debugPrint("  ⏳ Encoding frame $i...");
        final String frameBase64 = await _compressSilentFrame(silentFramesList[i], i);
        imageBase64List.add(frameBase64);
        debugPrint("  ✅ Frame $i encoded (${frameBase64.length} chars)");
      }

      final int totalChars = imageBase64List.fold(0, (sum, s) => sum + s.length);
      debugPrint("📊 Total payload: ~${(totalChars / 1024).toStringAsFixed(1)} KB "
          "(${imageBase64List.length} images)");

      // 3. Build JSON payload
      final Map<String, dynamic> payload = {
        "product_name": productName,
        "variant_name": variantName,
        "volume_total": volumeTotal,
        "sugar_content": sugarValue.toDouble(),
        "ai_confidence": aiConfidence,
        "ai_product_name": aiProductName,
        "user_corrected": isHighPriority,
        "user_id": cleanUserId,
        "image_base64_list": imageBase64List,
        "is_processed": false,
        "timestamp": timestamp,
      };

      // 4. Upload to Cloudinary
      final String docId = '${cleanUserId}_$timestamp';
      debugPrint("☁️ Uploading JSON → $docId...");

      await _uploadJson(
        jsonData: payload,
        publicId: docId,
        folder: 'training_data/$cleanUserId',
      );

      debugPrint("🚀 Upload complete! "
          "(1 primary + ${silentFramesList.length} silent frames)");
    } catch (e) {
      debugPrint("❌ Cloudinary Error: $e");
      rethrow;
    }
  }
}
