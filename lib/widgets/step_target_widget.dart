import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/activity_controller.dart';
import '../core/app_colors.dart';

/// Displays the user's daily step progress and sugar credit status.
///
/// Credit is hidden from the user as a raw number — instead we show
/// progress toward the daily cap and a motivational label.
class StepTargetWidget extends StatelessWidget {
  const StepTargetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityController>(
      builder: (context, activity, _) {
        final int steps        = activity.sessionSteps;
        final double credit    = activity.availableCredit;
        final double progress  = activity.creditProgress;
        final bool capped      = activity.isCreditCapped;

        final Color barColor = capped
            ? Colors.greenAccent
            : progress > 0.6
                ? Colors.tealAccent
                : Colors.tealAccent.withValues(alpha: 0.7);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_walk,
                          color: Colors.tealAccent, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        "Activity Offset",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (capped)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "🎉 Max reached!",
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Progress bar toward credit cap
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 10),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatChip(
                    label: "Steps today",
                    value: _formatSteps(steps),
                    color: Colors.tealAccent,
                  ),
                  _StatChip(
                    label: "Credit available",
                    value: credit > 0
                        ? "${credit.toStringAsFixed(1)}g"
                        : "0g",
                    color: credit > 0 ? Colors.greenAccent : Colors.white38,
                  ),
                  _StatChip(
                    label: "To max offset",
                    value: capped
                        ? "Done"
                        : "${activity.stepsToMaxCredit} steps",
                    color: Colors.white38,
                  ),
                ],
              ),

              // Hint
              const SizedBox(height: 12),
              Text(
                capped
                    ? "Daily offset cap reached. Keep walking for your health! 💪"
                    : "Steps you walk today will offset sugar from your next scan.",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return "${(steps / 1000).toStringAsFixed(1)}k";
    }
    return "$steps";
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}
