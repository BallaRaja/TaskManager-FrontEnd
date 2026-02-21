// lib/features/tasks/presentation/widgets/completed_section.dart

import 'package:flutter/material.dart';
import 'task_item.dart';

class CompletedSection extends StatelessWidget {
  final List<Map<String, dynamic>> completedTasks;

  const CompletedSection({super.key, required this.completedTasks});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeBackground = isDark
        ? const Color(0xFF2A2438)
        : Colors.grey.shade200;
    final badgeTextColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF1A1A1A);

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Row(
        children: [
          const Text(
            "Completed",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "${completedTasks.length}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.expand_more),
      children: completedTasks
          .map((t) => TaskItem(task: t, isCompleted: true))
          .toList(),
    );
  }
}
