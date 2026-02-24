// lib/features/tasks/presentation/widgets/task_item.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/session_manager.dart';
import '../tasks_controller.dart';
import 'edit_task_sheet.dart';

class TaskItem extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isCompleted;

  const TaskItem({super.key, required this.task, required this.isCompleted});

  String? _formatDueDate(String? iso) {
    if (iso == null) return null;
    // Convert UTC from backend → device local time for display
    final date = DateTime.parse(iso).toLocal();
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

  void _updateLocalTask(
    BuildContext context,
    Map<String, dynamic> updatedTask,
  ) {
    final controller = Provider.of<TasksController>(context, listen: false);
    controller.upsertTaskLocal(updatedTask);
  }

  void _removeLocalTask(BuildContext context) {
    final controller = Provider.of<TasksController>(context, listen: false);
    controller.removeTaskLocal(task["_id"].toString());
  }

  Future<void> _toggleComplete(BuildContext context) async {
    final token = await SessionManager.getToken();
    if (token == null) return;
    final newStatus = isCompleted ? "pending" : "completed";
    final taskId = task["_id"].toString();

    // Optimistic update — immediately reflect the change in UI
    final optimisticTask = Map<String, dynamic>.from(task);
    optimisticTask["status"] = newStatus;
    if (!isCompleted) {
      optimisticTask["completedAt"] = DateTime.now().toIso8601String();
    } else {
      optimisticTask["completedAt"] = null;
    }
    if (context.mounted) _updateLocalTask(context, optimisticTask);

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
        if (context.mounted) _updateLocalTask(context, updatedTask);
      } else {
        // Revert optimistic update on server error
        if (context.mounted) _updateLocalTask(context, task);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update task")),
          );
        }
      }
    } catch (e) {
      // Revert optimistic update on network error
      if (context.mounted) _updateLocalTask(context, task);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to update task")));
      }
    }
  }

  // NEW: Toggle Important / Star
  Future<void> _toggleImportant(BuildContext context) async {
    final token = await SessionManager.getToken();
    if (token == null) return;
    final taskId = task["_id"].toString();
    final bool currentlyImportant = task["priority"] == "high";
    final String newPriority = currentlyImportant ? "medium" : "high";
    // Optimistic UI update
    final optimisticTask = Map<String, dynamic>.from(task);
    optimisticTask["priority"] = newPriority;
    _updateLocalTask(context, optimisticTask);
    try {
      final response = await http.put(
        Uri.parse("${ApiConstants.backendUrl}/api/task/$taskId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"priority": newPriority}),
      );
      if (response.statusCode == 200) {
        final updatedTask = jsonDecode(response.body)["data"];
        _updateLocalTask(context, updatedTask);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentlyImportant
                    ? "Removed from Starred"
                    : "Added to Starred",
              ),
              backgroundColor: currentlyImportant ? Colors.grey : Colors.amber,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        // Revert on failure
        _updateLocalTask(context, task);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update priority")),
          );
        }
      }
    } catch (e) {
      // Revert on error
      _updateLocalTask(context, task);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Network error")));
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

  Future<void> _unarchiveTask(BuildContext context) async {
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
        body: jsonEncode({"isArchived": false}),
      );
      if (response.statusCode == 200) {
        _removeLocalTask(context);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Task unarchived"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to unarchive")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _formatDueDate(task["dueDate"]);
    final isToday = dueText?.startsWith("Today") == true;
    final bool isArchived = task["isArchived"] == true;
    final bool isImportant = task["priority"] == "high";
    return Dismissible(
      key: Key(task["_id"].toString()),
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
          color: isArchived ? Colors.green : Colors.grey[700],
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isArchived ? Icons.unarchive : Icons.archive,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(height: 4),
              Text(
                isArchived ? "Unarchive" : "Archive",
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      confirmDismiss: (direction) async {
        if (isArchived) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Unarchive Task?"),
              content: const Text(
                "This task will return to your active lists.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    "Unarchive",
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await _unarchiveTask(context);
            return true;
          }
          return false;
        }
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
      child: GestureDetector(
        onTap: isArchived ? null : () => showEditTaskSheet(context, task),
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
                onTap: isArchived ? null : () => _toggleComplete(context),
                child: Transform.scale(
                  scale: 1.25,
                  child: Checkbox(
                    value: isCompleted,
                    onChanged: isArchived
                        ? null
                        : (_) => _toggleComplete(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    activeColor: Colors.purple,
                    side: BorderSide(
                      color: isCompleted ? Colors.purple : Colors.grey.shade400,
                      width: 1.8,
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
              // STAR / IMPORTANT BUTTON
              IconButton(
                icon: Icon(
                  isImportant ? Icons.star : Icons.star_border,
                  color: isImportant ? Colors.amber : Colors.grey[400],
                  size: 28,
                ),
                onPressed: isArchived ? null : () => _toggleImportant(context),
                tooltip: isImportant
                    ? "Remove from Starred"
                    : "Mark as Important",
              ),
            ],
          ),
        ), // end Container
      ), // end GestureDetector
    );
  }
}
