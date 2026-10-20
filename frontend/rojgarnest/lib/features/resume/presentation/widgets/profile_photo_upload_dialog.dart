// lib/features/resume/presentation/widgets/profile_photo_upload_dialog.dart
// ✅ COMPLETE FIXED VERSION
// ✅ show() now accepts OPTIONAL `currentPhotoUrl` (backward compatible)
// ✅ Old callers: ProfilePhotoUploadDialog.show(context) → still works
// ✅ New callers: ProfilePhotoUploadDialog.show(context, currentPhotoUrl: url) → works
// ✅ Returns uploaded URL (String?) — null if cancelled
// ✅ Auto-syncs ProfileStateService + cache after upload
// ✅ No lines skipped

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:rojgarnest/core/config/api_config.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/services/profile_state_service.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';

// ============================================================
// ✅ MAIN: ProfilePhotoUploadDialog
// ============================================================
class ProfilePhotoUploadDialog extends StatefulWidget {
  /// ✅ OPTIONAL: Current photo URL (shown as preview if upload not started)
  final String? currentPhotoUrl;

  const ProfilePhotoUploadDialog({
    super.key,
    this.currentPhotoUrl,
  });

  /// ✅ FIXED: `show()` now accepts optional `currentPhotoUrl`
  /// Backward compatible — old callers just use `show(context)`
  /// Returns the uploaded URL (String?) or null if cancelled
  static Future<String?> show(
    BuildContext context, {
    String? currentPhotoUrl,
  }) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfilePhotoUploadDialog(
        currentPhotoUrl: currentPhotoUrl,
      ),
    );
  }

  @override
  State<ProfilePhotoUploadDialog> createState() =>
      _ProfilePhotoUploadDialogState();
}

class _ProfilePhotoUploadDialogState extends State<ProfilePhotoUploadDialog> {
  Uint8List? _selectedBytes;
  String? _selectedName;
  bool _isUploading = false;

  // ============================================================
  // PICK IMAGE
  // ============================================================
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // ✅ Size check (5 MB)
      if (file.size > 5 * 1024 * 1024) {
        if (mounted) {
          showMessage(
            context,
            "File too large. Max 5MB allowed.",
            isError: true,
          );
        }
        return;
      }

      setState(() {
        _selectedBytes = file.bytes;
        _selectedName = file.name;
      });

      debugPrint(
          "📸 ProfilePhotoUploadDialog: Picked ${file.name} (${file.size} bytes)");
    } catch (e) {
      debugPrint("❌ ProfilePhotoUploadDialog: Pick failed: $e");
      if (mounted) {
        showMessage(context, "Failed to pick image: $e", isError: true);
      }
    }
  }

  // ============================================================
  // UPLOAD IMAGE
  // ============================================================
  Future<void> _upload() async {
    if (_selectedBytes == null || _selectedName == null) return;

    setState(() => _isUploading = true);

    try {
      final token = await SecureStorage.getToken();
      if (token == null || token.isEmpty) {
        throw Exception("No authentication token found. Please login again.");
      }

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/user/upload-profile-photo',
      );
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        _selectedBytes!,
        filename: _selectedName!,
      );
      request.files.add(multipartFile);

      debugPrint("📤 Uploading profile photo to: $uri");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("📥 Upload response: ${response.statusCode}");
      debugPrint("📥 Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // ✅ Try multiple possible keys (backend may vary)
        final photoUrl = (data['url'] ??
                data['data']?['url'] ??
                data['profile_photo_url'] ??
                data['data']?['profile_photo_url'])
            ?.toString();

        if (photoUrl == null || photoUrl.isEmpty) {
          throw Exception("Server did not return a photo URL");
        }

        debugPrint("✅ Uploaded photo URL: $photoUrl");

        // ✅ Update ProfileStateService (memory + cache)
        ProfileStateService().setPhoto(url: photoUrl);

        // ✅ Force refresh from backend to ensure sync
        try {
          await ProfileStateService().loadPhotoFromBackend(forceRefresh: true);
        } catch (refreshError) {
          debugPrint(
              "⚠️ ProfilePhotoUploadDialog: Refresh failed: $refreshError");
        }

        if (mounted) {
          // ✅ Return uploaded URL to caller
          Navigator.of(context).pop(photoUrl);
        }
      } else {
        // Try to parse error message
        String errorMsg = "Upload failed (${response.statusCode})";
        try {
          final errorBody = jsonDecode(response.body);
          errorMsg =
              errorBody['message']?.toString() ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint("❌ ProfilePhotoUploadDialog: Upload failed: $e");
      if (mounted) {
        showMessage(context, "Upload failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final hasCurrentPhoto =
        widget.currentPhotoUrl != null && widget.currentPhotoUrl!.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ==================== HEADER ====================
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Profile Photo",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed:
                        _isUploading ? null : () => Navigator.of(context).pop(),
                    tooltip: "Cancel",
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // ==================== PREVIEW ====================
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF6C63FF),
                    width: 3,
                  ),
                  color: Colors.grey.shade100,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.15),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _selectedBytes != null
                      // ✅ Show newly picked image
                      ? Image.memory(
                          _selectedBytes!,
                          fit: BoxFit.cover,
                          width: 140,
                          height: 140,
                        )
                      // ✅ Show current photo (if exists)
                      : hasCurrentPhoto
                          ? Image.network(
                              widget.currentPhotoUrl!,
                              fit: BoxFit.cover,
                              width: 140,
                              height: 140,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                            )
                          : _buildPlaceholder(),
                ),
              ),
              const SizedBox(height: 12),

              // ==================== STATUS TEXT ====================
              if (_selectedBytes != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Ready to upload: $_selectedName",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else if (hasCurrentPhoto)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "✅ Current photo loaded from database",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "No photo uploaded yet",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // ==================== CHOOSE IMAGE BUTTON ====================
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickImage,
                icon: const Icon(Icons.image, size: 18),
                label: const Text("Choose Image"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                  side: const BorderSide(color: Color(0xFF6C63FF)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "JPG, PNG, or WEBP — Max 5MB",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // ==================== ACTION BUTTONS ====================
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_isUploading || _selectedBytes == null)
                          ? null
                          : _upload,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload, size: 18),
                      label: Text(
                        _isUploading ? "Uploading..." : "Upload",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.person,
        size: 70,
        color: Colors.grey.shade400,
      ),
    );
  }
}