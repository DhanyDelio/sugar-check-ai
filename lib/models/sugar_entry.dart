import 'dart:typed_data';

class SugarEntry {
  final String id;
  final String brandName;
  final String variantName;
  final double totalSugar;
  final DateTime timestamp;

  /// URL from Cloudinary — persisted to local storage
  final String? imageUrl;

  /// In-memory bytes for immediate display after scan — not persisted
  final Uint8List? imageBytes;

  SugarEntry({
    required this.id,
    required this.brandName,
    required this.variantName,
    required this.totalSugar,
    required this.timestamp,
    this.imageUrl,
    this.imageBytes,
  });

  String get displayName =>
      variantName.isNotEmpty ? '$brandName — $variantName' : brandName;

  /// Serialize to JSON for local storage — imageBytes intentionally excluded
  Map<String, dynamic> toJson() => {
        'id': id,
        'brandName': brandName,
        'variantName': variantName,
        'totalSugar': totalSugar,
        'timestamp': timestamp.toIso8601String(),
        'imageUrl': imageUrl,
      };

  factory SugarEntry.fromJson(Map<String, dynamic> json) => SugarEntry(
        id: json['id'] as String,
        brandName: json['brandName'] as String,
        variantName: json['variantName'] as String,
        totalSugar: (json['totalSugar'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        imageUrl: json['imageUrl'] as String?,
      );
}
