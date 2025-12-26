import 'package:flutter/material.dart';
import '../models/workout.dart';
import 'setup_mode_screen.dart';

class ExerciseSelectionScreen extends StatefulWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  State<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  static const _bgDark = Color.fromARGB(255, 18, 32, 47);
  static const _ink = Color(0xFF051328);
  static const _muted = Color(0xFF797B7F);
  static const _green = Color(0xFF00C951);

  final workouts = const <Workout>[
    Workout(
      title: 'Squats',
      subtitle: 'Lower Body Strength',
      benefits: [
        'Builds lower body strength and muscle mass',
        'Improves core stability and balance',
        'Enhances athletic performance',
        'Burns calories and boosts metabolism',
      ],
    ),
    Workout(
      title: 'Jumping Jacks',
      subtitle: 'Lower Body Strength',
      benefits: [
        'Improves cardiovascular endurance',
        'Warms up full body quickly',
        'Boosts coordination and rhythm',
        'Burns calories efficiently',
      ],
    ),
  ];

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Center(
        child: LayoutBuilder(
          builder: (context, c) {
            final cardW = (c.maxWidth * 0.92).clamp(320.0, 375.0);
            final cardH = cardW * (812 / 375);
            final s = cardW / 375;

            return ClipRRect(
              borderRadius: BorderRadius.circular(40 * s),
              child: Container(
                width: cardW,
                height: cardH,
                color: Colors.white,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(24 * s, 36 * s, 24 * s, 140 * s),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 56 * s,
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: InkWell(
                                      onTap: () => Navigator.pop(context),
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: _ink,
                                        size: 28 * s,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: Text(
                                      'Select Your\nWorkout',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _ink,
                                        fontSize: 24 * s,
                                        fontFamily: 'DM Sans',
                                        fontWeight: FontWeight.w700,
                                        height: 1.05,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 26 * s),

                            _WorkoutCard(
                              s: s,
                              workout: workouts[0],
                              selected: selectedIndex == 0,
                              showBenefits: true,
                              onTap: () => setState(() => selectedIndex = 0),
                              muted: _muted,
                              green: _green,
                            ),
                            SizedBox(height: 22 * s),
                            _WorkoutCard(
                              s: s,
                              workout: workouts[1],
                              selected: selectedIndex == 1,
                              showBenefits: false,
                              onTap: () => setState(() => selectedIndex = 1),
                              muted: _muted,
                              green: _green,
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      left: 24 * s,
                      right: 24 * s,
                      bottom: 38 * s,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SetupModeScreen()),
                            );
                        },
                        child: Container(
                          height: 71 * s,
                          decoration: BoxDecoration(
                            color: _ink,
                            borderRadius: BorderRadius.circular(15 * s),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Start Exercise',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24 * s,
                              fontFamily: 'DM Sans',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.s,
    required this.workout,
    required this.selected,
    required this.onTap,
    required this.showBenefits,
    required this.muted,
    required this.green,
  });

  final double s;
  final Workout workout;
  final bool selected;
  final VoidCallback onTap;
  final bool showBenefits;
  final Color muted;
  final Color green;

  static const _yellow = Color(0xFFFEF9C2);

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _yellow.withValues(alpha: 0.50) : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 317 * s,
        padding: EdgeInsets.all(14 * s),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10 * s),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
          border: selected ? Border.all(color: const Color(0x33051328)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workout.title,
              style: TextStyle(
                color: Colors.black,
                fontSize: 24 * s,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2 * s),
            Text(
              workout.subtitle,
              style: TextStyle(
                color: muted,
                fontSize: 14 * s,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
            if (showBenefits) ...[
              SizedBox(height: 14 * s),
              Text(
                'Benefits',
                style: TextStyle(
                  color: muted,
                  fontSize: 11 * s,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 6 * s),
              for (final b in workout.benefits)
                Padding(
                  padding: EdgeInsets.only(bottom: 4 * s),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✓',
                        style: TextStyle(
                          color: green,
                          fontSize: 11 * s,
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8 * s),
                      Expanded(
                        child: Text(
                          b,
                          style: TextStyle(
                            color: muted,
                            fontSize: 11 * s,
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w400,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
