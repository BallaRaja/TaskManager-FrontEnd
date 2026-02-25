// lib/features/calendar/presentation/widgets/weekly_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../calendar_controller.dart';
import 'calendar_task_tile.dart';

class WeeklyView extends StatelessWidget {
  const WeeklyView({super.key});

  static const List<String> _weekLabels = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<CalendarController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: _weekLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -100) {
              controller.setSelectedDate(
                controller.selectedDate.add(const Duration(days: 7)),
              );
            } else if (velocity > 100) {
              controller.setSelectedDate(
                controller.selectedDate.subtract(const Duration(days: 7)),
              );
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) {
              final direction = controller.navigationDirection;
              final slideIn =
                  Tween<Offset>(
                    begin: Offset(direction.toDouble(), 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );
              return ClipRect(
                child: SlideTransition(
                  position: slideIn,
                  child: FadeTransition(opacity: animation, child: child),
                ),
              );
            },
            child: Padding(
              key: ValueKey(firstDayOfWeek),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: weekDays.map((date) {
                  final hasTasks = controller
                      .getInstancesForDate(date)
                      .isNotEmpty;
                  final isSelected = _isSameDay(date, controller.selectedDate);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => controller.setSelectedDate(date),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.purple
                                  : (isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.grey.withOpacity(0.12)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              date.day.toString(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white : Colors.black87),
                                fontWeight: FontWeight.normal,
                                fontSize: 13,
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
                            )
                          else
                            const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.withOpacity(0.35),
          ),
        ),
        const SizedBox(height: 16),
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
                  return CalendarTaskTile(task: task);
                })
                .toList(),
          ),
        ),
      ],
    );
  }
}
