import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'core/navigation/navigation_service.dart';
import 'controllers/sugar_provider.dart';
import 'controllers/activity_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SugarProvider()),
        ChangeNotifierProvider(create: (_) => ActivityController()),
        ChangeNotifierProxyProvider<ActivityController, SugarProvider>(
          create: (_) => SugarProvider(),
          update: (_, activity, sugar) {
            sugar!.setActivityController(activity);
            return sugar;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Doctor Gula',
        navigatorKey: NavigationService.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF12121A),
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.tealAccent,
            brightness: Brightness.dark,
            surface: const Color(0xFF1E1E2E),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: const Color(0xFF1A1A2E),
            indicatorColor: Colors.tealAccent.withOpacity(0.15),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600);
              }
              return TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11);
            }),
          ),
          useMaterial3: true,
        ),
        home: MainScreen(key: MainScreen.globalKey),
      ),
    );
  }
}
