import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('tonecraft_onboarding_done') ?? false;

  runApp(ToneCraftApp(showOnboarding: !onboardingDone));
}

class ToneCraftApp extends StatelessWidget {
  final bool showOnboarding;

  const ToneCraftApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToneCraft',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: _buildTheme(),
      theme: _buildTheme(),
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0A14),
      fontFamily: 'Outfit',
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFBF5AF2),
        secondary: Color(0xFF0AE8F0),
        surface: Color(0xFF12121F),
        onPrimary: Colors.white,
        onSecondary: Color(0xFF0A0A14),
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0A14),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: 'Outfit',
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E1E30),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Outfit',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}
