import 'dart:math';
import 'package:flutter/material.dart';

/// Call [TaskCreatedOverlay.show] right after a task is confirmed to play
/// a full-screen confetti + checkmark celebration that auto-dismisses.
class TaskCreatedOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context) {
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (_) => _TaskCreatedAnimation(
        onDone: () {
          _entry?.remove();
          _entry = null;
        },
      ),
    );
    Overlay.of(context).insert(_entry!);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TaskCreatedAnimation extends StatefulWidget {
  final VoidCallback onDone;
  const _TaskCreatedAnimation({required this.onDone});

  @override
  State<_TaskCreatedAnimation> createState() => _TaskCreatedAnimationState();
}

class _TaskCreatedAnimationState extends State<_TaskCreatedAnimation>
    with TickerProviderStateMixin {
  // Controllers
  late final AnimationController _confettiCtrl;
  late final AnimationController _checkCtrl;
  late final AnimationController _fadeCtrl;

  // Check animations
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _labelOffset;

  final List<_Particle> _particles = [];
  final Random _rng = Random();

  static const _colors = [
    Color(0xFF7C4DFF),
    Color(0xFFB39DFF),
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFFF922B),
    Color(0xFFE040FB),
  ];

  @override
  void initState() {
    super.initState();

    // Generate 70 particles
    for (int i = 0; i < 70; i++) {
      _particles.add(
        _Particle(
          angle: _rng.nextDouble() * 2 * pi,
          speed: 180 + _rng.nextDouble() * 320,
          color: _colors[_rng.nextInt(_colors.length)],
          size: 5 + _rng.nextDouble() * 9,
          rotation: _rng.nextDouble() * 2 * pi,
          rotationSpeed: (_rng.nextDouble() - 0.5) * 12,
          isCircle: _rng.nextBool(),
        ),
      );
    }

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut),
    );

    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _labelOffset = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _checkCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Confetti + check burst together
    _confettiCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 80));
    _checkCtrl.forward();
    // Hold for the user to see
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      await _fadeCtrl.forward();
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _checkCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);

    return AnimatedBuilder(
      animation: _fadeCtrl,
      builder: (_, __) => Opacity(
        opacity: 1.0 - _fadeCtrl.value,
        child: Stack(
          children: [
            // ── Confetti ──────────────────────────────────────────
            AnimatedBuilder(
              animation: _confettiCtrl,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confettiCtrl.value,
                  center: center,
                ),
              ),
            ),

            // ── Checkmark circle ──────────────────────────────────
            Center(
              child: AnimatedBuilder(
                animation: _checkCtrl,
                builder: (_, __) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _checkOpacity.value,
                      child: Transform.scale(
                        scale: _checkScale.value,
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9C6BFF), Color(0xFF5C35D4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C4DFF).withOpacity(0.55),
                                blurRadius: 32,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 58,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Label ──
                    Transform.translate(
                      offset: Offset(0, _labelOffset.value),
                      child: Opacity(
                        opacity: _checkOpacity.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            '🎉  Task Added!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Particle {
  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final bool isCircle;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.isCircle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Offset center;

  const _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final t = Curves.easeOut.transform(progress);

    for (final p in particles) {
      final distance = p.speed * t;
      // Gravity effect — particles arc downward over time
      final gravity = 260 * t * t;
      final x = center.dx + cos(p.angle) * distance;
      final y = center.dy + sin(p.angle) * distance + gravity;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      paint.color = p.color.withOpacity(opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotationSpeed * progress);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.45,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
