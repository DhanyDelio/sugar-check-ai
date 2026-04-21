import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
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

const _keySessionSteps = 'activity_session_steps';
const _keyUsedCredit   = 'activity_used_credit';
const _keySavedDate    = 'activity_saved_date';

// ─────────────────────────────────────────────────────────────────────────────
// FOREGROUND TASK HANDLER
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_StepTaskHandler());
}

class _StepTaskHandler extends TaskHandler {
  StreamSubscription<StepCount>? _sub;
  int _baseline = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_keySessionSteps) ?? 0;

    _sub = Pedometer.stepCountStream.listen(
      (event) async {
        if (_baseline == 0) {
          _baseline = event.steps - saved;
        }
        final steps = event.steps - _baseline;
        final current = prefs.getInt(_keySessionSteps) ?? 0;
        if (steps > current) {
          await prefs.setInt(_keySessionSteps, steps);
          FlutterForegroundTask.updateService(
            notificationText: 'Steps today: $steps',
          );
        }
      },
      onError: (e) => debugPrint("❌ FG pedometer error: $e"),
      cancelOnError: false,
    );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Keep-alive ping
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _sub?.cancel();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ActivityController
// ─────────────────────────────────────────────────────────────────────────────

class ActivityController extends ChangeNotifier {
  /// Medical disclaimer — must be surfaced in any health-related UI.
  static const String medicalDisclaimer =
      'Doctor Gula adalah alat bantu edukasi kesehatan. '
      'Informasi yang ditampilkan bukan pengganti saran, diagnosis, '
      'atau pengobatan dari tenaga medis profesional. '
      'Selalu konsultasikan kondisi kesehatan Anda dengan dokter.';

  StreamSubscription<StepCount>? _stepSubscription;
  Timer? _syncTimer;

  int    _sessionSteps = 0;
  double _usedCredit   = 0;
  int    _pedometerBaseline = 0;
  bool   _isTracking   = false;
  bool   _hasPermission = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  int    get sessionSteps   => _sessionSteps;
  bool   get isTracking     => _isTracking;

  double get earnedCredit =>
      (_sessionSteps / _stepsPerGram).clamp(0.0, _maxCreditGrams);

  double get availableCredit =>
      (earnedCredit - _usedCredit).clamp(0.0, _maxCreditGrams);

  int get stepsToMaxCredit =>
      ((_maxCreditGrams - earnedCredit) * _stepsPerGram).round().clamp(0, 15000);

  double get creditProgress =>
      (earnedCredit / _maxCreditGrams).clamp(0.0, 1.0);

  bool get isCreditCapped => earnedCredit >= _maxCreditGrams;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Applies available credit against scanned sugar.
  /// Returns net grams to add to the visible meter.
  double processSugarIntake(double scannedGrams) {
    final double credit = availableCredit;
    if (credit <= 0) return scannedGrams;

    if (credit >= scannedGrams) {
      _usedCredit += scannedGrams;
      _persist();
      notifyListeners();
      return 0.0;
    }

    _usedCredit += credit;
    _persist();
    notifyListeners();
    return scannedGrams - credit;
  }

  /// Start step tracking with foreground service for background reliability.
  Future<void> startPassiveTracking() async {
    await _restoreState();
    await _requestPermission();
    if (!_hasPermission) return;
    await _initForegroundTask();
    _startPedometer();
    _startSyncTimer();
  }

  // ── Foreground Task ───────────────────────────────────────────────────────

  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'doctor_gula_steps',
        channelName: 'Step Tracking',
        channelDescription: 'Keeps step counting active in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showBadge: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: true,
        allowWakeLock: true,
      ),
    );

    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: 'Doctor Gula',
        notificationText: 'Counting your steps...',
        callback: startCallback,
      );
      debugPrint("🚀 Foreground service started");
    }
  }

  /// Periodically sync steps written by foreground isolate into main isolate.
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_keySessionSteps) ?? 0;
      if (saved > _sessionSteps) {
        _sessionSteps = saved;
        notifyListeners();
      }
    });
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String today = _todayKey();
      final String? savedDate = prefs.getString(_keySavedDate);

      if (savedDate != today) {
        debugPrint("🔄 New day — resetting sugar credit and steps");
        await prefs.remove(_keySessionSteps);
        await prefs.remove(_keyUsedCredit);
        await prefs.setString(_keySavedDate, today);
        _sessionSteps = 0;
        _usedCredit   = 0;
      } else {
        _sessionSteps = prefs.getInt(_keySessionSteps)  ?? 0;
        _usedCredit   = prefs.getDouble(_keyUsedCredit) ?? 0;
      }

      debugPrint(
          "📦 Restored: steps=$_sessionSteps "
          "earned=${earnedCredit.toStringAsFixed(2)}g "
          "available=${availableCredit.toStringAsFixed(2)}g");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Activity restore error: $e");
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySessionSteps,   _sessionSteps);
      await prefs.setDouble(_keyUsedCredit,  _usedCredit);
      await prefs.setString(_keySavedDate,   _todayKey());
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

  // ── Pedometer (main isolate — active when app is foreground) ──────────────

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
    debugPrint("👟 Pedometer started (1000 steps = 1g credit, cap 15g)");
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
    _syncTimer?.cancel();
    super.dispose();
  }
}
