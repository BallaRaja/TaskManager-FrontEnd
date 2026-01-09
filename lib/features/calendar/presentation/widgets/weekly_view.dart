// lib/features/calendar/presentation/widgets/weekly_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../calendar_controller.dart';
// import your TaskItem if you still want to use parts of it, otherwise we'll create inline cards

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
        // Month header + navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

        // Horizontal weekday selector
        SizedBox(
          height: 90,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: weekDays.map((date) {
                final hasTasks = controller
                    .getInstancesForDate(date)
                    .isNotEmpty;
                final isSelected = _isSameDay(date, controller.selectedDate);

                return GestureDetector(
                  onTap: () => controller.setSelectedDate(date),
                  child: Container(
                    width: 68,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE').format(date).toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected
                                ? Colors.purple
                                : Colors.grey[700],
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.purple
                                : Colors.transparent,
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1.5,
                                  ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (hasTasks)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.purple,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const Divider(height: 1, thickness: 1),

        // Main schedule area - time slots + tasks
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time labels column (fixed)
                SizedBox(
                  width: 56,
                  child: Column(
                    children: List.generate(12, (index) {
                      final hour = 8 + index;
                      return SizedBox(
                        height:
                            80, // ← height per hour slot - adjust to your taste
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Text(
                            '$hour${hour < 12 ? 'AM' : 'PM'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Tasks area - scrollable horizontally
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width:
                          420, // ≈ 60 * 7 — adjust according to desired day width
                      child: Stack(
                        children: [
                          // Grid lines / background slots
                          Column(
                            children: List.generate(12, (index) {
                              return Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[200]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),

                          // Actual task pills
                          ..._buildTaskPills(context, weekDays, controller),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTaskPills(
    BuildContext context,
    List<DateTime> weekDays,
    CalendarController controller,
  ) {
    final List<Widget> pills = [];

    for (int dayIndex = 0; dayIndex < weekDays.length; dayIndex++) {
      final date = weekDays[dayIndex];
      final tasks = controller.getInstancesForDate(date);

      for (final task in tasks) {
        final start = DateTime.parse(task["dueDate"]);
        // If you have real end time → use it; otherwise assume 1h default
        final durationMinutes = task["durationMinutes"] as int? ?? 60;
        final end = start.add(Duration(minutes: durationMinutes));

        final startHour = start.hour;
        final startMinute = start.minute;
        final durationHours = durationMinutes / 60;

        // Only show if task is in visible time range (8AM–8PM for example)
        if (startHour < 8 || startHour >= 20) continue;

        final topOffset = (startHour - 8) * 80 + (startMinute / 60) * 80;
        final height = durationHours * 80;

        final color = _getTaskColor(task); // ← customize as needed

        pills.add(
          Positioned(
            left: dayIndex * 60.0, // width per day
            top: topOffset,
            child: GestureDetector(
              onTap: () {
                // TODO: open task detail
              },
              child: Container(
                width: 54,
                height: height.clamp(40.0, 300.0),
                margin: const EdgeInsets.only(right: 6, left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task["title"] ?? "Untitled",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${DateFormat('h:mm').format(start)}${end.minute == 0 ? '' : ' - ${DateFormat('h:mma').format(end)}'}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return pills;
  }

  Color _getTaskColor(Map<String, dynamic> task) {
    // You can use category, priority, or any field
    final title = (task["title"] ?? "").toLowerCase();
    if (title.contains("design")) return Colors.green[600]!;
    if (title.contains("admin")) return Colors.purple[500]!;
    if (title.contains("dashboard")) return Colors.orange[700]!;
    if (title.contains("web")) return Colors.blue[600]!;
    return Colors.teal[600]!; // default
  }
}
