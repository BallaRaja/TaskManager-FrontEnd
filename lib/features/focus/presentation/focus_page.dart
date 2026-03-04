// lib/features/focus/presentation/focus_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../logic/focus_controller.dart';
import 'widgets/timer_widget.dart';
import 'widgets/focus_stats_card.dart';
import 'package:client/features/tasks/presentation/tasks_controller.dart';

String _formatDue(DateTime due) {
  final now = DateTime.now();
  final diff = due.difference(now);
  if (diff.inDays > 0) return DateFormat('MMM d, h:mm a').format(due);
  if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m left';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m left';
  return 'Overdue';
}

class FocusPage extends StatelessWidget {
  const FocusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FocusController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6B9D)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.timer_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Focus Mode',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Stats card ──
              const FocusStatsCard(),
              const SizedBox(height: 20),

              // ── Timer settings ──
              _DurationSettingsCard(ctrl: ctrl),
              const SizedBox(height: 20),

              // ── Timer ──
              Center(child: const TimerWidget()),
              const SizedBox(height: 20),

              // ── Task selector ──
              _TaskSelector(ctrl: ctrl),
              const SizedBox(height: 20),

              // ── Session history ──
              _SessionHistory(ctrl: ctrl, isDark: isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Session History ───────────────────────────────────────────

class _SessionHistory extends StatelessWidget {
  final FocusController ctrl;
  final bool isDark;

  const _SessionHistory({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (ctrl.sessionsToday == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              "Today's Sessions",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${ctrl.sessionsToday} done',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6C63FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1B2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: List.generate(ctrl.sessionsToday, (i) {
              final sessionNum = i + 1;
              final isLast = i == ctrl.sessionsToday - 1;
              return Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isLast
                                ? [
                                    const Color(0xFF6C63FF),
                                    const Color(0xFFFF6B9D),
                                  ]
                                : [
                                    Colors.grey.withOpacity(0.3),
                                    Colors.grey.withOpacity(0.2),
                                  ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$sessionNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isLast
                                  ? Colors.white
                                  : (isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLast
                                  ? (ctrl.selectedTaskTitle ?? 'Focus Session')
                                  : 'Focus Session $sessionNum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF2D2D2D),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${ctrl.workMinutes} min • Completed',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF6C63FF),
                        size: 18,
                      ),
                    ],
                  ),
                  if (i < ctrl.sessionsToday - 1)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        top: 8,
                        bottom: 8,
                      ),
                      child: Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.grey.withOpacity(0.12),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ── Duration Settings Card ────────────────────────────────────

class _DurationSettingsCard extends StatefulWidget {
  final FocusController ctrl;
  const _DurationSettingsCard({required this.ctrl});

  @override
  State<_DurationSettingsCard> createState() => _DurationSettingsCardState();
}

class _DurationSettingsCardState extends State<_DurationSettingsCard> {
  static const List<int> workOptions = [15, 20, 25, 30, 45, 60, 90];
  static const List<int> breakOptions = [5, 10, 15, 20];

  late TextEditingController _workCustomCtrl;
  late TextEditingController _breakCustomCtrl;

  @override
  void initState() {
    super.initState();
    _workCustomCtrl = TextEditingController();
    _breakCustomCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _workCustomCtrl.dispose();
    _breakCustomCtrl.dispose();
    super.dispose();
  }

  void _showCustomDialog(BuildContext context, bool isWork) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = widget.ctrl;
    final color = isWork ? const Color(0xFF6C63FF) : const Color(0xFF43C6AC);
    final textCtrl = isWork ? _workCustomCtrl : _breakCustomCtrl;
    textCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isWork ? Icons.timer_outlined : Icons.coffee_outlined,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isWork ? 'Custom Focus Duration' : 'Custom Break Duration',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D2D2D),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter duration in minutes (1–180)',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF2D2D2D),
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 40',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.grey.withOpacity(0.08),
                suffixText: 'min',
                suffixStyle: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final val = int.tryParse(textCtrl.text.trim());
              if (val != null && val >= 1 && val <= 180) {
                if (isWork) {
                  ctrl.setWorkMinutes(val);
                } else {
                  ctrl.setBreakMinutes(val);
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1B2E) : Colors.white;
    final labelColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final chipUnselectedColor = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.grey.withOpacity(0.1);
    final chipUnselectedText = isDark ? Colors.grey[300]! : Colors.grey[700]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: Color(0xFF6C63FF),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Timer Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const Spacer(),
              if (ctrl.isRunning)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Pause to change',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Focus Duration
          Row(
            children: [
              Text(
                'Focus Duration',
                style: TextStyle(
                  fontSize: 12,
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: ctrl.isRunning
                    ? null
                    : () => _showCustomDialog(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: Color(0xFF6C63FF),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Custom',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...workOptions.map((m) {
                final isSelected = ctrl.workMinutes == m;
                return GestureDetector(
                  onTap: ctrl.isRunning ? null : () => ctrl.setWorkMinutes(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF9C6FFF)],
                            )
                          : null,
                      color: isSelected ? null : chipUnselectedColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${m}m',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : chipUnselectedText,
                      ),
                    ),
                  ),
                );
              }),
              if (!workOptions.contains(ctrl.workMinutes))
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9C6FFF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${ctrl.workMinutes}m ✓',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Break Duration
          Row(
            children: [
              Text(
                'Break Duration',
                style: TextStyle(
                  fontSize: 12,
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: ctrl.isRunning
                    ? null
                    : () => _showCustomDialog(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF43C6AC).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: Color(0xFF43C6AC),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Custom',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF43C6AC),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...breakOptions.map((m) {
                final isSelected = ctrl.breakMinutes == m;
                return GestureDetector(
                  onTap: ctrl.isRunning ? null : () => ctrl.setBreakMinutes(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF43C6AC), Color(0xFF00E5CC)],
                            )
                          : null,
                      color: isSelected ? null : chipUnselectedColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${m}m',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : chipUnselectedText,
                      ),
                    ),
                  ),
                );
              }),
              if (!breakOptions.contains(ctrl.breakMinutes))
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF43C6AC), Color(0xFF00E5CC)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${ctrl.breakMinutes}m ✓',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Task Selector ─────────────────────────────────────────────

class _TaskSelector extends StatelessWidget {
  final FocusController ctrl;
  const _TaskSelector({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final tasksCtrl = context.watch<TasksController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingTasks = tasksCtrl.tasks
        .where((t) => t['status'] == 'pending' && t['isArchived'] != true)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                color: Color(0xFF6C63FF),
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Current Task',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6C63FF),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pendingTasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'No pending tasks found',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: ctrl.selectedTaskId,
              hint: const Text('Select a task to focus on'),
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                ),
              ),
              items: pendingTasks.map((t) {
                final id = t['_id']?.toString() ?? '';
                final title = t['title']?.toString() ?? 'Untitled';
                return DropdownMenuItem(
                  value: id,
                  child: Text(title, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final task = pendingTasks.firstWhere(
                  (t) => t['_id']?.toString() == val,
                );
                ctrl.selectTask(
                  val,
                  task['title']?.toString() ?? '',
                  dueDateStr: task['dueDate']?.toString(),
                );
              },
            ),
          if (ctrl.selectedTaskTitle != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.08),
                    const Color(0xFFFF6B9D).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.play_circle_rounded,
                    color: Color(0xFF6C63FF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ctrl.selectedTaskTitle!,
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (ctrl.selectedTaskDue != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Deadline: ${_formatDue(ctrl.selectedTaskDue!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
