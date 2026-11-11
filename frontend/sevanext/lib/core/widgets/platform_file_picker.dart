// lib/core/widgets/platform_file_picker.dart
// ✅ FIXED: NEVER accesses `file.path` on Web (was crashing)
// ✅ Works on ALL platforms: Mobile, Web, Desktop
// ✅ Complete file — no lines skipped

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import '../utils/platform_utils.dart';

class PlatformFilePicker {
  /// ✅ CRITICAL FIX: Safely extract path — NEVER touches .path on web
  /// On web, `PlatformFile.path` throws UnimplementedError.
  static String? _safePath(PlatformFile file) {
    if (kIsWeb) return null;
    try {
      return file.path;
    } catch (e) {
      debugPrint('⚠️ Could not read file.path: $e');
      return null;
    }
  }

  /// Pick a file with platform-aware error handling
  static Future<PlatformFileResult?> pickFile({
    required List<String> allowedExtensions,
    bool allowMultiple = false,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: true, // ✅ CRITICAL: Gets bytes for web
      );

      if (result == null) return null;
      if (result.files.isEmpty) return null;

      final file = result.files.first;

      return PlatformFileResult(
        name: file.name,
        bytes: file.bytes,
        size: file.size,
        path: _safePath(file), // ✅ SAFE on all platforms
        extension: file.extension ?? '',
      );
    } catch (e) {
      debugPrint('❌ File picker error: $e');
      throw Exception(PlatformUtils.getFilePickerErrorMessage(e));
    }
  }

  /// Pick image file (JPG, JPEG, PNG)
  static Future<PlatformFileResult?> pickImage() async {
    return pickFile(allowedExtensions: ['jpg', 'jpeg', 'png']);
  }

  /// Pick document file (PDF, DOC, DOCX)
  static Future<PlatformFileResult?> pickDocument() async {
    return pickFile(allowedExtensions: ['pdf', 'doc', 'docx']);
  }

  /// Pick PDF file only
  static Future<PlatformFileResult?> pickPDF() async {
    return pickFile(allowedExtensions: ['pdf']);
  }

  /// Pick any file type
  static Future<PlatformFileResult?> pickAnyFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;

      return PlatformFileResult(
        name: file.name,
        bytes: file.bytes,
        size: file.size,
        path: _safePath(file), // ✅ SAFE on all platforms
        extension: file.extension ?? '',
      );
    } catch (e) {
      debugPrint('❌ File picker error: $e');
      throw Exception(PlatformUtils.getFilePickerErrorMessage(e));
    }
  }
}

class PlatformFileResult {
  final String name;
  final Uint8List? bytes;
  final int size;
  final String? path;
  final String extension;

  PlatformFileResult({
    required this.name,
    this.bytes,
    required this.size,
    this.path,
    required this.extension,
  });

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
  bool get hasPath => path != null && path!.isNotEmpty;
}