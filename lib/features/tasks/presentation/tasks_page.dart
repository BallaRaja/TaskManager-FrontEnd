import 'package:flutter/material.dart';
import '../../profile/presentation/profile_sheet.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  void _showProfileSheet(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const ProfileSheet(),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: const Offset(0, 0))
              .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Tasks",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _showProfileSheet(context),
              child: const CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(
                  "https://images.unsplash.com/photo-1494790108377-be9c29b29330?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=987&q=80",
                ),
              ),
            ),
          ),
        ],
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: const Center(
        child: Text(
          "📋 Your Tasks Will Appear Here\nComing soon!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
      ),
    );
  }
}