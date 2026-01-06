// lib/features/tasks/presentation/tasks_page.dart
import 'package:client/features/tasks/presentation/widgets/add_task_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../profile/presentation/profile_sheet.dart';
import 'tasks_controller.dart';
import 'task_view_type.dart';
import 'widgets/task_list_tab.dart';
import 'widgets/task_item.dart';
import 'widgets/completed_section.dart';

class TasksPage extends StatefulWidget {
  final TaskViewType initialViewType;

  const TasksPage({super.key, this.initialViewType = TaskViewType.normal});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late TaskViewType _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = widget.initialViewType;
  }

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
    final titleController = TextEditingController();
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

  void _showViewMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Views",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: const Text("Starred"),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _viewType = TaskViewType.starred;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text("Archived"),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _viewType = TaskViewType.archived;
                });
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text("Close"),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 20),
          ],
        ),
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

          // === FILTERING LOGIC ===
          List<Map<String, dynamic>> displayedTasks = controller.tasks;
          if (_viewType == TaskViewType.normal) {
            if (controller.taskLists.isEmpty) {
              displayedTasks = controller.tasks;
            } else {
              final currentList =
                  controller.taskLists[controller.selectedListIndex];
              if (currentList["isDefault"] == true) {
                displayedTasks = controller.tasks;
              } else {
                final String currentListId = currentList["_id"] as String;
                displayedTasks = controller.tasks
                    .where(
                      (task) => task["taskListId"]?.toString() == currentListId,
                    )
                    .toList();
              }
            }
          } else if (_viewType == TaskViewType.starred) {
            displayedTasks = controller.tasks
                .where((task) => task["priority"] == "high")
                .toList();
          } else if (_viewType == TaskViewType.archived) {
            displayedTasks = controller.tasks
                .where((task) => task["isArchived"] == true)
                .toList();
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
                leading: _viewType == TaskViewType.normal
                    ? IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => _showViewMenu(context),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          setState(() {
                            _viewType = TaskViewType.normal;
                          });
                        },
                      ),
                title: Text(
                  _viewType == TaskViewType.starred
                      ? "Starred"
                      : _viewType == TaskViewType.archived
                      ? "Archived"
                      : "Tasks",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                centerTitle: true,
                actions: [
                  // Profile Avatar Button (Top Right)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: GestureDetector(
                      onTap: () => _showProfileSheet(context),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: controller.avatarUrl != null
                            ? NetworkImage(controller.avatarUrl!)
                            : null,
                        child: controller.isLoadingAvatar
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : controller.avatarUrl == null
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                    ),
                  ),
                ],
                bottom: _viewType == TaskViewType.normal
                    ? PreferredSize(
                        preferredSize: const Size.fromHeight(50),
                        child: _buildTabBar(context, controller),
                      )
                    : null,
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
            floatingActionButton: _viewType == TaskViewType.normal
                ? FloatingActionButton(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.purple,
                    onPressed: () => showAddTaskSheet(context),
                    child: const Icon(Icons.add, color: Colors.white, size: 32),
                  )
                : null,
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
              onTap: () => controller.selectList(e.key),
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
