import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// Conversion constants
/// 1g sugar = 4 kcal, 1 step = 0.04 kcal → 1g sugar = 100 steps
const double _kcalPerGram = 4.0;
const double _kcalPerStep = 0.04;
const double _stepsPerGram = _kcalPerGram / _kcalPerStep; // 100 steps/gram
const double _gramsPerStep = 1.0 / _stepsPerGram;         // 0.01 gram/step

class ActivityController extends ChangeNotifier {
  StreamSubscription<StepCount>? _stepSubscription;

  double _initialSugar = 0;
  double _remainingSugar = 0;
  int _sessionSteps = 0;
  int _pedometerBaseline = 0;
  bool _isTracking = false;
  bool _hasPermission = false;

  double get remainingSugar => _remainingSugar.clamp(0, double.infinity);
  double get initialSugar => _initialSugar;
  int get sessionSteps => _sessionSteps;
  int get targetSteps => (_initialSugar * _stepsPerGram).round();
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;

  /// Progress 0.0 → 1.0 (how much sugar is left)
  double get sugarProgress =>
      _initialSugar > 0 ? (remainingSugar / _initialSugar).clamp(0.0, 1.0) : 0.0;

  /// Start tracking steps for a given sugar amount
  Future<void> startTracking(double sugarGrams) async {
    await _requestPermission();
    if (!_hasPermission) return;

    _initialSugar = sugarGrams;
    _remainingSugar = sugarGrams;
    _sessionSteps = 0;
    _pedometerBaseline = 0;
    _isTracking = true;
    notifyListeners();

    _stepSubscription?.cancel();
    _stepSubscription = Pedometer.stepCountStream.listen(
      _onStep,
      onError: _onError,
      cancelOnError: false,
    );

    debugPrint("🏃 Activity tracking started: ${sugarGrams}g → $targetSteps steps target");
  }

  void _onStep(StepCount event) {
    if (_pedometerBaseline == 0) {
      // First event — set baseline so we count from 0
      _pedometerBaseline = event.steps;
    }

    final int newSessionSteps = event.steps - _pedometerBaseline;
    if (newSessionSteps <= _sessionSteps) return;

    final int delta = newSessionSteps - _sessionSteps;
    _sessionSteps = newSessionSteps;

    updateRemainingSugar(_sessionSteps);
  }

  void _onError(dynamic error) {
    debugPrint("❌ Pedometer error: $error");
  }

  /// Calculate remaining sugar based on steps taken.
  /// Sugar decreases by 0.01g per step, never below 0.
  void updateRemainingSugar(int stepsTaken) {
    final double burned = stepsTaken * _gramsPerStep;
    _remainingSugar = (_initialSugar - burned).clamp(0.0, _initialSugar);
    notifyListeners();
  }

  void stopTracking() {
    _stepSubscription?.cancel();
    _isTracking = false;
    notifyListeners();
    debugPrint("⏹ Activity tracking stopped");
  }

  Future<void> _requestPermission() async {
    final status = await Permission.activityRecognition.request();
    _hasPermission = status.isGranted;
    if (!_hasPermission) {
      debugPrint("❌ Activity recognition permission denied");
    }
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    super.dispose();
  }
}
