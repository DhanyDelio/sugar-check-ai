import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/activity_controller.dart';

/// Real-time sugar burn meter — shows remaining sugar as user walks.
/// Integrates with [ActivityController] via ChangeNotifier.
class SugarBurnWidget extends StatelessWidget {
  const SugarBurnWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityController>(
      builder: (context, activity, _) {
        if (!activity.isTracking) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_walk,
                      color: Colors.tealAccent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    "Burning Sugar",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Circular meter
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: activity.sugarProgress,
                      strokeWidth: 10,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _meterColor(activity.sugarProgress),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${activity.remainingSugar.toStringAsFixed(1)}g",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _meterColor(activity.sugarProgress),
                        ),
                      ),
                      Text(
                        "remaining",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Step counter
              Text(
                "Step ${activity.sessionSteps} / ${activity.targetSteps}",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.55),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),

              // Linear progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1.0 - activity.sugarProgress,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _meterColor(activity.sugarProgress),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("0 steps",
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.3))),
                  Text("${activity.targetSteps} steps",
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.3))),
                ],
              ),

              // Done state
              if (activity.remainingSugar <= 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "🎉 Sugar fully burned!",
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _meterColor(double progress) {
    if (progress > 0.7) return Colors.tealAccent;
    if (progress > 0.3) return Colors.orangeAccent;
    return Colors.greenAccent;
  }
}
