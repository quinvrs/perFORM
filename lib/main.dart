import 'package:flutter/material.dart';

import 'app_state.dart';

import 'models/workout.dart';
import 'models/workout_plan.dart';

import 'screens/welcome_screen.dart';
import 'screens/gender_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_section_screen.dart';
import 'screens/exercise_selection_screen.dart';
import 'screens/setup_mode_screen.dart';
import 'screens/exercise_screen.dart';
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

        // ✅ handle routes that REQUIRE arguments
        onGenerateRoute: (settings) {
          // /setup_mode expects Workout
          if (settings.name == '/setup_mode') {
            final workout = settings.arguments as Workout;
            return MaterialPageRoute(
              builder: (_) => SetupModeScreen(workout: workout),
            );
          }

          // /exercise expects ExerciseArgs(workout, plan)
          if (settings.name == '/exercise') {
            final args = settings.arguments as ExerciseArgs;
            return MaterialPageRoute(
              builder: (_) => ExerciseScreen(
                workout: args.workout,
                plan: args.plan,
              ),
            );
          }

          return null; // let routes map handle others
        },

        routes: {
          '/': (_) => const WelcomeFlowScreen(),
          '/gender': (_) => const GenderScreen(),
          '/profile': (_) => const ProfileSetUpScreen(),
          '/home': (_) => const HomeScreen(initialTab: 0),
          '/profile_section': (_) => const ProfileSectionScreen(),
          '/streak': (_) => const StreakScreen(),
          '/history': (_) => const HistoryScreen(),
          '/exercise_select': (_) => const ExerciseSelectionScreen(),

        },
      ),
    );
  }
}

class ExerciseArgs {
  final Workout workout;
  final WorkoutPlan plan;
  const ExerciseArgs({required this.workout, required this.plan});
}
