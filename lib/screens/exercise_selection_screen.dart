
import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../widgets/exercise_details_sheet.dart';

class ExerciseSelectionScreen extends StatefulWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  State<ExerciseSelectionScreen> createState() =>
      _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  static const _ink = Color(0xFF102A08);
  static const _muted = Color(0xFF697044);
  static const _cream = Color(0xFFFFF4DE);
  static const _orange = Color(0xFFFF6A00);
  static const _green = Color(0xFF6D8524);
  static const _lime = Color(0xFFDCEB63);

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
      label: 'Strength',
      minutes: '8–12 min',
      icon: Icons.fitness_center_rounded,
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
      label: 'Cardio',
      minutes: '5–10 min',
      icon: Icons.bolt_rounded,
    ),
  ];

  int selectedIndex = 0;

  void _openDetails(Workout w) {
    showExerciseDetailsSheet(
      context,
      workout: w,
      onStartExercise: () {
        Navigator.of(context).pushNamed(
          '/setup_mode',
          arguments: w,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final s = (size.width / 375.0).clamp(0.90, 1.12);

    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF4DE),
                      Color(0xFFFFE1B5),
                      Color(0xFFF2F4C0),
                    ],
                    stops: [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),

            Positioned(
              top: -80 * s,
              right: -90 * s,
              child: _SoftBlob(
                size: 210 * s,
                color: _orange.withAlpha(65),
              ),
            ),

            Positioned(
              bottom: -100 * s,
              left: -90 * s,
              child: _SoftBlob(
                size: 230 * s,
                color: _green.withAlpha(55),
              ),
            ),

            Positioned(
              top: 170 * s,
              left: -120 * s,
              child: _SoftBlob(
                size: 210 * s,
                color: _lime.withAlpha(70),
              ),
            ),

            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                22 * s,
                16 * s,
                22 * s,
                28 * s,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    s: s,
                    onBack: () => Navigator.pop(context),
                  ),

                  SizedBox(height: 26 * s),

                  Text(
                    'Choose your movement',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 30 * s,
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -0.8,
                    ),
                  ),

                  SizedBox(height: 8 * s),

                  Text(
                    'Pick an exercise and perFORM will guide your setup, count your reps, and track your session.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13.5 * s,
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),

                  SizedBox(height: 18 * s),

                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14 * s,
                      vertical: 10 * s,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(150),
                      borderRadius: BorderRadius.circular(18 * s),
                      border: Border.all(
                        color: Colors.white.withAlpha(160),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34 * s,
                          height: 34 * s,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _ink,
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: _lime,
                            size: 18 * s,
                          ),
                        ),
                        SizedBox(width: 10 * s),
                        Expanded(
                          child: Text(
                            '${_items.length} workouts available',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 13 * s,
                              fontFamily: 'DM Sans',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.swipe_rounded,
                          color: _green,
                          size: 20 * s,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 18 * s),

                  for (int i = 0; i < _items.length; i++) ...[
                    _WorkoutCard(
                      s: s,
                      item: _items[i],
                      selected: selectedIndex == i,
                      onSelect: () {
                        setState(() => selectedIndex = i);
                      },
                      onOpen: () {
                        setState(() => selectedIndex = i);
                        _openDetails(_items[i].workout);
                      },
                    ),
                    SizedBox(height: 16 * s),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.s,
    required this.onBack,
  });

  final double s;
  final VoidCallback onBack;

  static const _ink = Color(0xFF102A08);
  static const _muted = Color(0xFF697044);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white.withAlpha(165),
          borderRadius: BorderRadius.circular(16 * s),
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(16 * s),
            child: Container(
              width: 46 * s,
              height: 46 * s,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16 * s),
                border: Border.all(
                  color: Colors.white.withAlpha(180),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(18),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: _ink,
                size: 25 * s,
              ),
            ),
          ),
        ),

        const Spacer(),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Workout',
              style: TextStyle(
                color: _ink,
                fontSize: 16 * s,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Selection',
              style: TextStyle(
                color: _muted,
                fontSize: 12 * s,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkoutItem {
  const _WorkoutItem({
    required this.workout,
    required this.asset,
    required this.label,
    required this.minutes,
    required this.icon,
  });

  final Workout workout;
  final String asset;
  final String label;
  final String minutes;
  final IconData icon;
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.s,
    required this.item,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });

  final double s;
  final _WorkoutItem item;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  static const _ink = Color(0xFF102A08);
  static const _muted = Color(0xFF697044);
  static const _orange = Color(0xFFFF6A00);
  static const _lime = Color(0xFFDCEB63);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28 * s),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? const [
                  Color(0xFFFFC06E),
                  Color(0xFFFFF0CF),
                  Color(0xFFEAF1B6),
                ]
              : [
                  Colors.white.withAlpha(190),
                  Colors.white.withAlpha(130),
                ],
        ),
        border: Border.all(
          color: selected
              ? _orange.withAlpha(115)
              : Colors.white.withAlpha(160),
          width: selected ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? _orange.withAlpha(70)
                : Colors.black.withAlpha(22),
            blurRadius: selected ? 24 : 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28 * s),
        child: InkWell(
          borderRadius: BorderRadius.circular(28 * s),
          onTap: onSelect,
          child: Padding(
            padding: EdgeInsets.all(16 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: 10 * s),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _SmallPill(
                                  s: s,
                                  icon: item.icon,
                                  text: item.label,
                                  selected: selected,
                                ),
                                SizedBox(width: 8 * s),
                                _TimePill(
                                  s: s,
                                  text: item.minutes,
                                ),
                              ],
                            ),

                            SizedBox(height: 13 * s),

                            Text(
                              item.workout.title,
                              style: TextStyle(
                                color: _ink,
                                fontSize: 26 * s,
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                letterSpacing: -0.6,
                              ),
                            ),

                            SizedBox(height: 5 * s),

                            Text(
                              item.workout.subtitle,
                              style: TextStyle(
                                color: _muted,
                                fontSize: 13.5 * s,
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    _AvatarBubble(
                      s: s,
                      asset: item.asset,
                      selected: selected,
                    ),
                  ],
                ),

                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: selected
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16 * s),

                      Wrap(
                        spacing: 8 * s,
                        runSpacing: 8 * s,
                        children: item.workout.benefits
                            .take(4)
                            .map(
                              (benefit) => _BenefitChip(
                                s: s,
                                text: benefit,
                              ),
                            )
                            .toList(),
                      ),

                      SizedBox(height: 16 * s),

                      SizedBox(
                        width: double.infinity,
                        height: 46 * s,
                        child: ElevatedButton(
                          onPressed: onOpen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16 * s),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'View Details',
                                style: TextStyle(
                                  fontSize: 14 * s,
                                  fontFamily: 'DM Sans',
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 8 * s),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 19 * s,
                                color: _lime,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.s,
    required this.asset,
    required this.selected,
  });

  final double s;
  final String asset;
  final bool selected;

  static const _orange = Color(0xFFFF6A00);
  static const _green = Color(0xFF6D8524);

  @override
  Widget build(BuildContext context) {
    final box = selected ? 104 * s : 92 * s;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: box,
      height: box,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24 * s),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _orange,
            Color(0xFFFFB15A),
            Color(0xFFDCEB63),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _orange.withAlpha(selected ? 90 : 45),
            blurRadius: selected ? 18 : 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -18 * s,
            top: -18 * s,
            child: Container(
              width: 54 * s,
              height: 54 * s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(70),
              ),
            ),
          ),

          Positioned(
            left: -20 * s,
            bottom: -18 * s,
            child: Container(
              width: 64 * s,
              height: 64 * s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green.withAlpha(80),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(8 * s),
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_not_supported_rounded,
                size: 28 * s,
                color: Colors.black.withAlpha(90),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.s,
    required this.icon,
    required this.text,
    required this.selected,
  });

  final double s;
  final IconData icon;
  final String text;
  final bool selected;

  static const _ink = Color(0xFF102A08);
  static const _orange = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 9 * s,
        vertical: 6 * s,
      ),
      decoration: BoxDecoration(
        color: selected ? _ink : _orange.withAlpha(32),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13 * s,
            color: selected ? Colors.white : _orange,
          ),
          SizedBox(width: 5 * s),
          Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : _ink,
              fontSize: 11 * s,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.s,
    required this.text,
  });

  final double s;
  final String text;

  static const _muted = Color(0xFF697044);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 9 * s,
        vertical: 6 * s,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(130),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 13 * s,
            color: _muted,
          ),
          SizedBox(width: 5 * s),
          Text(
            text,
            style: TextStyle(
              color: _muted,
              fontSize: 11 * s,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({
    required this.s,
    required this.text,
  });

  final double s;
  final String text;

  static const _ink = Color(0xFF102A08);
  static const _green = Color(0xFF6D8524);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: 145 * s,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 9 * s,
        vertical: 8 * s,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(135),
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(
          color: Colors.white.withAlpha(150),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: _green,
            size: 14 * s,
          ),
          SizedBox(width: 6 * s),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: _ink.withAlpha(205),
                fontSize: 10.5 * s,
                height: 1.2,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftBlob extends StatelessWidget {
  const _SoftBlob({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 80,
              spreadRadius: 28,
            ),
          ],
        ),
      ),
    );
  }
}