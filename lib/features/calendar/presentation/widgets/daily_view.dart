// lib/features/calendar/presentation/widgets/daily_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../calendar_controller.dart';
import 'calendar_task_tile.dart';

class DailyView extends StatelessWidget {
  const DailyView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<CalendarController>(context);
    final overdue = controller.getOverdueInstances();
    final todayTasks = controller.getInstancesForDate(controller.selectedDate);
    final tomorrow = controller.selectedDate.add(const Duration(days: 1));
    final tomorrowTasks = controller.getInstancesForDate(tomorrow);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (overdue.isNotEmpty) ...[
          const Text(
            "OVERDUE",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...overdue.map((t) => CalendarTaskTile(task: t)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          "Today — ${DateFormat('EEEE, MMM d').format(controller.selectedDate)}",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...todayTasks.map((t) => CalendarTaskTile(task: t)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.withOpacity(0.35),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Tomorrow — ${DateFormat('EEEE, MMM d').format(tomorrow)}",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...tomorrowTasks.map((t) => CalendarTaskTile(task: t)),
        const SizedBox(height: 100),
      ],
    );
  }
}
