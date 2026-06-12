import 'package:flutter/material.dart';
import '../app_state.dart';

class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  static const _ink = Color(0xFF102A08);
  static const _yellow = Color(0xFFFF6A00);

  late final PageController _pageCtrl;

  final _items = const <_GenderItem>[
    _GenderItem(gender: Gender.male, label: 'Male', asset: 'assets/male-avatar.png'),
    _GenderItem(gender: Gender.female, label: 'Female', asset: 'assets/female-avatar.png'),
  ];

  int _pageIndex = 0;
  Gender? _selected;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88);

    _pageIndex = 0;
    _selected = _items[0].gender;
  }


  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final s = MediaQuery.sizeOf(context).width / 375.0;

    // progress between back and skip (gender step = 1/3)
    final progress = 1 / 3;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4DE),
      body: SafeArea(
        bottom: false,
        child: SizedBox.expand(
          child: Stack(
            children: [
              // TOP ROW: back + full progress line + skip
              Positioned(
                left: 16 * s,
                right: 16 * s,
                top: 10 * s,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/');
                      },
                      child: Icon(Icons.arrow_back_rounded, color: _ink, size: 26 * s),
                    ),
                    SizedBox(width: 12 * s),

                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          height: 4 * s,
                          color: Colors.black.withAlpha(20), // track
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress, // yellow fill %
                              child: Container(color: _yellow),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 12 * s),
                    InkWell(
                      onTap: () => Navigator.pushReplacementNamed(context, '/profile'),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: _ink.withAlpha(160),
                          fontSize: 12 * s,
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // TITLE
              Positioned(
                left: 24 * s,
                right: 24 * s,
                top: 70 * s,
                child: Column(
                  children: [
                    Text(
                      "What's your gender?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 22 * s,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'DM Sans',
                      ),
                    ),
                    SizedBox(height: 6 * s),
                    Text(
                      'Let us know you better',
                      style: TextStyle(
                        color: _ink.withAlpha(140),
                        fontSize: 12 * s,
                        fontFamily: 'DM Sans',
                      ),
                    ),
                  ],
                ),
              ),

              // SLIDING GENDER PICKER
              Positioned.fill(
                top: 140 * s,
                bottom: 120 * s,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _items.length,
                  onPageChanged: (i) => setState(() {
                    _pageIndex = i;
                    _selected = _items[i].gender;
                    }
                  ),

                  itemBuilder: (context, i) {
                    final item = _items[i];

                    return AnimatedBuilder(
                      animation: _pageCtrl,
                      builder: (context, child) {
                        double t = 0;
                        if (_pageCtrl.position.hasContentDimensions) {
                          t = (_pageCtrl.page! - i).abs().clamp(0.0, 1.0);
                        } else {
                          t = (_pageIndex - i).abs().toDouble().clamp(0.0, 1.0);
                        }

                        // not selected / off-center => lower opacity + smaller scale
                        final scale = 1.0 - (t * 0.10);
                        final opacity = 1.0 - (t * 0.55);

                        final isSelected = _selected == item.gender;

                        return Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: GestureDetector(
                              onTap: () => setState(() => _selected = item.gender),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // avatar + yellow star behind
                                  SizedBox(
                                    width: 340 * s,
                                    height: 380 * s,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 300 * s,
                                          color: _yellow.withValues(alpha: 0.60),
                                        ),
                                        Image.asset(
                                          item.asset,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) => Icon(
                                            Icons.person_rounded,
                                            size: 140 * s,
                                            color: Colors.black.withAlpha(60),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 10 * s),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 14 * s,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'DM Sans',
                                    ),
                                  ),

                                  // tiny selected indicator
                                  if (isSelected) ...[
                                    SizedBox(height: 10 * s),
                                    Container(
                                      width: 8 * s,
                                      height: 8 * s,
                                      decoration: const BoxDecoration(
                                        color: _yellow,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // NEXT BUTTON
              Positioned(
                left: 24 * s,
                right: 24 * s,
                bottom: 26 * s,
                child: SafeArea(
                  top: false,
                  child: InkWell(
                    onTap: _selected == null
                        ? null
                        : () {
                            state.saveProfile(
                              newName: state.name,
                              newGender: _selected!,
                              newHeightCm: state.heightCm,
                              newWeightKg: state.weightKg,
                            );

                            Navigator.pushReplacementNamed(context, '/profile');
                          },
                    child: Container(
                      height: 54 * s,
                      decoration: BoxDecoration(
                        color: _selected == null ? _yellow.withAlpha(90) : _yellow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'NEXT',
                        style: TextStyle(
                          color: _selected == null ? _ink.withAlpha(120) : _ink,
                          fontSize: 16 * s,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          fontFamily: 'DM Sans',
                        ),
                      ),
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

class _GenderItem {
  const _GenderItem({
    required this.gender,
    required this.label,
    required this.asset,
  });

  final Gender gender;
  final String label;
  final String asset;
}
