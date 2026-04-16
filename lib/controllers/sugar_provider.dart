import 'package:flutter/material.dart';
import '../models/sugar_entry.dart';

class SugarProvider extends ChangeNotifier {
  final List<SugarEntry> _entries = [];

  static const double whoLimit = 50.0; // gram per hari (WHO)

  List<SugarEntry> get entries => List.unmodifiable(_entries);

  /// Entry hari ini saja — auto-reset saat hari berganti
  List<SugarEntry> get todayEntries {
    final today = DateTime.now();
    return _entries.where((e) {
      return e.timestamp.year == today.year &&
          e.timestamp.month == today.month &&
          e.timestamp.day == today.day;
    }).toList();
  }

  /// Total gula hari ini
  double get todayTotal =>
      todayEntries.fold(0, (sum, e) => sum + e.totalSugar);

  /// Progress 0.0 - 1.0 untuk circular indicator
  double get progress => (todayTotal / whoLimit).clamp(0.0, 1.0);

  /// Warna indikator berdasarkan persentase
  Color get indicatorColor {
    final pct = todayTotal / whoLimit;
    if (pct > 1.0) return Colors.redAccent;
    if (pct > 0.7) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  void addEntry(SugarEntry entry) {
    _entries.insert(0, entry); // terbaru di atas
    notifyListeners();
  }
}
