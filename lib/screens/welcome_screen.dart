import 'dart:async';
import 'package:flutter/material.dart';

class LogoFrame {
  final double left;
  final double top;
  final double width;
  final double height;

  const LogoFrame({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

class WelcomeSmartAnimate extends StatefulWidget {
  const WelcomeSmartAnimate({super.key});

  @override
  State<WelcomeSmartAnimate> createState() => _WelcomeSmartAnimateState();
}

class _WelcomeSmartAnimateState extends State<WelcomeSmartAnimate> {
  static const _baseW = 375.0;
  static const _baseH = 812.0;

  static const List<LogoFrame> _frames = [
    LogoFrame(left: 119, top: 0, width: 104, height: 85),
    LogoFrame(left: 135, top: 352, width: 104, height: 117),
    LogoFrame(left: 96, top: 315, width: 170, height: 191),
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      setState(() => _index = (_index + 1) % _frames.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() => setState(() => _index = (_index + 1) % _frames.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, c) {
          final sx = c.maxWidth / _baseW;
          final sy = c.maxHeight / _baseH;
          final f = _frames[_index];

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _next,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.bounceOut,
                  left: f.left * sx,
                  top: f.top * sy,
                  width: f.width * sx,
                  height: f.height * sy,
                  child: Image.asset(
                    'assets/corerect-transparent-1.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
