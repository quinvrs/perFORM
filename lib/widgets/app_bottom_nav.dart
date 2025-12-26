import 'package:flutter/material.dart';

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({
    super.key,
    required this.scale,
    required this.selectedTab, // 0=Home, 1=Streak, 2=History
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

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  static const _navBlue = Color(0xFF1F3447);
  static const _yellow = Color(0xFFFEF9C2);
  static const _ink = Color(0xFF051328);

  @override
  Widget build(BuildContext context) {
    final h = 115 * widget.scale;

    return SizedBox(
      height: h,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;

          // positions (tweak if needed)
          final homeCX = w * 0.18;
          final streakCX = w * 0.40;
          final historyCX = w * 0.62;
          final plusCX = w * 0.86;

          double targetCX() {
            if (widget.selectedTab == 0) return homeCX;
            if (widget.selectedTab == 1) return streakCX;
            return historyCX;
          }

          IconData selectedIcon() {
            if (widget.selectedTab == 0) return Icons.home_rounded;
            if (widget.selectedTab == 1) return Icons.grid_view_rounded;
            return Icons.history_rounded;
          }

          String selectedLabel() {
            if (widget.selectedTab == 0) return 'Home';
            if (widget.selectedTab == 1) return 'Streak';
            return 'History';
          }

          final bubbleDia = 64 * widget.scale;
          final plusDia = 80 * widget.scale;

          final bubbleTop = -14 * widget.scale;
          final plusTop = -20 * widget.scale;

          final iconsTop = 44 * widget.scale;
          final labelsTop = 76 * widget.scale;

          final topY = 18 * widget.scale;
          final notchDepth = 40 * widget.scale;
          final notchRadius = bubbleDia * 0.60;

          Widget navItem({
            required double cx,
            required IconData icon,
            required String label,
            required VoidCallback onTap,
          }) {
            return Positioned(
              left: cx - (54 * widget.scale) / 2,
              top: iconsTop - 10 * widget.scale,
              child: SizedBox(
                width: 54 * widget.scale,
                height: 76 * widget.scale,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Column(
                    children: [
                      Icon(icon, size: 28 * widget.scale, color: Colors.white.withAlpha(170)),
                      SizedBox(height: (labelsTop - iconsTop) - 12 * widget.scale),
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withAlpha(170),
                          fontSize: 12 * widget.scale,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'DM Sans',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: targetCX()),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, cx, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // background bar (ignore taps so buttons always clickable)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: ClipPath(
                        clipper: _NavClipper(
                          centerX: cx,
                          notchRadius: notchRadius,
                          topY: topY,
                          notchDepth: notchDepth,
                        ),
                        child: Container(color: _navBlue),
                      ),
                    ),
                  ),

                  // unselected items
                  if (widget.selectedTab != 0)
                    navItem(cx: homeCX, icon: Icons.home_rounded, label: 'Home', onTap: widget.onHome),
                  if (widget.selectedTab != 1)
                    navItem(cx: streakCX, icon: Icons.grid_view_rounded, label: 'Streak', onTap: widget.onStreak),
                  if (widget.selectedTab != 2)
                    navItem(cx: historyCX, icon: Icons.history_rounded, label: 'History', onTap: widget.onHistory),

                  // selected floating bubble (animated via cx)
                  Positioned(
                    left: cx - bubbleDia / 2,
                    top: bubbleTop,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (widget.selectedTab == 0) widget.onHome();
                        if (widget.selectedTab == 1) widget.onStreak();
                        if (widget.selectedTab == 2) widget.onHistory();
                      },
                      child: Column(
                        children: [
                          Container(
                            width: bubbleDia,
                            height: bubbleDia,
                            decoration: BoxDecoration(
                              color: _navBlue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF000000).withAlpha(70),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(selectedIcon(), color: _yellow, size: 30 * widget.scale),
                          ),
                          SizedBox(height: 10 * widget.scale),
                          Text(
                            selectedLabel(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12 * widget.scale,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'DM Sans',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // plus button (kept fixed)
                  Positioned(
                    left: plusCX - plusDia / 2,
                    top: plusTop,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onPlus,
                      child: Container(
                        width: plusDia,
                        height: plusDia,
                        decoration: BoxDecoration(
                          color: _yellow,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF000000).withAlpha(45),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(Icons.add_rounded, size: 34 * widget.scale, color: _ink),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _NavClipper extends CustomClipper<Path> {
  _NavClipper({
    required this.centerX,
    required this.notchRadius,
    required this.topY,
    required this.notchDepth,
  });

  final double centerX;
  final double notchRadius;
  final double topY;
  final double notchDepth;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    final notchStartX = centerX - notchRadius * 1.6;
    final notchEndX = centerX + notchRadius * 1.6;
    final notchBottomY = topY + notchDepth;

    final p = Path()
      ..moveTo(0, topY)
      ..lineTo(notchStartX, topY);

    p.cubicTo(
      centerX - notchRadius,
      topY,
      centerX - notchRadius,
      notchBottomY,
      centerX,
      notchBottomY,
    );
    p.cubicTo(
      centerX + notchRadius,
      notchBottomY,
      centerX + notchRadius,
      topY,
      notchEndX,
      topY,
    );

    p
      ..lineTo(w, topY)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    return p;
  }

  @override
  bool shouldReclip(covariant _NavClipper oldClipper) {
    return centerX != oldClipper.centerX ||
        notchRadius != oldClipper.notchRadius ||
        topY != oldClipper.topY ||
        notchDepth != oldClipper.notchDepth;
  }
}
