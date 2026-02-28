// lib/features/calendar/presentation/widgets/calendar_task_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../calendar_controller.dart';
import 'package:client/features/tasks/presentation/tasks_controller.dart';

void showCalendarTaskDetail(BuildContext context, Map<String, dynamic> task) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CalendarTaskDetailSheet(task: task),
  );
}

class _CalendarTaskDetailSheet extends StatefulWidget {
  final Map<String, dynamic> task;
  const _CalendarTaskDetailSheet({required this.task});

  @override
  State<_CalendarTaskDetailSheet> createState() =>
      _CalendarTaskDetailSheetState();
}

class _CalendarTaskDetailSheetState extends State<_CalendarTaskDetailSheet> {
  late Map<String, dynamic> _task;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _task = Map<String, dynamic>.from(widget.task);
  }

  bool get _isCompleted => _task['status'] == 'completed';
  bool get _isImportant => _task['priority'] == 'high';

  String? _formatDue(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('EEE, MMM d • hh:mm a').format(dt);
  }

  String _repeatLabel(Map<String, dynamic>? repeat) {
    if (repeat == null) return 'No repeat';
    final freq = repeat['frequency'] as String? ?? 'none';
    if (freq == 'none') return 'No repeat';
    final interval = repeat['interval'] as int? ?? 1;
    final days = (repeat['daysOfWeek'] as List?)?.join(', ') ?? '';
    switch (freq) {
      case 'daily':
        return interval == 1 ? 'Every day' : 'Every $interval days';
      case 'weekly':
        return days.isNotEmpty
            ? 'Weekly: $days'
            : interval == 1
            ? 'Every week'
            : 'Every $interval weeks';
      case 'monthly':
        return interval == 1 ? 'Every month' : 'Every $interval months';
      default:
        return 'No repeat';
    }
  }

  Future<void> _toggleComplete() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    
    final calController = Provider.of<CalendarController>(context, listen: false);
    final tasksController = Provider.of<TasksController>(context, listen: false);
    
    final newStatus = _task['status'] == 'completed' ? 'pending' : 'completed';
    final taskId = _task['_id'].toString();
    
    // Optimistic update
    final updatedTask = Map<String, dynamic>.from(_task);
    updatedTask['status'] = newStatus;
    updatedTask['completedAt'] = newStatus == 'completed' 
        ? DateTime.now().toUtc().toIso8601String() 
        : null;

    try {
      final result = await tasksController.updateTask(taskId, {
        "status": newStatus,
        "completedAt": updatedTask['completedAt'],
      });
      
      if (result != null) {
        // Sync both controllers
        calController.upsertTaskLocal(result);
        // TasksController.updateTask already updates its local list
        
        if (mounted) {
          setState(() {
            _task = Map<String, dynamic>.from(result);
          });
        }
      } else {
        // Revert or show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update task")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error")),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dueStr = _formatDue(_task['dueDate'] as String?);
    final notes = _task['notes'] as String?;
    final repeat = _task['repeat'] as Map<String, dynamic>?;
    final repeatLabel = _repeatLabel(repeat);
    final title = _task['title'] as String? ?? 'Untitled';

    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1B2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ── handle ──
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── header band ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B2FF7), Color(0xFF5E35B1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Complete toggle button
                  GestureDetector(
                    onTap: _toggleComplete,
                    child: _toggling
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Icon(
                              _isCompleted
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              key: ValueKey(_isCompleted),
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            decoration: _isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.white60,
                          ),
                        ),
                        if (_isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Completed',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isImportant)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),

            // ── detail rows ──
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  // Due date
                  if (dueStr != null)
                    _DetailRow(
                      icon: Icons.schedule_rounded,
                      iconColor: Colors.purple,
                      label: 'Due',
                      value: dueStr,
                      isDark: isDark,
                    ),
                  // Priority
                  _DetailRow(
                    icon: _isImportant
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    iconColor: _isImportant ? Colors.amber : Colors.grey,
                    label: 'Priority',
                    value: _isImportant ? 'High (Starred)' : 'Normal',
                    isDark: isDark,
                  ),
                  // Repeat
                  _DetailRow(
                    icon: Icons.repeat_rounded,
                    iconColor: Colors.indigo,
                    label: 'Repeat',
                    value: repeatLabel,
                    isDark: isDark,
                  ),
                  // Notes
                  if (notes != null && notes.isNotEmpty)
                    _DetailRow(
                      icon: Icons.notes_rounded,
                      iconColor: Colors.teal,
                      label: 'Notes',
                      value: notes,
                      isDark: isDark,
                      multiLine: true,
                    ),

                  const SizedBox(height: 20),

                  // Toggle complete button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _isCompleted
                            ? Colors.grey[600]
                            : Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _toggling ? null : _toggleComplete,
                      icon: Icon(
                        _isCompleted
                            ? Icons.undo_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _isCompleted ? 'Mark as Pending' : 'Mark as Complete',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;
  final bool multiLine;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
    this.multiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: multiLine
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
