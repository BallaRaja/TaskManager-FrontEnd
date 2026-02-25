// lib/features/tasks/presentation/tasks_page.dart
import 'dart:async';
import 'package:client/features/tasks/presentation/widgets/add_task_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../profile/presentation/profile_sheet.dart';
import '../../auth/presentation/login_page.dart';
import '../../../core/utils/session_manager.dart';
import 'summary_page.dart';
import 'tasks_controller.dart';
import 'task_view_type.dart';
import 'widgets/task_list_tab.dart';
import 'widgets/task_item.dart';
import 'widgets/completed_section.dart';

class TasksPage extends StatefulWidget {
  final TaskViewType initialViewType;
  final ValueChanged<bool>? onThemeChanged;

  const TasksPage({
    super.key,
    this.initialViewType = TaskViewType.normal,
    this.onThemeChanged,
  });

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late TaskViewType _viewType;
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _viewType = widget.initialViewType;

    // 🔄 Update time every minute
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String get _formattedTime {
    return DateFormat('hh:mm a').format(_now);
  }

  void _showProfileSheet(BuildContext context) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) =>
          ProfileSheet(onThemeChanged: widget.onThemeChanged),
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

    // Refresh avatar after profile sheet closes
    if (context.mounted) {
      final controller = Provider.of<TasksController>(context, listen: false);
      await controller.refreshAvatar();
    }
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

  // ─────────────────────────────────────────────────────────
  //  List options (long-press on a tab)
  // ─────────────────────────────────────────────────────────

  void _showListOptions(
    BuildContext context,
    TasksController controller,
    int index,
    Map<String, dynamic> listData,
  ) {
    if (listData['isDefault'] == true) return; // My Tasks ─ no options

    final String listId = listData['_id'].toString();
    final String listTitle = listData['title']?.toString() ?? 'Untitled';
    final int taskCount = controller.tasks
        .where((t) => t['taskListId']?.toString() == listId)
        .length;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // List info chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.list_alt_rounded,
                      color: Colors.purple,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$taskCount task${taskCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEDE7F6),
                child: Icon(Icons.edit_outlined, color: Colors.purple),
              ),
              title: const Text(
                'Rename List',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, controller, listId, listTitle);
              },
            ),
            const SizedBox(height: 4),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: CircleAvatar(
                backgroundColor: Colors.red.shade50,
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: const Text(
                'Delete List',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
              subtitle: Text(
                '$taskCount task${taskCount == 1 ? '' : 's'} will also be deleted',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog(
                  context,
                  controller,
                  listId,
                  listTitle,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    TasksController controller,
    String listId,
    String currentTitle,
  ) {
    final renamer = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename List'),
        content: TextField(
          controller: renamer,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'List name',
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () async {
              Navigator.pop(ctx);
              await controller.renameTaskList(listId, renamer.text);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    TasksController controller,
    String listId,
    String listTitle,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete List?'),
          ],
        ),
        content: Text(
          '"$listTitle" and all its tasks will be permanently deleted.\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await controller.deleteTaskList(listId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openSidePanel(BuildContext context, TasksController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelWidth = MediaQuery.of(context).size.width * 0.78;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.48),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, __) => Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: isDark ? const Color(0xFF1C1B2E) : Colors.white,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.purple,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Task Manager',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // ── VIEWS section ──
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'VIEWS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  _panelTile(
                    ctx,
                    Icons.star_rounded,
                    'Starred',
                    () {
                      Navigator.pop(ctx);
                      setState(() => _viewType = TaskViewType.starred);
                    },
                    _viewType == TaskViewType.starred,
                  ),
                  _panelTile(
                    ctx,
                    Icons.inventory_2_outlined,
                    'Archived',
                    () {
                      Navigator.pop(ctx);
                      setState(() => _viewType = TaskViewType.archived);
                    },
                    _viewType == TaskViewType.archived,
                  ),
                  _panelTile(ctx, Icons.person_outline_rounded, 'Profile', () {
                    Navigator.pop(ctx);
                    _showProfileSheet(context);
                  }, false),
                  _panelTile(ctx, Icons.bar_chart_rounded, 'Summary', () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SummaryPage()),
                    );
                  }, false),
                  // ── MY LISTS + Logout section ──
                  ..._buildSidePanelLists(ctx, controller),
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  /// Builds the MY LISTS section widgets for the side panel.
  List<Widget> _buildSidePanelLists(
    BuildContext ctx,
    TasksController controller,
  ) {
    return [
      const SizedBox(height: 16),
      const Divider(height: 1),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'MY LISTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.sort_rounded,
                size: 20,
                color: Colors.grey,
              ),
              tooltip: 'Sort lists',
              onPressed: () => _showListSortSheet(ctx, controller),
            ),
          ],
        ),
      ),
      Expanded(
        child: ClipRect(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  clipBehavior: Clip.hardEdge,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: controller.taskLists.length,
                  itemBuilder: (_, i) {
                    final list = controller.taskLists[i];
                    final String listTitle =
                        list['title']?.toString() ?? 'Untitled';
                    final String listId = list['_id']?.toString() ?? '';
                    final int taskCount = controller.tasks
                        .where(
                          (t) =>
                              t['taskListId']?.toString() == listId &&
                              t['status'] != 'completed',
                        )
                        .length;
                    final bool isDefault = list['isDefault'] == true;
                    final bool isSelected =
                        _viewType == TaskViewType.normal &&
                        i == controller.selectedListIndex;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: ListTile(
                        leading: Icon(
                          isDefault
                              ? Icons.inbox_rounded
                              : Icons.list_alt_rounded,
                          color: isSelected ? Colors.purple : Colors.grey[600],
                          size: 22,
                        ),
                        title: Text(
                          listTitle,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected ? Colors.purple : null,
                          ),
                        ),
                        trailing: taskCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.purple
                                      : Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$taskCount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[700],
                                  ),
                                ),
                              )
                            : null,
                        tileColor: isSelected
                            ? Colors.purple.withOpacity(0.08)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _viewType = TaskViewType.normal;
                          });
                          controller.selectList(i);
                        },
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await SessionManager.clearSession();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LoginPage(onThemeChanged: widget.onThemeChanged),
                      ),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ];
  }

  // ── Sort Lists bottom sheet ────────────────────────────────────────

  void _showListSortSheet(BuildContext panelCtx, TasksController controller) {
    showModalBottomSheet(
      context: panelCtx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(panelCtx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sort My Lists',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _sortOptionTile(
                    sheetCtx,
                    icon: Icons.drag_indicator_rounded,
                    label: 'Custom Order',
                    sub: 'Drag lists into any order',
                    mode: TaskListSortMode.custom,
                    current: controller.listSortMode,
                    onSelect: () async {
                      await controller.setListSortMode(TaskListSortMode.custom);
                      setSheetState(() {});
                    },
                  ),
                  _sortOptionTile(
                    sheetCtx,
                    icon: Icons.sort_by_alpha_rounded,
                    label: 'A → Z',
                    sub: 'Alphabetical ascending',
                    mode: TaskListSortMode.az,
                    current: controller.listSortMode,
                    onSelect: () async {
                      await controller.setListSortMode(TaskListSortMode.az);
                      setSheetState(() {});
                    },
                  ),
                  _sortOptionTile(
                    sheetCtx,
                    icon: Icons.sort_by_alpha_rounded,
                    label: 'Z → A',
                    sub: 'Alphabetical descending',
                    mode: TaskListSortMode.za,
                    current: controller.listSortMode,
                    onSelect: () async {
                      await controller.setListSortMode(TaskListSortMode.za);
                      setSheetState(() {});
                    },
                  ),
                  if (controller.listSortMode == TaskListSortMode.custom) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 4),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEDE7F6),
                        child: Icon(
                          Icons.reorder_rounded,
                          color: Colors.purple,
                        ),
                      ),
                      title: const Text(
                        'Reorder Lists',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Drag to rearrange your lists'),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.purple,
                      ),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _showReorderListsSheet(panelCtx, controller);
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sortOptionTile(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required String sub,
    required TaskListSortMode mode,
    required TaskListSortMode current,
    required VoidCallback onSelect,
  }) {
    final bool isActive = current == mode;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: isActive ? Colors.purple : Colors.grey[600]),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          color: isActive ? Colors.purple : null,
        ),
      ),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      tileColor: isActive ? Colors.purple.withOpacity(0.07) : null,
      trailing: isActive
          ? const Icon(Icons.check_circle_rounded, color: Colors.purple)
          : null,
      onTap: onSelect,
    );
  }

  // ── Drag-reorder lists sheet ────────────────────────────────────

  void _showReorderListsSheet(
    BuildContext panelCtx,
    TasksController controller,
  ) {
    showModalBottomSheet(
      context: panelCtx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (sheetCtx, scrollCtrl) {
          // Non-default lists only
          final nonDefault = controller.taskLists
              .where((l) => l['isDefault'] != true)
              .toList();

          return StatefulBuilder(
            builder: (sheetCtx, setSheetState) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(panelCtx).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle + header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.reorder_rounded,
                                color: Colors.purple,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Reorder Lists',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(sheetCtx),
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Long-press and drag to reorder',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Reorderable list
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollController: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: nonDefault.length,
                        itemBuilder: (_, i) {
                          final list = nonDefault[i];
                          final title = list['title']?.toString() ?? 'Untitled';
                          return ListTile(
                            key: ValueKey(list['_id']),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: const Icon(
                              Icons.list_alt_rounded,
                              color: Colors.purple,
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.drag_handle_rounded,
                              color: Colors.grey,
                            ),
                          );
                        },
                        onReorder: (oldIdx, newIdx) async {
                          if (newIdx > oldIdx) newIdx--;
                          await controller.reorderLists(oldIdx, newIdx);
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _panelTile(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap,
    bool isActive,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.purple : Colors.grey[600],
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.purple : null,
          ),
        ),
        tileColor: isActive ? Colors.purple.withOpacity(0.08) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        onTap: onTap,
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
          Map<String, dynamic>? activeList; // non-null only for custom lists
          String? currentListId;

          if (_viewType == TaskViewType.normal) {
            if (controller.taskLists.isNotEmpty) {
              final currentList =
                  controller.taskLists[controller.selectedListIndex];
              currentListId = currentList['_id']?.toString();
              if (currentList["isDefault"] != true) {
                activeList = currentList;
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

          // Apply custom task order when in normal view with a known list
          final orderedPending =
              (_viewType == TaskViewType.normal && currentListId != null)
              ? controller.getOrderedPendingTasks(currentListId, pending)
              : pending;

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
                        onPressed: () => _openSidePanel(context, controller),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          setState(() {
                            _viewType = TaskViewType.normal;
                          });
                        },
                      ),

                // 🧠 CUSTOM TITLE ROW (Title + Time)
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
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
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formattedTime,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
                centerTitle: true,

                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: GestureDetector(
                      onTap: () => _showProfileSheet(context),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            controller.avatarUrl != null &&
                                !controller.avatarUrl!.contains('placeholder')
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
                            : (controller.avatarUrl == null ||
                                  controller.avatarUrl!.contains('placeholder'))
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
                  if (activeList != null)
                    _buildListHeader(
                      context,
                      activeList,
                      orderedPending.length,
                      completed.length,
                    ),
                  // Reorderable pending tasks (long-press to drag)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) => Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(16),
                      shadowColor: Colors.purple.withOpacity(0.25),
                      child: child,
                    ),
                    itemCount: orderedPending.length,
                    itemBuilder: (_, i) {
                      final task = orderedPending[i];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(task['_id']),
                        index: i,
                        child: TaskItem(task: task, isCompleted: false),
                      );
                    },
                    onReorder: (oldIdx, newIdx) {
                      if (newIdx > oldIdx) newIdx--;
                      if (currentListId != null) {
                        controller.reorderTasks(
                          currentListId,
                          oldIdx,
                          newIdx,
                          orderedPending,
                        );
                      }
                    },
                  ),
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

  // ─────────────────────────────────────────────────────────
  //  List name header (shown at the top of the task list for custom lists)
  // ─────────────────────────────────────────────────────────

  Widget _buildListHeader(
    BuildContext context,
    Map<String, dynamic> list,
    int pendingCount,
    int completedCount,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple.shade500, Colors.purple.shade800],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list['title']?.toString() ?? 'Untitled',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _listStatChip(
                      '$pendingCount pending',
                      Colors.white.withOpacity(0.25),
                    ),
                    _listStatChip(
                      '$completedCount done',
                      Colors.white.withOpacity(0.15),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.checklist_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listStatChip(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
              onLongPress: () =>
                  _showListOptions(context, controller, e.key, e.value),
              child: TaskListTab(
                title: e.value["title"] ?? "Untitled",
                isActive: e.key == controller.selectedListIndex,
              ),
            );
          }),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () => _showCreateListDialog(context, controller),
            child: const TaskListTab(title: "+ New List", isAddButton: true),
          ),
        ],
      ),
    );
  }
}
