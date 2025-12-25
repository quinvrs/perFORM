import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.userName,
  });

  final String userName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0; // 0=Home, 1=Streak, 2=History

  static const _bgDark = Color.fromARGB(255, 18, 32, 47);
  static const _ink = Color(0xFF051328);
  static const _navBlue = Color(0xFF1F3447);
  static const _yellow = Color(0xFFFEF9C2);

  @override
  Widget build(BuildContext context) {
    final name = widget.userName.trim().isEmpty ? 'Friend' : widget.userName.trim();

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
                    // ===== TOP BACK ARROW (like your 2nd photo) =====
                    Positioned(
                      left: 28 * s,
                      top: 28 * s,
                      child: InkWell(
                        onTap: () {
                          if (Navigator.canPop(context)) Navigator.pop(context);
                        },
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: _ink,
                          size: 28 * s,
                        ),
                      ),
                    ),

                    // ===== GREETING =====
                    Positioned(
                      left: 40 * s,
                      top: 104 * s,
                      child: SizedBox(
                        width: 295 * s,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello,',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 30 * s,
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w500,
                                height: 1.05,
                              ),
                            ),
                            SizedBox(height: 4 * s),
                            Text(
                              name, // ✅ from profile setup
                              style: TextStyle(
                                color: _ink,
                                fontSize: 48 * s,
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ===== INFO ROW =====
                    Positioned(
                      left: 40 * s,
                      top: 220 * s,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 18 * s,
                            height: 18 * s,
                            decoration: const ShapeDecoration(
                              color: _yellow,
                              shape: OvalBorder(),
                            ),
                            child: Center(
                              child: Text(
                                '!',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 12 * s,
                                  fontFamily: 'DM Sans',
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10 * s),
                          SizedBox(
                            width: 263 * s,
                            child: Opacity(
                              opacity: 0.70,
                              child: Text(
                                'You haven’t checked out the app\nrecently. Do some workouts.',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 14 * s,
                                  fontFamily: 'DM Sans',
                                  fontWeight: FontWeight.w400,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ===== YELLOW STREAK CARD =====
                    Positioned(
                      left: 40 * s,
                      top: 283 * s,
                      child: Container(
                        width: 292 * s,
                        height: 113 * s,
                        decoration: BoxDecoration(
                          color: _yellow,
                          borderRadius: BorderRadius.circular(10 * s),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF000000).withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 18 * s,
                              top: 10 * s,
                              child: Text(
                                'Current Streak',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 10 * s,
                                  fontFamily: 'DM Sans',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 18 * s,
                              top: 34 * s,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '10',
                                    style: TextStyle(
                                      color: const Color(0xFFECC051),
                                      fontSize: 48 * s,
                                      fontFamily: 'DM Sans',
                                      fontWeight: FontWeight.w700,
                                      height: 1.0,
                                    ),
                                  ),
                                  SizedBox(width: 2 * s),
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 6 * s),
                                    child: Text(
                                      'days',
                                      style: TextStyle(
                                        color: const Color(0xFFECC051),
                                        fontSize: 16 * s,
                                        fontFamily: 'DM Sans',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 18 * s,
                              bottom: 12 * s,
                              child: Text(
                                '35 Total Sessions Completed',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 10 * s,
                                  fontFamily: 'DM Sans',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),

                            // flame circle
                            Positioned(
                              right: 16 * s,
                              top: 18 * s,
                              child: Column(
                                children: [
                                  Container(
                                    width: 58 * s,
                                    height: 58 * s,
                                    decoration: BoxDecoration(
                                      color: _yellow,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF000000).withValues(alpha: 0.12),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.local_fire_department_rounded,
                                      color: _BottomNav.streakAccent,
                                      size: 37 * s,
                                    ),
                                  ),
                                  SizedBox(height: 6 * s),
                                  Text(
                                    'Keep it up!',
                                    style: TextStyle(
                                      color: const Color(0xFFA65F00),
                                      fontSize: 10 * s,
                                      fontFamily: 'DM Sans',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ===== YOUR PROGRESS =====
                    Positioned(
                      left: 40 * s,
                      top: 414 * s,
                      child: Text(
                        'Your Progress',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 20 * s,
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    // Card 1
                    Positioned(
                      left: 40 * s,
                      top: 449 * s,
                      child: _ProgressCard(
                        s: s,
                        title: 'Average Form Score',
                        mainValue: '88',
                        suffix: '%',
                        rightNote: '+3% from last month',
                      ),
                    ),

                    // Card 2
                    Positioned(
                      left: 40 * s,
                      top: 551 * s,
                      child: _ProgressCard(
                        s: s,
                        title: 'Weekly Session',
                        mainValue: '4',
                        suffix: 'sessions',
                        rightNote: '',
                      ),
                    ),

                    // ===== BOTTOM NAV (curved/notched like Figma) =====
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _BottomNav(
                        scale: s,
                        selectedTab: _tab,
                        onHome: () => setState(() => _tab = 0),
                        onStreak: () => setState(() => _tab = 1),
                        onHistory: () => setState(() => _tab = 2),
                        onPlus: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Camera Exercise')),
                          );
                        },
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.s,
    required this.title,
    required this.mainValue,
    required this.suffix,
    required this.rightNote,
  });

  final double s;
  final String title;
  final String mainValue;
  final String suffix;
  final String rightNote;

  static const _ink = Color(0xFF051328);
  static const _muted = Color(0xFF797B7F);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292 * s,
      height: 84 * s,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10 * s),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16 * s,
            top: 12 * s,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.black,
                fontSize: 16 * s,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Positioned(
            left: 16 * s,
            top: 38 * s,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  mainValue,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 32 * s,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: 8 * s),
                Padding(
                  padding: EdgeInsets.only(bottom: 6 * s),
                  child: Text(
                    suffix,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10 * s,
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (rightNote.isNotEmpty)
            Positioned(
              right: 16 * s,
              bottom: 16 * s,
              child: Text(
                rightNote,
                style: TextStyle(
                  color: _muted,
                  fontSize: 10 * s,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.scale,
    required this.selectedTab,
    required this.onHome,
    required this.onStreak,
    required this.onHistory,
    required this.onPlus,
  });

  final double scale;
  final int selectedTab;
  final VoidCallback onHome;
  final VoidCallback onStreak;
  final VoidCallback onHistory;
  final VoidCallback onPlus;

  static const _navBlue = Color(0xFF1F3447);
  static const _yellow = Color(0xFFFEF9C2);
  static const _ink = Color(0xFF051328);
  static const streakAccent = Color(0xFFECC051);

  @override
  Widget build(BuildContext context) {
    final h = 115 * scale;

    return SizedBox(
      height: h,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;

          // ===============================
          // ✅ MANUAL POSITION CONTROLS
          // (change these numbers freely)
          // ===============================

          // HOME bubble center X (try 0.18..0.28)
          final homeCX = w * 0.20;

          // PLUS button center X (try 0.80..0.92)
          final plusCX = w * 0.83;

          // Y positions
          final double homeBubbleTop = -14 * scale;     // bubble top offset
          final double plusTop = -20 * scale;          // plus top offset
          final double iconsY = 46 * scale;           // streak/history icon top

          // sizes
          final homeDia = 64 * scale;
          final plusDia = 80 * scale;

          // notch shape controls
          final double topY = 18 * scale;             // top edge of nav bar
          final double notchDepth = 40 * scale;       // how deep the home notch dips
          final double homeNotchRadius = homeDia * 0.60;

          // Streak & History X controls (center positions)
          final double streakCX = w * 0.45;
          final double historyCX = w * 0.64;

          // ===============================

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // clipped wavy bar
              Positioned.fill(
                child: ClipPath(
                  clipper: _NavClipper(
                    homeCenterX: homeCX,
                    homeNotchRadius: homeNotchRadius,
                    topY: topY,
                    notchDepth: notchDepth,
                  ),
                  child: Container(color: _navBlue),
                ),
              ),

              // HOME bubble (in notch)
              Positioned(
                left: homeCX - homeDia / 2,
                top: homeBubbleTop,
                child: Column(
                  children: [
                    Container(
                      width: homeDia,
                      height: homeDia,
                      decoration: BoxDecoration(
                        color: _navBlue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF000000).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: onHome,
                        customBorder: const CircleBorder(),
                        child: Icon(
                          Icons.home_rounded,
                          color: _yellow,
                          size: 30 * scale,
                        ),
                      ),
                    ),
                    SizedBox(height: 10 * scale),
                    Text(
                      'Home',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12 * scale,
                        fontFamily: 'DM Sans',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // STREAK icon
              Positioned(
                left: streakCX - (14 * scale),
                top: iconsY,
                child: InkWell(
                onTap: onStreak,
                child: Icon(
                  Icons.grid_view_rounded,
                  size: 28 * scale,
                  color: Colors.white.withValues(
                    alpha: selectedTab == 1 ? 1.0 : 0.70,
                  ),
                ),
              ),
            ),// HISTORY icon

              Positioned(
                left: historyCX - (14 * scale),
                top: iconsY,
                child: InkWell(
                  onTap: onHistory,
                  child: Icon(
                    Icons.history_rounded,
                    size: 28 * scale,
                    color: Colors.white.withValues(
                      alpha: selectedTab == 2 ? 1.0 : 0.55,
                    ),
                  ),
                ),
              ),

              // PLUS button
              Positioned(
                left: plusCX - plusDia / 2,
                top: plusTop,
                child: InkWell(
                  onTap: onPlus,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: plusDia,
                    height: plusDia,
                    decoration: BoxDecoration(
                      color: _yellow,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF000000).withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 34 * scale,
                      color: _ink,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavClipper extends CustomClipper<Path> {
  _NavClipper({
    required this.homeCenterX,
    required this.homeNotchRadius,
    required this.topY,
    required this.notchDepth,
  });

  final double homeCenterX;
  final double homeNotchRadius;
  final double topY;
  final double notchDepth;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    final left = 0.0;
    final right = w;

    final notchStartX = homeCenterX - homeNotchRadius * 1.6;
    final notchEndX = homeCenterX + homeNotchRadius * 1.6;

    final notchBottomY = topY + notchDepth;

    final p = Path();

    // top edge
    p.moveTo(left, topY);

    // line to before notch
    p.lineTo(notchStartX, topY);

    // notch dip (smooth)
    p.cubicTo(
      homeCenterX - homeNotchRadius,
      topY,
      homeCenterX - homeNotchRadius,
      notchBottomY,
      homeCenterX,
      notchBottomY,
    );
    p.cubicTo(
      homeCenterX + homeNotchRadius,
      notchBottomY,
      homeCenterX + homeNotchRadius,
      topY,
      notchEndX,
      topY,
    );

    // continue to right
    p.lineTo(right, topY);

    // sides + bottom
    p.lineTo(right, h);
    p.lineTo(left, h);
    p.close();

    return p;
  }

  @override
  bool shouldReclip(covariant _NavClipper oldClipper) {
    return homeCenterX != oldClipper.homeCenterX ||
        homeNotchRadius != oldClipper.homeNotchRadius ||
        topY != oldClipper.topY ||
        notchDepth != oldClipper.notchDepth;
  }
}
