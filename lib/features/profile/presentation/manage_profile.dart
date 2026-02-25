import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

import 'package:client/core/constants/api_constants.dart';
import '../../../core/utils/session_manager.dart';
import 'avatar_crop_page.dart';

class ManageProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const ManageProfilePage({super.key, required this.profileData});

  @override
  State<ManageProfilePage> createState() => _ManageProfilePageState();
}

class _ManageProfilePageState extends State<ManageProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;

  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  bool _hasChanges = false; // Track if photo was uploaded/deleted
  String? _avatarPreviewUrl;
  File? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  // Store original email to send it back unchanged
  late String _originalEmail;

  // Scroll-aware AppBar
  final ScrollController _scrollController = ScrollController();
  bool _appBarElevated = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profileData["profile"] ?? {};

    _nameController = TextEditingController(text: profile["fullName"] ?? "");
    _bioController = TextEditingController(text: profile["bio"] ?? "");

    // Store original email
    _originalEmail = (profile["email"] as String?)?.trim() ?? "";

    // Initial avatar preview - handle relative URLs from backend
    final avatarUrl = profile["avatarUrl"]?.toString();
    if (avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        !avatarUrl.contains('placeholder')) {
      if (avatarUrl.startsWith('/')) {
        // Relative URL from backend
        _avatarPreviewUrl = "${ApiConstants.backendUrl}$avatarUrl";
      } else if (avatarUrl.startsWith('http')) {
        // Absolute URL
        _avatarPreviewUrl = avatarUrl;
      } else {
        _avatarPreviewUrl = null;
      }
    } else {
      _avatarPreviewUrl = null;
    }

    print("🧪 [ManageProfile] Initial avatar preview: $_avatarPreviewUrl");

    _scrollController.addListener(() {
      final elevated = _scrollController.offset > 10;
      if (elevated != _appBarElevated) {
        setState(() => _appBarElevated = elevated);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Pick at higher resolution so crop has more pixels to work with
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (pickedFile == null || !mounted) return;

      // ── Instagram-like crop/zoom screen ──────────────────────────────
      final File? croppedFile = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AvatarCropPage(imageFile: File(pickedFile.path)),
        ),
      );

      if (croppedFile == null || !mounted) return;

      setState(() {
        _selectedImageFile = croppedFile;
        _avatarPreviewUrl = croppedFile.path;
      });

      // Upload the cropped result
      await _uploadPhoto();
    } catch (e) {
      print("🧪 [ManageProfile] Image picker error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to pick image: $e")));
      }
    }
  }

  Future<void> _uploadPhoto() async {
    if (_selectedImageFile == null) return;

    final token = await SessionManager.getToken();
    final userId = await SessionManager.getUserId();

    if (token == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please login again.")),
      );
      return;
    }

    setState(() => _isUploadingPhoto = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${ApiConstants.backendUrl}/api/profile/$userId/photo"),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Get file extension
      final extension = _selectedImageFile!.path.split('.').last.toLowerCase();

      // Determine content type
      MediaType contentType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          contentType = MediaType('image', 'jpeg');
          break;
        case 'png':
          contentType = MediaType('image', 'png');
          break;
        case 'gif':
          contentType = MediaType('image', 'gif');
          break;
        case 'webp':
          contentType = MediaType('image', 'webp');
          break;
        default:
          contentType = MediaType('image', 'jpeg');
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          _selectedImageFile!.path,
          contentType: contentType,
        ),
      );

      print("🧪 [ManageProfile] Uploading photo...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("🧪 [ManageProfile] Upload response: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final newAvatarUrl = responseData['data']['avatarUrl'];
        print("🧪 [ManageProfile] New avatar URL from backend: $newAvatarUrl");

        setState(() {
          _avatarPreviewUrl = "${ApiConstants.backendUrl}$newAvatarUrl";
          _selectedImageFile = null; // Clear local file after upload
          _hasChanges = true; // Mark that changes were made
        });

        print("🧪 [ManageProfile] Full avatar URL set to: $_avatarPreviewUrl");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Photo uploaded successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        final errorMsg =
            jsonDecode(response.body)["message"] ?? "Failed to upload photo";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("🧪 [ManageProfile] Upload error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload error: $e")));
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _deletePhoto() async {
    final token = await SessionManager.getToken();
    final userId = await SessionManager.getUserId();

    if (token == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please login again.")),
      );
      return;
    }

    setState(() => _isUploadingPhoto = true);

    try {
      final response = await http.delete(
        Uri.parse("${ApiConstants.backendUrl}/api/profile/$userId/photo"),
        headers: {"Authorization": "Bearer $token"},
      );

      print("🧪 [ManageProfile] Delete photo response: ${response.statusCode}");

      if (response.statusCode == 200) {
        setState(() {
          _avatarPreviewUrl = null;
          _selectedImageFile = null;
          _hasChanges = true; // Mark that changes were made
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Photo deleted successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to delete photo")));
      }
    } catch (e) {
      print("🧪 [ManageProfile] Delete error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Delete error: $e")));
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  void _showImageSourceDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1A1626) : Colors.white;
    final hasPhoto =
        _avatarPreviewUrl != null &&
        !_avatarPreviewUrl!.contains('placeholder');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Update Profile Photo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose how you\'d like to update your picture',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 24),

                // Options row
                Row(
                  children: [
                    // Gallery
                    Expanded(
                      child: _photoOptionTile(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Camera
                    Expanded(
                      child: _photoOptionTile(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                    if (hasPhoto) ...[
                      const SizedBox(width: 12),
                      // Remove
                      Expanded(
                        child: _photoOptionTile(
                          icon: Icons.delete_outline_rounded,
                          label: 'Remove',
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC62828), Color(0xFFEF5350)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(context);
                            _deletePhoto();
                          },
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Cancel
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.grey[100],
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoOptionTile({
    required IconData icon,
    required String label,
    required LinearGradient gradient,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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

    // Fetch latest profile to get current avatarUrl (in case photo was uploaded)
    String? currentAvatarUrl;
    try {
      final profileResponse = await http.get(
        Uri.parse("${ApiConstants.backendUrl}/api/profile/$userId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        currentAvatarUrl = profileData["data"]["profile"]["avatarUrl"];
        print(
          "🧪 [ManageProfile] Current avatarUrl from backend: $currentAvatarUrl",
        );
      }
    } catch (e) {
      print("🧪 [ManageProfile] Error fetching current profile: $e");
    }

    // Fallback to widget data if fetch failed
    currentAvatarUrl ??=
        widget.profileData["profile"]["avatarUrl"] ??
        "https://via.placeholder.com/150";

    final updates = {
      "profile": {
        "fullName": _nameController.text.trim(),
        "bio": _bioController.text.trim(),
        "email": _originalEmail, // ← Always include the current email
        "avatarUrl": currentAvatarUrl, // ← Preserve the current avatar
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
          Navigator.pop(context, true); // Signal success back to caller
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

  Widget _buildAvatar() {
    const double size = 110.0;
    final hasImage =
        _avatarPreviewUrl != null &&
        _avatarPreviewUrl!.isNotEmpty &&
        !_avatarPreviewUrl!.contains('placeholder');

    return GestureDetector(
      onTap: _isUploadingPhoto ? null : _showImageSourceDialog,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Outer glow ring
          Container(
            width: size + 8,
            height: size + 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.deepPurple.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // White separator
          Positioned(
            top: 3,
            left: 3,
            child: Container(
              width: size + 2,
              height: size + 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
          // Avatar image
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: ClipOval(
                child: _isUploadingPhoto
                    ? Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.purple,
                            ),
                          ),
                        ),
                      )
                    : _selectedImageFile != null
                    ? Image.file(
                        _selectedImageFile!,
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                      )
                    : hasImage
                    ? Image.network(
                        _avatarPreviewUrl!,
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          size: 54,
                          color: Colors.grey[500],
                        ),
                      )
                    : Icon(Icons.person, size: 54, color: Colors.grey[500]),
              ),
            ),
          ),
          // Camera badge
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    bool isDark = false,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.purple.shade400),
      labelStyle: TextStyle(
        color: Colors.purple.shade400,
        fontWeight: FontWeight.w500,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.purple.shade900 : Colors.purple.shade100,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1A2B) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0C1A) : const Color(0xFFF3F0FA);
    final cardColor = isDark ? const Color(0xFF1A1626) : Colors.white;
    final currentEmail = _originalEmail.isNotEmpty ? _originalEmail : "Not set";

    // AppBar colours depend on whether we've scrolled past the hero
    final appBarBg = _appBarElevated
        ? (isDark ? const Color(0xFF1A0D3D) : const Color(0xFF7B1FA2))
        : Colors.transparent;
    final iconColor = _appBarElevated || !isDark
        ? Colors.white
        : Colors.white70;
    final titleColor = Colors.white;
    final statusBarStyle =
        SystemUiOverlayStyle.light; // white status icons always

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: statusBarStyle,
        backgroundColor: appBarBg,
        elevation: _appBarElevated ? 4 : 0,
        shadowColor: Colors.black.withOpacity(0.3),
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: _appBarElevated
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(context, _hasChanges),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: iconColor,
              ),
            ),
          ),
        ),
        title: AnimatedOpacity(
          opacity: _appBarElevated ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            "Manage Account",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 19,
              color: titleColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // ── Hero gradient header ────────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2D1B5E), const Color(0xFF1A0D3D)]
                            : [
                                const Color(0xFF9C27B0),
                                const Color(0xFF6A1B9A),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(36),
                        bottomRight: Radius.circular(36),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 110),
                        _buildAvatar(),
                        const SizedBox(height: 14),
                        Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text
                              : "Your Name",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentEmail,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_isUploadingPhoto)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Uploading photo...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: GestureDetector(
                              onTap: _showImageSourceDialog,
                              child: Text(
                                'Tap avatar to change photo',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white.withOpacity(
                                    0.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Form section ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section label
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            'PERSONAL INFORMATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: Colors.purple.shade400,
                            ),
                          ),
                        ),

                        // ── Name card ─────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.purple.withOpacity(0.07),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: TextField(
                              controller: _nameController,
                              decoration: _fieldDecoration(
                                label: 'Full Name',
                                icon: Icons.person_outline_rounded,
                                isDark: isDark,
                              ),
                              textCapitalization: TextCapitalization.words,
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Email card (locked) ───────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A1626)
                                : const Color(0xFFFAF8FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? Colors.purple.shade900
                                  : Colors.purple.shade100,
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.email_outlined,
                                    color: Colors.purple.shade400,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email Address',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.purple.shade400,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        currentEmail,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        color: Colors.grey[500],
                                        size: 13,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Locked',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Section label
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            'ABOUT YOU',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: Colors.purple.shade400,
                            ),
                          ),
                        ),

                        // ── Bio card ──────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.purple.withOpacity(0.07),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: TextField(
                              controller: _bioController,
                              decoration: _fieldDecoration(
                                label: 'Bio',
                                hint: 'Tell the world a little about yourself…',
                                icon: Icons.edit_note_rounded,
                                isDark: isDark,
                              ).copyWith(alignLabelWithHint: true),
                              maxLines: 5,
                              maxLength: 200,
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sticky Save Button ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.4)
                      : Colors.purple.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _isLoading
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                  color: _isLoading ? Colors.grey[400] : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isLoading
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
