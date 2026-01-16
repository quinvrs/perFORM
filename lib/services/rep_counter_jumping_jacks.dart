import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Internal phases for the Jumping Jacks state machine:
/// - closed: feet together + arms down
/// - open:   feet apart + arms overhead
enum _Phase { unknown, closed, open }

class JumpingJacksRepCounter {
  JumpingJacksRepCounter({
    //added a jump parameter
    this.requireJump = true,
    this.minJumpTorso = 0.11,
    this.confirmJumpFrames = 2,
    this.bodyBaseEmaAlpha = 0.12,
    
    // Minimum landmark confidence required before we trust a point.
    this.minLikelihood = 0.55,

    // Exponential moving average smoothing for leg signals.
    // Higher = more responsive (better for fast jacks), lower = smoother (less jitter).
    this.emaAlpha = 0.45,

    // Normalized ankle distance (ankleDist / shoulderWidth) thresholds.
    // We use hysteresis by having separate open/close thresholds.
    this.openRatio = 1.10,
    this.closeRatio = 0.78,

    // Symmetry thresholds to prevent cheating with one leg only:
    // Each ankle must move away from the body center by this normalized amount.
    this.openSideRatio = 0.35,
    // To be considered "closed", both ankles must be close to the center.
    this.closeSideRatio = 0.24,

    // If some landmarks disappear (fast motion / blur), allow a few frames before resetting.
    this.graceMissingFrames = 4,

    // Prevent double-counting due to jitter when returning to closed.
    this.minRepInterval = const Duration(milliseconds: 320),
  });

  /// Public outputs
  int reps = 0;

  /// Useful for debugging on-screen (thresholds, state, etc.)
  String debug = '';

  // Tunables
  //added a jump parameter
  final bool requireJump;
  final double minJumpTorso;
  final int confirmJumpFrames;
  final double bodyBaseEmaAlpha;

  final double minLikelihood;
  final double emaAlpha;

  final double openRatio;
  final double closeRatio;

  final double openSideRatio;
  final double closeSideRatio;

  final int graceMissingFrames;
  final Duration minRepInterval;

  // Internal state
  _Phase _phase = _Phase.unknown;

  // Only count when we've seen an OPEN once before returning to CLOSED.
  bool _seenOpen = false;

  // Cooldown timer for rep counting.
  DateTime _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Smoothed signals (EMA)
  double? _emaAnkleRatio;
  double? _emaLeftSide;
  double? _emaRightSide;

  double? _baseBodyY;
  double? _emaBodyY;
  int _jumpHits = 0;
  bool _seenJump = false;

  // Counts consecutive "bad frames" (missing/low confidence)
  int _missingStreak = 0;

  /// Reset all counters/state (call this when a new set starts, or exercise ends).
  void reset() {
    reps = 0;
    debug = '';
    _phase = _Phase.unknown;
    _seenOpen = false;
    _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);
    _emaAnkleRatio = null;
    _emaLeftSide = null;
    _emaRightSide = null;
    _missingStreak = 0;
    _baseBodyY = 0;
    _emaBodyY = 0;
    _jumpHits = 0;
    _seenJump = false;
  }

  /// Update the rep counter from the latest pose.
  /// Returns true if a rep was counted on this frame.
  bool update({
    required Pose pose,
    required Size canvasSize,
    required Size imageSize,
    required InputImageRotation rotation,
    required CameraLensDirection lensDirection,
  }) {
    // Helper: landmark exists and is confident enough
    bool okLm(PoseLandmark? p) => p != null && p.likelihood >= minLikelihood;

    // We need these to reliably compute legs open/close and normalization.
    const required = <PoseLandmarkType>[
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];

    for (final t in required) {
      final lm = pose.landmarks[t];
      if (!okLm(lm)) return _handleMissing('missing/low: $t');
    }

    // Arms: prefer wrists (best for "hands overhead"),
    // but fallback to elbows if wrists are cropped/out of frame.
    final lWr = pose.landmarks[PoseLandmarkType.leftWrist];
    final rWr = pose.landmarks[PoseLandmarkType.rightWrist];
    final lEl = pose.landmarks[PoseLandmarkType.leftElbow];
    final rEl = pose.landmarks[PoseLandmarkType.rightElbow];

    final lArm = okLm(lWr) ? lWr : okLm(lEl) ? lEl : null;
    final rArm = okLm(rWr) ? rWr : okLm(rEl) ? rEl : null;

    if (lArm == null || rArm == null) {
      // Arms missing is common during fast motion; allow grace frames.
      return _handleMissing('arms missing');
    }

    // We have a valid frame; reset missing streak.
    _missingStreak = 0;

    // Landmark -> canvas mapping must match how your preview is displayed.
    Offset map(PoseLandmark p) =>
        _map(p.x, p.y, canvasSize, imageSize, rotation, lensDirection);

    // Key points in canvas coordinates
    final lAnk = map(pose.landmarks[PoseLandmarkType.leftAnkle]!);
    final rAnk = map(pose.landmarks[PoseLandmarkType.rightAnkle]!);
    final lSh = map(pose.landmarks[PoseLandmarkType.leftShoulder]!);
    final rSh = map(pose.landmarks[PoseLandmarkType.rightShoulder]!);
    final lHip = map(pose.landmarks[PoseLandmarkType.leftHip]!);
    final rHip = map(pose.landmarks[PoseLandmarkType.rightHip]!);

    final lArmPt = map(lArm);
    final rArmPt = map(rArm);

    // Normalization anchor: shoulder width (scales well across body sizes).
    final shoulderWidth = (lSh - rSh).distance.clamp(1.0, 1e9);

    // Legs: raw ankle distance
    final ankleDist = (lAnk - rAnk).distance;
    final ankleRatio = ankleDist / shoulderWidth;

    // Body center (x) from hips; used to ensure BOTH legs move (anti-cheat).
    final centerX = (lHip.dx + rHip.dx) / 2.0;
    final leftSide = (centerX - lAnk.dx).abs() / shoulderWidth;
    final rightSide = (rAnk.dx - centerX).abs() / shoulderWidth;

    // Torso reference for deriving head level when face landmarks are missing.
    final avgShoulderY = (lSh.dy + rSh.dy) / 2.0;
    final avgHipY = (lHip.dy + rHip.dy) / 2.0;
    final torsoH = (avgHipY - avgShoulderY).abs().clamp(1.0, 1e9);

    //added for jumping
    final rawBodyY = (avgShoulderY + avgHipY) / 2.0;
    
    _emaBodyY = _ema(_emaBodyY, rawBodyY, emaAlpha);
    final bodyY = _emaBodyY!;

    final bool jumpedNow = (_baseBodyY != null) && ((_baseBodyY! - bodyY) >= (minJumpTorso * torsoH));
    if (jumpedNow) {
      _jumpHits++;
    } else {
      _jumpHits = 0;
    }

    if (_jumpHits >= confirmJumpFrames) {
      _seenJump = true;
    }

    // --- Arms UP detection (good form) ---
    // We want "hands overhead" / arms above the head.
    // Use nose/eyes if present; otherwise estimate headY from shoulders + torso height.
    double headY = avgShoulderY - 0.45 * torsoH; // fallback estimate

    final nose = pose.landmarks[PoseLandmarkType.nose];
    final lEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rEye = pose.landmarks[PoseLandmarkType.rightEye];

    if (okLm(nose)) {
      headY = map(nose!).dy;
    } else if (okLm(lEye) && okLm(rEye)) {
      headY = (map(lEye!).dy + map(rEye!).dy) / 2.0;
    }

    final usingLeftWrist = lWr != null && lWr.likelihood >= minLikelihood;
    final usingRightWrist = rWr != null && rWr.likelihood >= minLikelihood;

    // If wrist missing, do NOT allow armsUp (prevents elbow/forehead cheating)
    if (!usingLeftWrist || !usingRightWrist) {
      // treat as missing arms for OPEN
      return _handleMissing('wrists missing (need overhead)');
    }


    // MORE STRICT: must be clearly above head (not forehead)
    // Try 0.26 first. If still counts forehead, increase to 0.28–0.32.
    final leftThresh  = headY - 0.34 * torsoH;
    final rightThresh = headY - 0.34 * torsoH;

    final armsUp = (lArmPt.dy < leftThresh) && (rArmPt.dy < rightThresh);

    // Arms DOWN: below shoulders (doesn't require hands near hips, helps fast reps).
    final avgArmY = (lArmPt.dy + rArmPt.dy) / 2.0;
    final armsDown = avgArmY > (avgShoulderY + 0.05 * torsoH);

    // --- Smooth leg signals to reduce jitter while staying responsive ---
    _emaAnkleRatio = _ema(_emaAnkleRatio, ankleRatio, emaAlpha);
    _emaLeftSide = _ema(_emaLeftSide, leftSide, emaAlpha);
    _emaRightSide = _ema(_emaRightSide, rightSide, emaAlpha);

    final r = _emaAnkleRatio!;
    final ls = _emaLeftSide!;
    final rs = _emaRightSide!;

    // Symmetry gate to stop "one-leg step" from counting as OPEN/CLOSED.
    final legsOpenSym = (ls >= openSideRatio && rs >= openSideRatio);
    final legsCloseSym = (ls <= closeSideRatio && rs <= closeSideRatio);

    // State detection:
    // - OPEN requires legs apart + arms overhead
    // - CLOSED requires legs together + arms down
    final isOpen = (r >= openRatio) && legsOpenSym && armsUp && (!requireJump || _seenJump);
    final isClosed = (r <= closeRatio) && legsCloseSym && armsDown;

    // Debug string for on-screen overlay
    debug =
        'phase=$_phase reps=$reps r=${r.toStringAsFixed(2)} '
        'ls=${ls.toStringAsFixed(2)} rs=${rs.toStringAsFixed(2)} '
        'open=${isOpen ? 1 : 0} closed=${isClosed ? 1 : 0}';

    // Transition handling
    if (isOpen) {
      _phase = _Phase.open;
      _seenOpen = true;
      return false;
    }

    if (isClosed) {
      if (!jumpedNow) {
        _baseBodyY = _ema(_baseBodyY, bodyY, bodyBaseEmaAlpha);
      }
      
      // Count only on OPEN -> CLOSED transition, with cooldown.
      if (_phase == _Phase.open && _seenOpen){
        if (requireJump && !_seenJump){
          debug += 'Blocked: no jump';
          _phase = _Phase.closed;
          return false;
        }

        final now = DateTime.now();
        if (now.difference(_lastRepTime) >= minRepInterval) {
          reps += 1;
          _lastRepTime = now;
          _seenOpen = false;
          _phase = _Phase.closed;
          debug += ' ✅ REP';
          return true;
        }
      }
      if (_phase != _Phase.open) {
        _seenJump = false;
        _jumpHits = 0;
      }

      _phase = _Phase.closed;
      return false;
    }

    // Neutral zone: do nothing, keep current phase.
    return false;
  }

  /// Handle frames where key landmarks are missing/low confidence.
  /// We allow a few grace frames before fully resetting the internal state.
  bool _handleMissing(String why) {
    _missingStreak++;
    debug = '$why (grace $_missingStreak/$graceMissingFrames)';

    if (_missingStreak > graceMissingFrames) {
      // Reset internal phase and filters after too many missing frames.
      _phase = _Phase.unknown;
      _seenOpen = false;
      _emaAnkleRatio = null;
      _emaLeftSide = null;
      _emaRightSide = null;

      _seenJump = false;
      _emaBodyY = null;
      _baseBodyY = null;
    }
    return false;
  }

  /// Exponential moving average (EMA) smoothing.
  double _ema(double? prev, double next, double a) {
    if (prev == null) return next;
    return prev + a * (next - prev);
  }

  /// Maps ML Kit landmark coordinates to your overlay canvas coordinates,
  /// taking rotation and front-camera mirroring into account.
  Offset _map(
    double x,
    double y,
    Size canvas,
    Size img,
    InputImageRotation rot,
    CameraLensDirection lens,
  ) {
    double tx;
    switch (rot) {
      case InputImageRotation.rotation90deg:
        tx = x * canvas.width / img.height;
        break;
      case InputImageRotation.rotation270deg:
        tx = canvas.width - (x * canvas.width / img.height);
        break;
      default:
        tx = x * canvas.width / img.width;
    }

    // Front camera preview is typically mirrored; mirror overlay x to match.
    if (lens == CameraLensDirection.front) {
      tx = canvas.width - tx;
    }

    double ty;
    switch (rot) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        ty = y * canvas.height / img.width;
        break;
      default:
        ty = y * canvas.height / img.height;
    }

    return Offset(tx, ty);
  }
}
