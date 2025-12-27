// lib/features/tasks/presentation/widgets/task_item.dart

import 'package:flutter/material.dart';

class TaskItem extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isCompleted;

  const TaskItem({super.key, required this.task, required this.isCompleted});

  String? _formatDueDate(String? iso) {
    if (iso == null) return null;
    final date = DateTime.parse(iso);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(date.year, date.month, date.day);

    if (taskDay == today) {
      return "Today, ${date.hour.toString().padLeft(2, '0')}:00";
    } else if (taskDay.difference(today).inDays == 1) {
      return "Tomorrow";
    }
    return "Later";
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _formatDueDate(task["dueDate"]);
    final isToday = dueText?.startsWith("Today") == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? Colors.transparent
              : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Checkbox(
            value: isCompleted,
            onChanged: (v) => print("Toggle ${task["_id"]} → $v"),
            shape: const CircleBorder(),
            activeColor: Colors.purple,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task["title"] ?? "Untitled",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? Colors.grey : null,
                  ),
                ),
                if (dueText != null || task["notes"] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      dueText ?? task["notes"] ?? "",
                      style: TextStyle(
                        fontSize: 12,
                        color: isToday ? Colors.red : Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.star,
              color: task["isStarred"] == true
                  ? Colors.yellow[600]
                  : Colors.grey[400],
            ),
            onPressed: () => print("Star ${task["_id"]}"),
          ),
        ],
      ),
    );
  }
}
