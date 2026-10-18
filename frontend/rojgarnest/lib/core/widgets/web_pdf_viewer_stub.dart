// lib/core/widgets/web_pdf_viewer_stub.dart
// ✅ Stub for mobile/native platforms (Android / iOS / Windows / Linux / macOS)
// ✅ This file MUST NOT import dart:html or dart:js_interop
// ✅ ALL functions must exist so conditional import works on all platforms

import 'dart:typed_data';
import 'package:flutter/material.dart';

// ============================================================================
// PDF BLOB STUBS
// ============================================================================
String? createPdfBlobUrl(Uint8List bytes) => null;

void revokeBlobUrl(String blobUrl) {}

Widget buildWebPdfFromBlob({
  required String blobUrl,
  required String title,
}) {
  return const Center(
    child: Text(
      'Web PDF viewer not available on this platform',
      style: TextStyle(color: Colors.white70),
    ),
  );
}

// ============================================================================
// ✅ NEW STUB: PDF FROM URL (for external PDFs)
// ============================================================================
Widget buildWebPdfFromUrl({
  required String url,
  required String title,
}) {
  return const Center(
    child: Text(
      'Web PDF viewer not available on this platform',
      style: TextStyle(color: Colors.white70),
    ),
  );
}

// ============================================================================
// IMAGE BLOB STUBS
// ============================================================================
String? createImageBlobUrl(Uint8List bytes, String mimeType) => null;

Widget buildWebImageFromBlob({
  required String blobUrl,
  required TransformationController controller,
}) {
  return const Center(
    child: Text(
      'Web image viewer not available on this platform',
      style: TextStyle(color: Colors.white70),
    ),
  );
}

// ============================================================================
// ✅ NEW STUB: IMAGE FROM URL (for external images)
// ============================================================================
Widget buildWebImageFromUrl({
  required String url,
  required TransformationController controller,
}) {
  return const Center(
    child: Text(
      'Web image viewer not available on this platform',
      style: TextStyle(color: Colors.white70),
    ),
  );
}

// ============================================================================
// DOWNLOAD STUB
// ============================================================================
void downloadBlobUrl(String blobUrl, String fileName) {
  // Stub - not available on mobile
}

// ============================================================================
// ✅ NEW STUB: OPEN EXTERNAL URL
// ============================================================================
void openExternalUrl(String url) {
  // Stub - not available on mobile
}

// ============================================================================
// ✅ BACKWARD COMPATIBILITY STUB: openPdfInNewTab
// ============================================================================
void openPdfInNewTab(String url) {
  openExternalUrl(url);
}