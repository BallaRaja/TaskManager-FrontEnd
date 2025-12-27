import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:client/core/constants/api_constants.dart';
import '../../../core/utils/session_manager.dart';

class ManageProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const ManageProfilePage({super.key, required this.profileData});

  @override
  State<ManageProfilePage> createState() => _ManageProfilePageState();
}

class _ManageProfilePageState extends State<ManageProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _avatarUrlController;

  bool _isLoading = false;
  String? _avatarPreviewUrl;

  @override
  void initState() {
    super.initState();
    final profile = widget.profileData["profile"];

    _nameController = TextEditingController(text: profile["fullName"] ?? "");
    _bioController = TextEditingController(text: profile["bio"] ?? "");
    _avatarUrlController = TextEditingController(
      text: profile["avatarUrl"] ?? "",
    );

    // Initial preview
    _avatarPreviewUrl = profile["avatarUrl"]?.toString().isNotEmpty == true
        ? profile["avatarUrl"]
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final token = await SessionManager.getToken();
    final userId = await SessionManager.getUserId();

    if (token == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please login again.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final updates = {
      "profile": {
        "fullName": _nameController.text.trim(),
        "bio": _bioController.text.trim(),
        if (_avatarUrlController.text.trim().isNotEmpty)
          "avatarUrl": _avatarUrlController.text.trim(),
      },
    };

    print("🧪 [ManageProfile] Saving updates: $updates");

    try {
      final response = await http.put(
        Uri.parse("${ApiConstants.backendUrl}/api/profile/$userId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(updates),
      );

      print("🧪 [ManageProfile] PUT Response: ${response.statusCode}");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        if (mounted) {
          Navigator.pop(context, true); // Signal success back to ProfileSheet
        }
      } else {
        final errorMsg =
            jsonDecode(response.body)["message"] ?? "Failed to update profile";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("🧪 [ManageProfile] Network Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error. Please try again.")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF171022)
        : const Color(0xFFF5F5F5);

    final profile = widget.profileData["profile"];
    final currentEmail = profile["email"] ?? "No email";

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Manage Account",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Large Avatar Preview
            Center(
              child: CircleAvatar(
                radius: 80,
                backgroundImage:
                    _avatarPreviewUrl != null && _avatarPreviewUrl!.isNotEmpty
                    ? NetworkImage(_avatarPreviewUrl!)
                    : null,
                backgroundColor: Colors.grey[300],
                child: _avatarPreviewUrl == null || _avatarPreviewUrl!.isEmpty
                    ? Icon(Icons.person, size: 100, color: Colors.grey[600])
                    : null,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              "Tap below to change avatar URL",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),

            const SizedBox(height: 32),

            // Avatar URL Input
            TextField(
              controller: _avatarUrlController,
              decoration: InputDecoration(
                labelText: "Avatar Image URL",
                hintText: "https://example.com/your-photo.jpg",
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.white,
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) {
                setState(() {
                  _avatarPreviewUrl = value.trim().isNotEmpty
                      ? value.trim()
                      : null;
                });
              },
            ),

            const SizedBox(height: 32),

            // Full Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Full Name",
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.white,
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 24),

            // Locked Email Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, color: Colors.grey[600]),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Email",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentEmail,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.lock_outline, color: Colors.grey[500], size: 20),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bio
            TextField(
              controller: _bioController,
              decoration: InputDecoration(
                labelText: "Bio (optional)",
                hintText: "Tell us about yourself...",
                prefixIcon: const Icon(Icons.short_text),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.white,
              ),
              maxLines: 5,
              maxLength: 200,
            ),

            const SizedBox(height: 48),

            // Save Button - Full width & prominent
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save Changes",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 40), // Extra bottom space
          ],
        ),
      ),
    );
  }
}
