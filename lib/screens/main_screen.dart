import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'scan_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static final GlobalKey<_MainScreenState> globalKey =
      GlobalKey<_MainScreenState>();

  static void switchToHome() {
    globalKey.currentState?._switchTab(0);
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      body: _currentIndex == 0 ? const HomeScreen() : const ScanScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _switchTab,
          backgroundColor: Colors.transparent,
          indicatorColor: Colors.tealAccent.withOpacity(0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.white38),
              selectedIcon:
                  Icon(Icons.home_rounded, color: Colors.tealAccent),
              label: "Home",
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined,
                  color: Colors.white38),
              selectedIcon:
                  Icon(Icons.qr_code_scanner, color: Colors.tealAccent),
              label: "Scan",
            ),
          ],
        ),
      ),
    );
  }
}
