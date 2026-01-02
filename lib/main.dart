import 'package:flutter/material.dart';
import 'app_state.dart';

import 'screens/welcome_screen.dart';
import 'screens/gender_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_section_screen.dart';
import 'screens/exercise_selection_screen.dart';
import 'screens/setup_mode_screen.dart';
import 'screens/streak_screen.dart';
import 'screens/history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) {
    return Material(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            details.exceptionAsString(),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppState _state = AppState();

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: _state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (_) => const WelcomeFlowScreen(),
          '/gender': (_) => const GenderScreen(),
          '/profile': (_) => const ProfileSetUpScreen(),
          '/home': (_) => const HomeScreen(initialTab: 0),
          '/profile_section': (_) => const ProfileSectionScreen(),
          '/streak': (_) => const StreakScreen(),
          '/history': (_) => const HistoryScreen(),

          '/exercise_select': (_) => const ExerciseSelectionScreen(),
          '/setup_mode': (_) => const SetupModeScreen(),
        },
      ),
    );
  }
}
