import 'package:flutter/material.dart';
import '../app_state.dart';

class ProfileSetUpScreen extends StatefulWidget {
  const ProfileSetUpScreen({super.key});

  @override
  State<ProfileSetUpScreen> createState() => _ProfileSetUpScreenState();
}

class _ProfileSetUpScreenState extends State<ProfileSetUpScreen> {
  Gender? _gender;
  final TextEditingController _nameCtrl = TextEditingController();

  double _heightCm = 180;
  double _weightKg = 80;

  static const _ink = Color(0xFF051328);
  static const _mutedBorder = Color(0x26051328);
  static const _yellow = Color(0xFFFEF9C2);

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    // Full-screen scale (design width = 375)
    final size = MediaQuery.sizeOf(context);
    final s = size.width / 375.0;

    // keyboard inset
    final kb = MediaQuery.viewInsetsOf(context).bottom;

    // preload if already has values
    if (_nameCtrl.text.isEmpty && state.name.isNotEmpty) {
      _nameCtrl.text = state.name;
      _gender = state.gender;
      _heightCm = state.heightCm;
      _weightKg = state.weightKg;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24 * s,
                  18 * s,
                  24 * s,
                  (110 * s) + kb, // ✅ keep space for button + keyboard
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Give us some basic information',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 32 * s,
                        fontFamily: 'DM Sans',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 18 * s),

                    Row(
                      children: [
                        Expanded(
                          child: _GenderCard(
                            label: 'Male',
                            icon: Icons.male,
                            selected: _gender == Gender.male,
                            scale: s,
                            onTap: () => setState(() => _gender = Gender.male),
                          ),
                        ),
                        SizedBox(width: 14 * s),
                        Expanded(
                          child: _GenderCard(
                            label: 'Female',
                            icon: Icons.female,
                            selected: _gender == Gender.female,
                            scale: s,
                            onTap: () => setState(() => _gender = Gender.female),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 22 * s),

                    Text(
                      'What shall we call you?',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18 * s,
                        fontFamily: 'DM Sans',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10 * s),
                    TextField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16 * s,
                        fontFamily: 'DM Sans',
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        hintStyle: TextStyle(
                          color: Colors.black.withAlpha(90),
                          fontSize: 16 * s,
                          fontFamily: 'DM Sans',
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14 * s,
                          vertical: 14 * s,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16 * s),
                          borderSide: const BorderSide(color: _mutedBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16 * s),
                          borderSide: const BorderSide(color: _mutedBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16 * s),
                          borderSide: const BorderSide(color: _ink, width: 1.5),
                        ),
                      ),
                    ),

                    SizedBox(height: 22 * s),

                    _SliderBlock(
                      title: 'Height',
                      valueText: '${_heightCm.round()}cm',
                      minText: '50cm',
                      maxText: '200cm',
                      min: 50,
                      max: 200,
                      value: _heightCm,
                      scale: s,
                      onChanged: (v) => setState(() => _heightCm = v),
                    ),

                    SizedBox(height: 18 * s),

                    _SliderBlock(
                      title: 'Weight',
                      valueText: '${_weightKg.round()}kg',
                      minText: '20kg',
                      maxText: '200kg',
                      min: 20,
                      max: 200,
                      value: _weightKg,
                      scale: s,
                      onChanged: (v) => setState(() => _weightKg = v),
                    ),
                  ],
                ),
              ),
            ),

            // bottom-right next button (pinned)
            Positioned(
              right: 18 * s,
              bottom: 18 * s,
              child: InkWell(
                onTap: () {
                  state.saveProfile(
                    newName: _nameCtrl.text.trim(),
                    newGender: _gender,
                    newHeightCm: _heightCm,
                    newWeightKg: _weightKg,
                  );
                  Navigator.pushReplacementNamed(context, '/home');
                },
                child: Container(
                  width: 56 * s,
                  height: 56 * s,
                  decoration: const ShapeDecoration(
                    color: _yellow,
                    shape: OvalBorder(),
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    color: _ink,
                    size: 22 * s,
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

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final double scale;
  final VoidCallback onTap;

  static const _ink = Color(0xFF051328);
  static const _mutedBorder = Color(0x26051328);
  static const _yellow = Color(0xFFFEF9C2);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20 * scale),
      onTap: onTap,
      child: Container(
        height: 132 * scale,
        decoration: ShapeDecoration(
          color: selected ? _yellow : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20 * scale),
            side: BorderSide(
              width: selected ? 0 : 1,
              color: _mutedBorder,
            ),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(icon, size: 54 * scale, color: _ink),
            ),
            Positioned(
              right: 10 * scale,
              top: 10 * scale,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: selected ? 1 : 0,
                child: Container(
                  width: 24 * scale,
                  height: 24 * scale,
                  decoration: const ShapeDecoration(
                    color: _ink,
                    shape: OvalBorder(),
                  ),
                  child: Icon(Icons.check, size: 16 * scale, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10 * scale,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 14 * scale,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderBlock extends StatelessWidget {
  const _SliderBlock({
    required this.title,
    required this.valueText,
    required this.minText,
    required this.maxText,
    required this.min,
    required this.max,
    required this.value,
    required this.scale,
    required this.onChanged,
  });

  final String title;
  final String valueText;
  final String minText;
  final String maxText;
  final double min;
  final double max;
  final double value;
  final double scale;
  final ValueChanged<double> onChanged;

  static const _ink = Color(0xFF051328);
  static const _mutedBorder = Color(0x26051328);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _ink,
                fontSize: 20 * scale,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              valueText,
              style: TextStyle(
                color: _ink,
                fontSize: 16 * scale,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 8 * scale),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _ink,
            inactiveTrackColor: _mutedBorder,
            thumbColor: Colors.white,
            overlayColor: _ink.withAlpha(25),
            trackHeight: 2 * scale,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10 * scale),
          ),
          child: Slider(
            min: min,
            max: max,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minText,
                style: TextStyle(
                  color: _ink,
                  fontSize: 12 * scale,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                maxText,
                style: TextStyle(
                  color: _ink,
                  fontSize: 12 * scale,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
