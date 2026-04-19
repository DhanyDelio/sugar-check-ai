import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// 1g sugar = 4 kcal, 1 step = 0.04 kcal → 100 steps per gram
const double _stepsPerGram = 100.0;
const double _gramsPerStep = 1.0 / _stepsPerGram;

class ActivityController extends ChangeNotifier {
  StreamSubscription<StepCount>? _stepSubscription;

  double _totalSugar = 0;   // reactive — updates when user adds more sugar
  int _sessionSteps = 0;
  int _pedometerBaseline = 0;
  bool _isTracking = false;
  bool _hasPermission = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  int get sessionSteps => _sessionSteps;
  bool get isTracking => _isTracking;

  /// Steps needed to burn all current sugar
  int get targetSteps => (_totalSugar * _stepsPerGram).round();

  /// Steps still needed (never below 0)
  int get remainingSteps => (targetSteps - _sessionSteps).clamp(0, targetSteps);

  /// Sugar already burned by steps taken
  double get burnedSugar =>
      (_sessionSteps * _gramsPerStep).clamp(0.0, _totalSugar);

  /// Sugar still remaining after steps
  double get remainingSugar =>
      (_totalSugar - burnedSugar).clamp(0.0, _totalSugar);

  /// Progress of steps vs target (0.0 → 1.0)
  double get stepProgress =>
      targetSteps > 0 ? (_sessionSteps / targetSteps).clamp(0.0, 1.0) : 0.0;

  bool get isFullyBurned => _totalSugar > 0 && remainingSugar <= 0;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Called every time sugar total changes (new scan confirmed).
  /// Steps already taken are preserved — target just increases.
  void updateSugarTarget(double totalSugar) {
    _totalSugar = totalSugar;
    debugPrint("🎯 Sugar target updated: ${totalSugar}g → $targetSteps steps needed");
    notifyListeners();

    // Auto-start tracking if not already running
    if (!_isTracking) _startPedometer();
  }

  /// Start step tracking (called on app init)
  Future<void> startPassiveTracking() async {
    if (_isTracking) return;
    await _requestPermission();
    if (!_hasPermission) return;
    _startPedometer();
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
      _pedometerBaseline = event.steps;
    }
    final int steps = event.steps - _pedometerBaseline;
    if (steps <= _sessionSteps) return;
    _sessionSteps = steps;
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
