import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
  }

  @override
  void dispose() {
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_avatarPreviewUrl != null &&
                  !_avatarPreviewUrl!.contains('placeholder'))
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _deletePhoto();
                  },
                ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF171022)
        : const Color(0xFFF5F5F5);

    final currentEmail = _originalEmail.isNotEmpty ? _originalEmail : "Not set";

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
        title: const Text(
          "Manage Account",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Avatar preview section ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 32, bottom: 24),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Circle avatar
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.purple.shade300,
                          width: 3,
                        ),
                        color: Colors.grey[300],
                      ),
                      child: ClipOval(
                        child: _isUploadingPhoto
                            ? const Center(child: CircularProgressIndicator())
                            : _selectedImageFile != null
                            ? Image.file(
                                _selectedImageFile!,
                                fit: BoxFit.cover,
                                width: 140,
                                height: 140,
                              )
                            : _avatarPreviewUrl != null &&
                                  _avatarPreviewUrl!.isNotEmpty &&
                                  !_avatarPreviewUrl!.contains('placeholder')
                            ? Image.network(
                                _avatarPreviewUrl!,
                                fit: BoxFit.cover,
                                width: 140,
                                height: 140,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Icons.person,
                                      size: 70,
                                      color: Colors.grey[600],
                                    ),
                              )
                            : Icon(
                                Icons.person,
                                size: 70,
                                color: Colors.grey[600],
                              ),
                      ),
                    ),

                    // Camera button (bottom-right)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploadingPhoto
                            ? null
                            : _showImageSourceDialog,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.purple,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Hint text
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'Tap the camera icon to update your photo',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),

            // === Form Fields ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
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
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.lock_outline,
                          color: Colors.grey[500],
                          size: 20,
                        ),
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

                  // Save Button
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

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
