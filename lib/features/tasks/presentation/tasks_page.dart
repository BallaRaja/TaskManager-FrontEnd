import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/session_manager.dart';
import '../../profile/presentation/profile_sheet.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String? _avatarUrl; // Will hold the avatar from API
  bool _isLoadingAvatar = true; // Show loading until we fetch it

  @override
  void initState() {
    super.initState();
    _fetchProfileAvatar();
  }

  Future<void> _fetchProfileAvatar() async {
    final token = await SessionManager.getToken();
    final userId = await SessionManager.getUserId();

    if (token == null || userId == null) {
      setState(() {
        _isLoadingAvatar = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("${ApiConstants.backendUrl}/api/profile/$userId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final String? avatar = json["data"]?["profile"]?["avatarUrl"];

        if (mounted) {
          setState(() {
            _avatarUrl = avatar;
            _isLoadingAvatar = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingAvatar = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAvatar = false);
      }
    }
  }

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
          position: Tween(
            begin: const Offset(1, 0),
            end: const Offset(0, 0),
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
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
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                child: _isLoadingAvatar
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _avatarUrl!,
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              size: 24,
                              color: Colors.grey,
                            );
                          },
                        ),
                      )
                    : const Icon(Icons.person, size: 24, color: Colors.grey),
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