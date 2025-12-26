import 'package:flutter/material.dart';

class WelcomeFlowScreen extends StatefulWidget {
  const WelcomeFlowScreen({super.key});

  @override
  State<WelcomeFlowScreen> createState() => _WelcomeFlowScreenState();
}

class _WelcomeFlowScreenState extends State<WelcomeFlowScreen> {
  int _i = 0;

  static const double _finalIconY = -0.25;
  static const double _textGroupY = 0.18;
  static const double _coreRectTightenPx = 1;

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
  }

  @override
  Widget build(BuildContext context) {
    final f = _frames[_i];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 18, 32, 47),
      body: Center(
        child: LayoutBuilder(
          builder: (context, c) {
            final cardW = (c.maxWidth * 0.9).clamp(320.0, 420.0);
            final cardH = cardW * (812 / 375);

            final logoW = cardW * (203 / 375);
            final logoH = cardH * (229 / 812);

            return ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: SizedBox(
                width: cardW,
                height: cardH,
                child: Stack(
                  children: [
                    Container(color: Colors.white),

                    AnimatedOpacity(
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

                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: f.uiOpacity,
                      child: Stack(
                        children: [
                          Align(
                            alignment: const Alignment(0.0, _textGroupY),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'WELCOME TO',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF1F3447),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'DM Sans',
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'CORE',
                                      style: TextStyle(
                                        color: Color(0xFF537892),
                                        fontSize: 48,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'DM Sans',
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(-_coreRectTightenPx, 0),
                                      child: const Text(
                                        'rect',
                                        style: TextStyle(
                                          color: Color(0xFF051328),
                                          fontSize: 48,
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

                          Positioned(
                            right: 18,
                            bottom: 18,
                            child: InkWell(
                              onTap: () {
                                Navigator.pushReplacementNamed(context, '/profile');
                              },
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: const ShapeDecoration(
                                  color: Color(0xFFFEF9C2),
                                  shape: OvalBorder(),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward,
                                  color: Color(0xFF1F3447),
                                ),
                              ),
                            ),
                          ),
                        ],
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
