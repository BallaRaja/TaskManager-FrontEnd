// lib/features/tasks/presentation/summary_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'tasks_controller.dart';

class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TasksController()..init(),
      child: const _SummaryView(),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TasksController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF12111F)
          : const Color(0xFFF4F4FB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1B2E) : Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Summary',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : _buildBody(context, controller, isDark),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TasksController controller,
    bool isDark,
  ) {
    final tasks = controller.tasks;
    final taskLists = controller.taskLists;

    final totalTasks = tasks.length;
    final completedTasks = tasks
        .where((t) => t['status'] == 'completed')
        .length;
    final pendingTasks = tasks.where((t) => t['status'] != 'completed').length;
    final starredTasks = tasks.where((t) => t['isStarred'] == true).length;
    final archivedTasks = tasks.where((t) => t['isArchived'] == true).length;
    final totalLists = taskLists.length;

    final completionRate = totalTasks > 0
        ? (completedTasks / totalTasks * 100).toStringAsFixed(1)
        : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Completion card ──
          _CompletionCard(
            completed: completedTasks,
            total: totalTasks,
            rate: completionRate,
            isDark: isDark,
          ),
          const SizedBox(height: 20),

          // ── Section heading ──
          _sectionHeading('Overview'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.task_alt_rounded,
                  label: 'Total Tasks',
                  value: '$totalTasks',
                  color: Colors.purple,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Completed',
                  value: '$completedTasks',
                  color: Colors.green,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.pending_actions_rounded,
                  label: 'Pending',
                  value: '$pendingTasks',
                  color: Colors.orange,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.star_rounded,
                  label: 'Starred',
                  value: '$starredTasks',
                  color: Colors.amber,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'Archived',
                  value: '$archivedTasks',
                  color: Colors.blueGrey,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.list_alt_rounded,
                  label: 'My Lists',
                  value: '$totalLists',
                  color: Colors.indigo,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Lists breakdown ──
          if (taskLists.isNotEmpty) ...[
            _sectionHeading('Lists Breakdown'),
            const SizedBox(height: 12),
            ...taskLists.map((list) {
              final String listId = list['_id']?.toString() ?? '';
              final String title = list['title']?.toString() ?? 'Untitled';
              final bool isDefault = list['isDefault'] == true;
              final int count = controller.tasks
                  .where(
                    (t) =>
                        t['taskListId']?.toString() == listId &&
                        t['status'] != 'completed',
                  )
                  .length;
              final int doneCount = controller.tasks
                  .where(
                    (t) =>
                        t['taskListId']?.toString() == listId &&
                        t['status'] == 'completed',
                  )
                  .length;

              return _ListBreakdownTile(
                title: title,
                isDefault: isDefault,
                pending: count,
                completed: doneCount,
                isDark: isDark,
              );
            }),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeading(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Completion progress card ──────────────────────────────────────────────────
class _CompletionCard extends StatelessWidget {
  final int completed;
  final int total;
  final String rate;
  final bool isDark;

  const _CompletionCard({
    required this.completed,
    required this.total,
    required this.rate,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B2FF7), Color(0xFF5E35B1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Completion Rate',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$rate%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$completed of $total tasks completed',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              color: Colors.white,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── List Breakdown Tile ───────────────────────────────────────────────────────
class _ListBreakdownTile extends StatelessWidget {
  final String title;
  final bool isDefault;
  final int pending;
  final int completed;
  final bool isDark;

  const _ListBreakdownTile({
    required this.title,
    required this.isDefault,
    required this.pending,
    required this.completed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total = pending + completed;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDefault ? Icons.inbox_rounded : Icons.list_alt_rounded,
                color: Colors.purple,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$completed/$total',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.withOpacity(0.15),
              color: Colors.purple,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _pill('$pending pending', Colors.orange),
              const SizedBox(width: 8),
              _pill('$completed done', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
