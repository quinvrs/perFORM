import 'dart:math' as math;
import 'dart:ui' as ui;

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

  static const double _finalGroupY = -0.10;

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
      align: Alignment(0.0, _finalGroupY),
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

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3DC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final w = c.maxWidth;

            // Balanced logo size.
            final logoW = (w * 0.92).clamp(280.0, 420.0);
            final logoH = (h * 0.24).clamp(120.0, 190.0);

            return SizedBox.expand(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0xFFFFF3DC),
                    ),
                  ),

                  // Animated orange + green background matched to logo colors.
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
                                        Color(0xFFFFB15A),
                                        Color(0xFFEAF0AF),
                                        Color(0xFF637A22),
                                      ],
                                      stops: [0.0, 0.43, 0.72, 1.0],
                                    ),
                                  ),
                                ),
                              ),

                              // Main logo-orange glow.
                              Positioned(
                                left: -w * 0.38 + (w * 0.17 * wave),
                                top: -h * 0.12 + (h * 0.08 * wave2),
                                child: _MovingGlow(
                                  size: w * 1.12,
                                  colors: const [
                                    Color(0xFFFF6A00),
                                    Color(0xFFFF9B2F),
                                  ],
                                  opacity: 0.88,
                                ),
                              ),

                              // Warm orange lower glow.
                              Positioned(
                                right: -w * 0.50 + (w * 0.13 * wave2),
                                bottom: -h * 0.29 + (h * 0.08 * wave),
                                child: _MovingGlow(
                                  size: w * 1.20,
                                  colors: const [
                                    Color(0xFFFF7A00),
                                    Color(0xFFFFBA56),
                                  ],
                                  opacity: 0.78,
                                ),
                              ),

                              // Logo-green upper accent.
                              Positioned(
                                right: -w * 0.22 + (w * 0.09 * wave),
                                top: h * 0.08 + (h * 0.05 * wave2),
                                child: _MovingGlow(
                                  size: w * 0.78,
                                  colors: const [
                                    Color(0xFFDCEB63),
                                    Color(0xFF6E8527),
                                  ],
                                  opacity: 0.70,
                                ),
                              ),

                              // Deep green lower accent.
                              Positioned(
                                left: -w * 0.34 + (w * 0.08 * wave2),
                                bottom: -h * 0.17 + (h * 0.05 * wave),
                                child: _MovingGlow(
                                  size: w * 0.95,
                                  colors: const [
                                    Color(0xFF6D8524),
                                    Color(0xFF173A12),
                                  ],
                                  opacity: 0.62,
                                ),
                              ),

                              // Lowered moving wave.
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

                  // Bigger animated logo only.
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
                        child: const _GlowingAssetLogo(
                          asset: 'assets/perform-text-logo.png',
                        ),
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

class _GlowingAssetLogo extends StatelessWidget {
  const _GlowingAssetLogo({
    required this.asset,
  });

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: 1.07,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 16,
              sigmaY: 16,
            ),
            child: Opacity(
              opacity: 0.45,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),

        Transform.translate(
          offset: const Offset(0, 4),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 8,
              sigmaY: 8,
            ),
            child: Opacity(
              opacity: 0.30,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),

        Image.asset(
          asset,
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ],
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

    // Increase this to move the wave lower.
    // Lower value = wave goes higher.
    final down = size.height * 0.13;

    final path = Path()
      ..moveTo(-size.width * 0.25 + shift, size.height * 0.60 + lift + down)
      ..cubicTo(
        size.width * 0.08 + shift,
        size.height * 0.44 + lift + down,
        size.width * 0.36 + shift,
        size.height * 0.72 + lift + down,
        size.width * 0.66 + shift,
        size.height * 0.54 + lift + down,
      )
      ..cubicTo(
        size.width * 0.84 + shift,
        size.height * 0.44 + lift + down,
        size.width * 1.02 + shift,
        size.height * 0.48 + lift + down,
        size.width * 1.24 + shift,
        size.height * 0.40 + lift + down,
      )
      ..lineTo(size.width * 1.24 + shift, size.height * 0.51 + lift + down)
      ..cubicTo(
        size.width * 0.96 + shift,
        size.height * 0.58 + lift + down,
        size.width * 0.80 + shift,
        size.height * 0.58 + lift + down,
        size.width * 0.62 + shift,
        size.height * 0.68 + lift + down,
      )
      ..cubicTo(
        size.width * 0.34 + shift,
        size.height * 0.82 + lift + down,
        size.width * 0.02 + shift,
        size.height * 0.56 + lift + down,
        -size.width * 0.25 + shift,
        size.height * 0.72 + lift + down,
      )
      ..close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xAA173A12),
          Color(0xBBDCEB63),
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