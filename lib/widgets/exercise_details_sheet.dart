import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/workout.dart';
import '../app_state.dart';
import '../models/workout_plan.dart';

Future<void> showExerciseDetailsSheet(
  BuildContext context, {
  required Workout workout,
  required VoidCallback onStartExercise,
}) async {
  final state = AppStateScope.of(context);

  final plan = WorkoutPlan.recommended(
    workoutTitle: workout.title,
    level: parseActivityLevel(state.activityLevel),
  );

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xFF102507).withValues(alpha: 0.58),
    builder: (sheetCtx) {
      return _ExerciseDetailsSheet(
        workout: workout,
        plan: plan,
        onStartExercise: () {
          Navigator.pop(sheetCtx);
          onStartExercise();
        },
      );
    },
  );
}

class _ExerciseDetailsSheet extends StatefulWidget {
  const _ExerciseDetailsSheet({
    required this.workout,
    required this.plan,
    required this.onStartExercise,
  });

  final Workout workout;
  final WorkoutPlan plan;
  final VoidCallback onStartExercise;

  @override
  State<_ExerciseDetailsSheet> createState() => _ExerciseDetailsSheetState();
}

class _ExerciseDetailsSheetState extends State<_ExerciseDetailsSheet> {
  static const _segBg = Color(0xFFF0F7D7);

  int _tab = 0; // 0=Animation, 1=Muscle, 2=How to do

  VideoPlayerController? _vid;
  bool _vidReady = false;
  bool _vidError = false;
  bool _started = false;     
  bool _pendingPlay = false;  

  @override
  void initState() {
    super.initState();

    final asset = _videoFor(widget.workout.title);
    if (asset != null) {
      _vid = VideoPlayerController.asset(asset)
        ..setLooping(true)
        ..initialize().then((_) async {
          if (!mounted) return;
          _vidReady = true;

          // If user already tapped while initializing, play as soon as ready
          if (_pendingPlay) {
            _pendingPlay = false;
            _started = true;
            await _vid!.play();
            }

          setState(() {});
        }).catchError((_) {
          if (!mounted) return;
          setState(() => _vidError = true);
        });
    } else {
      _vidError = true;
    }
  }

  @override
  void dispose() {
    _vid?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 375.0;

    final title = widget.workout.title;
    final plan = widget.plan;

    final ytId = _youtubeIdFor(title);
    final ytUrl = ytId == null ? null : Uri.parse('https://www.youtube.com/watch?v=$ytId');

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22 * s)),
            ),
            child: Column(
              children: [
                SizedBox(height: 10 * s),
                Container(
                  width: 56 * s,
                  height: 5 * s,
                  decoration: BoxDecoration(
                    color: const Color(0xFF596B22).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),

                // header row
                Padding(
                  padding: EdgeInsets.fromLTRB(18 * s, 14 * s, 12 * s, 10 * s),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          style: TextStyle(
                            color: const Color(0xFF173A12),
                            fontSize: 24 * s,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DM Sans',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, size: 26 * s),
                      ),
                    ],
                  ),
                ),

                // Poster (YouTube thumbnail) -> plays OFFLINE asset video when tapped
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18 * s),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16 * s),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
          // --- Poster image (shown before first play OR if video fails) ---
                          if (!_started || !_vidReady || _vid == null || _vidError)
                            (ytId != null)
                                ? Image.network(
                                    'https://img.youtube.com/vi/$ytId/hqdefault.jpg',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Image.asset(
                                      _imageFor(title),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    _imageFor(title),
                                    fit: BoxFit.cover,
                                  )
                          else
                            // --- Actual offline video (after first play) ---
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _vid!.value.size.width,
                                height: _vid!.value.size.height,
                                child: VideoPlayer(_vid!),
                              ),
                            ),
                          // subtle overlay
                          Container(color: const Color(0xFF173A12).withValues(alpha: 0.14)),

                          // loading spinner if still initializing
                          if (_vid != null && !_vidReady && !_vidError)
                            const Center(child: CircularProgressIndicator()),

                          // play/pause icon overlay
                          Center(
                            child: Container(
                              width: 64 * s,
                              height: 64 * s,
                              decoration: BoxDecoration(
                                color: const Color(0xFF102507).withValues(alpha: 0.62),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                (_started && _vid != null && _vidReady && !_vidError && _vid!.value.isPlaying)
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: const Color(0xFFFFF4DF),
                                size: 40 * s,
                              ),
                            ),
                          ),

                          // tap behavior: play offline video (NOT YouTube)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                if (_vid == null || _vidError) return;

                                // first tap: switch from poster -> video and play
                                if (!_started) {
                                  setState(() => _started = true);

                                  if (_vidReady) {
                                    await _vid!.play();
                                    if (mounted) setState(() {});
                                  } else {
                                    // user tapped before init finished; play when ready
                                    setState(() => _pendingPlay = true);
                                  }
                                  return;
                                }

                                // subsequent taps: toggle play/pause
                                if (_vidReady) {
                                  if (_vid!.value.isPlaying) {
                                    await _vid!.pause();
                                  } else {
                                    await _vid!.play();
                                  }
                                  if (mounted) setState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (ytUrl != null) ...[
                  SizedBox(height: 10 * s),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18 * s),
                    child: InkWell(
                      onTap: () => _openYoutube(ytUrl),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 46 * s,
                        decoration: BoxDecoration(
                          color: _BottomStartButton._ink,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_fill_rounded,
                              size: 22 * s,
                              color: _BottomStartButton._yellow,
                            ),
                            SizedBox(width: 8 * s),
                            Text(
                              'YOUTUBE',
                              style: TextStyle(
                                color: _BottomStartButton._yellow,
                                fontSize: 12 * s,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                fontFamily: 'DM Sans',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                SizedBox(height: 12 * s),

                // segmented tabs
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18 * s),
                  child: Container(
                    height: 42 * s,
                    decoration: BoxDecoration(
                      color: _segBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        _SegBtn(
                          s: s,
                          label: 'Preview',
                          selected: _tab == 0,
                          onTap: () => setState(() => _tab = 0),
                        ),
                        _SegBtn(
                          s: s,
                          label: 'Muscle',
                          selected: _tab == 1,
                          onTap: () => setState(() => _tab = 1),
                        ),
                        _SegBtn(
                          s: s,
                          label: 'How to do',
                          selected: _tab == 2,
                          onTap: () => setState(() => _tab = 2),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 10 * s),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(18 * s, 6 * s, 18 * s, 24 * s),
                    child: _tab == 0
                        ? _TabAnimation(s: s, plan: plan, hasLink: ytUrl != null)
                        : _tab == 1
                            ? _TabMuscle(s: s, title: title, plan: plan)
                            : _TabHowTo(s: s, title: title, plan: plan),
                  ),
                ),

                _BottomStartButton(
                  s: s,
                  onTap: widget.onStartExercise,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openYoutube(Uri url) async {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

class _BottomStartButton extends StatelessWidget {
  const _BottomStartButton({
    required this.s,
    required this.onTap,
  });

  final double s;
  final VoidCallback onTap;

  static const _ink = Color(0xFF173A12);
  static const _yellow = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18 * s, 0, 18 * s, 14 * s),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 56 * s,
            decoration: BoxDecoration(
              color: _yellow,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              'START EXERCISE',
              style: TextStyle(
                color: const Color(0xFFFFF4DF),
                fontSize: 16 * s,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                fontFamily: 'DM Sans',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({
    required this.s,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double s;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _ink = Color(0xFF173A12);
  static const _yellow = Color(0xFFDFFF71);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.all(4 * s),
          decoration: BoxDecoration(
            color: selected ? _yellow : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _ink : const Color(0xFF173A12).withValues(alpha: 0.62),
              fontSize: 12 * s,
              fontWeight: FontWeight.w800,
              fontFamily: 'DM Sans',
            ),
          ),
        ),
      ),
    );
  }
}

class _TabAnimation extends StatelessWidget {
  const _TabAnimation({
    required this.s,
    required this.plan,
    required this.hasLink,
  });

  final double s;
  final WorkoutPlan plan;
  final bool hasLink;

  static const _blue = Color(0xFF5D741E);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionRow(s: s, left: 'SETS', right: '${plan.sets}', leftColor: _blue),
        SizedBox(height: 8 * s),
        if (plan.isTimed) ...[
          _SectionRow(s: s, left: 'TIMER PER SET', right: plan.timerLabel, leftColor: _blue),
          SizedBox(height: 8 * s),
          _SectionRow(s: s, left: 'REPS', right: 'COUNTED LIVE', leftColor: _blue),
        ] else ...[
          _SectionRow(s: s, left: 'REPS PER SET', right: '${plan.reps}', leftColor: _blue),
        ],
        SizedBox(height: 12 * s),
        Text(
          'Preview',
          style: TextStyle(
            color: const Color(0xFF173A12),
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Sans',
          ),
        ),
        SizedBox(height: 8 * s),
        Text(
          hasLink
              ? 'Tap the video to play/pause. Use the YouTube button for the full online demo.'
              : 'Tap the video to play/pause.',
          style: TextStyle(
            color: const Color(0xFF173A12).withValues(alpha: 0.70),
            fontSize: 13 * s,
            height: 1.35,
            fontFamily: 'DM Sans',
          ),
        ),
      ],
    );
  }
}

class _TabMuscle extends StatelessWidget {
  const _TabMuscle({
    required this.s,
    required this.title,
    required this.plan,
  });

  final double s;
  final String title;
  final WorkoutPlan plan;

  static const _blue = Color(0xFF5D741E);
  static const _yellow = Color(0xFFFFC067);

  @override
  Widget build(BuildContext context) {
    final areas = _focusAreasFor(title);
    final benefits = _benefitsFor(title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionRow(s: s, left: 'SETS', right: '${plan.sets}', leftColor: _blue),
        SizedBox(height: 8 * s),
        if (plan.isTimed)
          _SectionRow(s: s, left: 'TIMER PER SET', right: plan.timerLabel, leftColor: _blue)
        else
          _SectionRow(s: s, left: 'REPS PER SET', right: '${plan.reps}', leftColor: _blue),
        SizedBox(height: 14 * s),
        Text(
          'FOCUS AREA',
          style: TextStyle(
            color: _blue,
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Sans',
          ),
        ),
        SizedBox(height: 10 * s),
        Wrap(
          spacing: 10 * s,
          runSpacing: 10 * s,
          children: [
            for (final a in areas)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
                decoration: BoxDecoration(
                  color: _yellow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8 * s,
                      height: 8 * s,
                      decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 8 * s),
                    Text(
                      a,
                      style: TextStyle(
                        color: const Color(0xFF173A12),
                        fontSize: 12 * s,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'DM Sans',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: 18 * s),
        Text(
          'BENEFITS',
          style: TextStyle(
            color: _blue,
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Sans',
          ),
        ),
        SizedBox(height: 10 * s),
        for (final b in benefits)
          Padding(
            padding: EdgeInsets.only(bottom: 8 * s),
            child: Text(
              '• $b',
              style: TextStyle(
                color: const Color(0xFF173A12).withValues(alpha: 0.78),
                fontSize: 13 * s,
                height: 1.35,
                fontFamily: 'DM Sans',
              ),
            ),
          ),
      ],
    );
  }
}

class _TabHowTo extends StatelessWidget {
  const _TabHowTo({
    required this.s,
    required this.title,
    required this.plan,
  });

  final double s;
  final String title;
  final WorkoutPlan plan;

  static const _blue = Color(0xFF5D741E);

  @override
  Widget build(BuildContext context) {
    final how = _howToFor(title);
    final mistakes = _commonMistakesFor(title);
    final breath = _breathingTipsFor(title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionRow(s: s, left: 'SETS', right: '${plan.sets}', leftColor: _blue),
        SizedBox(height: 8 * s),
        if (plan.isTimed)
          _SectionRow(s: s, left: 'TIMER PER SET', right: plan.timerLabel, leftColor: _blue)
        else
          _SectionRow(s: s, left: 'REPS PER SET', right: '${plan.reps}', leftColor: _blue),
        SizedBox(height: 14 * s),
        Text(
          'INSTRUCTIONS',
          style: TextStyle(
            color: _blue,
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Sans',
          ),
        ),
        SizedBox(height: 10 * s),
        Text(
          how,
          style: TextStyle(
            color: const Color(0xFF173A12).withValues(alpha: 0.88),
            fontSize: 14 * s,
            height: 1.5,
            fontFamily: 'DM Sans',
          ),
        ),
        SizedBox(height: 18 * s),
        Text(
          'COMMON MISTAKES',
          style: TextStyle(
            color: _blue,
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Sans',
          ),
        ),
        SizedBox(height: 10 * s),
        for (int i = 0; i < mistakes.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 12 * s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 14 * s,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'DM Sans',
                  ),
                ),
                SizedBox(width: 10 * s),
                Expanded(
                  child: Text(
                    mistakes[i],
                    style: TextStyle(
                      color: const Color(0xFF173A12).withValues(alpha: 0.78),
                      fontSize: 13 * s,
                      height: 1.45,
                      fontFamily: 'DM Sans',
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 8 * s),
        Text(
          'BREATHING TIPS',
          style: TextStyle(
            color: _blue,
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Sans',
          ),
        ),
        SizedBox(height: 10 * s),
        for (final t in breath)
          Padding(
            padding: EdgeInsets.only(bottom: 8 * s),
            child: Text(
              '• $t',
              style: TextStyle(
                color: const Color(0xFF173A12).withValues(alpha: 0.78),
                fontSize: 13 * s,
                height: 1.35,
                fontFamily: 'DM Sans',
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.s,
    required this.left,
    required this.right,
    required this.leftColor,
  });

  final double s;
  final String left;
  final String right;
  final Color leftColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          left,
          style: TextStyle(
            color: leftColor,
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Sans',
          ),
        ),
        const Spacer(),
        Text(
          right,
          style: TextStyle(
            color: const Color(0xFF173A12).withValues(alpha: 0.70),
            fontSize: 16 * s,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Sans',
          ),
        ),
      ],
    );
  }
}

/// ---- helpers ----
String? _videoFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('jump')) return 'assets/jumpingjacks.mp4';
  if (t.contains('squat')) return 'assets/squat.mp4';
  return null;
}

String _imageFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('jump')) return 'assets/jumping-jacks.png';
  if (t.contains('squat')) return 'assets/squats.png';
  return 'assets/workout.png';
}

String? _youtubeIdFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('jump')) return 'iSSAk4XCsRA';
  if (t.contains('squat')) return 'xqvCmoLULNY';
  return null;
}

List<String> _benefitsFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('jump')) {
    return const [
      'Improves cardiovascular endurance',
      'Warms up the whole body quickly',
      'Boosts coordination and rhythm',
      'Burns calories efficiently',
      'Strengthens shoulders, hips, and legs',
      'Great for HIIT and warm-ups',
    ];
  }
  return const [
    'Builds lower body strength and muscle mass',
    'Improves core stability and balance',
    'Enhances athletic performance',
    'Burns calories and boosts metabolism',
  ];
}

List<String> _focusAreasFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('jump')) {
    return const ['Shoulders', 'Quadriceps', 'Adductors', 'Glutes', 'Calves', 'Core'];
  }
  return const ['Quadriceps', 'Glutes', 'Hamstrings', 'Core', 'Lower back'];
}

String _howToFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('jump')) {
    return "Start with your feet together and arms by your sides, then jump up with your feet apart while raising your hands overhead.\n\nReturn to the start position and repeat for the next rep. Keep a steady rhythm and stay light on your feet.";
  }
  return "Stand with feet shoulder-width apart. Brace your core and keep your chest up.\n\nPush your hips back and bend your knees to lower down. Keep your heels planted.\n\nDrive through your heels to stand back up. Repeat with control.";
}

List<String> _commonMistakesFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('jump')) {
    return const [
      'Landing too hard — try landing softly on the balls of your feet to reduce impact.',
      'Not keeping knees aligned — avoid collapsing knees inward when you land.',
      'Shrugging shoulders — keep shoulders relaxed while arms move overhead.',
    ];
  }
  return const [
    'Knees caving inward — keep knees tracking over toes.',
    'Heels lifting — shift weight back and keep heels down.',
    'Rounding the back — keep chest up and core braced.',
  ];
}

List<String> _breathingTipsFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('jump')) {
    return const [
      'Inhale as you jump your feet apart.',
      'Exhale as you jump back together.',
      'Keep breathing steady—don’t hold your breath.',
    ];
  }
  return const [
    'Inhale on the way down.',
    'Exhale as you stand up.',
    'Keep your core braced while breathing.',
  ];
}
