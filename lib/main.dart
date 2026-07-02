import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/local_storage_service.dart';
import 'services/admob_service.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/animated_splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage (Hive)
  await LocalStorageService.init();

  // Initialize AdMob
  await AdMobService.initialize();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(
        localStorageService: LocalStorageService(),
        prefs: prefs,
      ),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final themeMode = provider.themeMode == 'Light'
              ? ThemeMode.light
              : provider.themeMode == 'Dark'
              ? ThemeMode.dark
              : ThemeMode.system;

          return MaterialApp(
            title: 'Spare Change',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.green,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
              cardTheme: const CardThemeData(elevation: 2),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.green,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
              cardTheme: const CardThemeData(elevation: 2),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            home: const AnimatedSplashScreen(child: HomeScreen()),
          );
        },
      ),
    );
  }
}
