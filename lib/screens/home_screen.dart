import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/activity_controller.dart';
import '../controllers/sugar_provider.dart';
import '../widgets/consumption_log_widget.dart';
import '../widgets/daily_sugar_card.dart';
import '../widgets/step_target_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _dailyLimit = 50.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityController>().startPassiveTracking();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      body: SafeArea(
        child: Consumer<SugarProvider>(
          builder: (context, sugar, _) {
            final double consumed = sugar.todayTotal;
            final entries = sugar.todayEntries;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  const Text(
                    "Hello 👋",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Daily Sugar Intake",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Daily Sugar Card ─────────────────────────────────────
                  DailySugarCard(
                    consumed: consumed,
                    limit: _dailyLimit,
                  ),
                  const SizedBox(height: 24),

                  // ── Step Target ──────────────────────────────────────────
                  const StepTargetWidget(),
                  const SizedBox(height: 24),

                  // ── Today's Consumption ──────────────────────────────────
                  ConsumptionLogWidget(entries: entries),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
