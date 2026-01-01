import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../widgets/exercise_details_sheet.dart';

class ExerciseSelectionScreen extends StatefulWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  State<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  static const _ink = Color(0xFF051328);
  static const _muted = Color(0xFF797B7F);
  static const _green = Color(0xFF00C951);


  final _items = const <_WorkoutItem>[
    _WorkoutItem(
      workout: Workout(
        title: 'Squats',
        subtitle: 'Lower Body Strength',
        benefits: [
          'Builds lower body strength and muscle mass',
          'Improves core stability and balance',
          'Enhances athletic performance',
          'Burns calories and boosts metabolism',
        ],
      ),
      asset: 'assets/squat-avatar.png',
    ),
    _WorkoutItem(
      workout: Workout(
        title: 'Jumping Jacks',
        subtitle: 'Full Body Cardio',
        benefits: [
          'Improves cardiovascular endurance',
          'Warms up the whole body quickly',
          'Boosts coordination and rhythm',
          'Burns calories efficiently',
          'Strengthens shoulders, hips, and legs',
          'Great for HIIT and warm-ups',
        ],
      ),
      asset: 'assets/jumping-jack-avatar.png',
    ),
  ];

  int selectedIndex = 0;

  void _openDetails(Workout w) {
    showExerciseDetailsSheet(
      context,
      workout: w,
    onStartExercise: () {
      Navigator.of(context).pop();
      // go to Setup Mode screen
      Navigator.pushNamed(context, '/setup_mode'); 
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final s = size.width / 375.0;

    return Scaffold(
      backgroundColor: Colors.white, 
      body: SafeArea(
        child: SizedBox.expand(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24 * s, 18 * s, 24 * s, 24 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header
                SizedBox(
                  height: 56 * s,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.arrow_back_rounded, color: _ink, size: 28 * s),
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
                SizedBox(height: 22 * s),

                for (int i = 0; i < _items.length; i++) ...[
                  _WorkoutCard(
                    s: s,
                    item: _items[i],
                    selected: selectedIndex == i,
                    muted: _muted,
                    green: _green,
                    onTap: () {
                      setState(() => selectedIndex = i);
                      _openDetails(_items[i].workout); 
                    },
                  ),
                  SizedBox(height: 16 * s),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkoutItem {
  const _WorkoutItem({required this.workout, required this.asset});
  final Workout workout;
  final String asset;
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.s,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.muted,
    required this.green,
  });

  final double s;
  final _WorkoutItem item;
  final bool selected;
  final VoidCallback onTap;
  final Color muted;
  final Color green;

  static const _yellow = Color(0xFFFEF9C2);

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _yellow.withValues(alpha: 0.55) : Colors.white;

    // bigger image box when selected
    final avatarBox = selected ? 92 * s : 78 * s;
    final starSize = selected ? 90 * s : 76 * s;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14 * s),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12 * s),
          border: Border.all(color: Colors.black.withAlpha(selected ? 25 : 18)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top row: text + big avatar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 10 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.workout.title,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24 * s,
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2 * s),
                        Text(
                          item.workout.subtitle,
                          style: TextStyle(
                            color: muted,
                            fontSize: 14 * s,
                            fontFamily: 'DM Sans',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(
                  width: avatarBox,
                  height: avatarBox,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: starSize,
                        color: _yellow.withValues(alpha: 0.9),
                      ),
                      Image.asset(
                        item.asset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.image_not_supported_rounded,
                          size: 24 * s,
                          color: Colors.black.withAlpha(80),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // benefits show only when selected (like your screenshot)
            if (selected) ...[
              SizedBox(height: 12 * s),
              Text(
                'Benefits',
                style: TextStyle(
                  color: muted,
                  fontSize: 11 * s,
                  fontFamily: 'DM Sans',
                ),
              ),
              SizedBox(height: 6 * s),
              for (final b in item.workout.benefits)
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
                          fontWeight: FontWeight.w700,
                          fontFamily: 'DM Sans',
                        ),
                      ),
                      SizedBox(width: 8 * s),
                      Expanded(
                        child: Text(
                          b,
                          style: TextStyle(
                            color: muted,
                            fontSize: 11 * s,
                            height: 1.25,
                            fontFamily: 'DM Sans',
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
