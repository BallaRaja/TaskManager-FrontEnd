// lib/features/tasks/presentation/widgets/task_list_tab.dart
import 'package:flutter/material.dart';

class TaskListTab extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool isAddButton;

  const TaskListTab({
    super.key,
    required this.title,
    this.isActive = false,
    this.isAddButton = false,
  });

  @override
  Widget build(BuildContext context) {
    // Add button uses different styling
    if (isAddButton) {
      return Padding(
        padding: const EdgeInsets.only(right: 32),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Container(height: 3, width: 40, color: Colors.transparent),
          ],
        ),
      );
    }

    // Regular task list tab
    return Padding(
      padding: const EdgeInsets.only(right: 32),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isActive ? Colors.purple : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: isActive ? Colors.purple : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
