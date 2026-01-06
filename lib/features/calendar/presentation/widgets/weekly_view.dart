// lib/features/calendar/presentation/widgets/weekly_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../calendar_controller.dart';
import '../../../tasks/presentation/widgets/task_item.dart';

class WeeklyView extends StatelessWidget {
  const WeeklyView({super.key});

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<CalendarController>(context);
    final DateTime firstDayOfWeek = controller.selectedDate.subtract(
      Duration(days: controller.selectedDate.weekday % 7),
    );
    final List<DateTime> weekDays = List.generate(
      7,
      (i) => firstDayOfWeek.add(Duration(days: i)),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  controller.setSelectedDate(
                    controller.selectedDate.subtract(const Duration(days: 7)),
                  );
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(controller.selectedDate),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  controller.setSelectedDate(
                    controller.selectedDate.add(const Duration(days: 7)),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: weekDays.map((date) {
              final hasTasks = controller.getInstancesForDate(date).isNotEmpty;
              final isSelected = _isSameDay(date, controller.selectedDate);
              return GestureDetector(
                onTap: () => controller.setSelectedDate(date),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 60,
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEE').format(date),
                        style: TextStyle(
                          color: isSelected ? Colors.purple : Colors.grey[600],
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isSelected
                            ? Colors.purple
                            : Colors.transparent,
                        child: Text(
                          date.day.toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (hasTasks)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: Colors.purple,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Tasks for ${DateFormat('EEEE, MMM d').format(controller.selectedDate)}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: controller
                .getInstancesForDate(controller.selectedDate)
                .map((task) {
                  return TaskItem(
                    task: task,
                    isCompleted: task["status"] == "completed",
                  );
                })
                .toList(),
          ),
        ),
      ],
    );
  }
}
