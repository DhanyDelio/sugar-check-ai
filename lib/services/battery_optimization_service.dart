import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';

/// Handles battery optimization whitelist guidance.
/// Shows a one-time dialog that walks the user through disabling
/// battery optimization for this app — required for reliable background
/// step counting on Realme, Xiaomi, OPPO, and other aggressive OEM ROMs.
class BatteryOptimizationService {
  static const String _shownKey = 'battery_opt_dialog_shown';

  /// Returns true if battery optimization is still active (not whitelisted).
  static Future<bool> isOptimizationActive() async {
    if (!Platform.isAndroid) return false;
    // If foreground service can run, battery optimization is likely disabled
    final canSchedule = await FlutterForegroundTask.canScheduleExactAlarms;
    return !canSchedule;
  }

  /// Returns true if the dialog has never been shown before.
  static Future<bool> shouldShowDialog() async {
    if (!Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_shownKey) ?? false);
  }

  /// Mark dialog as shown so it never appears again.
  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shownKey, true);
  }

  /// Opens the system app settings page directly.
  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Show the guided dialog if it hasn't been shown yet.
  /// Call this from HomeScreen after the first frame.
  static Future<void> showIfNeeded(BuildContext context) async {
    if (!await shouldShowDialog()) return;
    if (!context.mounted) return;
    await markShown();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BatteryOptDialog(),
    );
  }
}

class _BatteryOptDialog extends StatelessWidget {
  const _BatteryOptDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Text("🔋", style: TextStyle(fontSize: 22)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Enable Background Steps",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "To count your steps accurately — even when the screen is off — "
            "Doctor Gula needs to be excluded from battery optimization.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _Step(number: "1", text: "Tap \"Open Settings\" below"),
          _Step(number: "2", text: "Tap \"Battery\" or \"Battery Optimization\""),
          _Step(number: "3", text: "Find \"Doctor Gula\" in the list"),
          _Step(number: "4", text: "Select \"Don't optimize\" or \"No restrictions\""),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.tealAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              "💡 This is a one-time setup. You won't be asked again.",
              style: TextStyle(
                color: Colors.tealAccent.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            "Skip",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () async {
            Navigator.of(context).pop();
            await BatteryOptimizationService.openSettings();
          },
          child: const Text(
            "Open Settings",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.tealAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
