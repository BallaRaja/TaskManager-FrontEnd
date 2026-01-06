// lib/features/calendar/presentation/widgets/monthly_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../calendar_controller.dart';
import '../../../tasks/presentation/widgets/task_item.dart';

class MonthlyView extends StatelessWidget {
  const MonthlyView({super.key});

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<CalendarController>(context);
    final DateTime focusedMonth = DateTime(
      controller.selectedDate.year,
      controller.selectedDate.month,
      1,
    );
    final int daysInMonth = _daysInMonth(focusedMonth.year, focusedMonth.month);
    final DateTime firstDayOfMonth = focusedMonth;
    final int startWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday

    final List<Widget> dayCells = [];

    // Empty cells before month starts
    for (int i = 0; i < startWeekday; i++) {
      dayCells.add(const SizedBox.shrink());
    }

    // Actual days
    for (int day = 1; day <= daysInMonth; day++) {
      final DateTime thisDate = DateTime(
        focusedMonth.year,
        focusedMonth.month,
        day,
      );
      final bool hasTasks = controller.getInstancesForDate(thisDate).isNotEmpty;
      final bool isSelected = _isSameDay(thisDate, controller.selectedDate);

      dayCells.add(
        GestureDetector(
          onTap: () => controller.setSelectedDate(thisDate),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.purple : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              if (hasTasks)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.circle, size: 6, color: Colors.purple),
                ),
            ],
          ),
        ),
      );
    }

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
                  final newMonth = DateTime(
                    controller.selectedDate.year,
                    controller.selectedDate.month - 1,
                  );
                  controller.setSelectedDate(newMonth);
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(focusedMonth),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final newMonth = DateTime(
                    controller.selectedDate.year,
                    controller.selectedDate.month + 1,
                  );
                  controller.setSelectedDate(newMonth);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Weekday headers
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.2,
          children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
              .map(
                (day) => Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        // Calendar grid
        Expanded(
          flex: 2,
          child: GridView.count(
            crossAxisCount: 7,
            physics: const NeverScrollableScrollPhysics(),
            children: dayCells,
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "Tasks on ${DateFormat('EEEE, MMM d').format(controller.selectedDate)}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: controller
                .getInstancesForDate(controller.selectedDate)
                .map(
                  (task) => TaskItem(
                    task: task,
                    isCompleted: task["status"] == "completed",
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
