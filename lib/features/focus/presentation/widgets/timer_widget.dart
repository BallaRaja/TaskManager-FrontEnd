// lib/features/focus/presentation/widgets/timer_widget.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../logic/focus_controller.dart';

// ── Motivational Quotes ───────────────────────────────────────
const List<String> _focusQuotes = [
  "Deep work is the superpower of the 21st century.",
  "Focus is the art of knowing what to ignore.",
  "One task at a time. That's the secret.",
  "The secret of getting ahead is getting started.",
  "Concentrate all your thoughts on the task at hand.",
  "Energy flows where attention goes.",
  "Small progress is still progress.",
  "Your future self will thank you.",
  "Do the hard thing first. Everything else is easy.",
  "Clarity comes from engagement, not thought.",
];

class TimerWidget extends StatefulWidget {
  const TimerWidget({super.key});

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget>
    with TickerProviderStateMixin {
  // Pulse while running
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Glow pulse
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  // Burst ring on completion
  late AnimationController _burstCtrl;
  late Animation<double> _burstScale;
  late Animation<double> _burstFade;

  // Break wave rings
  late AnimationController _waveCtrl;

  // Slide-in for break/resume banner
  late AnimationController _bannerCtrl;
  late Animation<Offset> _bannerSlide;
  late Animation<double> _bannerFade;

  bool _lastCompletionFlag = false;
  bool _lastBreakFlag = false;
  bool _lastResumeFlag = false;

  late String _currentQuote;
  int _quoteIndex = 0;

  @override
  void initState() {
    super.initState();
    _quoteIndex = Random().nextInt(_focusQuotes.length);
    _currentQuote = _focusQuotes[_quoteIndex];

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _burstScale = Tween<double>(
      begin: 0.9,
      end: 1.8,
    ).animate(CurvedAnimation(parent: _burstCtrl, curve: Curves.easeOut));
    _burstFade = Tween<double>(
      begin: 0.9,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _burstCtrl, curve: Curves.easeIn));

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _bannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOut));
    _bannerFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _burstCtrl.dispose();
    _waveCtrl.dispose();
    _bannerCtrl.dispose();
    super.dispose();
  }

  void _nextQuote() {
    setState(() {
      _quoteIndex = (_quoteIndex + 1) % _focusQuotes.length;
      _currentQuote = _focusQuotes[_quoteIndex];
    });
  }

  String _estimatedFinish(int secondsLeft) {
    final finish = DateTime.now().add(Duration(seconds: secondsLeft));
    final h = finish.hour;
    final m = finish.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return 'Done by $displayH:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FocusController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWork = ctrl.phase == FocusPhase.work;
    final isBreak = ctrl.phase == FocusPhase.breakTime;
    final total = ctrl.totalSecondsForPhase;
    final progress = (total > 0)
        ? (1 - (ctrl.secondsLeft / total)).clamp(0.0, 1.0)
        : 0.0;

    // Colors per phase
    final Color primaryColor = isBreak
        ? const Color(0xFF43C6AC)
        : const Color(0xFF6C63FF);
    final Color secondaryColor = isBreak
        ? const Color(0xFF00E5CC)
        : const Color(0xFFFF6B9D);

    // ── React to effect flags ──────────────────────────────
    if (ctrl.triggerCompletionEffect && !_lastCompletionFlag) {
      _lastCompletionFlag = true;
      _burstCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
      _nextQuote();
      ctrl.consumeEffectFlags();
    } else if (!ctrl.triggerCompletionEffect) {
      _lastCompletionFlag = false;
    }

    if (ctrl.triggerBreakEffect && !_lastBreakFlag) {
      _lastBreakFlag = true;
      _bannerCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
      ctrl.consumeEffectFlags();
    } else if (!ctrl.triggerBreakEffect) {
      _lastBreakFlag = false;
    }

    if (ctrl.triggerResumeEffect && !_lastResumeFlag) {
      _lastResumeFlag = true;
      _bannerCtrl.reverse();
      HapticFeedback.mediumImpact();
      ctrl.consumeEffectFlags();
    } else if (!ctrl.triggerResumeEffect) {
      _lastResumeFlag = false;
    }

    // Pulse & glow: only while work is running
    if (ctrl.isRunning && isWork) {
      if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
      if (!_glowCtrl.isAnimating) _glowCtrl.repeat(reverse: true);
    } else {
      if (_pulseCtrl.isAnimating) {
        _pulseCtrl.stop();
        _pulseCtrl.animateTo(0);
      }
      if (_glowCtrl.isAnimating) {
        _glowCtrl.stop();
        _glowCtrl.animateTo(0);
      }
    }

    return Column(
      children: [
        // ── Phase label ──────────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _PhaseLabel(
            key: ValueKey(ctrl.phase),
            phase: ctrl.phase,
            isDeadline: ctrl.isDeadlineMode,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 16),

        // ── Motivational quote (shown while running) ─────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: ctrl.isRunning && isWork
              ? GestureDetector(
                  onTap: _nextQuote,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '"$_currentQuote"',
                      key: ValueKey(_currentQuote),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              : ctrl.hasTaskSelected
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Select a task below to start focusing',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 20),

        // ── Circular timer ───────────────────────────────────
        SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow layer
              if (ctrl.isRunning && isWork)
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, __) => Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(
                            0.15 * _glowAnim.value,
                          ),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),

              // Break wave
              if (isBreak)
                AnimatedBuilder(
                  animation: _waveCtrl,
                  builder: (_, __) => CustomPaint(
                    size: const Size(280, 280),
                    painter: _WavePainter(
                      phase: _waveCtrl.value * 2 * pi,
                      color: primaryColor,
                      isDark: isDark,
                    ),
                  ),
                ),

              // Burst ring
              AnimatedBuilder(
                animation: _burstCtrl,
                builder: (_, __) => _burstCtrl.isAnimating
                    ? Transform.scale(
                        scale: _burstScale.value,
                        child: Opacity(
                          opacity: _burstFade.value,
                          child: Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: secondaryColor,
                                width: 4,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Gradient progress arc with pulse
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: ctrl.isRunning && isWork ? _pulseAnim.value : 1.0,
                  child: child,
                ),
                child: CustomPaint(
                  size: const Size(280, 280),
                  painter: _GradientCirclePainter(
                    progress: progress,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    isDark: isDark,
                    isRunning: ctrl.isRunning,
                  ),
                ),
              ),

              // Inner content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _TimerCenter(
                  key: ValueKey('${ctrl.phase}_${ctrl.isRunning}'),
                  ctrl: ctrl,
                  isDark: isDark,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),

        // ── Estimated finish time ────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: ctrl.isRunning && ctrl.secondsLeft > 0
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _estimatedFinish(ctrl.secondsLeft),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(height: 12),
        ),

        const SizedBox(height: 20),

        // ── Controls ─────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CtrlBtn(
              icon: Icons.replay_rounded,
              onTap: ctrl.hasTaskSelected ? ctrl.reset : null,
              bg: isDark ? Colors.white.withOpacity(0.09) : Colors.grey[200]!,
              iconColor: isDark ? Colors.grey[300]! : Colors.grey[600]!,
              tooltip: 'Reset',
            ),
            const SizedBox(width: 20),

            // Play / Pause
            GestureDetector(
              onTap: isBreak
                  ? null
                  : (ctrl.isRunning ? ctrl.pause : ctrl.start),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: isBreak
                      ? null
                      : (ctrl.hasTaskSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [primaryColor, secondaryColor],
                              )
                            : null),
                  color: isBreak
                      ? primaryColor.withOpacity(0.4)
                      : (!ctrl.hasTaskSelected ? Colors.grey[400] : null),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(
                        ctrl.isRunning ? 0.55 : 0.3,
                      ),
                      blurRadius: ctrl.isRunning ? 32 : 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isBreak
                      ? const Icon(
                          Icons.coffee_rounded,
                          key: ValueKey('break'),
                          color: Colors.white,
                          size: 30,
                        )
                      : Icon(
                          ctrl.isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          key: ValueKey(ctrl.isRunning),
                          color: Colors.white,
                          size: 38,
                        ),
                ),
              ),
            ),

            const SizedBox(width: 20),
            _CtrlBtn(
              icon: Icons.stop_rounded,
              onTap: ctrl.hasTaskSelected ? ctrl.clearTask : null,
              bg: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50,
              iconColor: Colors.red,
              tooltip: 'Stop',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Break banner ─────────────────────────────────────
        SlideTransition(
          position: _bannerSlide,
          child: FadeTransition(
            opacity: _bannerFade,
            child: isBreak
                ? _BreakBanner(color: primaryColor, isDark: isDark)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

// ── Phase Label ───────────────────────────────────────────────

class _PhaseLabel extends StatelessWidget {
  final FocusPhase phase;
  final bool isDeadline;
  final Color color;

  const _PhaseLabel({
    super.key,
    required this.phase,
    required this.isDeadline,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    switch (phase) {
      case FocusPhase.work:
        label = isDeadline ? '⏰ Deadline Focus' : '🎯 Focus Time';
        break;
      case FocusPhase.breakTime:
        label = '☕ Break Time';
        break;
      case FocusPhase.completed:
        label = '✅ Session Done';
        break;
      default:
        label = '🎯 Ready to Focus';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Timer Center ──────────────────────────────────────────────

class _TimerCenter extends StatelessWidget {
  final FocusController ctrl;
  final bool isDark;
  final Color color;

  const _TimerCenter({
    super.key,
    required this.ctrl,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isBreak = ctrl.phase == FocusPhase.breakTime;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Task name above timer
        if (ctrl.selectedTaskTitle != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              ctrl.selectedTaskTitle!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
                letterSpacing: 0.3,
              ),
            ),
          ),
        if (ctrl.selectedTaskTitle != null) const SizedBox(height: 4),

        // Time display
        Text(
          ctrl.hasTaskSelected ? ctrl.formattedTime : '--:--',
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            shadows: [Shadow(color: color.withOpacity(0.3), blurRadius: 16)],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isBreak
              ? 'Relax 🌿'
              : ctrl.isDeadlineMode
              ? 'Until deadline'
              : ctrl.isRunning
              ? 'Stay focused ✨'
              : ctrl.hasTaskSelected
              ? 'Tap play to start'
              : 'No task selected',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isBreak) ...[
          const SizedBox(height: 4),
          Text(
            'Work resumes after break',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Break Banner ──────────────────────────────────────────────

class _BreakBanner extends StatelessWidget {
  final Color color;
  final bool isDark;
  const _BreakBanner({required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.self_improvement_rounded, color: color, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Break in progress',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13,
                ),
              ),
              Text(
                'Breathe. Next session starts automatically.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Control Button ────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color bg;
  final Color iconColor;
  final String tooltip;

  const _CtrlBtn({
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.iconColor,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.35 : 1.0,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ),
      ),
    );
  }
}

// ── Gradient Circle Painter ───────────────────────────────────

class _GradientCirclePainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;
  final bool isRunning;

  _GradientCirclePainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
    required this.isRunning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = isDark
            ? Colors.white.withOpacity(0.07)
            : primaryColor.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );

    if (progress > 0) {
      // Gradient arc
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + 2 * pi,
        colors: [primaryColor, secondaryColor, primaryColor],
        stops: const [0.0, 0.5, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, paint);

      // Glowing dot at tip of arc
      if (progress > 0.02 && isRunning) {
        final angle = -pi / 2 + 2 * pi * progress;
        final dotX = cx + r * cos(angle);
        final dotY = cy + r * sin(angle);

        canvas.drawCircle(
          Offset(dotX, dotY),
          7,
          Paint()
            ..color = secondaryColor
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(Offset(dotX, dotY), 5, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_GradientCirclePainter old) =>
      old.progress != progress ||
      old.primaryColor != primaryColor ||
      old.isRunning != isRunning;
}

// ── Wave Painter ──────────────────────────────────────────────

class _WavePainter extends CustomPainter {
  final double phase;
  final Color color;
  final bool isDark;

  _WavePainter({
    required this.phase,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseR = size.width / 2 - 14;
    final paint = Paint()
      ..color = color.withOpacity(isDark ? 0.07 : 0.05)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final r = baseR * (0.45 + 0.2 * sin(phase + i * 1.2));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.phase != phase;
}
