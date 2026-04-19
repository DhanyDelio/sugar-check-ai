import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/activity_controller.dart';
import '../controllers/sugar_provider.dart';
import '../widgets/sugar_burn_widget.dart';
import '../widgets/sugar_meter_widget.dart';
import '../widgets/sugar_history_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Doctor Gula",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Track your daily sugar intake",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
              const SizedBox(height: 24),

              const SugarMeterWidget(),
              const SizedBox(height: 16),

              // Start walking button — appears when there's sugar to burn
              Consumer2<SugarProvider, ActivityController>(
                builder: (context, sugar, activity, _) {
                  if (sugar.todayTotal <= 0 || activity.isTracking) {
                    return const SizedBox.shrink();
                  }
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.tealAccent,
                        side: const BorderSide(color: Colors.tealAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.directions_walk, size: 18),
                      label: Text(
                        "Burn ${sugar.todayTotal.toStringAsFixed(1)}g with walking",
                      ),
                      onPressed: () =>
                          activity.startTracking(sugar.todayTotal),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Real-time burn meter
              const SugarBurnWidget(),
              const SizedBox(height: 28),

              Text(
                "Today's History",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 12),

              const SugarHistoryWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
