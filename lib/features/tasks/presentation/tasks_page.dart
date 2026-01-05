// lib/features/tasks/presentation/tasks_page.dart
import 'package:client/features/tasks/presentation/widgets/add_task_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../profile/presentation/profile_sheet.dart';
import 'tasks_controller.dart';
import 'widgets/task_list_tab.dart';
import 'widgets/task_item.dart';
import 'widgets/completed_section.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  void _showProfileSheet(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const ProfileSheet(),
      transitionBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  void _showCreateListDialog(BuildContext context, TasksController controller) {
    final TextEditingController titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New List"),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter list name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(ctx);
                await controller.createTaskList(title);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TasksController()..init(),
      child: Consumer<TasksController>(
        builder: (context, controller, _) {
          if (controller.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final currentList = controller.taskLists.isNotEmpty
              ? controller.taskLists[controller.selectedListIndex]
              : null;

          List<Map<String, dynamic>> displayedTasks;

          if (controller.taskLists.isEmpty) {
            displayedTasks = controller.tasks;
          } else if (currentList?["isDefault"] == true) {
            displayedTasks = controller.tasks;
          } else {
            final String currentListId = currentList?["_id"] as String;
            displayedTasks = controller.tasks
                .where(
                  (task) => task["taskListId"]?.toString() == currentListId,
                )
                .toList();
          }

          /// 🔍 DEBUG PRINTS (CURRENT LIST + TASKS)
          if (currentList != null) {
            debugPrint("🔁 Switched to Task List");
            debugPrint("📌 Index: ${controller.selectedListIndex}");
            debugPrint("📂 Title: ${currentList["title"]}");
            debugPrint("🆔 List ID: ${currentList["_id"]}");
            debugPrint("⭐ Is Default: ${currentList["isDefault"]}");
            debugPrint("📊 Total tasks in this list: ${displayedTasks.length}");
            debugPrint("📝 Tasks:");

            for (final task in displayedTasks) {
              debugPrint(
                "  • Task ID: ${task["_id"]} | "
                "Title: ${task["title"]} | "
                "Status: ${task["status"]} | "
                "taskListId: ${task["taskListId"]}",
              );
            }
            debugPrint("────────────────────────────");
          }

          final pending = displayedTasks
              .where((t) => t["status"] == "pending")
              .toList();
          final completed = displayedTasks
              .where((t) => t["status"] == "completed")
              .toList();

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(100),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {},
                ),
                title: const Text(
                  "Tasks",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                centerTitle: true,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => _showProfileSheet(context),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            controller.avatarUrl?.isNotEmpty == true
                            ? NetworkImage(controller.avatarUrl!)
                            : null,
                        child: controller.isLoadingAvatar
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : controller.avatarUrl?.isNotEmpty == true
                            ? null
                            : const Icon(Icons.person),
                      ),
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(50),
                  child: _buildTabBar(context, controller),
                ),
              ),
            ),
            body: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  ...pending.map((t) => TaskItem(task: t, isCompleted: false)),
                  const SizedBox(height: 32),
                  CompletedSection(completedTasks: completed),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              shape: const CircleBorder(),
              backgroundColor: Colors.purple,
              onPressed: () => showAddTaskSheet(context),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, TasksController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ...controller.taskLists.asMap().entries.map((e) {
            return GestureDetector(
              onTap: () {
                controller.selectList(e.key);
                debugPrint("➡️ User tapped list index ${e.key}");
              },
              child: TaskListTab(
                title: e.value["title"] ?? "Untitled",
                isActive: e.key == controller.selectedListIndex,
              ),
            );
          }),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () => _showCreateListDialog(context, controller),
            child: const TaskListTab(title: "Add new list", isAddButton: true),
          ),
        ],
      ),
    );
  }
}
