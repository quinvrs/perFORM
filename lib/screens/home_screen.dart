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
    AppStateScope.of(context); // listen to changes

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

  // streak heat accent (your earlier idea)
  Color _getStreakAccent(int streak) {
    if (streak <= 0) return _muted;
    if (streak == 1) return const Color(0xFFFBC02D);
    if (streak == 2) return const Color(0xFFFFA000);
    if (streak == 3) return const Color(0xFFF57C00);
    if (streak == 4) return const Color(0xFFE64A19);
    return const Color(0xFFD32F2F);
  }

  Color _getStreakBg(int streak) {
    if (streak <= 0) return Colors.white;
    if (streak == 1) return const Color(0xFFFFFDE7);
    if (streak == 2) return const Color(0xFFFFF8E1);
    if (streak == 3) return const Color(0xFFFFF3E0);
    if (streak == 4) return const Color(0xFFFBE9E7);
    return const Color(0xFFFFEBEE);
  }

  static Color _formTint(int score) {
    if (score <= 0) return const Color(0xFF6B7280); // gray
    if (score < 40) return const Color(0xFFDC2626); // red
    if (score < 80) return const Color(0xFFF97316); // orange
    return const Color(0xFF16A34A); // green
  }

  static int _nextMilestone(int streak) {
    if (streak < 3) return 3;
    if (streak < 7) return 7;
    if (streak < 14) return 14;
    if (streak < 30) return 30;
    return ((streak ~/ 30) + 1) * 30;
  }

  static String _milestoneLabel(int m) {
    if (m == 3) return '3-day streak';
    if (m == 7) return '1-week streak';
    if (m == 14) return '2-week streak';
    if (m == 30) return '30-day streak';
    return '$m-day streak';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final name = state.name.trim().isEmpty ? 'Friend' : state.name.trim();
    final records = state.historyRecordsSorted;

    final streak = state.currentStreak;
    final weekly = state.weeklySessions();
    final isActive = streak > 0;

    final accentColor = _getStreakAccent(streak);
    final cardBgColor = _getStreakBg(streak);

    // status message
    String statusMsg;
    Widget statusIconWidget;

    if (streak == 0) {
      statusMsg =
          'You haven’t checked out the app\nrecently. Do some workouts.';
      statusIconWidget = _StatusIcon(
        scale: scale,
        color: const Color(0xFFFFF9C4),
        child: Text(
          '!',
          style: TextStyle(
            color: _ink,
            fontSize: 12 * scale,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else if (streak == 1) {
      statusMsg = 'Off to a great start!\nKeep the momentum going.';
      statusIconWidget = _StatusIcon(
        scale: scale,
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
        scale: scale,
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
        scale: scale,
        color: const Color(0xFFFFE0B2),
        child: Icon(
          Icons.local_fire_department_rounded,
          size: 14 * scale,
          color: const Color(0xFFE65100),
        ),
      );
    }

    // stats (don’t change DB logic)
    final totalSessions = records.length;

    double totalScore = 0;
    int scoredCount = 0;
    int totalRepsAllTime = 0;

    for (final r in records) {
      if (r.formScore > 0) {
        totalScore += r.formScore;
        scoredCount++;
      }
      totalRepsAllTime += r.reps;
    }

    final avgScore = scoredCount == 0 ? 0 : (totalScore / scoredCount).round();
    final avgReps = totalSessions == 0
        ? 0
        : (totalRepsAllTime / totalSessions).round();

    // streak motivation
    final milestone = _nextMilestone(streak);
    final progressToMilestone = milestone == 0
        ? 0.0
        : (streak / milestone).clamp(0.0, 1.0);

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
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          SizedBox(height: 18 * scale),
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

          // streak card
          Container(
            width: double.infinity,
            height: 155 * scale,
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(12 * scale),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withAlpha(24),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18 * scale,
                12 * scale,
                16 * scale,
                22 * scale,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Streak',
                          style: TextStyle(
                            color: _ink.withValues(alpha: 0.75),
                            fontSize: 10 * scale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6 * scale),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$streak',
                              style: TextStyle(
                                color: isActive ? accentColor : _ink,
                                fontSize: 48 * scale,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(width: 6 * scale),
                            Padding(
                              padding: EdgeInsets.only(bottom: 6 * scale),
                              child: Text(
                                'days',
                                style: TextStyle(
                                  color: isActive ? accentColor : _muted,
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          '$totalSessions Total Sessions Completed',
                          style: TextStyle(
                            color: _ink.withValues(alpha: 0.75),
                            fontSize: 10 * scale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8 * scale),

                        // milestone progress
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: (streak == 0)
                                      ? 0
                                      : progressToMilestone,
                                  minHeight: 7 * scale,
                                  backgroundColor: Colors.black.withValues(
                                    alpha: 0.06,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isActive
                                        ? accentColor
                                        : const Color(0xFFBFC4CC),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10 * scale),
                            Text(
                              streak == 0
                                  ? 'Start'
                                  : '${milestone - streak} to ${_milestoneLabel(milestone)}',
                              style: TextStyle(
                                color: _ink.withValues(alpha: 0.70),
                                fontSize: 10 * scale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12 * scale),
                  Column(
                    children: [
                      Container(
                        width: 68 * scale,
                        height: 68 * scale,
                        decoration: BoxDecoration(
                          color: isActive
                              ? accentColor.withValues(alpha: 0.14)
                              : const Color(0xFFF2F4F7),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF000000).withAlpha(18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          color: isActive
                              ? accentColor
                              : const Color(0xFFBFC4CC),
                          size: 34 * scale,
                        ),
                      ),
                      SizedBox(height: 17 * scale),
                      Text(
                        isActive ? 'Keep it up!' : 'Start your streak!',
                        style: TextStyle(
                          color: isActive ? accentColor : _muted,
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

          // 3 columns (like your earlier look)
          Row(
            children: [
              _ProgressMetricCard(
                scale: scale,
                height: 132 * scale,
                title: 'Average\nForm Score',
                value: '$avgScore',
                suffix: '%',
                tint: _formTint(avgScore),
              ),
              SizedBox(width: 12 * scale),
              _ProgressMetricCard(
                scale: scale,
                height: 132 * scale,
                title: 'Weekly\nSessions',
                value: '$weekly',
                suffix: 'sessions',
                tint: const Color(0xFF537892),
              ),
              SizedBox(width: 12 * scale),
              _ProgressMetricCard(
                scale: scale,
                height: 132 * scale,
                title: 'Avg. Reps/\nSession',
                value: '$avgReps',
                suffix: 'reps',
                tint: const Color(0xFFECC051),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.scale,
    required this.color,
    required this.child,
  });

  final double scale;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18 * scale,
      height: 18 * scale,
      decoration: ShapeDecoration(color: color, shape: const OvalBorder()),
      child: Center(child: child),
    );
  }
}

// -------------------------------------------------------------
// UPDATED STREAK TAB: BOUNDED NAVIGATION
// -------------------------------------------------------------
// -------------------------------------------------------------
// UPDATED STREAK TAB: SMOOTH 1-MONTH NAVIGATION
// -------------------------------------------------------------
class _StreakTab extends StatefulWidget {
  const _StreakTab({required this.scale, required this.navPad});
  final double scale, navPad;

  @override
  State<_StreakTab> createState() => _StreakTabState();
}

class _StreakTabState extends State<_StreakTab> {
  static const _ink = Color(0xFF051328);
  static const _gold = Color(0xFFECC051);

  late DateTime _focusedDate;

  @override
  void initState() {
    super.initState();
    _focusedDate = DateTime.now();
  }

  Color _getDailyColor(int count) {
    if (count <= 0) return const Color(0xFFEDEFF3);
    const Color startColor = Color.fromARGB(255, 79, 185, 83);
    const Color endColor = Color.fromARGB(255, 20, 93, 25);
    const int maxSaturatedCount = 10;
    double t = ((count - 1) / (maxSaturatedCount - 1)).clamp(0.0, 1.0);
    return Color.lerp(startColor, endColor, t)!;
  }

  // --- NAVIGATION BOUNDS ---
  bool get _canGoBack => _focusedDate.year > 2020;

  // Allow going forward up to next month
  bool get _canGoForward {
    final now = DateTime.now();
    final maxFuture = DateTime(now.year, now.month + 1);
    return _focusedDate.isBefore(maxFuture);
  }

  // --- CHANGED LOGIC HERE ---
  void _prevMonth() {
    if (!_canGoBack) return;
    setState(() {
      // NOW MOVES 1 MONTH BACK (was -3)
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1);
    });
  }

  void _nextMonth() {
    if (!_canGoForward) return;
    setState(() {
      // MOVES 1 MONTH FORWARD
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1);
    });
  }

  bool _isFuture(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return day.isAfter(today);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final year = _focusedDate.year;
    final month = _focusedDate.month;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfMonth = DateTime(year, month, 1);
    final offset = firstDayOfMonth.weekday % 7;
    final totalCells = ((offset + daysInMonth + 6) ~/ 7) * 7;

    final streak = state.currentStreak;
    final weekly = state.weeklySessions();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24 * widget.scale,
        24 * widget.scale,
        24 * widget.scale,
        widget.navPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40 * widget.scale,
            child: Center(
              child: Text(
                'Activity Calendar',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20 * widget.scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(height: 18 * widget.scale),
          Row(
            children: [
              _MetricCard(
                scale: widget.scale,
                title: 'Streak',
                value: '$streak',
                tint: _gold,
              ),
              SizedBox(width: 14 * widget.scale),
              _MetricCard(
                scale: widget.scale,
                title: 'Weekly\nSessions',
                value: '$weekly',
                suffix: 'sessions',
                tint: const Color(0xFF537892),
              ),
            ],
          ),
          SizedBox(height: 18 * widget.scale),

          Container(
            padding: EdgeInsets.all(16 * widget.scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10 * widget.scale),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Left Arrow
                    Opacity(
                      opacity: _canGoBack ? 1.0 : 0.0,
                      child: InkWell(
                        onTap: _canGoBack ? _prevMonth : null,
                        borderRadius: BorderRadius.circular(50),
                        child: Padding(
                          padding: EdgeInsets.all(4 * widget.scale),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: _ink,
                            size: 24 * widget.scale,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 8 * widget.scale),
                    Text(
                      '${_monthName(month)} $year',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16 * widget.scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),

                    // Right Arrow
                    Opacity(
                      opacity: _canGoForward ? 1.0 : 0.0,
                      child: InkWell(
                        onTap: _canGoForward ? _nextMonth : null,
                        borderRadius: BorderRadius.circular(50),
                        child: Padding(
                          padding: EdgeInsets.all(4 * widget.scale),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: _ink,
                            size: 24 * widget.scale,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12 * widget.scale),

                Row(
                  children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map(
                        (t) => Expanded(
                          child: Center(
                            child: Text(
                              t,
                              style: TextStyle(
                                color: Color(0xFF797B7F),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 10 * widget.scale),

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
                    final currentDay = DateTime(year, month, day);

                    final isFuture = _isFuture(currentDay);

                    final workoutCount = isFuture
                        ? 0
                        : state.historyRecordsSorted.where((r) {
                            final d = r.dateTime;
                            return d.year == currentDay.year &&
                                d.month == currentDay.month &&
                                d.day == currentDay.day;
                          }).length;

                    Color bg;
                    Color fg;

                    if (isFuture) {
                      bg = Colors.white;
                      fg = const Color(0xFFE0E0E0);
                    } else {
                      bg = _getDailyColor(workoutCount);
                      fg = workoutCount > 0
                          ? Colors.white
                          : const Color(0xFF797B7F);
                    }

                    final isToday =
                        DateTime.now().year == year &&
                        DateTime.now().month == month &&
                        DateTime.now().day == day;

                    return Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10 * widget.scale),
                        border: isToday
                            ? Border.all(color: _ink, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 12 * widget.scale,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) => [
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.scale,
    required this.title,
    required this.value,
    required this.tint,
    this.suffix,
  });

  final double scale;
  final String title;
  final String value;
  final String? suffix;
  final Color tint;

  static const _ink = Color(0xFF051328);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 120 * scale,
        padding: EdgeInsets.fromLTRB(
          14 * scale,
          12 * scale,
          14 * scale,
          12 * scale,
        ),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16 * scale),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tint,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w700,
                height: 1.10,
              ),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: tint,
                      fontSize: 36 * scale,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      fontFamily: 'DM Sans',
                    ),
                  ),
                  if (suffix != null) ...[
                    SizedBox(width: 6 * scale),
                    Padding(
                      padding: EdgeInsets.only(bottom: 8 * scale),
                      child: Text(
                        suffix!,
                        style: TextStyle(
                          color: _ink.withValues(alpha: 0.65),
                          fontSize: 12 * scale,
                          height: 1.0,
                          fontFamily: 'DM Sans',
                        ),
                      ),
                    ),
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

// -------------------------------------------------------------
// UPDATED HISTORY TAB: CALCULATES DURATION INSTEAD OF REPS
// -------------------------------------------------------------
class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.scale, required this.navPad});
  final double scale, navPad;

  static const _ink = Color(0xFF051328);

  static Color _formTint(int score) {
    if (score <= 0) return const Color(0xFF6B7280); // gray
    if (score < 40) return const Color(0xFFDC2626); // red
    if (score < 80) return const Color(0xFFF97316); // orange
    return const Color(0xFF16A34A); // green
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final records = state.historyRecordsSorted;

    // --- NEW LOGIC: Calculate Total Duration (parsing HH:MM:SS or MM:SS) ---
    int totalSeconds = 0;
    double totalForm = 0;
    int count = 0;

    for (final r in records) {
      if (r.formScore > 0) {
        totalForm += r.formScore;
        count++;
      }

      // Parse Duration
      final parts = r.duration.split(':');
      if (parts.length == 3) {
        // HH:MM:SS
        totalSeconds +=
            (int.tryParse(parts[0]) ?? 0) * 3600 +
            (int.tryParse(parts[1]) ?? 0) * 60 +
            (int.tryParse(parts[2]) ?? 0);
      } else if (parts.length == 2) {
        // MM:SS
        totalSeconds +=
            (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      }
    }

    final avgForm = count == 0 ? 0 : (totalForm / count).round();
    final formColor = _formTint(avgForm);

    // Format Duration Text
    String durationText;
    if (totalSeconds >= 3600) {
      int h = totalSeconds ~/ 3600;
      int m = (totalSeconds % 3600) ~/ 60;
      durationText = '${h}h ${m}m';
    } else {
      int m = totalSeconds ~/ 60;
      durationText = (totalSeconds > 0 && m == 0) ? '< 1m' : '${m}m';
    }

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
                  fontWeight: FontWeight.w800,
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
                  accent: formColor,
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
                  icon: Icons.timer_outlined, // Changed Icon to Timer
                  title: 'Total\nDuration', // Changed Title
                  value: durationText, // Changed Value
                  unit: 'time', // Changed Unit
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
                  // Unchanged: We pass formTint just as your existing card expects
                  _WorkoutCard(
                    scale: scale,
                    record: record,
                    formTint: _formTint(record.formScore.toInt()),
                  ),
                  SizedBox(height: 14 * scale),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ProgressMetricCard extends StatelessWidget {
  const _ProgressMetricCard({
    required this.scale,
    required this.title,
    required this.value,
    required this.tint,
    this.suffix,
    this.height,
  });

  final double scale;
  final String title;
  final String value;
  final String? suffix;
  final Color tint;
  final double? height;

  static const _ink = Color(0xFF051328);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: height ?? (120 * scale),
        padding: EdgeInsets.fromLTRB(
          14 * scale,
          12 * scale,
          14 * scale,
          12 * scale,
        ),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16 * scale),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tint,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w700,
                height: 1.10,
              ),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: tint,
                      fontSize: 34 * scale,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      fontFamily: 'DM Sans',
                    ),
                  ),
                  if (suffix != null) ...[
                    SizedBox(width: 6 * scale),
                    Padding(
                      padding: EdgeInsets.only(bottom: 8 * scale),
                      child: Text(
                        suffix!,
                        style: TextStyle(
                          color: _ink.withValues(alpha: 0.65),
                          fontSize: 11 * scale,
                          height: 1.0,
                          fontFamily: 'DM Sans',
                        ),
                      ),
                    ),
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
                    fontWeight: FontWeight.w700,
                    height: 1.10,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: accent,
                    fontSize: 40 * scale,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: 6 * scale),
                Padding(
                  padding: EdgeInsets.only(bottom: 8 * scale),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: unit == '%'
                          ? accent
                          : accent.withValues(alpha: 0.70),
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w600,
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

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.scale,
    required this.record,
    required this.formTint,
  });

  final double scale;
  final WorkoutRecord record;
  final Color formTint;

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
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * scale,
                  vertical: 4 * scale,
                ),
                decoration: BoxDecoration(
                  color: formTint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  '${record.formScore.toInt()}% Form',
                  style: TextStyle(
                    color: formTint,
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w700,
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
          style: TextStyle(
            fontSize: 20 * scale,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF051328),
          ),
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
    if (path != null && path.trim().isNotEmpty) {
      if (!kIsWeb) {
        final f = File(path);
        if (f.existsSync()) img = FileImage(f);
      }
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
