import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MEDICAL SAFETY CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

/// WHO reference: maximum safe daily sugar intake.
const double kMaxDailyLimit = 50.0;

/// WHO reference: ideal/recommended daily sugar intake.
const double kIdealDailyLimit = 25.0;

/// Conservative conversion: 1000 steps = 1 gram of sugar offset.
///
/// Rationale: A more aggressive ratio (e.g. 100:1) risks over-estimating
/// caloric burn from low-intensity activity, which could encourage
/// compensatory over-consumption of sugar. 1000:1 is intentionally
/// conservative to prioritise medical safety over user convenience.
const double _stepsPerGram = 1000.0;

/// Maximum sugar credit earnable per day: 15 grams.
///
/// Safety cap rationale: Even with high step counts, we cap the offset at 15g
/// (30% of WHO max limit). This prevents "exercise compensation" behaviour —
/// the well-documented tendency to over-eat after exercise. The cap ensures
/// the app never implicitly endorses consuming more than the WHO limit.
const double _maxCreditGrams = 15.0;

// ─────────────────────────────────────────────────────────────────────────────
// PERSISTENCE KEYS
// ─────────────────────────────────────────────────────────────────────────────

const _keySessionSteps  = 'activity_session_steps';
const _keyUsedCredit    = 'activity_used_credit';
const _keySavedDate     = 'activity_saved_date'; // YYYY-MM-DD

// ─────────────────────────────────────────────────────────────────────────────
// ActivityController
// ─────────────────────────────────────────────────────────────────────────────

/// Manages step tracking and the hidden Sugar Credit system.
///
/// FLOW:
///   Steps accumulate → converted to sugarCredit (capped at 15g, hidden from UI)
///   On scan → SugarProvider calls processSugarIntake()
///            → credit offsets scanned grams before they hit the meter
///            → only the net amount (scanned - credit) enters the visible meter
///
/// The meter never decreases in real-time as the user walks.
/// Credit is only consumed at the moment of a product scan.
class ActivityController extends ChangeNotifier {
  /// Medical disclaimer — must be surfaced in any health-related UI.
  static const String medicalDisclaimer =
      'Doctor Gula adalah alat bantu edukasi kesehatan. '
      'Informasi yang ditampilkan bukan pengganti saran, diagnosis, '
      'atau pengobatan dari tenaga medis profesional. '
      'Selalu konsultasikan kondisi kesehatan Anda dengan dokter.';

  StreamSubscription<StepCount>? _stepSubscription;

  int    _sessionSteps = 0;
  double _usedCredit   = 0; // grams of credit already consumed by scans today
  int    _pedometerBaseline = 0;
  bool   _isTracking   = false;
  bool   _hasPermission = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  int get sessionSteps => _sessionSteps;
  bool get isTracking  => _isTracking;

  /// Total credit earned from steps today (before usage), capped at 15g.
  double get earnedCredit =>
      (_sessionSteps / _stepsPerGram).clamp(0.0, _maxCreditGrams);

  /// Credit still available to offset the next scan.
  double get availableCredit => (earnedCredit - _usedCredit).clamp(0.0, _maxCreditGrams);

  /// Steps still needed to reach the daily credit cap (15g = 15,000 steps).
  int get stepsToMaxCredit =>
      ((_maxCreditGrams - earnedCredit) * _stepsPerGram).round().clamp(0, 15000);

  /// Progress toward the credit cap (0.0 → 1.0).
  double get creditProgress => (earnedCredit / _maxCreditGrams).clamp(0.0, 1.0);

  bool get isCreditCapped => earnedCredit >= _maxCreditGrams;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Called by SugarProvider when user confirms a scan.
  ///
  /// Returns the NET grams that should be added to the visible sugar meter
  /// after applying available credit as an offset.
  ///
  /// Example:
  ///   availableCredit = 5g, scannedGrams = 18g → returns 13g, credit used = 5g
  ///   availableCredit = 20g (capped to 15g), scannedGrams = 10g → returns 0g, credit used = 10g
  double processSugarIntake(double scannedGrams) {
    final double credit = availableCredit;

    if (credit <= 0) {
      // No credit available — full amount hits the meter
      return scannedGrams;
    }

    if (credit >= scannedGrams) {
      // Credit fully covers this scan — meter gets 0
      _usedCredit += scannedGrams;
      _persist();
      notifyListeners();
      return 0.0;
    }

    // Partial offset — meter gets the remainder
    _usedCredit += credit;
    _persist();
    notifyListeners();
    return scannedGrams - credit;
  }

  /// Start step tracking (called on app init).
  /// Restores persisted state and starts the pedometer stream.
  Future<void> startPassiveTracking() async {
    await _restoreState();
    await _requestPermission();
    if (!_hasPermission) return;
    _startPedometer();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String today = _todayKey();
      final String? savedDate = prefs.getString(_keySavedDate);

      if (savedDate != today) {
        // Midnight reset — new day, clear all daily data
        debugPrint("🔄 New day — resetting sugar credit and steps");
        await prefs.remove(_keySessionSteps);
        await prefs.remove(_keyUsedCredit);
        await prefs.setString(_keySavedDate, today);
        _sessionSteps = 0;
        _usedCredit   = 0;
      } else {
        _sessionSteps = prefs.getInt(_keySessionSteps)    ?? 0;
        _usedCredit   = prefs.getDouble(_keyUsedCredit)   ?? 0;
      }

      debugPrint(
          "📦 Restored activity: steps=$_sessionSteps "
          "earnedCredit=${earnedCredit.toStringAsFixed(2)}g "
          "usedCredit=${_usedCredit.toStringAsFixed(2)}g "
          "availableCredit=${availableCredit.toStringAsFixed(2)}g");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Activity restore error: $e");
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySessionSteps,    _sessionSteps);
      await prefs.setDouble(_keyUsedCredit,   _usedCredit);
      await prefs.setString(_keySavedDate,    _todayKey());
    } catch (e) {
      debugPrint("❌ Activity persist error: $e");
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _startPedometer() {
    _stepSubscription?.cancel();
    _pedometerBaseline = 0;
    _isTracking = true;
    notifyListeners();

    _stepSubscription = Pedometer.stepCountStream.listen(
      _onStep,
      onError: (e) => debugPrint("❌ Pedometer error: $e"),
      cancelOnError: false,
    );
    debugPrint("👟 Step tracking started (1000 steps = 1g credit, cap 15g)");
  }

  void _onStep(StepCount event) {
    if (_pedometerBaseline == 0) {
      _pedometerBaseline = event.steps - _sessionSteps;
      debugPrint("📍 Baseline set: $_pedometerBaseline");
    }
    final int steps = event.steps - _pedometerBaseline;
    if (steps <= _sessionSteps) return;
    _sessionSteps = steps;
    _persist();
    notifyListeners();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.activityRecognition.request();
    _hasPermission = status.isGranted;
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    super.dispose();
  }
}
