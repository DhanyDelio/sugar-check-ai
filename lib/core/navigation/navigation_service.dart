import 'package:flutter/material.dart';

class NavigationService {
  // 1. Key to enable navigation from anywhere in the application
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // 2. Function to push a new screen onto the navigation stack
  static Future<dynamic> navigateTo(Widget screen) {
    return navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // 3. Function to replace the current screen with a new one
  static Future<dynamic> replaceWith(Widget screen) {
    return navigatorKey.currentState!.pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // 4. Function to manually go back to the previous screen
  static void goBack() {
    if (navigatorKey.currentState!.canPop()) {
      navigatorKey.currentState!.pop();
    }
  }
}
