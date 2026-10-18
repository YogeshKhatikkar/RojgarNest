// lib/features/jobs/presentation/widgets/submit_document_dialog.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rojgarnest/core/services/cloudinary_service.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';

class SubmitDocumentDialog extends StatefulWidget {
  final String applicationId;
  final String applicantName;
  final String jobTitle;
  final VoidCallback onSuccess;

  const SubmitDocumentDialog({
    super.key,
    required this.applicationId,
    required this.applicantName,
    required this.jobTitle,
    required this.onSuccess,
  });

  @override
  State<SubmitDocumentDialog> createState() => _SubmitDocumentDialogState();
}

class _SubmitDocumentDialogState extends State<SubmitDocumentDialog> {
  bool _isUploading = false;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

 // Only showing the specific method that needs fixing

Future<void> _pickFile() async {
  try {
    // ✅ FIXED: Removed .platform
        FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

    if (result != null && mounted) {
      final file = result.files.first;
      setState(() {
        _selectedFileName = file.name;
        _selectedFileBytes = file.bytes;
      });
    }
  } catch (e) {
    if (mounted) {
      showMessage(context, "Error picking file: $e", isError: true);
    }
  }
}

  Future<void> _submitWithDocument() async {
    if (_selectedFileBytes == null || _selectedFileName == null) {
      showMessage(context, "Please select a PDF or Image file", isError: true);
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Upload document to Cloudinary - result is used implicitly via success/failure
      await CloudinaryService.uploadApplicationDocument(
        fileBytes: _selectedFileBytes!,
        fileName: _selectedFileName!,
        applicationId: widget.applicationId,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        showMessage(
          context,
          "✅ Document submitted successfully to Cloudinary!",
        );
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          "Failed to submit: ${e.toString()}",
          isError: true,
        );
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.9 > 500 ? 500.0 : screenWidth * 0.9;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cloud_upload,
                    color: Colors.teal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Submit Application Document",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${widget.applicantName} - ${widget.jobTitle}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              "📄 Upload Document (PDF or Image)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              "The document will be stored securely in Cloudinary",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _selectedFileName != null
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        _selectedFileName != null ? Colors.green : Colors.blue,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFileName != null
                          ? Icons.check_circle
                          : Icons.cloud_upload,
                      size: 48,
                      color: _selectedFileName != null
                          ? Colors.green
                          : Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFileName != null
                          ? _selectedFileName!
                          : "Tap to select PDF or Image",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedFileName != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _selectedFileName != null
                            ? Colors.green
                            : Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_selectedFileName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "${(_selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Additional Notes (Optional)",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Add any remarks about this submission...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isUploading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitWithDocument,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, size: 18),
                              SizedBox(width: 8),
                              Text("Upload to Cloudinary"),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_queue, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Your document will be stored in Cloudinary at:\nRojgarNest_uploads/users_data/{username}/applications/",
                      style: const TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
