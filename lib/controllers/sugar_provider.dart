import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sugar_entry.dart';
import 'activity_controller.dart';

class SugarProvider extends ChangeNotifier {
  final List<SugarEntry> _entries = [];
  ActivityController? _activityController;
  static const String _storageKey = 'sugar_entries';
  static const double whoLimit = 50.0;

  SugarProvider() {
    _loadFromStorage();
  }

  /// Inject ActivityController so sugar changes auto-update step target.
  /// Also immediately syncs the sugar target in case entries were already loaded.
  void setActivityController(ActivityController controller) {
    _activityController = controller;
    // Sync target after current build frame completes — avoids setState during build
    if (todayTotal > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.updateSugarTarget(todayTotal);
      });
    }
  }

  List<SugarEntry> get entries => todayEntries;

  /// Today's entries only — old entries are purged from memory on access
  List<SugarEntry> get todayEntries {
    final today = DateTime.now();
    _purgeOldEntries(today);
    return _entries.where((e) =>
        e.timestamp.year == today.year &&
        e.timestamp.month == today.month &&
        e.timestamp.day == today.day).toList();
  }

  double get todayTotal =>
      todayEntries.fold(0, (sum, e) => sum + e.totalSugar);

  double get progress => (todayTotal / whoLimit).clamp(0.0, 1.0);

  Color get indicatorColor {
    final pct = todayTotal / whoLimit;
    if (pct > 1.0) return Colors.redAccent;
    if (pct > 0.7) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  void addEntry(SugarEntry entry) {
    _entries.insert(0, entry);
    notifyListeners();
    _saveToStorage();
    // Reactively update step target whenever sugar total changes
    _activityController?.updateSugarTarget(todayTotal);
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  /// Load entries from local storage on app start.
  /// Only today's entries are kept — yesterday's data is discarded (smart reset).
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_storageKey);
      if (raw == null) return;

      final List<dynamic> jsonList = jsonDecode(raw);
      final today = DateTime.now();

      for (final item in jsonList) {
        final SugarEntry entry = SugarEntry.fromJson(item as Map<String, dynamic>);
        // Smart reset: only load today's entries — yesterday resets the meter
        if (entry.timestamp.year == today.year &&
            entry.timestamp.month == today.month &&
            entry.timestamp.day == today.day) {
          _entries.add(entry);
        }
      }

      debugPrint("📦 Loaded ${_entries.length} entries from storage");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Storage load error: $e");
    }
  }

  /// Persist today's entries to local storage.
  /// Only imageUrl is saved — imageBytes are excluded to keep storage lean.
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList =
          todayEntries.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
      debugPrint("💾 Saved ${jsonList.length} entries to storage");
    } catch (e) {
      debugPrint("❌ Storage save error: $e");
    }
  }

  /// Remove entries from previous days to free memory
  void _purgeOldEntries(DateTime today) {
    final before = _entries.length;
    _entries.removeWhere((e) =>
        e.timestamp.year != today.year ||
        e.timestamp.month != today.month ||
        e.timestamp.day != today.day);
    if (_entries.length < before) {
      debugPrint("🧹 Purged ${before - _entries.length} old entries from memory");
      _saveToStorage();
    }
  }
}
