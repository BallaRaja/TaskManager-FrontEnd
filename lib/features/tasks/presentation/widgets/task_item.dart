// lib/features/tasks/presentation/widgets/task_item.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/session_manager.dart';
import '../tasks_controller.dart';

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
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return "Today, $hour:$minute";
    } else if (taskDay.difference(today).inDays == 1) {
      return "Tomorrow";
    }
    return "Later";
  }

  // Optimistically update UI
  void _updateLocalTask(
    BuildContext context,
    Map<String, dynamic> updatedTask,
  ) {
    final controller = Provider.of<TasksController>(context, listen: false);
    final index = controller.tasks.indexWhere((t) => t["_id"] == task["_id"]);
    if (index != -1) {
      controller.tasks[index] = updatedTask;
      controller.notifyListeners();
    }
  }

  void _removeLocalTask(BuildContext context) {
    final controller = Provider.of<TasksController>(context, listen: false);
    controller.tasks.removeWhere((t) => t["_id"] == task["_id"]);
    controller.notifyListeners();
  }

  Future<void> _toggleComplete(BuildContext context) async {
    final token = await SessionManager.getToken();
    if (token == null) return;

    final newStatus = isCompleted ? "pending" : "completed";
    final taskId = task["_id"].toString();

    try {
      final response = await http.put(
        Uri.parse("${ApiConstants.backendUrl}/api/task/$taskId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "status": newStatus,
          if (!isCompleted) "completedAt": DateTime.now().toIso8601String(),
          if (isCompleted) "completedAt": null,
        }),
      );

      if (response.statusCode == 200) {
        final updatedTask = jsonDecode(response.body)["data"];
        _updateLocalTask(context, updatedTask);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to update task")));
      }
    }
  }

  Future<void> _deleteTask(BuildContext context) async {
    final token = await SessionManager.getToken();
    if (token == null) return;
    final taskId = task["_id"].toString();

    try {
      final response = await http.delete(
        Uri.parse("${ApiConstants.backendUrl}/api/task/$taskId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        _removeLocalTask(context);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Task deleted"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to delete")));
      }
    }
  }

  Future<void> _archiveTask(BuildContext context) async {
    final token = await SessionManager.getToken();
    if (token == null) return;
    final taskId = task["_id"].toString();

    try {
      final response = await http.put(
        Uri.parse("${ApiConstants.backendUrl}/api/task/$taskId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"isArchived": true}),
      );

      if (response.statusCode == 200) {
        _removeLocalTask(context);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Task archived"),
              backgroundColor: Colors.grey,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to archive")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _formatDueDate(task["dueDate"]);
    final isToday = dueText?.startsWith("Today") == true;
    final taskId = task["_id"].toString();

    return Dismissible(
      key: Key(taskId),
      background: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.red,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_forever, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text("Delete", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
      secondaryBackground: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.grey[700],
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.archive, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text("Archive", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Delete Task?"),
              content: const Text("This cannot be undone."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    "Delete",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await _deleteTask(context);
            return true;
          }
          return false;
        } else {
          await _archiveTask(context);
          return true;
        }
      },
      child: Container(
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
            GestureDetector(
              onTap: () => _toggleComplete(context),
              child: Checkbox(
                value: isCompleted,
                onChanged: (_) => _toggleComplete(context),
                shape: const CircleBorder(),
                activeColor: Colors.purple,
              ),
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
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
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
                color: task["priority"] == "high"
                    ? Colors.yellow[600]
                    : Colors.grey[400],
              ),
              onPressed: () => print(
                "Toggle important $taskId",
              ), // You can implement this later
            ),
          ],
        ),
      ),
    );
  }
}
