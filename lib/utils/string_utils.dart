/// Converts a snake_case JSON key to Title Case for UI display.
/// The original key is not modified — this is display-only formatting.
///
/// Examples:
///   formatLabel('volume_total')    → 'Volume Total'
///   formatLabel('sugar_per_serving') → 'Sugar Per Serving'
///   formatLabel('serving_weight')  → 'Serving Weight'
String formatLabel(String key) {
  return key
      .split('_')
      .map((word) => word.isEmpty
          ? ''
          : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
