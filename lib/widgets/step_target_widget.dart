import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/activity_controller.dart';

/// Always-visible step target widget.
/// Dynamically updates as sugar intake increases.
class StepTargetWidget extends StatelessWidget {
  const StepTargetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityController>(
      builder: (context, activity, _) {
        final int target = activity.targetSteps;
        final int done = activity.sessionSteps;
        final int remaining = activity.remainingSteps;
        final double progress = activity.stepProgress;
        final bool fullyBurned = activity.isFullyBurned;

        final Color barColor = fullyBurned
            ? Colors.greenAccent
            : progress > 0.7
                ? Colors.tealAccent
                : Colors.tealAccent.withValues(alpha: 0.7);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
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
                        "Steps to Burn Sugar",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (fullyBurned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "🎉 Done!",
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Progress bar
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
                    label: "Done",
                    value: "$done steps",
                    color: Colors.tealAccent,
                  ),
                  _StatChip(
                    label: "Remaining",
                    value: target == 0 ? "—" : "$remaining steps",
                    color: Colors.white54,
                  ),
                  _StatChip(
                    label: "Target",
                    value: target == 0 ? "Scan to set" : "$target steps",
                    color: Colors.white38,
                  ),
                ],
              ),

              // Hint when no sugar yet
              if (target == 0) ...[
                const SizedBox(height: 12),
                Text(
                  "Scan a product to see how many steps you need to burn its sugar.",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
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
