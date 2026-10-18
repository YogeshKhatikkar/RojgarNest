// lib/features/resume/services/resume_pdf_service.dart
// ✅ Full page coverage for ALL formats
// ✅ Fetches profile photo bytes BEFORE building PDF → so it shows in every format

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:rojgarnest/features/resume/presentation/screens/format/resume_format_manager.dart';

class ResumePdfService {
  // ============================================================
  // ✅ FETCH PROFILE PHOTO BYTES
  // ============================================================
  static Future<Uint8List?> _fetchPhotoBytes(String url) async {
    if (url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return null;
    }

    try {
      debugPrint('🖼️ Fetching profile photo for PDF: $url');
      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (response.data != null && response.data!.isNotEmpty) {
        debugPrint('✅ Photo fetched: ${response.data!.length} bytes');
        return Uint8List.fromList(response.data!);
      }
    } catch (e) {
      debugPrint('⚠️ Photo fetch failed: $e');
    }
    return null;
  }

  static String _extractPhotoUrl(Map<String, dynamic> data) {
    try {
      final userInfo = data['user_info'] as Map? ?? {};
      final additional = data['additional_details'] as Map? ?? {};
      final candidates = <dynamic>[
        userInfo['profile_photo_url'],
        additional['profile_photo_url'],
        data['profile_photo_url'],
      ];
      for (final c in candidates) {
        final s = (c ?? '').toString().trim();
        if (s.isNotEmpty &&
            (s.startsWith('http://') || s.startsWith('https://'))) {
          return s;
        }
      }
    } catch (_) {}
    return '';
  }

  // ============================================================
  // CORE: Build PDF bytes
  // ============================================================
  static Future<Uint8List> buildPdfBytes({
    required Map<String, dynamic> data,
    required String styleKey,
    required String colorHex,
  }) async {
    final format = ResumeFormatManager.getFormatById(styleKey) ??
        ResumeFormatManager.defaultFormat;

    debugPrint('📄 ResumePdfService → format: ${format.id} (${format.name})');

    // ✅ Fetch photo bytes first
    final photoUrl = _extractPhotoUrl(data);
    final photoBytes = await _fetchPhotoBytes(photoUrl);

    final enrichedData = Map<String, dynamic>.from(data);
    if (photoBytes != null) {
      enrichedData['_profile_photo_bytes'] = photoBytes;
    }

    final doc = pw.Document();
    const pageFormat = PdfPageFormat.a4;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => format.buildPdfContent(enrichedData, pageFormat),
      ),
    );

    return await doc.save();
  }

  // ============================================================
  // PUBLIC ACTIONS
  // ============================================================
  static Future<void> download({
    required String fileNameBase,
    required Map<String, dynamic> data,
    required String styleKey,
    required String colorHex,
  }) async {
    try {
      final bytes = await buildPdfBytes(
        data: data,
        styleKey: styleKey,
        colorHex: colorHex,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${fileNameBase}_${styleKey}_Resume.pdf',
      );
      debugPrint('✅ Downloaded: ${fileNameBase}_${styleKey}_Resume.pdf');
    } catch (e) {
      debugPrint('❌ Download error: $e');
      rethrow;
    }
  }

  static Future<void> print({
    required Map<String, dynamic> data,
    required String styleKey,
    required String colorHex,
  }) async {
    try {
      final bytes = await buildPdfBytes(
        data: data,
        styleKey: styleKey,
        colorHex: colorHex,
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: '${styleKey}_Resume',
      );
      debugPrint('✅ Sent to printer: $styleKey');
    } catch (e) {
      debugPrint('❌ Print error: $e');
      rethrow;
    }
  }

  static Future<void> share({
    required String fileNameBase,
    required Map<String, dynamic> data,
    required String styleKey,
    required String colorHex,
  }) async {
    try {
      final bytes = await buildPdfBytes(
        data: data,
        styleKey: styleKey,
        colorHex: colorHex,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${fileNameBase}_${styleKey}_Resume.pdf',
      );
      debugPrint('✅ Shared: ${fileNameBase}_${styleKey}_Resume.pdf');
    } catch (e) {
      debugPrint('❌ Share error: $e');
      rethrow;
    }
  }
}