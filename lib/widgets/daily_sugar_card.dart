import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Animated circular sugar intake card
class DailySugarCard extends StatefulWidget {
  final double consumed;
  final double limit;

  const DailySugarCard({
    super.key,
    required this.consumed,
    required this.limit,
  });

  @override
  State<DailySugarCard> createState() => _DailySugarCardState();
}

class _DailySugarCardState extends State<DailySugarCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnim;
  double _prevProgress = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _buildAnimation(0, _progress);
    _animController.forward();
  }

  @override
  void didUpdateWidget(DailySugarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consumed != widget.consumed ||
        oldWidget.limit != widget.limit) {
      _buildAnimation(_prevProgress, _progress);
      _animController.forward(from: 0);
    }
  }

  double get _progress =>
      widget.limit > 0 ? (widget.consumed / widget.limit).clamp(0.0, 1.0) : 0;

  void _buildAnimation(double from, double to) {
    _prevProgress = to;
    _progressAnim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  Color _progressColor(double progress) {
    if (progress >= 1.0) return Colors.redAccent;
    if (progress >= 0.7) return Colors.orangeAccent;
    return Colors.tealAccent;
  }

  String _statusMessage(double progress) {
    if (widget.consumed == 0) return "No sugar intake yet";
    return "${(progress * 100).toStringAsFixed(0)}% of your daily limit used";
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (context, _) {
        final double p = _progressAnim.value;
        final Color color = _progressColor(p);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Circular progress
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: p,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${widget.consumed.toStringAsFixed(0)}g",
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          "Daily Sugar Intake",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Consumed / Limit
              Text(
                "${widget.consumed.toStringAsFixed(0)} / ${widget.limit.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),

              // Status message
              Text(
                _statusMessage(p),
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
