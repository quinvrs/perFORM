import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';

class ProfileSetUpScreen extends StatefulWidget {
  const ProfileSetUpScreen({super.key});

  @override
  State<ProfileSetUpScreen> createState() => _ProfileSetUpScreenState();
}

class _ProfileSetUpScreenState extends State<ProfileSetUpScreen> {
  final TextEditingController _nameCtrl = TextEditingController();

  double _heightCm = 180;
  double _weightKg = 80;

  String? _selectedGoal; // "Lose Weight" | "Build Muscle" | "Keep Fit"
  String? _selectedActivity; // "Sedentary" | ...

  bool _goalError = false;
  bool _activityError = false;

  static const _ink = Color(0xFF051328);
  static const _mutedBorder = Color(0x26051328);
  static const _yellow = Color(0xFFFEF9C2);

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _editNumberDialog({
    required String title,
    required double current,
    required double min,
    required double max,
    required String suffix,
    required void Function(double v) onSave,
  }) async {
    final ctrl = TextEditingController(text: current.round().toString());

    final res = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(hintText: 'Enter value ($suffix)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v == null) return;
              Navigator.pop(ctx, v.clamp(min, max));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (res != null) onSave(res);
  }

  Widget _requiredTitle(double s, String text) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: _ink,
          fontSize: 18 * s,
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: text),
          TextSpan(
            text: ' *',
            style: TextStyle(
              color: Colors.red,
              fontSize: 18 * s,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final size = MediaQuery.sizeOf(context);
    final s = size.width / 375.0;
    final kb = MediaQuery.viewInsetsOf(context).bottom;

    // preload if already has values
    if (_nameCtrl.text.isEmpty && state.name.isNotEmpty) {
      _nameCtrl.text = state.name;
      _heightCm = state.heightCm;
      _weightKg = state.weightKg;
    }
    if (_selectedGoal == null && (state.mainGoal ?? '').isNotEmpty) {
      _selectedGoal = state.mainGoal;
    }
    if (_selectedActivity == null && (state.activityLevel ?? '').isNotEmpty) {
      _selectedActivity = state.activityLevel;
    }

    // Profile step progress (2/3)
    final progress = 2 / 3;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 0),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pushReplacementNamed(context, '/gender'),
                        child: Icon(Icons.arrow_back_rounded, color: _ink, size: 26 * s),
                      ),
                      SizedBox(width: 12 * s),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            height: 4 * s,
                            color: Colors.black.withAlpha(20),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: progress,
                                child: Container(color: _yellow),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24 * s,
                      18 * s,
                      24 * s,
                      (110 * s) + kb,
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
                            contentPadding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 14 * s),
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
                          onValueTap: () => _editNumberDialog(
                            title: 'Edit Height',
                            current: _heightCm,
                            min: 50,
                            max: 200,
                            suffix: 'cm',
                            onSave: (v) => setState(() => _heightCm = v),
                          ),
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
                          onValueTap: () => _editNumberDialog(
                            title: 'Edit Weight',
                            current: _weightKg,
                            min: 20,
                            max: 200,
                            suffix: 'kg',
                            onSave: (v) => setState(() => _weightKg = v),
                          ),
                        ),

                        // GOALS (required)
                        SizedBox(height: 22 * s),
                        _requiredTitle(s, 'What are your main goals?'),
                        if (_goalError)
                          Padding(
                            padding: EdgeInsets.only(top: 6 * s),
                            child: Text('Please select a goal.', style: TextStyle(color: Colors.red, fontSize: 12 * s)),
                          ),
                        SizedBox(height: 10 * s),

                        _GoalTile(
                          s: s,
                          title: 'Lose Weight',
                          icon: Icons.monitor_weight_outlined,
                          selected: _selectedGoal == 'Lose Weight',
                          onTap: () => setState(() {
                            _selectedGoal = 'Lose Weight';
                            _goalError = false;
                          }),
                        ),
                        SizedBox(height: 10 * s),
                        _GoalTile(
                          s: s,
                          title: 'Build Muscle',
                          icon: Icons.fitness_center_rounded,
                          selected: _selectedGoal == 'Build Muscle',
                          onTap: () => setState(() {
                            _selectedGoal = 'Build Muscle';
                            _goalError = false;
                          }),
                        ),
                        SizedBox(height: 10 * s),
                        _GoalTile(
                          s: s,
                          title: 'Keep Fit',
                          icon: Icons.favorite_border_rounded,
                          selected: _selectedGoal == 'Keep Fit',
                          onTap: () => setState(() {
                            _selectedGoal = 'Keep Fit';
                            _goalError = false;
                          }),
                        ),

                        // ACTIVITY (required)
                        SizedBox(height: 22 * s),
                        _requiredTitle(s, "What's your activity level?"),
                        if (_activityError)
                          Padding(
                            padding: EdgeInsets.only(top: 6 * s),
                            child: Text('Please select an activity level.', style: TextStyle(color: Colors.red, fontSize: 12 * s)),
                          ),
                        SizedBox(height: 10 * s),

                        _ActivityTile(
                          s: s,
                          emoji: '🪑',
                          title: 'Sedentary',
                          selected: _selectedActivity == 'Sedentary',
                          onTap: () => setState(() {
                            _selectedActivity = 'Sedentary';
                            _activityError = false;
                          }),
                        ),
                        SizedBox(height: 10 * s),
                        _ActivityTile(
                          s: s,
                          emoji: '🚶',
                          title: 'Lightly active',
                          selected: _selectedActivity == 'Lightly active',
                          onTap: () => setState(() {
                            _selectedActivity = 'Lightly active';
                            _activityError = false;
                          }),
                        ),
                        SizedBox(height: 10 * s),
                        _ActivityTile(
                          s: s,
                          emoji: '🏃',
                          title: 'Moderately active',
                          selected: _selectedActivity == 'Moderately active',
                          onTap: () => setState(() {
                            _selectedActivity = 'Moderately active';
                            _activityError = false;
                          }),
                        ),
                        SizedBox(height: 10 * s),
                        _ActivityTile(
                          s: s,
                          emoji: '🥵',
                          title: 'Very active',
                          selected: _selectedActivity == 'Very active',
                          onTap: () => setState(() {
                            _selectedActivity = 'Very active';
                            _activityError = false;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // NEXT button
            Positioned(
              right: 18 * s,
              bottom: 18 * s,
              child: InkWell(
                onTap: () {
                  final goalMissing = _selectedGoal == null;
                  final actMissing = _selectedActivity == null;

                  setState(() {
                    _goalError = goalMissing;
                    _activityError = actMissing;
                  });

                  if (goalMissing || actMissing) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please complete the required fields.')),
                    );
                    return;
                  }

                  state.saveProfile(
                    newName: _nameCtrl.text.trim(),
                    newGender: state.gender,
                    newHeightCm: _heightCm,
                    newWeightKg: _weightKg,
                    newMainGoal: _selectedGoal,
                    newActivityLevel: _selectedActivity,
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
                  child: Icon(Icons.arrow_forward, color: _ink, size: 22 * s),
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
    required this.onValueTap,
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

  // clickable right value only
  final VoidCallback onValueTap;

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
            InkWell(
              onTap: onValueTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                child: Text(
                  valueText,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16 * scale,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                  ),
                ),
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
              Text(minText, style: TextStyle(color: _ink, fontSize: 12 * scale, fontFamily: 'DM Sans')),
              Text(maxText, style: TextStyle(color: _ink, fontSize: 12 * scale, fontFamily: 'DM Sans')),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.s,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final double s;
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const _ink = Color(0xFF051328);
  static const _yellow = Color(0xFFFEF9C2);

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _yellow.withAlpha(140) : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(16 * s),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 14 * s),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16 * s),
          border: Border.all(color: Colors.black.withAlpha(selected ? 28 : 18)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18 * s, color: _ink),
            SizedBox(width: 10 * s),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: _ink, fontSize: 14 * s, fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, size: 18 * s, color: _ink),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.s,
    required this.emoji,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final double s;
  final String emoji;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  static const _ink = Color(0xFF051328);
  static const _yellow = Color(0xFFFEF9C2);

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _yellow.withAlpha(140) : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(16 * s),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 14 * s),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16 * s),
          border: Border.all(color: Colors.black.withAlpha(selected ? 28 : 18)),
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: 16 * s)),
            SizedBox(width: 10 * s),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: _ink, fontSize: 14 * s, fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, size: 18 * s, color: _ink),
          ],
        ),
      ),
    );
  }
}
