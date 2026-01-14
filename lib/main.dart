import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/firestore_service.dart';
import 'services/sync_service.dart';
import 'services/auth_service.dart';
import 'services/admob_service.dart';
import 'services/encryption_service.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/group_setup_screen.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  // Note: On Android, Firebase will automatically use google-services.json
  await Firebase.initializeApp();

  // Initialize encryption service
  EncryptionService().initialize();

  // Initialize AdMob
  await AdMobService.initialize();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize services
  final firestoreService = FirestoreService();
  final syncService = SyncService(firestoreService);
  await syncService.initialize();

  runApp(
    MyApp(
      firestoreService: firestoreService,
      syncService: syncService,
      prefs: prefs,
    ),
  );
}

class MyApp extends StatelessWidget {
  final FirestoreService firestoreService;
  final SyncService syncService;
  final SharedPreferences prefs;

  const MyApp({
    super.key,
    required this.firestoreService,
    required this.syncService,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(
        firestoreService: firestoreService,
        syncService: syncService,
        prefs: prefs,
      ),
      child: MaterialApp(
        title: 'Spare Change',
        debugShowCheckedModeBanner: false,
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
        home: const AuthWrapper(),
      ),
    );
  }
}

// Separate widget to handle auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // User is signed in, check if they have a group
          return FutureBuilder<Map<String, dynamic>?>(
            future: AuthService().getUserGroup(),
            builder: (context, groupSnapshot) {
              if (groupSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (groupSnapshot.data == null) {
                // User doesn't have a group, show setup screen
                return const GroupSetupScreen();
              }

              // User has a group, show home screen
              return const HomeScreen();
            },
          );
        }

        // User is not signed in, show authentication screen
        return const AuthScreen();
      },
    );
  }
}
