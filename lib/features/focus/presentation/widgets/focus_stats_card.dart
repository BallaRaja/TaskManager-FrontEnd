// lib/features/focus/presentation/widgets/focus_stats_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/focus_controller.dart';

class FocusStatsCard extends StatelessWidget {
  const FocusStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FocusController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = ctrl.goalProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1C1B2E), const Color(0xFF2A2842)]
              : [const Color(0xFF6C63FF), const Color(0xFF9C6FFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(isDark ? 0.2 : 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              const Text(
                "Today's Focus",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // Pomodoro tomatoes 🍅
              _PomodoroIndicator(sessions: ctrl.sessionsToday),
            ],
          ),
          const SizedBox(height: 20),

          // ── Stats Row ──
          Row(
            children: [
              _StatBubble(
                icon: Icons.local_fire_department_rounded,
                iconColor: Colors.orange.shade300,
                label: 'Sessions',
                value: '${ctrl.sessionsToday}',
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _StatBubble(
                icon: Icons.timer_outlined,
                iconColor: Colors.lightBlueAccent,
                label: 'Focus Time',
                value: _formatMinutes(ctrl.totalMinutesToday),
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _StatBubble(
                icon: Icons.bolt_rounded,
                iconColor: Colors.amber.shade300,
                label: 'Streak',
                value: '${ctrl.streak}d 🔥',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Goal Progress ──
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                'Daily Goal: ${FocusController.dailyGoalMinutes} min',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                // Background track
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Progress fill
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: progress >= 1.0
                            ? [Colors.greenAccent, Colors.green]
                            : [Colors.white, Colors.white.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (progress >= 1.0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.celebration_rounded, color: Colors.amber, size: 16),
                SizedBox(width: 6),
                Text(
                  'Daily goal reached! Amazing work! 🎉',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// ── Pomodoro Indicator ────────────────────────────────────────

class _PomodoroIndicator extends StatelessWidget {
  final int sessions;
  const _PomodoroIndicator({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final displayCount = sessions.clamp(0, 8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(
          displayCount,
          (i) => const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Text('🍅', style: TextStyle(fontSize: 14)),
          ),
        ),
        if (sessions > 8)
          Text(
            '+${sessions - 8}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (sessions == 0)
          const Text(
            'No sessions yet',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
      ],
    );
  }
}

// ── Stat Bubble ───────────────────────────────────────────────

class _StatBubble extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;

  const _StatBubble({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
