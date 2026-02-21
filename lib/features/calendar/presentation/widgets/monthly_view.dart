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
    final media = MediaQuery.of(context);
    final isSmallScreen = media.size.width < 360;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final DateTime focusedMonth = DateTime(
      controller.selectedDate.year,
      controller.selectedDate.month,
      1,
    );

    final int daysInMonth = _daysInMonth(focusedMonth.year, focusedMonth.month);

    final int startWeekday =
        DateTime(focusedMonth.year, focusedMonth.month, 1).weekday % 7;

    final List<Widget> dayCells = [];

    // Empty slots before first day
    for (int i = 0; i < startWeekday; i++) {
      dayCells.add(const SizedBox.shrink());
    }

    // Days
    for (int day = 1; day <= daysInMonth; day++) {
      final DateTime thisDate = DateTime(
        focusedMonth.year,
        focusedMonth.month,
        day,
      );

      final bool isSelected = _isSameDay(thisDate, controller.selectedDate);
      final bool hasTasks = controller.getInstancesForDate(thisDate).isNotEmpty;

      dayCells.add(
        GestureDetector(
          onTap: () => controller.setSelectedDate(thisDate),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSmallScreen ? 32 : 36,
                  height: isSmallScreen ? 32 : 36,
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
                    day.toString(),
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      fontWeight: FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),

                // Task dot (overlay — no vertical expansion)
                if (hasTasks)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.purple,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -100) {
              // swipe left → next month
              controller.setSelectedDate(
                DateTime(
                  controller.selectedDate.year,
                  controller.selectedDate.month + 1,
                  1,
                ),
              );
            } else if (velocity > 100) {
              // swipe right → previous month
              controller.setSelectedDate(
                DateTime(
                  controller.selectedDate.year,
                  controller.selectedDate.month - 1,
                  1,
                ),
              );
            }
          },
          child: Column(
            children: [
              // ───── Month Header ─────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        controller.setSelectedDate(
                          DateTime(
                            controller.selectedDate.year,
                            controller.selectedDate.month - 1,
                            1,
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          DateFormat('MMMM yyyy').format(focusedMonth),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        controller.setSelectedDate(
                          DateTime(
                            controller.selectedDate.year,
                            controller.selectedDate.month + 1,
                            1,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ───── Weekday Row ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children:
                      const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                          .map(
                            (day) => Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),

              const SizedBox(height: 6),

              // ───── Calendar Grid (NO FIXED HEIGHT) ─────
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isSmallScreen ? 1.25 : 1.15,
                children: dayCells,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.35)),
        ),
        const SizedBox(height: 4),

        // ───── Selected Day Header ─────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            "Tasks on ${DateFormat('EEEE, MMM d').format(controller.selectedDate)}",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),

        // ───── Task List ─────
        Expanded(
          child: controller.getInstancesForDate(controller.selectedDate).isEmpty
              ? const Center(
                  child: Text(
                    "No tasks for this day",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: controller
                      .getInstancesForDate(controller.selectedDate)
                      .length,
                  itemBuilder: (context, index) {
                    final task = controller.getInstancesForDate(
                      controller.selectedDate,
                    )[index];
                    return TaskItem(
                      task: task,
                      isCompleted: task["status"] == "completed",
                    );
                  },
                ),
        ),
      ],
    );
  }
}
