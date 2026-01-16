import 'package:flutter/material.dart';
import '../app_state.dart';

class WelcomeFlowScreen extends StatefulWidget {
  const WelcomeFlowScreen({super.key});

  @override
  State<WelcomeFlowScreen> createState() => _WelcomeFlowScreenState();
}

class _WelcomeFlowScreenState extends State<WelcomeFlowScreen> {
  int _i = 0;

  static const double _finalIconY = -0.15;

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

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _playOnce();
  }

  Future<void> _playOnce() async {
    for (var k = 0; k < _frames.length; k++) {
      if (!mounted) return;
      setState(() => _i = k);
      await Future.delayed(_hold);
    }

    if (!mounted || _navigated) return;
    _navigated = true;

    // small delay so last frame settles
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final state = AppStateScope.of(context);

    // -----------------------------------------------------------
    // FIX: Use 'isLoading' instead of '!loaded'
    // -----------------------------------------------------------
    if (state.isLoading) {
      var waited = 0;
      while (state.isLoading && waited < 2000) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited += 100;
        if (!mounted) return;
      }
    }

    // Since AuthGate handles the Profile check, if we are here,
    // it usually means we need to set up.
    // However, we keep this check just in case.
    final target = state.hasProfile ? '/home' : '/gender';
    
    Navigator.pushReplacementNamed(context, target);
  }

  @override
  Widget build(BuildContext context) {
    final f = _frames[_i];

    final mq = MediaQuery.of(context);
    final size = mq.size;
    // Full screen size
    final s = (size.shortestSide / 375.0).clamp(0.90, 1.10);

    final logoW = (175 * s).clamp(140.0, 210.0);
    final logoH = (201 * s).clamp(160.0, 240.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final h = c.maxHeight;
          final w = c.maxWidth;

          final textLogoMaxW = (w * 0.58).clamp(200.0, 520.0); 
          final textLogoMaxH = (h * 0.12).clamp(50.0, 140.0);  

          final gapIconToText = (35 * s).clamp(30.0, 40.0); // adjust if you want closer

          final iconCenterY = (h / 2) * (f.align.y + 1.0);
          final iconHalfH = (logoH * f.scale) / 2;

          final textTop = (iconCenterY + iconHalfH + gapIconToText)
              .clamp(0.0, h - 220); 
              
          return SizedBox.expand(
            child: Stack(
              children: [
                // Base white
                Positioned.fill(child: Container(color: Colors.white)),

                // Animated gradient background
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: f.bgOpacity,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            Color(0xFFFFF5B8),
                            Color(0xFFBFD1E6),
                            Color(0xFF6E7C8A),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Animated logo
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

                // UI (WELCOME TO + text-logo image)
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
                                color: const Color(0xFF1F3447),
                                fontSize: 20 * s,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'DM Sans',
                              ),
                            ),
                            SizedBox(height: (6 * s).clamp(4.0, 10.0)),

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
                                  child: Image.asset('assets/corerect-text-logo.png'),
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