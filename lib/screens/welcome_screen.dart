import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../app_state.dart';

class WelcomeFlowScreen extends StatefulWidget {
  const WelcomeFlowScreen({super.key});

  @override
  State<WelcomeFlowScreen> createState() => _WelcomeFlowScreenState();
}

class _WelcomeFlowScreenState extends State<WelcomeFlowScreen>
    with SingleTickerProviderStateMixin {
  int _i = 0;

  static const double _finalIconY = -0.30;

  static const _frames =
      <({Alignment align, double scale, double bgOpacity, double uiOpacity})>[
    (
      align: Alignment(-0.85, -0.85),
      scale: 0.22,
      bgOpacity: 0.0,
      uiOpacity: 0.0,
    ),
    (
      align: Alignment(0.0, -0.05),
      scale: 0.35,
      bgOpacity: 0.0,
      uiOpacity: 0.0,
    ),
    (
      align: Alignment(0.0, -0.05),
      scale: 0.55,
      bgOpacity: 0.0,
      uiOpacity: 0.0,
    ),
    (
      align: Alignment(0.0, -0.05),
      scale: 0.55,
      bgOpacity: 1.0,
      uiOpacity: 0.0,
    ),
    (
      align: Alignment(0.0, _finalIconY),
      scale: 1.0,
      bgOpacity: 1.0,
      uiOpacity: 1.0,
    ),
  ];

  static const _bounce = Duration(milliseconds: 180);
  static const _hold = Duration(milliseconds: 550);

  late final AnimationController _backgroundController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _playOnce();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _playOnce() async {
    for (var k = 0; k < _frames.length; k++) {
      if (!mounted) return;
      setState(() => _i = k);
      await Future.delayed(_hold);
    }

    if (!mounted || _navigated) return;
    _navigated = true;

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final state = AppStateScope.of(context);

    if (state.isLoading) {
      var waited = 0;

      while (state.isLoading && waited < 2000) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited += 100;

        if (!mounted) return;
      }
    }

    final target = state.hasProfile ? '/home' : '/gender';

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, target);
  }

  @override
  Widget build(BuildContext context) {
    final f = _frames[_i];

    final mq = MediaQuery.of(context);
    final size = mq.size;
    final s = (size.shortestSide / 375.0).clamp(0.90, 1.10);

    final logoW = (175 * s).clamp(140.0, 210.0);
    final logoH = (201 * s).clamp(160.0, 240.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4DE),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final w = c.maxWidth;

            final textLogoMaxW = (w * 0.58).clamp(200.0, 520.0);
            final textLogoMaxH = (h * 0.12).clamp(50.0, 140.0);

            final gapIconToText = (35 * s).clamp(30.0, 40.0);

            final iconCenterY = (h / 2) * (f.align.y + 1.0);
            final iconHalfH = (logoH * f.scale) / 2;

            final textTop = (iconCenterY + iconHalfH + gapIconToText)
                .clamp(0.0, h - 220);

            return SizedBox.expand(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0xFFFFF4DE),
                    ),
                  ),

                  // Animated orange + green background.
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: f.bgOpacity,
                      child: AnimatedBuilder(
                        animation: _backgroundController,
                        builder: (context, _) {
                          final t = _backgroundController.value;
                          final wave = math.sin(t * math.pi * 2);
                          final wave2 = math.cos(t * math.pi * 2);

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFF3DC),
                                        Color(0xFFFFD79A),
                                        Color(0xFFE8F2B1),
                                      ],
                                      stops: [0.0, 0.52, 1.0],
                                    ),
                                  ),
                                ),
                              ),

                              // Moving orange area.
                              Positioned(
                                left: -w * 0.34 + (w * 0.18 * wave),
                                top: -h * 0.10 + (h * 0.08 * wave2),
                                child: _MovingGlow(
                                  size: w * 1.08,
                                  colors: const [
                                    Color(0xFFFF5A00),
                                    Color(0xFFFF9C32),
                                  ],
                                  opacity: 0.90,
                                ),
                              ),

                              // Second orange area.
                              Positioned(
                                right: -w * 0.48 + (w * 0.14 * wave2),
                                bottom: -h * 0.26 + (h * 0.08 * wave),
                                child: _MovingGlow(
                                  size: w * 1.18,
                                  colors: const [
                                    Color(0xFFFF7A00),
                                    Color(0xFFFFB84D),
                                  ],
                                  opacity: 0.82,
                                ),
                              ),

                              // Visible lime green accent.
                              Positioned(
                                right: -w * 0.18 + (w * 0.10 * wave),
                                top: h * 0.06 + (h * 0.06 * wave2),
                                child: _MovingGlow(
                                  size: w * 0.72,
                                  colors: const [
                                    Color(0xFFDFFF7A),
                                    Color(0xFFA9C93B),
                                  ],
                                  opacity: 0.72,
                                ),
                              ),

                              // Visible olive-green accent.
                              Positioned(
                                left: -w * 0.30 + (w * 0.08 * wave2),
                                bottom: -h * 0.12 + (h * 0.05 * wave),
                                child: _MovingGlow(
                                  size: w * 0.90,
                                  colors: const [
                                    Color(0xFF6D8524),
                                    Color(0xFF536B1C),
                                  ],
                                  opacity: 0.58,
                                ),
                              ),

                              // Green moving ribbon through the middle.
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _GreenRibbonPainter(
                                      progress: t,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Animated logo.
                  AnimatedAlign(
                    duration: _bounce,
                    curve: Curves.bounceOut,
                    alignment: f.align,
                    child: AnimatedScale(
                      duration: _bounce,
                      curve: Curves.bounceOut,
                      scale: f.scale,
                      child: SizedBox(
                        width: logoW,
                        height: logoH,
                        child: Image.asset(
                          'assets/corerect-transparent-1.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  // WELCOME TO + text-logo image.
                  Positioned(
                    top: textTop,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: f.uiOpacity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'WELCOME TO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              height: 1.1,
                              color: const Color(0xFF173A12),
                              fontSize: 20 * s,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'DM Sans',
                              letterSpacing: 0.7,
                            ),
                          ),
                          SizedBox(
                            height: (6 * s).clamp(4.0, 10.0),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: textLogoMaxW,
                              maxHeight: textLogoMaxH,
                            ),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: ClipRect(
                                child: Align(
                                  alignment: Alignment.center,
                                  widthFactor: 0.61,
                                  heightFactor: 0.57,
                                  child: Image.asset(
                                    'assets/corerect-text-logo.png',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MovingGlow extends StatelessWidget {
  const _MovingGlow({
    required this.size,
    required this.colors,
    required this.opacity,
  });

  final double size;
  final List<Color> colors;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors.first,
                colors.last.withValues(alpha: 0.78),
                colors.last.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.58, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _GreenRibbonPainter extends CustomPainter {
  const _GreenRibbonPainter({
    required this.progress,
  });

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final shift = math.sin(progress * math.pi * 2) * size.width * 0.08;
    final lift = math.cos(progress * math.pi * 2) * size.height * 0.025;

    final path = Path()
      ..moveTo(-size.width * 0.25 + shift, size.height * 0.60 + lift)
      ..cubicTo(
        size.width * 0.08 + shift,
        size.height * 0.44 + lift,
        size.width * 0.36 + shift,
        size.height * 0.72 + lift,
        size.width * 0.66 + shift,
        size.height * 0.54 + lift,
      )
      ..cubicTo(
        size.width * 0.84 + shift,
        size.height * 0.44 + lift,
        size.width * 1.02 + shift,
        size.height * 0.48 + lift,
        size.width * 1.24 + shift,
        size.height * 0.40 + lift,
      )
      ..lineTo(size.width * 1.24 + shift, size.height * 0.51 + lift)
      ..cubicTo(
        size.width * 0.96 + shift,
        size.height * 0.58 + lift,
        size.width * 0.80 + shift,
        size.height * 0.58 + lift,
        size.width * 0.62 + shift,
        size.height * 0.68 + lift,
      )
      ..cubicTo(
        size.width * 0.34 + shift,
        size.height * 0.82 + lift,
        size.width * 0.02 + shift,
        size.height * 0.56 + lift,
        -size.width * 0.25 + shift,
        size.height * 0.72 + lift,
      )
      ..close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xAA536B1C),
          Color(0xBBDFFF7A),
          Color(0x996D8524),
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GreenRibbonPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
