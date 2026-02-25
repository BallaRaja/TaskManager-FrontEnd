// lib/features/calendar/presentation/widgets/calendar_task_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'calendar_task_detail_sheet.dart';

class CalendarTaskTile extends StatelessWidget {
  final Map<String, dynamic> task;

  const CalendarTaskTile({super.key, required this.task});

  String? _timeLabel(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = task['title'] as String? ?? 'Untitled';
    final isCompleted = task['status'] == 'completed';
    final isImportant = task['priority'] == 'high';
    final timeLabel = _timeLabel(task['dueDate'] as String?);
    final notes = task['notes'] as String?;

    return GestureDetector(
      onTap: () => showCalendarTaskDetail(context, task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? Colors.transparent
                : Colors.grey.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green
                    : isImportant
                    ? Colors.amber
                    : Colors.purple,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                  if (timeLabel != null || notes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        timeLabel ?? notes ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                ],
              ),
            ),

            // Trailing icons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isImportant)
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                if (isCompleted)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 18,
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
