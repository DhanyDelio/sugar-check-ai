import 'dart:typed_data';

class SugarEntry {
  final String id;
  final String brandName;
  final String variantName;

  /// Raw sugar from the product label — never modified after scan.
  final double rawSugarGrams;

  /// Credit applied from steps at the time of this scan.
  final double appliedCredit;

  /// Net sugar added to the visible meter = rawSugarGrams - appliedCredit.
  /// This is what the dashboard meter accumulates.
  double get totalSugar => (rawSugarGrams - appliedCredit).clamp(0.0, rawSugarGrams);

  final double volumeTotal;
  final String volumeLabel;
  final DateTime timestamp;

  /// URL from Cloudinary — persisted to local storage
  final String? imageUrl;

  /// In-memory bytes for immediate display after scan — not persisted
  final Uint8List? imageBytes;

  SugarEntry({
    required this.id,
    required this.brandName,
    required this.variantName,
    required this.rawSugarGrams,
    required this.timestamp,
    this.appliedCredit = 0,
    this.volumeTotal = 0,
    this.volumeLabel = '',
    this.imageUrl,
    this.imageBytes,
  });

  String get displayName =>
      variantName.isNotEmpty ? '$brandName — $variantName' : brandName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'brandName': brandName,
        'variantName': variantName,
        'rawSugarGrams': rawSugarGrams,
        'appliedCredit': appliedCredit,
        'volumeTotal': volumeTotal,
        'volumeLabel': volumeLabel,
        'timestamp': timestamp.toIso8601String(),
        'imageUrl': imageUrl,
      };

  factory SugarEntry.fromJson(Map<String, dynamic> json) => SugarEntry(
        id: json['id'] as String,
        brandName: json['brandName'] as String,
        variantName: json['variantName'] as String,
        // Support old entries that used 'totalSugar' key
        rawSugarGrams: (json['rawSugarGrams'] as num?)?.toDouble()
            ?? (json['totalSugar'] as num?)?.toDouble()
            ?? 0,
        appliedCredit: (json['appliedCredit'] as num?)?.toDouble() ?? 0,
        volumeTotal: (json['volumeTotal'] as num?)?.toDouble() ?? 0,
        volumeLabel: json['volumeLabel'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
        imageUrl: json['imageUrl'] as String?,
      );
}
