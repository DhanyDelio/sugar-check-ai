import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1g sugar = 4 kcal, 1 step = 0.04 kcal → 100 steps per gram
const double _stepsPerGram = 100.0;
const double _gramsPerStep = 1.0 / _stepsPerGram;

const _keyTotalSugar   = 'activity_total_sugar';
const _keySessionSteps = 'activity_session_steps';
const _keySavedDate    = 'activity_saved_date'; // YYYY-MM-DD

class ActivityController extends ChangeNotifier {
  StreamSubscription<StepCount>? _stepSubscription;

  double _totalSugar = 0;
  int _sessionSteps = 0;
  int _pedometerBaseline = 0;
  bool _isTracking = false;
  bool _hasPermission = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  double get initialSugar  => _totalSugar;
  int    get sessionSteps  => _sessionSteps;
  bool   get isTracking    => _isTracking;

  /// Steps needed to burn all current sugar
  int get targetSteps => (_totalSugar * _stepsPerGram).round();

  /// Steps still needed (never below 0)
  int get remainingSteps =>
      (targetSteps - _sessionSteps).clamp(0, targetSteps);

  /// Sugar already burned by steps taken
  double get burnedSugar =>
      (_sessionSteps * _gramsPerStep).clamp(0.0, _totalSugar);

  /// Sugar still remaining after steps
  double get remainingSugar =>
      (_totalSugar - burnedSugar).clamp(0.0, _totalSugar);

  /// Progress of steps vs target (0.0 → 1.0)
  double get stepProgress =>
      targetSteps > 0
          ? (_sessionSteps / targetSteps).clamp(0.0, 1.0)
          : 0.0;

  bool get isFullyBurned => _totalSugar > 0 && remainingSugar <= 0;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Called every time sugar total changes (new scan confirmed).
  /// Steps already taken are preserved — target just increases.
  void updateSugarTarget(double totalSugar) {
    _totalSugar = totalSugar;
    _persist();
    debugPrint(
        "🎯 Sugar target updated: ${totalSugar}g → $targetSteps steps needed");
    notifyListeners();

    if (!_isTracking) _startPedometer();
  }

  /// Start step tracking (called on app init).
  /// Also restores persisted state from previous session.
  Future<void> startPassiveTracking() async {
    await _restoreState();
    if (_isTracking) return;
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

      // Smart reset: if saved date is not today, discard step progress
      // but keep sugar target (entries are still today's)
      if (savedDate != today) {
        debugPrint("🔄 New day — resetting session steps");
        await prefs.remove(_keySessionSteps);
        await prefs.setString(_keySavedDate, today);
        _sessionSteps = 0;
      } else {
        _sessionSteps = prefs.getInt(_keySessionSteps) ?? 0;
      }

      _totalSugar = prefs.getDouble(_keyTotalSugar) ?? 0;

      debugPrint(
          "📦 Restored activity: sugar=${_totalSugar}g steps=$_sessionSteps");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Activity restore error: $e");
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyTotalSugar, _totalSugar);
      await prefs.setInt(_keySessionSteps, _sessionSteps);
      await prefs.setString(_keySavedDate, _todayKey());
    } catch (e) {
      debugPrint("❌ Activity persist error: $e");
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
    debugPrint("👟 Step tracking started");
  }

  void _onStep(StepCount event) {
    if (_pedometerBaseline == 0) {
      // Set baseline so new steps are counted relative to where we left off
      _pedometerBaseline = event.steps - _sessionSteps;
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
