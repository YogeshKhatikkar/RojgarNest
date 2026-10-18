// lib/features/resume/presentation/widgets/profile_photo_upload_dialog.dart
// ✅ Complete file with FIXED upload method
// ✅ Handles all response shapes

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/core/widgets/platform_file_picker.dart';
import 'package:rojgarnest/core/services/profile_state_service.dart';
import 'package:rojgarnest/features/user/providers/user_profile_provider.dart';

class ProfilePhotoUploadDialog extends StatefulWidget {
  final String? currentPhotoUrl;

  const ProfilePhotoUploadDialog({super.key, this.currentPhotoUrl});

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
  bool _isUploading = false;
  String? _fileName;
  Uint8List? _fileBytes;
  double _progress = 0;

  Future<void> _pickImage() async {
    try {
      final result = await PlatformFilePicker.pickFile(
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (result == null) return;
      if (result.bytes == null) {
        if (mounted) {
          showMessage(context, "File data unavailable", isError: true);
        }
        return;
      }
      if (result.size > 5 * 1024 * 1024) {
        if (mounted) showMessage(context, "Max 5MB allowed", isError: true);
        return;
      }
      setState(() {
        _fileName = result.name;
        _fileBytes = result.bytes;
      });
    } catch (e) {
      if (mounted) showMessage(context, "Error: $e", isError: true);
    }
  }

  Future<void> _upload() async {
    if (_fileBytes == null || _fileName == null) {
      showMessage(context, "Please select a photo first", isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0;
    });

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(_fileBytes!, filename: _fileName!),
      });

      final response = await DioClient.dio.post(
        '/user/upload-profile-photo',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = sent / total);
          }
        },
      );

      debugPrint("=" * 70);
      debugPrint("📸 UPLOAD RESPONSE: ${response.data}");
      debugPrint("=" * 70);

      final data = response.data;

      String? url;
      String? publicId;

      if (data is Map) {
        url = data['url']?.toString();
        publicId = data['public_id']?.toString();

        if ((url == null || url.isEmpty) && data['data'] is Map) {
          final nested = data['data'] as Map;
          url = nested['url']?.toString();
          publicId ??= nested['public_id']?.toString();
        }

        if (url == null || url.isEmpty) {
          url = data['profile_photo_url']?.toString();
        }

        if ((url == null || url.isEmpty) && data['additional_details'] is Map) {
          final additional = data['additional_details'] as Map;
          url = additional['profile_photo_url']?.toString();
          publicId ??= additional['profile_photo_public_id']?.toString();
        }

        if (url == null || url.isEmpty) {
          url = data['photo_url']?.toString();
        }
      }

      url = url?.trim();

      if (url == null || url.isEmpty) {
        throw Exception("Server returned no photo URL");
      }

      debugPrint("✅ Extracted URL: $url");
      debugPrint("✅ Extracted publicId: $publicId");

      ProfileStateService().setPhoto(url: url, publicId: publicId);

      if (mounted) {
        Provider.of<UserProfileProvider>(context, listen: false)
            .setProfilePhoto(url: url, publicId: publicId);
      }

      if (mounted) {
        showMessage(context, "✅ Profile photo updated!");
        Navigator.pop(context, url);
      }
    } catch (e) {
      debugPrint("❌ Upload error: $e");
      if (mounted) {
        showMessage(
          context,
          "Upload failed: ${e.toString().replaceAll('Exception:', '').trim()}",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Profile Photo Required",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Add a photo to complete your resume",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _isUploading ? null : _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _fileBytes != null
                          ? Colors.green
                          : const Color(0xFF6C63FF),
                      width: 2,
                    ),
                  ),
                  child: _fileBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            _fileBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                size: 48, color: Colors.grey.shade600),
                            const SizedBox(height: 8),
                            const Text(
                              "Tap to select photo",
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "JPG / PNG / WEBP · Max 5MB",
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                ),
              ),
              if (_fileName != null) ...[
                const SizedBox(height: 12),
                Text(
                  _fileName!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (_isUploading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFF6C63FF),
                ),
                const SizedBox(height: 8),
                Text(
                  "Uploading ${(_progress * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isUploading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Skip for Now"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _upload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Upload Photo"),
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
}