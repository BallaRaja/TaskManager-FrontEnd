import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:client/core/constants/api_constants.dart';
import '../../../core/utils/session_manager.dart';
import '../../auth/presentation/login_page.dart';

class ProfileSheet extends StatelessWidget {
  const ProfileSheet({super.key});

  /// Fetch profile from backend
  Future<Map<String, dynamic>> _fetchProfile() async {
    final token = await SessionManager.getToken();
    final userId = await SessionManager.getUserId();

    print("🧪 [Profile] token: ${token}");
    print("🧪 [Profile] userId: $userId");

    if (token == null || userId == null) {
      throw Exception("SESSION_EXPIRED");
    }

    final response = await http.get(
      Uri.parse("${ApiConstants.backendUrl}/api/profile/$userId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception("SESSION_EXPIRED");
    }

    if (response.statusCode != 200) {
      throw Exception("FAILED_TO_LOAD_PROFILE");
    }

    final decoded = jsonDecode(response.body);
    return decoded["data"];
  }

  Future<void> _logout(BuildContext context) async {
    await SessionManager.clearSession();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF171022) : Colors.white,
      child: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _fetchProfile(),
          builder: (context, snapshot) {
            // Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Error (mostly session expired)
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Session expired",
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => _logout(context),
                      child: const Text("Login again"),
                    ),
                  ],
                ),
              );
            }

            // Success
            final profile = snapshot.data!;
            final user = profile["profile"];
            final stats = profile["stats"];

            final avatarUrl = user["avatarUrl"];
            final hasAvatar =
                avatarUrl != null && avatarUrl.toString().isNotEmpty;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                    child: !hasAvatar
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // Name
                  Text(
                    user["fullName"] ?? "User",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Email
                  Text(
                    user["email"] ?? "",
                    style: const TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 24),

                  // Stats Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey[850]
                          : const Color(0xFFF7F5F8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _statRow("Total Tasks", stats["totalTasks"]),
                        _statRow("Completed", stats["tasksCompleted"]),
                        _statRow("Pending", stats["pendingTasks"]),
                        _statRow("Overdue", stats["overdueTasks"]),
                        _statRow("Streak", stats["streak"]),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _logout(context),
                      child: const Text("Sign out"),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
