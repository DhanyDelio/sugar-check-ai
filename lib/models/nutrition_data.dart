/// Model untuk data nutrisi yang diinput user di EditScreen
/// Menggantikan Map<String, dynamic> mentah
class NutritionData {
  final String kategori;
  final String namaProduk;
  final String varian;
  final double totalGula;

  // Minuman
  final double? volumeTotalMl;
  final double? volumePersajianMl;
  final double? gulaPersajianG;

  // Makanan
  final double? beratTotalG;
  final double? beratSajianG;

  const NutritionData.minuman({
    required this.namaProduk,
    required this.varian,
    required this.volumeTotalMl,
    required this.volumePersajianMl,
    required this.gulaPersajianG,
    required this.totalGula,
  })  : kategori = 'minuman',
        beratTotalG = null,
        beratSajianG = null;

  const NutritionData.makanan({
    required this.namaProduk,
    required this.varian,
    required this.beratTotalG,
    required this.beratSajianG,
    required this.gulaPersajianG,
    required this.totalGula,
  })  : kategori = 'makanan',
        volumeTotalMl = null,
        volumePersajianMl = null;

  Map<String, dynamic> toJson() {
    if (kategori == 'minuman') {
      return {
        'kategori': kategori,
        'nama_produk': namaProduk,
        'varian': varian,
        'volume_total_ml': volumeTotalMl ?? 0,
        'volume_persajian_ml': volumePersajianMl ?? 0,
        'gula_per_sajian_g': gulaPersajianG ?? 0,
        'total_gula_g': totalGula,
      };
    }
    return {
      'kategori': kategori,
      'nama_produk': namaProduk,
      'varian': varian,
      'berat_total_g': beratTotalG ?? 0,
      'berat_sajian_g': beratSajianG ?? 0,
      'gula_per_sajian_g': gulaPersajianG ?? 0,
      'total_gula_g': totalGula,
    };
  }
}
