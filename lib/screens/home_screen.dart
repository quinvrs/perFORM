import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/app_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.initialTab});
  final int initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    AppStateScope.of(context); // Listen to changes

    final size = MediaQuery.sizeOf(context);
    final s = size.width / 375.0;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navPad = (130 * s) + bottomInset;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        bottom: false,
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    _HomeTab(scale: s, navPad: navPad),
                    _StreakTab(scale: s, navPad: navPad),
                    _HistoryTab(scale: s, navPad: navPad),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: Material(
                    color: Colors.transparent,
                    child: AppBottomNav(
                      scale: s,
                      selectedTab: _tab,
                      onHome: () => setState(() => _tab = 0),
                      onStreak: () => setState(() => _tab = 1),
                      onHistory: () => setState(() => _tab = 2),
                      onPlus: () async {
                        final res = await Navigator.pushNamed(
                          context,
                          '/exercise_select',
                        );
                        if (res == true && mounted) setState(() => _tab = 1);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.scale, required this.navPad});
  final double scale;
  final double navPad;

  static const _ink = Color(0xFF051328);
  static const _muted = Color(0xFF797B7F);

  // --- STREAK COLOR LOGIC (HEAT MAP) ---

  // 1. The Accent Color (Text & Icons) - Getting Darker/Hotter
  Color _getStreakAccent(int streak) {
    if (streak <= 0) return _muted; // Gray
    if (streak == 1) return const Color(0xFFFBC02D); // Yellow (Warm)
    if (streak == 2) return const Color(0xFFFFA000); // Amber (Hotter)
    if (streak == 3) return const Color(0xFFF57C00); // Orange (Fire)
    if (streak == 4) return const Color(0xFFE64A19); // Deep Orange (Burning)
    return const Color(0xFFD32F2F); // Red (Inferno - 5+ days)
  }

  // 2. The Background Color (Card Tint) - Matching the Accent
  Color _getStreakBg(int streak) {
    if (streak <= 0) return Colors.white;
    if (streak == 1) return const Color(0xFFFFFDE7); // Yellow Tint
    if (streak == 2) return const Color(0xFFFFF8E1); // Amber Tint
    if (streak == 3) return const Color(0xFFFFF3E0); // Orange Tint
    if (streak == 4) return const Color(0xFFFBE9E7); // Deep Orange Tint
    return const Color(0xFFFFEBEE); // Red Tint
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final name = state.name.trim().isEmpty ? 'Friend' : state.name.trim();
    final streak = state.currentStreak;
    final isActive = streak > 0;

    // Get dynamic colors based on streak count
    final accentColor = _getStreakAccent(streak);
    final cardBgColor = _getStreakBg(streak);

    // --- Dynamic Status Message ---
    String statusMsg;
    Widget statusIconWidget;
    if (streak == 0) {
      statusMsg =
          'You haven’t checked out the app\nrecently. Do some workouts.';
      statusIconWidget = _StatusIcon(
        color: const Color(0xFFFFF9C4),
        child: Text(
          '!',
          style: TextStyle(
            color: _ink,
            fontSize: 12 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else if (streak == 1) {
      statusMsg = 'Off to a great start!\nKeep the momentum going.';
      statusIconWidget = _StatusIcon(
        color: const Color(0xFFDBFCE7),
        child: Icon(
          Icons.thumb_up_rounded,
          size: 12 * scale,
          color: const Color(0xFF15803D),
        ),
      );
    } else if (streak == 2) {
      statusMsg = 'Two days in a row!\nYou are building a habit.';
      statusIconWidget = _StatusIcon(
        color: const Color(0xFFE0F2FE),
        child: Icon(
          Icons.trending_up_rounded,
          size: 14 * scale,
          color: const Color(0xFF0369A1),
        ),
      );
    } else {
      statusMsg = 'You are on fire!\nKeep that streak alive.';
      statusIconWidget = _StatusIcon(
        color: const Color(0xFFFFE0B2),
        child: Icon(
          Icons.local_fire_department_rounded,
          size: 14 * scale,
          color: const Color(0xFFE65100),
        ),
      );
    }

    // --- Real Stats Calculation ---
    final totalSessions = state.historyRecordsSorted.length;
    double totalScore = 0;
    int scoredCount = 0;
    int totalRepsAllTime = 0;

    for (final record in state.historyRecordsSorted) {
      if (record.formScore > 0) {
        totalScore += record.formScore;
        scoredCount++;
      }
      totalRepsAllTime += record.reps;
    }

    final avgScore = scoredCount == 0 ? 0 : (totalScore / scoredCount).round();
    final avgReps = totalSessions == 0
        ? 0
        : (totalRepsAllTime / totalSessions).round();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24 * scale, 18 * scale, 24 * scale, navPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 54 * scale,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/corerect-transparent.png',
                  height: 44 * scale,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/profile_section'),
                  borderRadius: BorderRadius.circular(999),
                  child: _ProfileAvatar(scale: scale),
                ),
              ],
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            'Hello,',
            style: TextStyle(
              color: _ink,
              fontSize: 30 * scale,
              fontWeight: FontWeight.w500,
              height: 1.05,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            name,
            style: TextStyle(
              color: _ink,
              fontSize: 48 * scale,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          SizedBox(height: 18 * scale),

          // Dynamic Status Message
          Row(
            children: [
              statusIconWidget,
              SizedBox(width: 10 * scale),
              Expanded(
                child: Opacity(
                  opacity: 0.70,
                  child: Text(
                    statusMsg,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 14 * scale,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18 * scale),

          // --- DYNAMIC HEAT STREAK CARD ---
          Container(
            width: double.infinity,
            height: 113 * scale,
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(10 * scale),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withAlpha(35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 18 * scale,
                  top: 10 * scale,
                  child: Text(
                    'Current Streak',
                    style: TextStyle(color: _ink, fontSize: 10 * scale),
                  ),
                ),

                // Streak Number (Colored)
                Positioned(
                  left: 18 * scale,
                  top: 34 * scale,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$streak',
                        style: TextStyle(
                          color: isActive ? accentColor : _ink,
                          fontSize: 48 * scale,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(width: 2 * scale),
                      Padding(
                        padding: EdgeInsets.only(bottom: 6 * scale),
                        child: Text(
                          'days',
                          style: TextStyle(
                            color: isActive ? accentColor : _muted,
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Fire Icon & Text (Colored)
                Positioned(
                  right: 16 * scale,
                  top: 18 * scale,
                  child: Column(
                    children: [
                      Container(
                        width: 58 * scale,
                        height: 58 * scale,
                        decoration: BoxDecoration(
                          color: isActive
                              ? accentColor.withOpacity(0.15)
                              : const Color(
                                  0xFFF2F4F7,
                                ), // Circle is light tint of accent
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF000000).withAlpha(35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          color: isActive
                              ? accentColor
                              : const Color(0xFFBFC4CC), // Icon is solid accent
                          size: 37 * scale,
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                      Text(
                        isActive ? 'Keep it up!' : 'Start your streak!',
                        style: TextStyle(
                          color: isActive
                              ? accentColor
                              : _muted, // Text is solid accent
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 18 * scale),
          Text(
            'Your Progress',
            style: TextStyle(
              color: _ink,
              fontSize: 20 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 14 * scale),

          // Stats Cards
          _ProgressCard(
            scale: scale,
            title: 'Average Form Score',
            mainValue: '$avgScore',
            suffix: '%',
            rightNote: '',
          ),
          SizedBox(height: 18 * scale),
          _ProgressCard(
            scale: scale,
            title: 'Avg. Reps / Session',
            mainValue: '$avgReps',
            suffix: 'reps',
            rightNote: '',
          ),
          SizedBox(height: 18 * scale),
          _ProgressCard(
            scale: scale,
            title: 'Total Sessions',
            mainValue: '$totalSessions',
            suffix: 'workouts',
            rightNote: 'Lifetime',
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final Color color;
  final Widget child;
  const _StatusIcon({required this.color, required this.child});
  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 375.0;
    return Container(
      width: 18 * s,
      height: 18 * s,
      decoration: ShapeDecoration(color: color, shape: const OvalBorder()),
      child: Center(child: child),
    );
  }
}

class _StreakTab extends StatelessWidget {
  const _StreakTab({required this.scale, required this.navPad});
  final double scale, navPad;
  static const _ink = Color(0xFF051328);

  // FIX: Calendar should use GREEN for workouts, not the streak color
  static const _green = Color(0xFF00C951);
  static const _gold = Color(
    0xFFECC051,
  ); // Keep gold only for the Streak Metric Card

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final now = DateTime.now();
    final year = now.year, month = now.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final offset = DateTime(year, month, 1).weekday % 7;
    final totalCells = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final streak = state.currentStreak;
    final weekly = state.weeklySessions();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24 * scale, 24 * scale, 24 * scale, navPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40 * scale,
            child: Center(
              child: Text(
                'Activity Calendar',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: 18 * scale),
          Row(
            children: [
              _MetricCard(
                scale: scale,
                title: 'Streak',
                value: '$streak',
                tint: _gold,
              ),
              SizedBox(width: 14 * scale),
              _MetricCard(
                scale: scale,
                title: 'Weekly\nSessions',
                value: '$weekly',
                suffix: 'sessions',
                tint: const Color(0xFF537892),
              ),
            ],
          ),
          SizedBox(height: 18 * scale),
          Container(
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10 * scale),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_monthName(month)} $year',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12 * scale),
                Row(
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map(
                        (t) => Expanded(
                          child: Center(
                            child: Text(
                              t,
                              style: TextStyle(
                                color: Color(0xFF797B7F),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 10 * scale),

                // SCROLLABLE CALENDAR FIX
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalCells,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, i) {
                    if (i < offset || (i - offset + 1) > daysInMonth)
                      return const SizedBox.shrink();
                    final day = i - offset + 1;
                    final done = state.isWorkoutDay(DateTime(year, month, day));
                    return Container(
                      decoration: BoxDecoration(
                        color: done
                            ? _green
                            : const Color(
                                0xFFEDEFF3,
                              ), // FIX: Green for calendar
                        borderRadius: BorderRadius.circular(10 * scale),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: done
                                ? Colors.white
                                : const Color(0xFF797B7F),
                            fontWeight: FontWeight.w700,
                            fontSize: 12 * scale,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 14 * scale),
                Row(
                  children: [
                    _LegendDot(color: _green, scale: scale),
                    SizedBox(width: 8 * scale),
                    Text(
                      'Workout Done',
                      style: TextStyle(color: _ink, fontSize: 12 * scale),
                    ),
                    SizedBox(width: 16 * scale),
                    _LegendDot(
                      color: const Color(0xFFEDEFF3),
                      scale: scale,
                      border: true,
                    ),
                    SizedBox(width: 8 * scale),
                    Text(
                      'No Activity',
                      style: TextStyle(color: _ink, fontSize: 12 * scale),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _monthName(int m) => [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m - 1];
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.scale, required this.navPad});
  final double scale, navPad;
  static const _ink = Color(0xFF051328);
  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final records = state.historyRecordsSorted;

    int totalReps = records.fold(0, (sum, r) => sum + r.reps);
    double totalForm = 0;
    int count = 0;
    for (var r in records) {
      if (r.formScore > 0) {
        totalForm += r.formScore;
        count++;
      }
    }
    int avgForm = count == 0 ? 0 : (totalForm / count).round();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24 * scale, 24 * scale, 24 * scale, navPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40 * scale,
            child: Center(
              child: Text(
                'Workout History',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: 18 * scale),
          Row(
            children: [
              Expanded(
                child: _HistoryStatCard(
                  scale: scale,
                  accent: const Color(0xFFECC051),
                  icon: Icons.favorite_border,
                  title: 'Avg. Form\nScore',
                  value: '$avgForm',
                  unit: '%',
                ),
              ),
              SizedBox(width: 14 * scale),
              Expanded(
                child: _HistoryStatCard(
                  scale: scale,
                  accent: const Color(0xFF537892),
                  icon: Icons.bolt,
                  title: 'Total Reps',
                  value: '$totalReps',
                  unit: 'reps',
                ),
              ),
            ],
          ),
          SizedBox(height: 18 * scale),
          if (records.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40 * scale),
              child: Center(
                child: Text(
                  'No workouts yet.',
                  style: TextStyle(
                    color: _ink.withValues(alpha: 0.65),
                    fontSize: 14 * scale,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (final record in records.take(20)) ...[
                  _WorkoutCard(scale: scale, record: record),
                  SizedBox(height: 14 * scale),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.scale,
    required this.title,
    required this.value,
    required this.tint,
    this.suffix,
  });
  final double scale;
  final String title, value;
  final String? suffix;
  final Color tint;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 120 * scale,
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16 * scale),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: tint,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: tint,
                fontSize: 36 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.scale,
    this.border = false,
  });
  final Color color;
  final double scale;
  final bool border;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12 * scale,
      height: 12 * scale,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3 * scale),
        border: border ? Border.all(color: const Color(0xFFBFC4CC)) : null,
      ),
    );
  }
}

class _HistoryStatCard extends StatelessWidget {
  const _HistoryStatCard({
    required this.scale,
    required this.accent,
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
  });
  final double scale;
  final Color accent;
  final IconData icon;
  final String title, value, unit;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132 * scale,
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18 * scale),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 40 * scale,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              SizedBox(width: 6 * scale),
              Padding(
                padding: EdgeInsets.only(bottom: 8 * scale),
                child: Text(
                  unit,
                  style: TextStyle(color: accent, fontSize: 14 * scale),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.scale, required this.record});
  final double scale;
  final WorkoutRecord record;
  @override
  Widget build(BuildContext context) {
    final date = record.dateTime;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                record.type,
                style: TextStyle(
                  fontSize: 18 * scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * scale,
                  vertical: 4 * scale,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBFCE7),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  '${record.formScore.toInt()}% Form',
                  style: TextStyle(
                    color: const Color(0xFF3C926C),
                    fontSize: 10 * scale,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),
          Text(
            '${date.month}/${date.day}/${date.year}',
            style: TextStyle(
              color: const Color(0xFF797B7F),
              fontSize: 10 * scale,
            ),
          ),
          SizedBox(height: 10 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniStat(scale: scale, value: '${record.reps}', label: 'Reps'),
              _MiniStat(
                scale: scale,
                value: record.duration,
                label: 'Duration',
              ),
              _MiniStat(scale: scale, value: '${record.sets}', label: 'Sets'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.scale,
    required this.value,
    required this.label,
  });
  final double scale;
  final String value, label;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w500),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10 * scale,
            color: const Color(0xFF797B7F),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.scale});
  final double scale;
  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final path = state.avatarPath;
    ImageProvider? img;
    if (path != null && path.trim().isNotEmpty && !kIsWeb) {
      final f = File(path);
      if (f.existsSync()) img = FileImage(f);
    }
    return CircleAvatar(
      radius: 22 * scale,
      backgroundColor: Colors.black.withAlpha(18),
      backgroundImage: img,
      child: img == null
          ? Icon(
              Icons.person_rounded,
              color: const Color(0xFF051328),
              size: 22 * scale,
            )
          : null,
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.scale,
    required this.title,
    required this.mainValue,
    required this.suffix,
    required this.rightNote,
  });
  final double scale;
  final String title, mainValue, suffix, rightNote;
  static const _ink = Color(0xFF051328);
  static const _muted = Color(0xFF797B7F);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 84 * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withAlpha(26),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16 * scale,
          12 * scale,
          16 * scale,
          12 * scale,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.black,
                fontSize: 16 * scale,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  mainValue,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 32 * scale,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: 8 * scale),
                Padding(
                  padding: EdgeInsets.only(bottom: 6 * scale),
                  child: Text(
                    suffix,
                    style: TextStyle(color: _muted, fontSize: 10 * scale),
                  ),
                ),
                const Spacer(),
                if (rightNote.isNotEmpty)
                  Text(
                    rightNote,
                    style: TextStyle(color: _muted, fontSize: 10 * scale),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
