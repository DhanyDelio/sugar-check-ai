import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/sugar_provider.dart';

class SugarMeterWidget extends StatelessWidget {
  const SugarMeterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SugarProvider>();
    final total = provider.todayTotal;
    final color = provider.indicatorColor;
    final progress = provider.progress;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${total.toStringAsFixed(1)}g",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    "/ ${SugarProvider.whoLimit.toInt()}g",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _statusLabel(progress),
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "WHO daily limit: ${SugarProvider.whoLimit.toInt()}g",
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(double progress) {
    if (progress > 1.0) return "🚨 Daily limit exceeded!";
    if (progress > 0.7) return "⚠️ Approaching limit — be careful";
    return "✅ You're doing great";
  }
}
