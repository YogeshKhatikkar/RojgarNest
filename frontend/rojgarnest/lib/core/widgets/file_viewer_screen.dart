// lib/core/widgets/file_viewer_screen.dart
// ✅ FIXED: External PDFs now open on Web WITHOUT CORS issues
// ✅ Strategy:
//    - Cloudinary/owned PDFs → Download bytes → Blob URL (works)
//    - External PDFs on Web → Direct iframe embed (no XHR)
//    - Mobile → Download to local file (as before)
// ✅ PDF, Image, Google Drive, and all other file types supported
// ✅ DOWNLOAD icon available for all supported types

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

// Native PDF viewer (Android/iOS only)
import 'package:flutter_pdfview/flutter_pdfview.dart';

// ✅ Conditional web imports
import 'web_pdf_viewer_stub.dart'
    if (dart.library.js_interop) 'web_pdf_viewer_web.dart' as web_viewer;

// ============================================================================
// FILE TYPE DETECTOR - ENHANCED
// ============================================================================
class FileTypeDetector {
  static const Set<String> imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'wbmp', 'ico', 'tiff', 'tif', 'svg',
  };
  static const Set<String> pdfExtensions = {'pdf'};
  static const Set<String> wordExtensions = {'doc', 'docx', 'odt', 'rtf'};
  static const Set<String> excelExtensions = {'xls', 'xlsx', 'ods', 'csv'};
  static const Set<String> pptExtensions = {'ppt', 'pptx', 'odp'};
  static const Set<String> textExtensions = {
    'txt', 'log', 'md', 'json', 'xml', 'html', 'css', 'js', 'yaml', 'yml'
  };
  static const Set<String> videoExtensions = {
    'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp'
  };
  static const Set<String> audioExtensions = {
    'mp3', 'wav', 'aac', 'ogg', 'flac', 'm4a', 'wma'
  };

  static String getExtension(String urlOrName) {
    if (urlOrName.isEmpty) return '';
    try {
      final clean = urlOrName.split('?').first.split('#').first;
      final segments = clean.split('/');
      final last = segments.isNotEmpty ? segments.last : clean;
      if (last.contains('.')) {
        return last.split('.').last.toLowerCase().trim();
      }
    } catch (e) {
      debugPrint('Extension parse error: $e');
    }
    return '';
  }

  static bool isPdf(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();

    if (explicitType != null) {
      final t = explicitType.toLowerCase();
      if (t == 'pdf' || t.contains('pdf')) return true;
    }

    final ext = getExtension(url);
    if (pdfExtensions.contains(ext)) return true;

    if (lower.contains('/raw/upload/')) return true;
    if (lower.contains('/raw/authenticated/')) return true;
    if (lower.contains('.pdf')) return true;
    if (lower.contains('application/pdf')) return true;
    if (lower.contains('/pdf/')) return true;
    if (lower.contains('type=pdf')) return true;
    if (lower.contains('format=pdf')) return true;

    if (lower.contains('docs.google.com') && lower.contains('export=pdf')) {
      return true;
    }
    return false;
  }

  static bool isImage(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();

    if (explicitType != null) {
      final t = explicitType.toLowerCase();
      if (t == 'image' || t.contains('image')) return true;
    }

    final ext = getExtension(url);
    if (imageExtensions.contains(ext)) return true;

    if (isPdf(url, explicitType: explicitType)) return false;

    if (lower.contains('cloudinary.com') &&
        (lower.contains('/image/upload/') ||
         lower.contains('/image/authenticated/'))) {
      return true;
    }
    if (lower.contains('image/')) return true;
    if (lower.contains('img/')) return true;
    if (lower.contains('photo/')) return true;
    if (lower.contains('picture/')) return true;
    return false;
  }

  static bool isWord(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    if (explicitType != null && explicitType.toLowerCase().contains('word')) {
      return true;
    }
    return wordExtensions.contains(getExtension(url));
  }

  static bool isExcel(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    if (explicitType != null && explicitType.toLowerCase().contains('excel')) {
      return true;
    }
    return excelExtensions.contains(getExtension(url));
  }

  static bool isPowerPoint(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    if (explicitType != null &&
        explicitType.toLowerCase().contains('powerpoint')) {
      return true;
    }
    return pptExtensions.contains(getExtension(url));
  }

  static bool isText(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    if (explicitType != null && explicitType.toLowerCase().contains('text')) {
      return true;
    }
    return textExtensions.contains(getExtension(url));
  }

  static bool isVideo(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    if (explicitType != null && explicitType.toLowerCase().contains('video')) {
      return true;
    }
    return videoExtensions.contains(getExtension(url));
  }

  static bool isAudio(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    if (explicitType != null && explicitType.toLowerCase().contains('audio')) {
      return true;
    }
    return audioExtensions.contains(getExtension(url));
  }

  static bool isGoogleDrive(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('drive.google.com') ||
        lower.contains('docs.google.com');
  }

  static bool isCloudinary(String url) {
    if (url.isEmpty) return false;
    return url.toLowerCase().contains('cloudinary.com');
  }

  static IconData getIcon(String url, {String? explicitType}) {
    if (url.isEmpty) return Icons.insert_drive_file;
    if (isPdf(url, explicitType: explicitType)) return Icons.picture_as_pdf;
    if (isImage(url, explicitType: explicitType)) return Icons.image;
    if (isWord(url, explicitType: explicitType)) return Icons.description;
    if (isExcel(url, explicitType: explicitType)) return Icons.table_chart;
    if (isPowerPoint(url, explicitType: explicitType)) return Icons.slideshow;
    if (isText(url, explicitType: explicitType)) return Icons.text_snippet;
    if (isVideo(url, explicitType: explicitType)) return Icons.video_file;
    if (isAudio(url, explicitType: explicitType)) return Icons.audio_file;
    if (isGoogleDrive(url)) return Icons.cloud;
    return Icons.insert_drive_file;
  }

  static Color getColor(String url, {String? explicitType}) {
    if (url.isEmpty) return Colors.blueGrey;
    if (isPdf(url, explicitType: explicitType)) return Colors.red;
    if (isImage(url, explicitType: explicitType)) return Colors.blue;
    if (isWord(url, explicitType: explicitType)) return Colors.indigo;
    if (isExcel(url, explicitType: explicitType)) return Colors.green;
    if (isPowerPoint(url, explicitType: explicitType)) return Colors.orange;
    if (isText(url, explicitType: explicitType)) return Colors.grey;
    if (isVideo(url, explicitType: explicitType)) return Colors.purple;
    if (isAudio(url, explicitType: explicitType)) return Colors.pink;
    if (isGoogleDrive(url)) return Colors.teal;
    return Colors.blueGrey;
  }

  static String getExtensionFromMime(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'application/pdf':
        return 'pdf';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/bmp':
        return 'bmp';
      case 'image/tiff':
        return 'tiff';
      case 'text/plain':
        return 'txt';
      case 'application/msword':
        return 'doc';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'docx';
      case 'application/vnd.ms-excel':
        return 'xls';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return 'xlsx';
      default:
        return 'file';
    }
  }

  static String getMimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }
}

// ============================================================================
// MAIN FILE VIEWER SCREEN
// ============================================================================
class FileViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? downloadUrl;
  final String? fileType;
  final String? fileName;

  const FileViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.downloadUrl,
    this.fileType,
    this.fileName,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _localFilePath;
  Uint8List? _fileBytes;

  // ✅ Blob URLs for web (only for CORS-friendly sources)
  String? _blobUrl;
  String _blobMimeType = '';

  // ✅ NEW: Flag to indicate we're using direct iframe (external URL)
  bool _useDirectIframe = false;

  final TransformationController _imageController = TransformationController();
  double _zoomScale = 1.0;

  String _effectiveUrl = '';
  String _fileExtension = '';
  bool _isWeb = false;
  bool _isPdf = false;
  bool _isImage = false;
  bool _isWord = false;
  bool _isExcel = false;
  bool _isPowerPoint = false;
  bool _isText = false;
  bool _isVideo = false;
  bool _isAudio = false;
  bool _isGoogleDrive = false;
  bool _isExternalUrl = false;
  bool _isCloudinaryUrl = false;

  @override
  void initState() {
    super.initState();
    _isWeb = kIsWeb;
    _initializeViewer();
  }

  @override
  void dispose() {
    _imageController.dispose();
    if (_isWeb && _blobUrl != null) {
      web_viewer.revokeBlobUrl(_blobUrl!);
    }
    super.dispose();
  }

  void _initializeViewer() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _useDirectIframe = false;
    });

    _effectiveUrl = widget.url.trim();
    if (_effectiveUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No URL provided';
      });
      return;
    }

    // Ensure URL has protocol
    if (!_effectiveUrl.startsWith('http') &&
        !_effectiveUrl.startsWith('file') &&
        !_effectiveUrl.startsWith('blob:')) {
      _effectiveUrl = 'https://$_effectiveUrl';
    }

    _isCloudinaryUrl = _effectiveUrl.contains('cloudinary.com');
    _isExternalUrl = !_isCloudinaryUrl;

    _detectFileType();

    debugPrint('=' * 70);
    debugPrint('📄 FILE VIEWER INITIALIZED');
    debugPrint('   URL: $_effectiveUrl');
    debugPrint('   Is PDF: $_isPdf');
    debugPrint('   Is Image: $_isImage');
    debugPrint('   Is Google Drive: $_isGoogleDrive');
    debugPrint('   Is External: $_isExternalUrl');
    debugPrint('   Is Cloudinary: $_isCloudinaryUrl');
    debugPrint('   Platform: ${_isWeb ? "Web" : "Mobile"}');
    debugPrint('   File Extension: $_fileExtension');
    debugPrint('=' * 70);

    // ✅ Handle Google Drive links specially
    if (_isGoogleDrive) {
      setState(() => _isLoading = false);
      return;
    }

    // ========================================================================
    // ✅ PDF HANDLING
    // ========================================================================
    if (_isPdf) {
      if (_isWeb) {
        // ✅ SMART STRATEGY FOR WEB:
        // - Cloudinary PDFs → download bytes → blob (works, CORS allowed)
        // - External PDFs → direct iframe (bypasses CORS entirely)
        if (_isCloudinaryUrl) {
          _prepareWebBlobUrl('application/pdf');
        } else {
          // External PDF → direct iframe embed (NO download)
          debugPrint('🔗 External PDF detected → using DIRECT iframe embed');
          setState(() {
            _useDirectIframe = true;
            _isLoading = false;
          });
        }
      } else {
        // Mobile: download to local file
        _downloadPdfForMobile();
      }
      return;
    }

    // ========================================================================
    // ✅ IMAGE HANDLING
    // ========================================================================
    if (_isImage) {
      if (_isWeb) {
        // Cloudinary images → blob (works)
        // External images → try direct img tag with crossOrigin
        if (_isCloudinaryUrl) {
          _prepareWebBlobUrl(null);
        } else {
          // External image → direct embed
          debugPrint('🔗 External Image detected → using DIRECT img embed');
          setState(() {
            _useDirectIframe = true;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
      return;
    }

    // ========================================================================
    // ✅ TEXT HANDLING
    // ========================================================================
    if (_isText && _isCloudinaryUrl) {
      _downloadTextFile();
      return;
    }

    // Other file types - show unsupported view
    setState(() => _isLoading = false);
  }

  void _detectFileType() {
    _fileExtension = FileTypeDetector.getExtension(_effectiveUrl);
    final explicitType = widget.fileType?.toLowerCase() ?? '';

    _isPdf = FileTypeDetector.isPdf(_effectiveUrl, explicitType: explicitType);
    _isImage = !_isPdf &&
        FileTypeDetector.isImage(_effectiveUrl, explicitType: explicitType);
    _isWord = FileTypeDetector.isWord(_effectiveUrl, explicitType: explicitType);
    _isExcel =
        FileTypeDetector.isExcel(_effectiveUrl, explicitType: explicitType);
    _isPowerPoint =
        FileTypeDetector.isPowerPoint(_effectiveUrl, explicitType: explicitType);
    _isText = FileTypeDetector.isText(_effectiveUrl, explicitType: explicitType);
    _isVideo =
        FileTypeDetector.isVideo(_effectiveUrl, explicitType: explicitType);
    _isAudio =
        FileTypeDetector.isAudio(_effectiveUrl, explicitType: explicitType);
    _isGoogleDrive = FileTypeDetector.isGoogleDrive(_effectiveUrl);
  }

  // ========================================================================
  // ✅ WEB BLOB PREPARATION (only for Cloudinary / owned files)
  // ========================================================================
  Future<void> _prepareWebBlobUrl(String? explicitMime) async {
    try {
      debugPrint('⬇️ Downloading bytes for web blob...');
      debugPrint('   URL: $_effectiveUrl');

      // ✅ NO custom User-Agent header (avoid preflight)
      final response = await Dio().get<List<int>>(
        _effectiveUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Accept': '*/*',
            // ✅ Do NOT add User-Agent — it triggers CORS preflight
          },
        ),
      );

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Empty response from server');
      }

      final bytes = Uint8List.fromList(response.data!);
      debugPrint('✅ Downloaded ${bytes.length} bytes');

      String mimeType = explicitMime ?? _detectMimeType(response, bytes);
      debugPrint('✅ MIME type: $mimeType');

      String? blobUrl;
      if (mimeType == 'application/pdf') {
        blobUrl = web_viewer.createPdfBlobUrl(bytes);
      } else if (mimeType.startsWith('image/')) {
        blobUrl = web_viewer.createImageBlobUrl(bytes, mimeType);
      } else {
        blobUrl = web_viewer.createPdfBlobUrl(bytes);
      }

      if (blobUrl == null || blobUrl.isEmpty) {
        throw Exception('Failed to create blob URL');
      }

      if (mounted) {
        setState(() {
          _blobUrl = blobUrl;
          _blobMimeType = mimeType;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Web blob preparation failed: $e');
      if (mounted) {
        // ✅ FALLBACK: If download fails, try direct iframe anyway
        debugPrint('🔄 Falling back to DIRECT iframe embed');
        setState(() {
          _useDirectIframe = true;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    }
  }

  String _detectMimeType(Response<List<int>> response, Uint8List bytes) {
    final contentType = response.headers.value('content-type') ?? '';
    if (contentType.isNotEmpty) {
      final lowerType = contentType.toLowerCase();
      if (lowerType.contains('pdf')) return 'application/pdf';
      if (lowerType.contains('image/jpeg')) return 'image/jpeg';
      if (lowerType.contains('image/jpg')) return 'image/jpeg';
      if (lowerType.contains('image/png')) return 'image/png';
      if (lowerType.contains('image/webp')) return 'image/webp';
      if (lowerType.contains('image/gif')) return 'image/gif';
      if (lowerType.contains('image/bmp')) return 'image/bmp';
      if (lowerType.contains('image/svg')) return 'image/svg+xml';
      if (lowerType.startsWith('image/')) {
        return contentType.split(';').first.trim();
      }
    }

    if (bytes.length >= 4) {
      if (bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46) {
        return 'application/pdf';
      }
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'image/jpeg';
      }
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        return 'image/gif';
      }
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
          bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
        return 'image/webp';
      }
      if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
        return 'image/bmp';
      }
    }

    if (_isPdf) return 'application/pdf';
    if (_isImage) return FileTypeDetector.getMimeFromExtension(_fileExtension);
    return 'application/octet-stream';
  }

  Future<void> _downloadPdfForMobile() async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = _getFileNameForLocalStorage();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        final size = await file.length();
        if (size > 0) {
          setState(() {
            _localFilePath = filePath;
            _isLoading = false;
          });
          return;
        }
      }

      await Dio().download(_effectiveUrl, filePath);

      if (mounted) {
        setState(() {
          _localFilePath = filePath;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to download PDF: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _downloadTextFile() async {
    try {
      final response = await Dio().get(
        _effectiveUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (mounted && response.data != null) {
        setState(() {
          _fileBytes = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load text file: $e';
        });
      }
    }
  }

  String _getFileNameForLocalStorage() {
    try {
      if (widget.fileName != null && widget.fileName!.isNotEmpty) {
        final name = widget.fileName!;
        if (name.contains('.')) return name;
        return '$name.$_fileExtension';
      }
      final clean = _effectiveUrl.split('?').first;
      final segments = clean.split('/');
      String name = segments.isNotEmpty ? segments.last : 'file';
      if (!name.contains('.')) {
        name = 'file.$_fileExtension';
      }
      return name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    } catch (_) {
      return 'file.$_fileExtension';
    }
  }

  String _getDownloadFileName() {
    String baseName;
    if (widget.fileName != null && widget.fileName!.isNotEmpty) {
      baseName = widget.fileName!;
      if (baseName.contains('.')) {
        baseName = baseName.split('.').first;
      }
    } else if (widget.title.isNotEmpty) {
      baseName = widget.title;
    } else {
      baseName = 'document';
    }

    String extension = '';
    if (_blobMimeType.isNotEmpty) {
      extension = FileTypeDetector.getExtensionFromMime(_blobMimeType);
    }
    if (extension.isEmpty || extension == 'file') {
      if (_isPdf) {
        extension = 'pdf';
      } else if (_isImage) {
        extension = _fileExtension.isNotEmpty ? _fileExtension : 'jpg';
      } else {
        extension = _fileExtension.isNotEmpty ? _fileExtension : 'file';
      }
    }

    baseName = baseName.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
    if (baseName.isEmpty) baseName = 'document';
    return '$baseName.$extension';
  }

  // ========================================================================
  // ✅ DOWNLOAD FILE (Web + Mobile)
  // ========================================================================
  Future<void> _downloadFile() async {
    try {
      // ✅ WEB: Use blob URL for download (only available for Cloudinary)
      if (_isWeb) {
        if (_blobUrl == null) {
          // For external URLs, open in browser instead
          _showSnackBar(
            'This file is hosted externally. Use "Open in Browser" to download.',
            isError: false,
          );
          // Try opening external URL in new tab
          web_viewer.openExternalUrl(_effectiveUrl);
          return;
        }

        final fileName = _getDownloadFileName();
        debugPrint('📥 Web download: $fileName');

        web_viewer.downloadBlobUrl(_blobUrl!, fileName);
        _showSnackBar('Downloading: $fileName');
        return;
      }

      // ✅ MOBILE: Download and save file
      _showSnackBar('Downloading file...');

      if (_localFilePath != null) {
        final dir = await getDownloadsDirectory() ??
            await getTemporaryDirectory();
        final fileName = _getDownloadFileName();
        final destPath = '${dir.path}/$fileName';

        final srcFile = File(_localFilePath!);
        await srcFile.copy(destPath);

        _showSnackBar('✅ Downloaded to: $destPath');
        return;
      }

      final dir =
          await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final fileName = _getDownloadFileName();
      final filePath = '${dir.path}/$fileName';

      await Dio().download(_effectiveUrl, filePath);
      _showSnackBar('✅ Downloaded to: $filePath');
    } catch (e) {
      debugPrint('❌ Download failed: $e');
      _showSnackBar('Download failed: $e', isError: true);
    }
  }

  void _refreshViewer() {
    if (_isWeb && _blobUrl != null) {
      web_viewer.revokeBlobUrl(_blobUrl!);
      _blobUrl = null;
    }
    _localFilePath = null;
    _fileBytes = null;
    _initializeViewer();
  }

  void _zoomIn() {
    setState(() {
      _zoomScale = (_zoomScale + 0.25).clamp(0.5, 5.0);
      _imageController.value = Matrix4.identity()
        ..setEntry(0, 0, _zoomScale)
        ..setEntry(1, 1, _zoomScale);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomScale = (_zoomScale - 0.25).clamp(0.5, 5.0);
      _imageController.value = Matrix4.identity()
        ..setEntry(0, 0, _zoomScale)
        ..setEntry(1, 1, _zoomScale);
    });
  }

  void _resetZoom() {
    setState(() {
      _zoomScale = 1.0;
      _imageController.value = Matrix4.identity();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openInBrowser() async {
    if (_isWeb) {
      web_viewer.openExternalUrl(_effectiveUrl);
      return;
    }
    try {
      final uri = Uri.parse(_effectiveUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not open in browser', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error opening browser: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isReady = !_isLoading && _errorMessage == null;

    return AppBar(
      title: Text(
        widget.title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: Colors.black87,
      foregroundColor: Colors.white,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).maybePop(),
        tooltip: 'Close',
      ),
      actions: [
        // Zoom controls for images
        if (_isImage && isReady && !_useDirectIframe) ...[
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomOut,
            tooltip: 'Zoom Out',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomIn,
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.aspect_ratio),
            onPressed: _resetZoom,
            tooltip: 'Reset Zoom',
          ),
        ],

        // ✅ DOWNLOAD BUTTON - only when blob URL is available
        if ((_isPdf || _isImage) && isReady && _blobUrl != null)
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadFile,
            tooltip: 'Download',
          ),

        // ✅ Open in browser - always available
        if (isReady)
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: 'Open in Browser',
          ),

        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshViewer,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingView();
    if (_errorMessage != null) return _buildErrorView();
    if (_isPdf) return _buildPdfView();
    if (_isImage) return _buildImageView();
    if (_isText && _fileBytes != null) return _buildTextView();
    if (_isGoogleDrive) return _buildGoogleDriveView();
    return _buildUnsupportedFileView();
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(seconds: 2),
            tween: Tween<double>(begin: 0.8, end: 1.2),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    FileTypeDetector.getIcon(_effectiveUrl,
                        explicitType: widget.fileType),
                    color: FileTypeDetector.getColor(_effectiveUrl,
                        explicitType: widget.fileType),
                    size: 36,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            _isPdf
                ? "Loading PDF..."
                : (_isImage ? "Loading image..." : "Loading file..."),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 20),
            const Text(
              "Failed to Load File",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _refreshViewer,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text("Open Browser"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // ✅ PDF VIEW - SMART STRATEGY
  // ========================================================================
  Widget _buildPdfView() {
    if (_isWeb) {
      // ✅ Case 1: Blob URL available (Cloudinary PDF downloaded)
      if (_blobUrl != null) {
        return web_viewer.buildWebPdfFromBlob(
          blobUrl: _blobUrl!,
          title: widget.title,
        );
      }

      // ✅ Case 2: Direct iframe for external PDF
      if (_useDirectIframe) {
        debugPrint('📄 Using DIRECT iframe for external PDF');
        return web_viewer.buildWebPdfFromUrl(
          url: _effectiveUrl,
          title: widget.title,
        );
      }

      // Should not reach here, but as fallback
      return _buildFileErrorView('PDF not prepared');
    }

    // Mobile
    if (_localFilePath != null) {
      final file = File(_localFilePath!);
      return FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingView();
          }
          if (snapshot.data == true) {
            return PDFView(
              filePath: _localFilePath!,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              pageSnap: true,
              defaultPage: 0,
              fitPolicy: FitPolicy.BOTH,
              onRender: (pages) {
                debugPrint('✅ PDF rendered: $pages pages');
              },
              onError: (error) {
                if (mounted) {
                  setState(() {
                    _errorMessage = 'Failed to display PDF: $error';
                  });
                }
              },
              onViewCreated: (PDFViewController pdfViewController) {
                debugPrint('✅ PDF view created');
              },
            );
          }
          return _buildFileErrorView('File not found');
        },
      );
    }

    return _buildFileErrorView('PDF not downloaded');
  }

  Widget _buildFileErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "Could not load file",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshViewer,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // ✅ IMAGE VIEW
  // ========================================================================
  Widget _buildImageView() {
    if (_isWeb) {
      // Blob URL (Cloudinary)
      if (_blobUrl != null) {
        debugPrint('🖼️ Building web image from blob: $_blobUrl');
        return web_viewer.buildWebImageFromBlob(
          blobUrl: _blobUrl!,
          controller: _imageController,
        );
      }

      // Direct external image
      if (_useDirectIframe) {
        debugPrint('🖼️ Building web image from direct URL');
        return web_viewer.buildWebImageFromUrl(
          url: _effectiveUrl,
          controller: _imageController,
        );
      }
    }

    // Mobile: use cached network image (works fine on mobile)
    return InteractiveViewer(
      transformationController: _imageController,
      minScale: 0.5,
      maxScale: 5.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: _effectiveUrl,
          placeholder: (_, __) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  "Loading image...",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          errorWidget: (_, url, error) {
            debugPrint('❌ Image load error: $error');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image,
                      size: 80, color: Colors.white38),
                  const SizedBox(height: 16),
                  const Text(
                    "Failed to load image",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _refreshViewer,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("Retry"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // TEXT VIEW
  Widget _buildTextView() {
    String content = '';
    try {
      content = String.fromCharCodes(_fileBytes!);
    } catch (e) {
      content = 'Failed to decode: $e';
    }
    return Container(
      color: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          content,
          style: const TextStyle(
            color: Color(0xFFD4D4D4),
            fontSize: 13,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ),
    );
  }

  // GOOGLE DRIVE VIEW
  Widget _buildGoogleDriveView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.teal.withValues(alpha: 0.4), width: 2),
              ),
              child: const Icon(Icons.cloud, size: 80, color: Colors.teal),
            ),
            const SizedBox(height: 28),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Google Drive Document",
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 260,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_new, size: 22),
                label: const Text(
                  "Open in Browser",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UNSUPPORTED FILE VIEW
  Widget _buildUnsupportedFileView() {
    final icon = FileTypeDetector.getIcon(_effectiveUrl,
        explicitType: widget.fileType);
    final color = FileTypeDetector.getColor(_effectiveUrl,
        explicitType: widget.fileType);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: color.withValues(alpha: 0.4), width: 2),
              ),
              child: Icon(icon, size: 80, color: color),
            ),
            const SizedBox(height: 28),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 260,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _openWithExternalApp,
                icon: const Icon(Icons.open_in_new, size: 22),
                label: const Text(
                  "Open File",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWithExternalApp() async {
    if (_isWeb) {
      await _openInBrowser();
      return;
    }
    try {
      String? path = _localFilePath;
      if (path == null) {
        final dir = await getTemporaryDirectory();
        final fileName = _getFileNameForLocalStorage();
        path = '${dir.path}/$fileName';
        final file = File(path);
        if (!await file.exists()) {
          await Dio().download(_effectiveUrl, path);
        }
      }
      await OpenFilex.open(path);
    } catch (e) {
      debugPrint('❌ Open failed: $e');
    }
  }
}