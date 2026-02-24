// lib/features/calendar/presentation/calendar_page.dart
import 'package:client/features/calendar/presentation/calendar_controller.dart';
import 'package:client/features/calendar/presentation/widgets/daily_view.dart';
import 'package:client/features/calendar/presentation/widgets/weekly_view.dart';
import 'package:client/features/calendar/presentation/widgets/monthly_view.dart';
import 'package:client/features/profile/presentation/profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CalendarPage extends StatefulWidget {
  final ValueChanged<bool>? onThemeChanged;

  const CalendarPage({super.key, this.onThemeChanged});

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
    ).then((_) {
      controller.refreshAvatar();
    });
  }

  void _openSidePanel(BuildContext context) {
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
                            Icons.calendar_month_rounded,
                            color: Colors.purple,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Calendar',
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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'CALENDAR VIEWS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  _panelTile(ctx, Icons.view_day_outlined, 'Daily', () {
                    Navigator.pop(ctx);
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                    setState(() => _currentIndex = 0);
                  }, _currentIndex == 0),
                  _panelTile(ctx, Icons.view_week_outlined, 'Weekly', () {
                    Navigator.pop(ctx);
                    _pageController.animateToPage(
                      1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                    setState(() => _currentIndex = 1);
                  }, _currentIndex == 1),
                  _panelTile(ctx, Icons.calendar_month_outlined, 'Monthly', () {
                    Navigator.pop(ctx);
                    _pageController.animateToPage(
                      2,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                    setState(() => _currentIndex = 2);
                  }, _currentIndex == 2),
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
                onPressed: () => _openSidePanel(context),
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
