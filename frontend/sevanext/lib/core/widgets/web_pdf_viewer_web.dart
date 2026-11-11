// lib/core/widgets/web_pdf_viewer_web.dart
// ✅ ONLY compiled on Web (via conditional import in file_viewer_screen.dart)
// ✅ FIXED: External PDFs now open via DIRECT iframe (NO CORS issues!)
// ✅ NEW: buildWebPdfFromUrl() - for external PDF URLs
// ✅ NEW: buildWebImageFromUrl() - for external image URLs
// ✅ NEW: openExternalUrl() - open any URL in new browser tab

import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;

// ============================================================================
// PDF BLOB URL (for Cloudinary/owned PDFs — CORS-friendly sources)
// ============================================================================
String? createPdfBlobUrl(Uint8List bytes) {
  try {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    debugPrint('✅ PDF Blob URL created: $url');
    return url;
  } catch (e) {
    debugPrint('❌ Failed to create PDF blob URL: $e');
    return null;
  }
}

void revokeBlobUrl(String blobUrl) {
  try {
    html.Url.revokeObjectUrl(blobUrl);
    debugPrint('✅ Blob URL revoked: $blobUrl');
  } catch (e) {
    debugPrint('⚠️ Failed to revoke blob URL: $e');
  }
}

// ============================================================================
// ✅ PDF FROM BLOB (Cloudinary PDFs — works perfectly)
// ============================================================================
Widget buildWebPdfFromBlob({
  required String blobUrl,
  required String title,
}) {
  return _WebPdfIframe(blobUrl: blobUrl, title: title);
}

class _WebPdfIframe extends StatefulWidget {
  final String blobUrl;
  final String title;

  const _WebPdfIframe({
    required this.blobUrl,
    required this.title,
  });

  @override
  State<_WebPdfIframe> createState() => _WebPdfIframeState();
}

class _WebPdfIframeState extends State<_WebPdfIframe> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'pdf-blob-${DateTime.now().microsecondsSinceEpoch}';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = widget.blobUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#1E1E1E'
          ..setAttribute('type', 'application/pdf')
          ..setAttribute('allow', 'fullscreen');

        debugPrint('✅ PDF iframe created with src: ${widget.blobUrl}');
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}

// ============================================================================
// ✅ NEW: PDF FROM URL (External PDFs — NO CORS issues!)
// This uses direct iframe embedding. The browser treats the iframe `src`
// as a navigation (not XHR), so it completely bypasses CORS.
// ============================================================================
Widget buildWebPdfFromUrl({
  required String url,
  required String title,
}) {
  return _WebPdfFromUrl(url: url, title: title);
}

class _WebPdfFromUrl extends StatefulWidget {
  final String url;
  final String title;

  const _WebPdfFromUrl({
    required this.url,
    required this.title,
  });

  @override
  State<_WebPdfFromUrl> createState() => _WebPdfFromUrlState();
}

class _WebPdfFromUrlState extends State<_WebPdfFromUrl> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'pdf-url-${DateTime.now().microsecondsSinceEpoch}';

    debugPrint('📄 Creating DIRECT iframe for external PDF: ${widget.url}');

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        // ✅ Direct iframe embed — browser handles this as a navigation,
        // NOT as an XHR, so NO CORS restrictions apply!
        final iframe = html.IFrameElement()
          ..src = widget.url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#1E1E1E'
          ..setAttribute('type', 'application/pdf')
          ..setAttribute('allow', 'fullscreen')
          ..setAttribute('allowfullscreen', 'true');

        debugPrint('✅ Direct PDF iframe created for: ${widget.url}');
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}

// ============================================================================
// IMAGE BLOB URL (for Cloudinary/owned images)
// ============================================================================
String? createImageBlobUrl(Uint8List bytes, String mimeType) {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    debugPrint('✅ Image Blob URL created ($mimeType): $url');
    return url;
  } catch (e) {
    debugPrint('❌ Failed to create image blob URL: $e');
    return null;
  }
}

Widget buildWebImageFromBlob({
  required String blobUrl,
  required TransformationController controller,
}) {
  return _WebImageFromBlob(blobUrl: blobUrl, controller: controller);
}

class _WebImageFromBlob extends StatefulWidget {
  final String blobUrl;
  final TransformationController controller;

  const _WebImageFromBlob({
    required this.blobUrl,
    required this.controller,
  });

  @override
  State<_WebImageFromBlob> createState() => _WebImageFromBlobState();
}

class _WebImageFromBlobState extends State<_WebImageFromBlob> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'img-blob-${DateTime.now().microsecondsSinceEpoch}';

    debugPrint('🖼️ Registering web image blob view: $_viewId');
    debugPrint('   Blob URL: ${widget.blobUrl}');

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final img = html.ImageElement()
          ..src = widget.blobUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.backgroundColor = '#000000';

        debugPrint('✅ <img> created for blob');
        return img;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: widget.controller,
      minScale: 0.5,
      maxScale: 5.0,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

// ============================================================================
// ✅ NEW: IMAGE FROM DIRECT URL (External images)
// ============================================================================
Widget buildWebImageFromUrl({
  required String url,
  required TransformationController controller,
}) {
  return _WebImageFromUrl(url: url, controller: controller);
}

class _WebImageFromUrl extends StatefulWidget {
  final String url;
  final TransformationController controller;

  const _WebImageFromUrl({
    required this.url,
    required this.controller,
  });

  @override
  State<_WebImageFromUrl> createState() => _WebImageFromUrlState();
}

class _WebImageFromUrlState extends State<_WebImageFromUrl> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'img-url-${DateTime.now().microsecondsSinceEpoch}';

    debugPrint('🖼️ Creating DIRECT img for external URL: ${widget.url}');

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final img = html.ImageElement()
          ..src = widget.url
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.backgroundColor = '#000000';

        debugPrint('✅ Direct <img> created for URL: ${widget.url}');
        return img;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: widget.controller,
      minScale: 0.5,
      maxScale: 5.0,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

// ============================================================================
// DOWNLOAD BLOB URL
// ============================================================================
void downloadBlobUrl(String blobUrl, String fileName) {
  try {
    debugPrint('📥 Downloading: $fileName');
    debugPrint('   From: $blobUrl');

    final anchor = html.AnchorElement(href: blobUrl)
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);

    debugPrint('✅ Download triggered for: $fileName');
  } catch (e) {
    debugPrint('❌ Download failed: $e');
    try {
      html.window.open(blobUrl, '_blank');
      debugPrint('✅ Opened in new tab as fallback');
    } catch (e2) {
      debugPrint('❌ Fallback also failed: $e2');
    }
  }
}

// ============================================================================
// ✅ NEW: OPEN EXTERNAL URL IN NEW TAB
// ============================================================================
void openExternalUrl(String url) {
  try {
    debugPrint('🌐 Opening external URL: $url');
    html.window.open(url, '_blank');
  } catch (e) {
    debugPrint('❌ Failed to open external URL: $e');
  }
}

// ============================================================================
// ✅ BACKWARD COMPATIBILITY: openPdfInNewTab (alias for openExternalUrl)
// ============================================================================
void openPdfInNewTab(String url) {
  openExternalUrl(url);
}