import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/app_bottom_nav.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  // Fixed current month
  final DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const _bgDark = Color.fromARGB(255, 18, 32, 47);
  static const _ink = Color(0xFF051328);
  static const _streakAccent = Color(0xFFECC051);
  static const _weeklyBlue = Color(0xFF537892);
  static const _green = Color(0xFF00C951);

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    // Full screen sizing (design width = 375)
    final size = MediaQuery.sizeOf(context);
    final s = size.width / 375.0;

    // bottom nav height allowance (same idea as before)
    final navPad = 130 * s;

    final streak = state.currentStreak == 0 ? 10 : state.currentStreak;
    final weekly = state.weeklySessions();

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24 * s, 24 * s, 24 * s, navPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pushReplacementNamed(context, '/home'),
                          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28 * s),
                        ),
                        const Spacer(),
                        Text(
                          'Activity Calendar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22 * s,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(width: 28 * s),
                      ],
                    ),

                    SizedBox(height: 18 * s),

                    // Metric cards row (NO OVERFLOW)
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            s: s,
                            tint: _streakAccent.withValues(alpha: 0.12),
                            title: 'Streak',
                            titleColor: _streakAccent,
                            icon: Icons.flag_rounded,
                            iconColor: _streakAccent,
                            value: '$streak',
                            valueColor: _streakAccent,
                            suffix: '',
                          ),
                        ),
                        SizedBox(width: 16 * s),
                        Expanded(
                          child: _MetricCard(
                            s: s,
                            tint: _weeklyBlue.withValues(alpha: 0.12),
                            title: 'Weekly\nSessions',
                            titleColor: _weeklyBlue,
                            icon: Icons.sports_gymnastics_rounded,
                            iconColor: _weeklyBlue,
                            value: '$weekly',
                            valueColor: _weeklyBlue,
                            suffix: 'sessions',
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 18 * s),

                    // Calendar card (white)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14 * s),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF000000).withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(14 * s),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_monthName(_month.month)} ${_month.year}',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20 * s,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 10 * s),
                          _DowHeader(s: s),
                          SizedBox(height: 10 * s),

                          _CalendarGrid(
                            s: s,
                            month: _month,
                            isDone: (d) => state.isWorkoutDay(d),
                            onToggle: (d) => state.toggleWorkoutDay(d),
                          ),

                          SizedBox(height: 14 * s),

                          // Legend
                          Row(
                            children: [
                              Container(
                                width: 13 * s,
                                height: 13 * s,
                                decoration: BoxDecoration(
                                  color: _green,
                                  borderRadius: BorderRadius.circular(2 * s),
                                ),
                              ),
                              SizedBox(width: 8 * s),
                              Text(
                                'Workout Done',
                                style: TextStyle(color: _ink, fontSize: 12 * s),
                              ),
                              SizedBox(width: 18 * s),
                              Container(
                                width: 13 * s,
                                height: 13 * s,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(2 * s),
                                ),
                              ),
                              SizedBox(width: 8 * s),
                              Text(
                                'No Activity',
                                style: TextStyle(color: _ink, fontSize: 12 * s),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom nav pinned
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: Colors.transparent,
                child: AppBottomNav(
                  scale: s,
                  selectedTab: 1,
                  onHome: () => Navigator.pushReplacementNamed(context, '/home'),
                  onStreak: () {},
                  onHistory: () => Navigator.pushReplacementNamed(context, '/history'),
                  onPlus: () => Navigator.pushNamed(context, '/exercise_select'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[m - 1];
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.s,
    required this.tint,
    required this.title,
    required this.titleColor,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.valueColor,
    required this.suffix,
  });

  final double s;
  final Color tint;
  final String title;
  final Color titleColor;
  final IconData icon;
  final Color iconColor;
  final String value;
  final Color valueColor;
  final String suffix;

  static const _ink = Color(0xFF051328);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132 * s,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20 * s),
      ),
      padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 12 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16 * s, color: iconColor),
              SizedBox(width: 7 * s),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 14 * s,
                    fontWeight: FontWeight.w600,
                    height: 1.10,
                  ),
                ),
              ),
            ],
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
                    color: valueColor,
                    fontSize: 36 * s,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    fontFamily: 'DM Sans',
                  ),
                ),
                if (suffix.isNotEmpty) ...[
                  SizedBox(width: 8 * s),
                  Padding(
                    padding: EdgeInsets.only(bottom: 6 * s),
                    child: Text(
                      suffix,
                      style: TextStyle(
                        color: _ink.withValues(alpha: 0.55),
                        fontSize: 14 * s,
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
    );
  }
}

class _DowHeader extends StatelessWidget {
  const _DowHeader({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: List.generate(7, (i) {
        return Expanded(
          child: Center(
            child: Text(
              days[i],
              style: TextStyle(
                color: const Color(0xFF797B7F),
                fontSize: 13 * s,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.s,
    required this.month,
    required this.isDone,
    required this.onToggle,
  });

  final double s;
  final DateTime month;
  final bool Function(DateTime day) isDone;
  final void Function(DateTime day) onToggle;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    // Sunday=0 ... Saturday=6
    final firstWeekday = first.weekday % 7;

    const totalCells = 42; // 6 weeks
    final cells = List<DateTime?>.generate(totalCells, (i) {
      final dayNum = i - firstWeekday + 1;
      if (dayNum < 1 || dayNum > daysInMonth) return null;
      return DateTime(month.year, month.month, dayNum);
    });

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8 * s,
        crossAxisSpacing: 8 * s,
        childAspectRatio: (32 / 31),
      ),
      itemBuilder: (context, i) {
        final d = cells[i];
        if (d == null) return const SizedBox.shrink();

        final done = isDone(d);
        final bg = done ? const Color(0xFF00C951) : const Color(0xFFF3F4F6);
        final fg = done ? Colors.white : const Color(0xFF797B7F);

        return InkWell(
          borderRadius: BorderRadius.circular(10 * s),
          onTap: () => onToggle(d),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10 * s),
            ),
            child: Center(
              child: Text(
                '${d.day}',
                style: TextStyle(
                  color: fg,
                  fontSize: 13 * s,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
