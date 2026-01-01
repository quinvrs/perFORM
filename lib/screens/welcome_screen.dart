import 'package:flutter/material.dart';

class WelcomeFlowScreen extends StatefulWidget {
  const WelcomeFlowScreen({super.key});

  @override
  State<WelcomeFlowScreen> createState() => _WelcomeFlowScreenState();
}

class _WelcomeFlowScreenState extends State<WelcomeFlowScreen> {
  int _i = 0;

  static const double _finalIconY = -0.27;
  static const double _textGroupY = 0.20;
  static const double _coreRectTightenPx = 0;

  static const _frames = <({
    Alignment align,
    double scale,
    double bgOpacity,
    double uiOpacity,
  })>[
    (align: Alignment(-0.85, -0.85), scale: 0.22, bgOpacity: 0.0, uiOpacity: 0.0),
    (align: Alignment(0.0, -0.05), scale: 0.35, bgOpacity: 0.0, uiOpacity: 0.0),
    (align: Alignment(0.0, -0.05), scale: 0.55, bgOpacity: 0.0, uiOpacity: 0.0),
    (align: Alignment(0.0, -0.05), scale: 0.55, bgOpacity: 1.0, uiOpacity: 0.0),
    (align: Alignment(0.0, _finalIconY), scale: 1.0, bgOpacity: 1.0, uiOpacity: 1.0),
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

    Navigator.pushReplacementNamed(context, '/gender');
  }

  @override
  Widget build(BuildContext context) {
    final f = _frames[_i];

    // Full screen size
    final size = MediaQuery.sizeOf(context);
    final s = size.width / 375.0;

    final logoW = 175 * s;
    final logoH = 201 * s;

    return Scaffold(
      backgroundColor: Colors.white, 
      body: SizedBox.expand( 
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

            // UI text (button removed)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: f.uiOpacity,
                child: Align(
                  alignment: const Alignment(0.0, _textGroupY),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'WELCOME TO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          height: 0.6,
                          color: const Color(0xFF1F3447),
                          fontSize: 20 * s,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'DM Sans',
                        ),
                      ),
                      const SizedBox(height: 0),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'CORE',
                            style: TextStyle(
                              color: const Color(0xFF537892),
                              fontSize: 48 * s,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'DM Sans',
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(-_coreRectTightenPx, 0),
                            child: Text(
                              'rect',
                              style: TextStyle(
                                color: const Color(0xFF051328),
                                fontSize: 48 * s,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'DM Sans',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
