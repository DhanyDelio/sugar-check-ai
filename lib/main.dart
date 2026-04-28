import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'amplifyconfiguration.dart';
import 'core/app_colors.dart';
import 'screens/main_screen.dart';
import 'core/navigation/navigation_service.dart';
import 'controllers/sugar_provider.dart';
import 'controllers/activity_controller.dart';

Future<void> _configureAmplify() async {
  try {
    await Amplify.addPlugins([
      AmplifyAuthCognito(),
      AmplifyStorageS3(),
    ]);
    await Amplify.configure(amplifyconfig);
    debugPrint("✅ Amplify configured successfully");
  } on AmplifyAlreadyConfiguredException {
    debugPrint("⚠️ Amplify already configured — skipping");
  } catch (e) {
    debugPrint("❌ Amplify configuration error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  await _configureAmplify();
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
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.tealAccent,
            brightness: Brightness.dark,
            surface: AppColors.card,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: AppColors.navBar,
            indicatorColor: Colors.tealAccent.withValues(alpha: 0.15),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600);
              }
              return TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11);
            }),
          ),
          useMaterial3: true,
        ),
        home: MainScreen(key: MainScreen.globalKey),
      ),
    );
  }
}
