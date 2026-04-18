import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import '../widgets/bottom_nav_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static final GlobalKey<_MainScreenState> globalKey = GlobalKey<_MainScreenState>();

  static void switchToHome() {
    globalKey.currentState?._switchTab(0);
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ScanScreen(),
  ];

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0
          ? const HomeScreen()
          : const ScanScreen(),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _switchTab,
      ),
    );
  }
}
