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
    return Padding(
      padding: const EdgeInsets.only(right: 32),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isAddButton
                  ? Colors.grey[600]
                  : isActive
                  ? Colors.purple
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          if (!isAddButton)
            Container(
              height: 3,
              width: 40,
              color: isActive ? Colors.purple : Colors.transparent,
            ),
        ],
      ),
    );
  }
}
