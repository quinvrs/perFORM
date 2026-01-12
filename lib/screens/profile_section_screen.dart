import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';

class ProfileSectionScreen extends StatefulWidget {
  const ProfileSectionScreen({super.key});

  @override
  State<ProfileSectionScreen> createState() => _ProfileSectionScreenState();
}

class _ProfileSectionScreenState extends State<ProfileSectionScreen> {
  // style
  static const _ink = Color(0xFF051328);
  static const _mutedBorder = Color(0x26051328);
  static const _yellow = Color(0xFFFEF9C2);

  // controllers/state
  final TextEditingController _nameCtrl = TextEditingController();

  Gender? _gender;
  double _heightCm = 180;
  double _weightKg = 80;

  String? _selectedGoal;
  String? _selectedActivity;
  String? _avatarPath;

  @override
  void initState() {
    super.initState();

    // preload from AppState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppStateScope.of(context);

      setState(() {
        _nameCtrl.text = state.name;
        _gender = state.gender;
        _heightCm = state.heightCm;
        _weightKg = state.weightKg;
        _selectedGoal = state.mainGoal;
        _selectedActivity = state.activityLevel;
        _avatarPath = state.avatarPath;
      });
    });
  }

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
          decoration: InputDecoration(hintText: 'Enter value ($suffix)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (!mounted) return;
    if (x == null) return;

    setState(() => _avatarPath = x.path);

    // save immediately so Home can show it right away
    final state = AppStateScope.of(context);
    state.setAvatarPath(x.path);
  }

  void _removeAvatar() {
    setState(() => _avatarPath = null);
    final state = AppStateScope.of(context);
    state.setAvatarPath(null);
  }

  // -------------------------------------------------------------
  // Logic to confirm and delete workout history
  // -------------------------------------------------------------
  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Workout History?'),
        content: const Text(
          'This will permanently delete all your streaks, reps, and sessions.\n\nYour profile settings (name, weight, etc.) will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _ink)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // close dialog
              final state = AppStateScope.of(context);
              await state
                  .clearAllWorkouts(); // Calls AppState -> DatabaseHelper

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All workout history erased.')),
                );
              }
            },
            child: const Text(
              'Erase Data',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // NEW: Logic to Delete Profile & Reset App
  // -------------------------------------------------------------
  void _confirmDeleteProfile() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Profile?',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'This will permanently delete EVERYTHING:\n\n'
          '• Your Name & Stats\n'
          '• Your Workout History\n'
          '• Your Streaks\n\n'
          'The app will reset to the Welcome screen. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _ink)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog

              // 1. Delete data
              final state = AppStateScope.of(context);
              await state.deleteProfile();

              if (!mounted) return;

              // 2. Navigate to Welcome Screen (Restart App Flow)
              // This removes all previous routes so user can't go back
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/welcome',
                (route) => false,
              );
            },
            child: const Text(
              'Delete Forever',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _saveAll() {
    final state = AppStateScope.of(context);

    state.saveProfile(
      newName: _nameCtrl.text.trim(),
      newGender: _gender,
      newHeightCm: _heightCm,
      newWeightKg: _weightKg,
      newMainGoal: _selectedGoal,
      newActivityLevel: _selectedActivity,
      newAvatarPath: _avatarPath,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final s = size.width / 375.0;
    final kb = MediaQuery.viewInsetsOf(context).bottom;

    final avatarWidget =
        (_avatarPath != null && File(_avatarPath!).existsSync())
        ? ClipOval(
            child: Image.file(
              File(_avatarPath!),
              width: 84 * s,
              height: 84 * s,
              fit: BoxFit.cover,
            ),
          )
        : Container(
            width: 84 * s,
            height: 84 * s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEDEFF3),
            ),
            alignment: Alignment.center,
            child: Text(
              (_nameCtrl.text.trim().isEmpty
                  ? 'U'
                  : _nameCtrl.text.trim()[0].toUpperCase()),
              style: TextStyle(
                color: _ink,
                fontSize: 28 * s,
                fontWeight: FontWeight.w800,
                fontFamily: 'DM Sans',
              ),
            ),
          );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24 * s,
                16 * s,
                24 * s,
                (120 * s) + kb,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // top bar
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: _ink,
                          size: 26 * s,
                        ),
                      ),
                      SizedBox(width: 12 * s),
                      Text(
                        'Profile',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 18 * s,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'DM Sans',
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 18 * s),

                  // avatar
                  Row(
                    children: [
                      Stack(
                        children: [
                          avatarWidget,
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: InkWell(
                              onTap: () async {
                                await showModalBottomSheet(
                                  context: context,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(18 * s),
                                    ),
                                  ),
                                  builder: (_) => SafeArea(
                                    child: Padding(
                                      padding: EdgeInsets.all(14 * s),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.photo_library_outlined,
                                            ),
                                            title: const Text('Choose photo'),
                                            onTap: () async {
                                              Navigator.pop(context);
                                              await _pickAvatar();
                                            },
                                          ),
                                          if (_avatarPath != null)
                                            ListTile(
                                              leading: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              title: const Text('Remove photo'),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _removeAvatar();
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 30 * s,
                                height: 30 * s,
                                decoration: BoxDecoration(
                                  color: _yellow,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.edit,
                                  size: 16 * s,
                                  color: _ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 14 * s),
                      Expanded(
                        child: Text(
                          'Tap to change your photo.',
                          style: TextStyle(
                            color: _ink.withValues(alpha: 0.70),
                            fontSize: 13 * s,
                            height: 1.2,
                            fontFamily: 'DM Sans',
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 22 * s),

                  // name
                  Text(
                    'Name',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16 * s,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'DM Sans',
                    ),
                  ),
                  SizedBox(height: 10 * s),
                  TextField(
                    controller: _nameCtrl,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16 * s,
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
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

                  // gender
                  Text(
                    'Gender',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16 * s,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'DM Sans',
                    ),
                  ),
                  SizedBox(height: 10 * s),
                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceChip(
                          s: s,
                          label: 'Male',
                          selected: _gender == Gender.male,
                          onTap: () => setState(() => _gender = Gender.male),
                        ),
                      ),
                      SizedBox(width: 10 * s),
                      Expanded(
                        child: _ChoiceChip(
                          s: s,
                          label: 'Female',
                          selected: _gender == Gender.female,
                          onTap: () => setState(() => _gender = Gender.female),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 22 * s),

                  // height + weight
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

                  SizedBox(height: 22 * s),

                  // goal
                  Text(
                    'Main Goal',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16 * s,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'DM Sans',
                    ),
                  ),
                  SizedBox(height: 10 * s),
                  _GoalTile(
                    s: s,
                    title: 'Lose Weight',
                    icon: Icons.monitor_weight_outlined,
                    selected: _selectedGoal == 'Lose Weight',
                    onTap: () => setState(() => _selectedGoal = 'Lose Weight'),
                  ),
                  SizedBox(height: 10 * s),
                  _GoalTile(
                    s: s,
                    title: 'Build Muscle',
                    icon: Icons.fitness_center_rounded,
                    selected: _selectedGoal == 'Build Muscle',
                    onTap: () => setState(() => _selectedGoal = 'Build Muscle'),
                  ),
                  SizedBox(height: 10 * s),
                  _GoalTile(
                    s: s,
                    title: 'Keep Fit',
                    icon: Icons.favorite_border_rounded,
                    selected: _selectedGoal == 'Keep Fit',
                    onTap: () => setState(() => _selectedGoal = 'Keep Fit'),
                  ),

                  SizedBox(height: 22 * s),

                  // activity
                  Text(
                    'Activity Level',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16 * s,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'DM Sans',
                    ),
                  ),
                  SizedBox(height: 10 * s),
                  _ActivityTile(
                    s: s,
                    emoji: '🪑',
                    title: 'Sedentary',
                    selected: _selectedActivity == 'Sedentary',
                    onTap: () =>
                        setState(() => _selectedActivity = 'Sedentary'),
                  ),
                  SizedBox(height: 10 * s),
                  _ActivityTile(
                    s: s,
                    emoji: '🚶',
                    title: 'Lightly active',
                    selected: _selectedActivity == 'Lightly active',
                    onTap: () =>
                        setState(() => _selectedActivity = 'Lightly active'),
                  ),
                  SizedBox(height: 10 * s),
                  _ActivityTile(
                    s: s,
                    emoji: '🏃',
                    title: 'Moderately active',
                    selected: _selectedActivity == 'Moderately active',
                    onTap: () =>
                        setState(() => _selectedActivity = 'Moderately active'),
                  ),
                  SizedBox(height: 10 * s),
                  _ActivityTile(
                    s: s,
                    emoji: '🥵',
                    title: 'Very active',
                    selected: _selectedActivity == 'Very active',
                    onTap: () =>
                        setState(() => _selectedActivity = 'Very active'),
                  ),

                  // -------------------------------------------------------------
                  // Clear History Button
                  // -------------------------------------------------------------
                  SizedBox(height: 32 * s),
                  Center(
                    child: InkWell(
                      onTap: _confirmClearData,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12 * s,
                          horizontal: 16 * s,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_forever_rounded,
                              color: Colors.red[700],
                              size: 20 * s,
                            ),
                            SizedBox(width: 8 * s),
                            Text(
                              'Clear Workout History',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 14 * s,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'DM Sans',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // -------------------------------------------------------------
                  // NEW: Delete Profile Button
                  // -------------------------------------------------------------
                  SizedBox(height: 12 * s), // Small gap
                  Center(
                    child: InkWell(
                      onTap: _confirmDeleteProfile,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12 * s,
                          horizontal: 16 * s,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_off_rounded,
                              color: Colors.red[900],
                              size: 20 * s,
                            ),
                            SizedBox(width: 8 * s),
                            Text(
                              'Delete Profile & Reset App',
                              style: TextStyle(
                                color: Colors.red[900],
                                fontSize: 14 * s,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'DM Sans',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 30 * s), // Extra padding at bottom
                ],
              ),
            ),

            // Save button pinned
            Positioned(
              left: 18 * s,
              right: 18 * s,
              bottom: 14 * s,
              child: SafeArea(
                top: false,
                bottom: true,
                child: InkWell(
                  onTap: _saveAll,
                  borderRadius: BorderRadius.circular(14 * s),
                  child: Container(
                    height: 56 * s,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _ink,
                      borderRadius: BorderRadius.circular(14 * s),
                    ),
                    child: Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16 * s,
                        fontWeight: FontWeight.w800,
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
    );
  }
}

// ... [Helper widgets below are unchanged] ...

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.s,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double s;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _ink = Color(0xFF051328);
  static const _yellow = Color(0xFFFEF9C2);

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _yellow.withAlpha(150) : Colors.white;

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
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: _ink,
              fontSize: 14 * s,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700,
            ),
          ),
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
                padding: EdgeInsets.symmetric(
                  horizontal: 6 * scale,
                  vertical: 2 * scale,
                ),
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
              Text(
                minText,
                style: TextStyle(
                  color: _ink,
                  fontSize: 12 * scale,
                  fontFamily: 'DM Sans',
                ),
              ),
              Text(
                maxText,
                style: TextStyle(
                  color: _ink,
                  fontSize: 12 * scale,
                  fontFamily: 'DM Sans',
                ),
              ),
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
                style: TextStyle(
                  color: _ink,
                  fontSize: 14 * s,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 18 * s, color: _ink),
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
                style: TextStyle(
                  color: _ink,
                  fontSize: 14 * s,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 18 * s, color: _ink),
          ],
        ),
      ),
    );
  }
}
