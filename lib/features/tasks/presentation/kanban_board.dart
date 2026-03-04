// lib/features/tasks/presentation/kanban_board.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'tasks_controller.dart';

class KanbanBoard extends StatefulWidget {
  const KanbanBoard({super.key});

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  // Track which column is being hovered
  String? _hoveredColumn;

  static const columns = [
    {'id': 'todo', 'label': 'To Do', 'icon': Icons.radio_button_unchecked},
    {'id': 'in_progress', 'label': 'In Progress', 'icon': Icons.timelapse_rounded},
    {'id': 'done', 'label': 'Done', 'icon': Icons.check_circle_rounded},
  ];

  static const Map<String, Color> columnColors = {
    'todo': Color(0xFF6366F1),
    'in_progress': Color(0xFFF59E0B),
    'done': Color(0xFF10B981),
  };

  List<Map<String, dynamic>> _getTasksForColumn(
    List<Map<String, dynamic>> tasks,
    String columnId,
    String? currentListId,
  ) {
    return tasks.where((task) {
      if (task['isArchived'] == true) return false;
      // Filter by current list if applicable
      if (currentListId != null) {
        if (task['taskListId']?.toString() != currentListId) return false;
      }

      final status = task['status']?.toString() ?? 'pending';

      if (columnId == 'todo') {
        return status == 'pending' || status == 'todo';
      } else if (columnId == 'in_progress') {
        return status == 'in_progress';
      } else if (columnId == 'done') {
        return status == 'completed' || status == 'done';
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TasksController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? currentListId;
    if (controller.taskLists.isNotEmpty) {
      final currentList = controller.taskLists[controller.selectedListIndex];
      if (currentList['isDefault'] != true) {
        currentListId = currentList['_id']?.toString();
      }
    }

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: columns.map((col) {
        final colId = col['id'] as String;
        final colLabel = col['label'] as String;
        final colIcon = col['icon'] as IconData;
        final colColor = columnColors[colId]!;
        final colTasks = _getTasksForColumn(controller.tasks, colId, currentListId);
        final isHovered = _hoveredColumn == colId;

        return _KanbanColumn(
          colId: colId,
          colLabel: colLabel,
          colIcon: colIcon,
          colColor: colColor,
          tasks: colTasks,
          isHovered: isHovered,
          isDark: isDark,
          onHoverChanged: (hovered) {
            setState(() => _hoveredColumn = hovered ? colId : null);
          },
          onTaskDropped: (task) async {
            final taskId = task['_id']?.toString();
            if (taskId == null) return;

            // Map kanban column to backend status
            String newStatus;
            if (colId == 'todo') {
              newStatus = 'pending';
            } else if (colId == 'in_progress') {
              newStatus = 'in_progress';
            } else {
              newStatus = 'completed';
            }

            await controller.updateTaskStatus(taskId, newStatus);
          },
        );
      }).toList(),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String colId;
  final String colLabel;
  final IconData colIcon;
  final Color colColor;
  final List<Map<String, dynamic>> tasks;
  final bool isHovered;
  final bool isDark;
  final ValueChanged<bool> onHoverChanged;
  final Future<void> Function(Map<String, dynamic>) onTaskDropped;

  const _KanbanColumn({
    required this.colId,
    required this.colLabel,
    required this.colIcon,
    required this.colColor,
    required this.tasks,
    required this.isHovered,
    required this.isDark,
    required this.onHoverChanged,
    required this.onTaskDropped,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF1C1B2E) : const Color(0xFFF4F3FF);
    final hoverBgColor = colColor.withOpacity(isDark ? 0.15 : 0.08);

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) {
        final task = details.data;
        // Prevent dropping on same column
        final currentStatus = task['status']?.toString() ?? 'pending';
        if (colId == 'todo' && (currentStatus == 'pending' || currentStatus == 'todo')) return false;
        if (colId == 'in_progress' && currentStatus == 'in_progress') return false;
        if (colId == 'done' && (currentStatus == 'completed' || currentStatus == 'done')) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        onHoverChanged(false);
        onTaskDropped(details.data);
      },
      onMove: (_) => onHoverChanged(true),
      onLeave: (_) => onHoverChanged(false),
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 260,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: isHovered ? hoverBgColor : bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHovered ? colColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(colIcon, color: colColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      colLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Divider with color accent
              Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),

              // Task cards
              Expanded(
                child: tasks.isEmpty
                    ? _EmptyColumnHint(colColor: colColor, isDark: isDark, isHovered: isHovered)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: tasks.length,
                        itemBuilder: (_, i) => _KanbanTaskCard(
                          task: tasks[i],
                          colColor: colColor,
                          isDark: isDark,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyColumnHint extends StatelessWidget {
  final Color colColor;
  final bool isDark;
  final bool isHovered;

  const _EmptyColumnHint({
    required this.colColor,
    required this.isDark,
    required this.isHovered,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedOpacity(
        opacity: isHovered ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHovered ? Icons.add_circle_outline : Icons.inbox_outlined,
                color: colColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isHovered ? 'Drop here' : 'No tasks',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black38,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanbanTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final Color colColor;
  final bool isDark;

  const _KanbanTaskCard({
    required this.task,
    required this.colColor,
    required this.isDark,
  });

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final date = DateTime.tryParse(dateStr)?.toLocal();
    if (date == null) return '';
    return DateFormat('MMM d').format(date);
  }

  bool _isOverdue(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    final date = DateTime.tryParse(dateStr)?.toLocal();
    if (date == null) return false;
    return date.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final priority = task['priority']?.toString();
    final dueDate = task['dueDate']?.toString();
    final title = task['title']?.toString() ?? 'Untitled';
    final description = task['description']?.toString() ?? '';
    final overdue = _isOverdue(dueDate);
    final priorityColor = _priorityColor(priority);
    final cardBg = isDark ? const Color(0xFF252340) : Colors.white;

    return Draggable<Map<String, dynamic>>(
      data: task,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        shadowColor: colColor.withOpacity(0.4),
        child: SizedBox(
          width: 236,
          child: _buildCard(cardBg, priorityColor, priority, dueDate, overdue, title, description, opacity: 1.0),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCard(cardBg, priorityColor, priority, dueDate, overdue, title, description),
      ),
      child: _buildCard(cardBg, priorityColor, priority, dueDate, overdue, title, description),
    );
  }

  Widget _buildCard(
    Color cardBg,
    Color priorityColor,
    String? priority,
    String? dueDate,
    bool overdue,
    String title,
    String description, {
    double opacity = 1.0,
  }) {
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border(
            left: BorderSide(color: priorityColor, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Description
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 10),

            // Footer row: priority + due date
            Row(
              children: [
                // Priority chip
                if (priority != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      priority[0].toUpperCase() + priority.substring(1),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: priorityColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Due date
                if (dueDate != null && dueDate.isNotEmpty) ...[
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 11,
                    color: overdue ? const Color(0xFFEF4444) : Colors.grey[500],
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatDate(dueDate),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: overdue ? const Color(0xFFEF4444) : Colors.grey[500],
                    ),
                  ),
                ],

                const Spacer(),

                // Drag handle hint
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 14,
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}