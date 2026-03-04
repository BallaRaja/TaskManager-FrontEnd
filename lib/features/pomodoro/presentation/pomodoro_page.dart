import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Pomodoro Timer Page
//  - Work / Short Break / Long Break modes
//  - Circular animated countdown ring
//  - Pulse animation on completion
//  - Session dots to track progress
//  - Customisable durations
// ─────────────────────────────────────────────────────────────────────────────

enum PomodoroMode { work, shortBreak, longBreak }

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage>
    with TickerProviderStateMixin {
  // ── Configurable durations (minutes) ──
  int _workMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;
  int _sessionsBeforeLong = 4;

  // ── State ──
  PomodoroMode _mode = PomodoroMode.work;
  int _completedSessions = 0;
  bool _isRunning = false;
  bool _hasStarted = false;

  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _ticker;

  // ── Animations ──
  late AnimationController _ringController;
  late AnimationController _pulseController;
  late AnimationController _breatheController;
  late Animation<double> _pulseAnim;
  late Animation<double> _breatheAnim;

  // ── Completed-burst controller ──
  late AnimationController _burstController;
  late Animation<double> _burstAnim;

  @override
  void initState() {
    super.initState();
    _totalSeconds = _workMinutes * 60;
    _remainingSeconds = _totalSeconds;

    // Ring progress — drives the arc painter
    _ringController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );

    // Pulse when timer completes
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Idle breathing
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _breatheAnim = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    // Completion burst ring
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _burstAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _burstController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ringController.dispose();
    _pulseController.dispose();
    _breatheController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  // ── Derived ──
  Color get _modeColor {
    switch (_mode) {
      case PomodoroMode.work:
        return Colors.deepPurple;
      case PomodoroMode.shortBreak:
        return const Color(0xFF00897B); // teal
      case PomodoroMode.longBreak:
        return const Color(0xFF1565C0); // blue
    }
  }

  Color get _modeAccent {
    switch (_mode) {
      case PomodoroMode.work:
        return Colors.purpleAccent;
      case PomodoroMode.shortBreak:
        return Colors.tealAccent;
      case PomodoroMode.longBreak:
        return Colors.lightBlueAccent;
    }
  }

  String get _modeLabel {
    switch (_mode) {
      case PomodoroMode.work:
        return 'Focus Time';
      case PomodoroMode.shortBreak:
        return 'Short Break';
      case PomodoroMode.longBreak:
        return 'Long Break';
    }
  }

  IconData get _modeIcon {
    switch (_mode) {
      case PomodoroMode.work:
        return Icons.local_fire_department_rounded;
      case PomodoroMode.shortBreak:
        return Icons.coffee_rounded;
      case PomodoroMode.longBreak:
        return Icons.self_improvement_rounded;
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Timer logic ──

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _hasStarted = true;
    });
    _breatheController.stop();

    // Set ring controller duration to remaining time and animate forward
    final progress = 1.0 - (_remainingSeconds / _totalSeconds);
    _ringController.duration = Duration(seconds: _totalSeconds);
    _ringController.forward(from: progress);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 0) {
        _onTimerComplete();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  void _pauseTimer() {
    _ticker?.cancel();
    _ringController.stop();
    _breatheController.repeat(reverse: true);
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _ticker?.cancel();
    _ringController.reset();
    _breatheController.repeat(reverse: true);
    setState(() {
      _remainingSeconds = _totalSeconds;
      _isRunning = false;
      _hasStarted = false;
    });
  }

  void _onTimerComplete() {
    _ticker?.cancel();
    _ringController.stop();
    HapticFeedback.heavyImpact();

    // Play pulse + burst
    _pulseController.forward(from: 0).then((_) {
      _pulseController.reverse();
    });
    _burstController.forward(from: 0);

    setState(() {
      _isRunning = false;
      _hasStarted = false;
    });

    if (_mode == PomodoroMode.work) {
      setState(() => _completedSessions++);
      // Auto-switch to break
      final isLong =
          _completedSessions > 0 &&
          _completedSessions % _sessionsBeforeLong == 0;
      _switchMode(isLong ? PomodoroMode.longBreak : PomodoroMode.shortBreak);
      _showCompletionSnack(
        isLong
            ? '🎉 Great work! Take a long break.'
            : '☕ Nice! Take a short break.',
      );
    } else {
      _switchMode(PomodoroMode.work);
      _showCompletionSnack('💪 Break over! Time to focus.');
    }
  }

  void _switchMode(PomodoroMode mode) {
    _ticker?.cancel();
    _ringController.reset();
    int minutes;
    switch (mode) {
      case PomodoroMode.work:
        minutes = _workMinutes;
        break;
      case PomodoroMode.shortBreak:
        minutes = _shortBreakMinutes;
        break;
      case PomodoroMode.longBreak:
        minutes = _longBreakMinutes;
        break;
    }
    setState(() {
      _mode = mode;
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
      _isRunning = false;
      _hasStarted = false;
    });
    _ringController.duration = Duration(seconds: _totalSeconds);
    _breatheController.repeat(reverse: true);
  }

  void _showCompletionSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 15)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: _modeColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSettingsSheet() {
    int tmpWork = _workMinutes;
    int tmpShort = _shortBreakMinutes;
    int tmpLong = _longBreakMinutes;
    int tmpSessions = _sessionsBeforeLong;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Widget sliderRow(
              String label,
              int value,
              int min,
              int max,
              ValueChanged<int> onChanged,
            ) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label.contains('Sessions')
                                ? '$value'
                                : '$value min',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(ctx).copyWith(
                        activeTrackColor: Colors.deepPurple,
                        inactiveTrackColor: Colors.deepPurple.withOpacity(0.15),
                        thumbColor: Colors.deepPurple,
                        overlayColor: Colors.deepPurple.withOpacity(0.15),
                        trackHeight: 5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                      ),
                      child: Slider(
                        value: value.toDouble(),
                        min: min.toDouble(),
                        max: max.toDouble(),
                        divisions: max - min,
                        onChanged: (v) {
                          setSheetState(() => onChanged(v.round()));
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Timer Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  sliderRow(
                    'Focus Duration',
                    tmpWork,
                    1,
                    60,
                    (v) => tmpWork = v,
                  ),
                  sliderRow(
                    'Short Break',
                    tmpShort,
                    1,
                    15,
                    (v) => tmpShort = v,
                  ),
                  sliderRow('Long Break', tmpLong, 5, 30, (v) => tmpLong = v),
                  sliderRow(
                    'Sessions Before Long Break',
                    tmpSessions,
                    2,
                    8,
                    (v) => tmpSessions = v,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _workMinutes = tmpWork;
                          _shortBreakMinutes = tmpShort;
                          _longBreakMinutes = tmpLong;
                          _sessionsBeforeLong = tmpSessions;
                        });
                        _switchMode(_mode);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _totalSeconds > 0
        ? 1.0 - (_remainingSeconds / _totalSeconds)
        : 0.0;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121020)
          : const Color(0xFFF6F4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pomodoro',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
            onPressed: _showSettingsSheet,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Mode selector chips ──
            _buildModeChips(isDark),

            const SizedBox(height: 12),

            // ── Mode label + icon ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Row(
                key: ValueKey(_mode),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_modeIcon, color: _modeColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    _modeLabel,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _modeColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── Timer ring ──
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _pulseAnim,
                    _breatheAnim,
                    _burstAnim,
                  ]),
                  builder: (context, child) {
                    final scale = _isRunning || _hasStarted
                        ? _pulseAnim.value
                        : _breatheAnim.value * _pulseAnim.value;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Burst ring on completion
                        AnimatedBuilder(
                          animation: _burstAnim,
                          builder: (context, _) {
                            if (_burstAnim.value == 0) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              width: 260 + 40 * _burstAnim.value,
                              height: 260 + 40 * _burstAnim.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _modeAccent.withOpacity(
                                    1 - _burstAnim.value,
                                  ),
                                  width: 3,
                                ),
                              ),
                            );
                          },
                        ),

                        // Progress ring
                        CustomPaint(
                          size: const Size(260, 260),
                          painter: _RingPainter(
                            progress: progress,
                            color: _modeColor,
                            accentColor: _modeAccent,
                            isDark: isDark,
                          ),
                        ),

                        // Time display
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(_remainingSeconds),
                              style: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: 2,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isRunning
                                  ? 'Running'
                                  : _hasStarted
                                  ? 'Paused'
                                  : 'Ready',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey[500],
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Controls ──
            _buildControls(isDark),

            const SizedBox(height: 20),

            // ── Session dots ──
            _buildSessionDots(isDark),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SUB-WIDGETS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildModeChips(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: PomodoroMode.values.map((m) {
          final isActive = m == _mode;
          String label;
          switch (m) {
            case PomodoroMode.work:
              label = 'Focus';
              break;
            case PomodoroMode.shortBreak:
              label = 'Short';
              break;
            case PomodoroMode.longBreak:
              label = 'Long';
              break;
          }
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () {
                  if (!_isRunning) _switchMode(m);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _modeColorFor(m).withOpacity(isDark ? 0.25 : 0.12)
                        : isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive
                          ? _modeColorFor(m).withOpacity(0.5)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive
                            ? _modeColorFor(m)
                            : isDark
                            ? Colors.white60
                            : Colors.grey[600],
                      ),
                      child: Text(label),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _modeColorFor(PomodoroMode m) {
    switch (m) {
      case PomodoroMode.work:
        return Colors.deepPurple;
      case PomodoroMode.shortBreak:
        return const Color(0xFF00897B);
      case PomodoroMode.longBreak:
        return const Color(0xFF1565C0);
    }
  }

  Widget _buildControls(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reset
          _controlButton(
            icon: Icons.refresh_rounded,
            label: 'Reset',
            onTap: _resetTimer,
            isDark: isDark,
            color: Colors.grey,
          ),
          // Play / Pause
          GestureDetector(
            onTap: _isRunning ? _pauseTimer : _startTimer,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_modeColor, _modeAccent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _modeColor.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(_isRunning),
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
          // Skip
          _controlButton(
            icon: Icons.skip_next_rounded,
            label: 'Skip',
            onTap: () {
              if (!_isRunning && !_hasStarted) return;
              _onTimerComplete();
            },
            isDark: isDark,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[100],
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white70 : Colors.grey[700],
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDots(bool isDark) {
    return Column(
      children: [
        Text(
          'Sessions: $_completedSessions',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_sessionsBeforeLong, (i) {
            final done =
                i < (_completedSessions % _sessionsBeforeLong) ||
                (_completedSessions > 0 &&
                    _completedSessions % _sessionsBeforeLong == 0 &&
                    i < _sessionsBeforeLong);
            return AnimatedContainer(
              duration: Duration(milliseconds: 300 + i * 60),
              curve: Curves.easeOutBack,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: done ? 14 : 10,
              height: done ? 14 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? _modeColor
                    : isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.grey[300],
                boxShadow: done
                    ? [
                        BoxShadow(
                          color: _modeColor.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Custom Ring Painter
// ═══════════════════════════════════════════════════════════════════════════════

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color accentColor;
  final bool isDark;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const strokeWidth = 10.0;

    // Background track
    final bgPaint = Paint()
      ..color = isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: pi * 2 - pi / 2,
        colors: [color, accentColor, color],
        stops: const [0.0, 0.5, 1.0],
        transform: const GradientRotation(-pi / 2),
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, progressPaint);

      // Glow dot at end of arc
      final angle = -pi / 2 + 2 * pi * progress;
      final dotCenter = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      final glowPaint = Paint()
        ..color = accentColor.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(dotCenter, 6, glowPaint);

      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(dotCenter, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.isDark != isDark;
}
