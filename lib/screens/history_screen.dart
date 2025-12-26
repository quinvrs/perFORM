// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/app_bottom_nav.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _bgDark = Color.fromARGB(255, 18, 32, 47);
  static const _ink = Color(0xFF051328);

  static const _avgAccent = Color(0xFFECC051);
  static const _repsAccent = Color(0xFF537892);

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final days = state.workoutDaysSorted;

    final totalWorkouts = days.length;
    final totalReps = totalWorkouts * 45; // placeholder
    const avgFormScore = 88; // placeholder

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
                        padding: EdgeInsets.fromLTRB(40 * s, 40 * s, 40 * s, 170 * s),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 40 * s,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    child: InkWell(
                                      onTap: () {
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        } else {
                                          Navigator.pushReplacementNamed(context, '/home');
                                        }
                                      },
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: _ink,
                                        size: 28 * s,
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      'Workout History',
                                      style: TextStyle(
                                        color: _ink,
                                        fontSize: 24 * s,
                                        fontFamily: 'DM Sans',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 30 * s),

                            // ✅ Use IntrinsicHeight so both cards can grow and still match height.
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      s: s,
                                      bg: _avgAccent.withValues(alpha: 0.10),
                                      accent: _avgAccent,
                                      icon: Icons.favorite_border_rounded,
                                      title: 'Avg. Form\nScore',
                                      value: '$avgFormScore',
                                      unit: '%',
                                    ),
                                  ),
                                  SizedBox(width: 20 * s),
                                  Expanded(
                                    child: _StatCard(
                                      s: s,
                                      bg: _repsAccent.withValues(alpha: 0.10),
                                      accent: _repsAccent,
                                      icon: Icons.bolt_rounded,
                                      title: 'Total Reps',
                                      value: '$totalReps',
                                      unit: 'reps',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 24 * s),

                            if (days.isEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 60 * s),
                                child: Center(
                                  child: Text(
                                    'No workouts yet.\nTap days in Streak calendar!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _ink.withValues(alpha: 0.65),
                                      fontSize: 14 * s,
                                      fontFamily: 'DM Sans',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: [
                                  for (int i = 0; i < days.length; i++) ...[
                                    _WorkoutCard(
                                      s: s,
                                      title: 'Squat',
                                      dateText: _formatDate(days[i]),
                                      reps: 45,
                                      durationText: '12 min',
                                      sets: 3,
                                      formPercent: (i % 2 == 0) ? 92 : 88,
                                      chipStyle: (i % 2 == 0)
                                          ? _ChipStyle.green
                                          : _ChipStyle.yellow,
                                    ),
                                    SizedBox(height: 16 * s),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: Colors.transparent,
                        child: AppBottomNav(
                          scale: s,
                          selectedTab: 2,
                          onHome: () => Navigator.pushReplacementNamed(context, '/home'),
                          onStreak: () => Navigator.pushReplacementNamed(context, '/streak'),
                          onHistory: () {},
                          onPlus: () => Navigator.pushNamed(context, '/exercise_select'),
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

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[(d.month - 1).clamp(0, 11)];
    return '$m ${d.day}, ${d.year}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.s,
    required this.bg,
    required this.accent,
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
  });

  final double s;
  final Color bg;
  final Color accent;
  final IconData icon;
  final String title;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      // ✅ This is the key: NO fixed height; give it a minimum only.
      constraints: BoxConstraints(minHeight: 128 * s),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20 * s),
      ),
      padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 12 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16 * s, color: accent),
              SizedBox(width: 7 * s),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 14 * s,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w500,
                    height: 1.08,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // ✅ Makes sure big numbers never overflow
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: accent,
                    fontSize: 40 * s,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: 6 * s),
                Padding(
                  padding: EdgeInsets.only(bottom: 6 * s),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: accent,
                      fontSize: 14 * s,
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w400,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChipStyle { green, yellow }

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.s,
    required this.title,
    required this.dateText,
    required this.reps,
    required this.durationText,
    required this.sets,
    required this.formPercent,
    required this.chipStyle,
  });

  final double s;
  final String title;
  final String dateText;
  final int reps;
  final String durationText;
  final int sets;
  final int formPercent;
  final _ChipStyle chipStyle;

  static const _muted = Color(0xFF797B7F);

  @override
  Widget build(BuildContext context) {
    final chipBg = chipStyle == _ChipStyle.green
        ? const Color(0xFFDBFCE7)
        : const Color(0xFFFEF9C2);

    final chipText = chipStyle == _ChipStyle.green
        ? const Color(0xFF3C926C)
        : const Color(0xFFA65F00);

    return Container(
      width: double.infinity,
      height: 123 * s,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10 * s),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 1,
            offset: Offset(0, 1),
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20 * s, 12 * s, 16 * s, 12 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20 * s,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 4 * s),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(50 * s),
                ),
                child: Text(
                  '$formPercent% Form',
                  style: TextStyle(
                    color: chipText,
                    fontSize: 10 * s,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2 * s),
          Text(
            dateText,
            style: TextStyle(
              color: _muted,
              fontSize: 10 * s,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _Metric(s: s, value: '$reps', label: 'Reps')),
              Expanded(child: _Metric(s: s, value: durationText, label: 'Duration')),
              Expanded(child: _Metric(s: s, value: '$sets', label: 'Sets')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.s, required this.value, required this.label});

  final double s;
  final String value;
  final String label;

  static const _ink = Color(0xFF051328);
  static const _muted = Color(0xFF797B7F);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: _ink,
            fontSize: 24 * s,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 4 * s),
        Text(
          label,
          style: TextStyle(
            color: _muted,
            fontSize: 10 * s,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
