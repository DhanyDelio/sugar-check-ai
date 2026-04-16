/// Model untuk hasil scan AI (TFLite inference)
/// Menggantikan penggunaan primitif String + double terpisah
class ScanResult {
  final String product;
  final double confidence;
  final bool isConfident;

  const ScanResult({
    required this.product,
    required this.confidence,
    required this.isConfident,
  });

  static const ScanResult empty = ScanResult(
    product: '',
    confidence: 0,
    isConfident: false,
  );

  @override
  String toString() =>
      'ScanResult(product: $product, confidence: ${confidence.toStringAsFixed(1)}%, isConfident: $isConfident)';
}
