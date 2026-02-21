import 'dart:convert';
import 'package:client/features/profile/presentation/manage_profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:client/core/constants/api_constants.dart';
import 'package:client/core/theme/app_theme.dart';
import '../../../core/utils/session_manager.dart';
import '../../auth/presentation/login_page.dart';

class ProfileSheet extends StatefulWidget {
  final ValueChanged<bool>? onThemeChanged;

  const ProfileSheet({super.key, this.onThemeChanged});

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final token = await SessionManager.getToken();
    final userId = await SessionManager.getUserId();

    print("🧪 [Profile] Loading profile | userId: $userId");

    if (token == null || userId == null) {
      setState(() => error = "SESSION_EXPIRED");
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("${ApiConstants.backendUrl}/api/profile/$userId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("🧪 [Profile] GET Status: ${response.statusCode}");

      if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() => error = "SESSION_EXPIRED");
        return;
      }

      if (response.statusCode != 200) {
        setState(() => error = "FAILED_TO_LOAD_PROFILE");
        return;
      }

      final decoded = jsonDecode(response.body);
      print(
        "🧪 [Profile] Profile data loaded: ${decoded["data"]["profile"]["avatarUrl"]}",
      );
      setState(() {
        profileData = decoded["data"];
        isLoading = false;
      });
    } catch (e) {
      print("🧪 [Profile] Load error: $e");
      setState(() => error = "NETWORK_ERROR");
    }
  }

  Future<void> _updateAiFeatures(bool newValue) async {
    final token = await SessionManager.getToken();
    final userId = await SessionManager.getUserId();

    // Optimistic update - update UI immediately
    setState(() {
      profileData!["aiFeatures"] = newValue;
    });

    print("🧪 [Profile] Toggling AI Features to: $newValue");

    try {
      final response = await http.put(
        Uri.parse("${ApiConstants.backendUrl}/api/profile/$userId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"aiFeatures": newValue}),
      );

      print("🧪 [Profile] PUT Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("AI features updated"),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        // Revert on failure
        setState(() {
          profileData!["aiFeatures"] = !newValue;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update AI features")),
        );
      }
    } catch (e) {
      print("🧪 [Profile] Toggle error: $e");
      // Revert UI
      setState(() {
        profileData!["aiFeatures"] = !newValue;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Network error")));
    }
  }

  Future<void> _logout(BuildContext context) async {
    await SessionManager.clearSession();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPage(onThemeChanged: widget.onThemeChanged),
        ),
        (_) => false,
      );
    }
  }

  Future<void> _updateThemeMode(bool useDarkMode) async {
    await AppTheme.saveTheme(useDarkMode);
    widget.onThemeChanged?.call(useDarkMode);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          useDarkMode
              ? "Default mode set to Dark"
              : "Default mode set to Light",
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? _buildErrorState(error!)
              : _buildProfileContent(isDark),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error == "SESSION_EXPIRED"
                ? "Session expired"
                : "Error loading profile",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _logout(context),
            child: const Text("Login again"),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(bool isDark) {
    final user = profileData!["profile"];
    final aiFeatures = profileData!["aiFeatures"] as bool;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final featureCardColor = isDark
        ? const Color(0xFF1E1A2B)
        : const Color(0xFFECDEFF);
    final featureIconColor = isDark
        ? AppTheme.darkSecondary
        : Colors.purple.shade700;
    final featureTextColor = isDark
        ? AppTheme.darkTextPrimary
        : Colors.purple.shade900;

    final avatarUrl = user["avatarUrl"] ?? '';

    // Build full avatar URL
    String? fullAvatarUrl;
    bool hasAvatar = false;

    if (avatarUrl.isNotEmpty && !avatarUrl.contains('placeholder')) {
      if (avatarUrl.startsWith('/')) {
        // Relative URL from backend
        fullAvatarUrl = "${ApiConstants.backendUrl}$avatarUrl";
        hasAvatar = true;
      } else if (avatarUrl.startsWith('http')) {
        // Absolute URL
        fullAvatarUrl = avatarUrl;
        hasAvatar = true;
      }
    }

    print(
      "🧪 [Profile] Displaying avatar | avatarUrl: $avatarUrl | fullAvatarUrl: $fullAvatarUrl | hasAvatar: $hasAvatar",
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          // Close button (top-right)
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.grey[600]),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          const SizedBox(height: 24),

          // Avatar
          CircleAvatar(
            radius: 48,
            backgroundImage: hasAvatar && fullAvatarUrl != null
                ? NetworkImage(fullAvatarUrl)
                : null,
            backgroundColor: Colors.grey[300],
            child: !hasAvatar
                ? Icon(Icons.person, size: 50, color: Colors.grey[600])
                : null,
          ),

          const SizedBox(height: 20),

          // Name
          Text(
            user["fullName"] ?? "User",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),

          const SizedBox(height: 6),

          // Email
          Text(
            user["email"] ?? "",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),

          const SizedBox(height: 20),

          // Manage Account Button
          OutlinedButton(
            onPressed: () async {
              print("🧪 [Profile] Opening Manage Account");

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManageProfilePage(profileData: profileData!),
                ),
              );

              // If changes were saved, refresh profile data
              if (result == true) {
                print("🧪 [Profile] Changes detected, reloading profile...");
                setState(() => isLoading = true);
                await _loadProfile();
              }
            },
            // ... style as before
            child: Text("Manage Account" /* ... */),
          ),

          const SizedBox(height: 32),

          // AI Features Card - Special background like HTML
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: featureCardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: featureIconColor, size: 24),
                    const SizedBox(width: 14),
                    Text(
                      "AI Features",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: featureTextColor,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: aiFeatures,
                  activeThumbColor: Colors.purple[600],
                  activeTrackColor: const Color(0xFFECB5F6),
                  onChanged: _updateAiFeatures,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: featureCardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.dark_mode, color: featureIconColor, size: 24),
                    const SizedBox(width: 14),
                    Text(
                      "Dark Mode",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: featureTextColor,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: isDarkMode,
                  activeThumbColor: Colors.purple[600],
                  activeTrackColor: const Color(0xFFECB5F6),
                  onChanged: _updateThemeMode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Help & Feedback
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: isDark
                  ? const Color(0xFF2A2438)
                  : Colors.grey[200],
              child: Icon(
                Icons.help_outline,
                color: isDark ? AppTheme.darkSecondary : Colors.grey[700],
                size: 22,
              ),
            ),
            title: Text(
              "Help & feedback",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
            onTap: () {
              print("🧪 [Profile] Help & feedback tapped");
            },
          ),

          const SizedBox(height: 48),

          // Footer
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      "Privacy Policy",
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                  Text(" • ", style: TextStyle(color: Colors.grey[500])),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      "Terms of Service",
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[600]!),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Sign out",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "v2.4.0 (Build 392)",
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
