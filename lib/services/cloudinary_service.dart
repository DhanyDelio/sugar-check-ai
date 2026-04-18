import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CloudinaryService {
  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/raw/upload';

  /// Compress primary image to 800px width, quality 45
  Future<Uint8List> _compressPrimary(Uint8List imageBytes) async {
    final Uint8List? result = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: 800,
      minHeight: 800,
      quality: 45,
      format: CompressFormat.jpeg,
    );
    final Uint8List compressed = result ?? imageBytes;
    debugPrint("  🗜 [primary] ${imageBytes.lengthInBytes} → ${compressed.lengthInBytes} bytes");
    return compressed;
  }

  /// Compress silent frame to 400px width, quality 30
  Future<Uint8List> _compressSilentFrame(Uint8List imageBytes, int index) async {
    final Uint8List? result = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: 400,
      minHeight: 400,
      quality: 30,
      format: CompressFormat.jpeg,
    );
    final Uint8List compressed = result ?? imageBytes;
    debugPrint("  🗜 [frame_$index] ${imageBytes.lengthInBytes} → ${compressed.lengthInBytes} bytes");
    return compressed;
  }

  /// Upload JSON payload to Cloudinary as a raw file using MultipartFile.
  /// public_id is capped at 50 chars to avoid display name limit errors.
  Future<String> _uploadJson({
    required Map<String, dynamic> jsonData,
    required String publicId,
    required String folder,
  }) async {
    // Write JSON to a temp file — avoids base64 display name limit
    final dir = await getTemporaryDirectory();
    final File tempFile = File('${dir.path}/$publicId.json');
    await tempFile.writeAsString(jsonEncode(jsonData));

    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl))
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..fields['public_id'] = publicId
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        tempFile.path,
        filename: '$publicId.json',
      ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    // Clean up temp file
    await tempFile.delete();

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
    try {
      final String cleanUserId =
          userId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final String timestamp =
          DateTime.now().millisecondsSinceEpoch.toString();

      // 1. Compress and encode primary image
      debugPrint("☁️ Compressing primary image...");
      final Uint8List primaryBytes = await _compressPrimary(primaryImage);
      final String primaryBase64 = base64Encode(primaryBytes);
      debugPrint("✅ Primary encoded (${primaryBase64.length} chars)");

      // 2. Compress and encode silent frames sequentially
      debugPrint("☁️ Compressing ${silentFramesList.length} silent frame(s)...");
      final List<String> imageBase64List = [primaryBase64];

      for (int i = 0; i < silentFramesList.length; i++) {
        debugPrint("  ⏳ Encoding frame $i...");
        final Uint8List frameBytes =
            await _compressSilentFrame(silentFramesList[i], i);
        imageBase64List.add(base64Encode(frameBytes));
        debugPrint("  ✅ Frame $i encoded");
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

      // 4. Upload to Cloudinary — public_id max 50 chars
      final String shortId = '${cleanUserId}_$timestamp';
      final String publicId = shortId.length > 50
          ? shortId.substring(shortId.length - 50)
          : shortId;

      debugPrint("☁️ Uploading JSON → $publicId...");
      final String url = await _uploadJson(
        jsonData: payload,
        publicId: publicId,
        folder: 'training_data/$cleanUserId',
      );

      debugPrint("🚀 Upload complete! "
          "(1 primary + ${silentFramesList.length} silent frames)");
      return url;
    } catch (e) {
      debugPrint("❌ Cloudinary Error: $e");
      rethrow;
    }
  }
}
