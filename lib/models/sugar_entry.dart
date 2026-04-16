import 'dart:typed_data';

class SugarEntry {
  final String id;
  final String brandName;
  final String variantName;
  final double totalSugar;
  final Uint8List? imageBytes;
  final DateTime timestamp;

  SugarEntry({
    required this.id,
    required this.brandName,
    required this.variantName,
    required this.totalSugar,
    this.imageBytes,
    required this.timestamp,
  });

  String get displayName =>
      variantName.isNotEmpty ? '$brandName — $variantName' : brandName;
}
