import 'package:flutter/material.dart';
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
