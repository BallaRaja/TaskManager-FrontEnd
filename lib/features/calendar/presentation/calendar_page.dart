// lib/features/calendar/presentation/calendar_page.dart
import 'package:client/features/calendar/presentation/calendar_controller.dart';
import 'package:client/features/calendar/presentation/widgets/daily_view.dart';
import 'package:client/features/calendar/presentation/widgets/weekly_view.dart';
import 'package:client/features/calendar/presentation/widgets/monthly_view.dart';
import 'package:client/features/profile/presentation/profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late PageController _pageController;
  int _currentIndex = 0; // 0 = Daily, 1 = Weekly, 2 = Monthly

  final List<Widget> _views = const [DailyView(), WeeklyView(), MonthlyView()];

  final List<String> _titles = const ["Daily", "Weekly", "Monthly"];

  void _showProfileSheet(BuildContext context) {
    final controller = Provider.of<CalendarController>(context, listen: false);
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
    ).then((_) {
      // Refresh avatar after profile sheet closes
      controller.refreshAvatar();
    });
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CalendarController()..init(),
      child: Consumer<CalendarController>(
        builder: (context, controller, _) {
          if (controller.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
              title: Text(
                "Calendar • ${_titles[_currentIndex]}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => _showProfileSheet(context),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          controller.avatarUrl != null &&
                              controller.avatarUrl!.isNotEmpty
                          ? NetworkImage(controller.avatarUrl!)
                          : null,
                      child:
                          controller.avatarUrl == null ||
                              controller.avatarUrl!.isEmpty
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: controller.refresh,
              child: Column(
                children: [
                  // Indicator dots at the top
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentIndex == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentIndex == index
                                ? Colors.purple
                                : Colors.grey[400],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Swipable views
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      children: _views,
                    ),
                  ),
                ],
              ),
            ),
            // Removed FAB completely as requested
          );
        },
      ),
    );
  }
}
