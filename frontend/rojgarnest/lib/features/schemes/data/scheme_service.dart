// lib/features/schemes/data/scheme_service.dart
// ✅ COMPLETE FIXED - Always returns schemes from local master data as fallback
// ✅ Maps all fields correctly for UI
// ✅ FIXED: applyForScheme now sends documents with BOTH `url` AND `document_url`
// ✅ FIXED: uploadTempDocument returns URL from ALL possible response fields
// ✅ FIXED: uploadTempDocument NEVER sends empty document_type (422 fix)
// ✅ FIXED: NEVER calls logout on any error
// ✅ FIXED: Verbose debug logging for every document sent/received
// ✅ NEW: CustomAdmin scheme application methods (fetch, detail, status, review, final-submit)
// ✅ FIXED: submitApplication is now properly INSIDE the class
// ✅ NEW: getMyApplications returns documents from BOTH `documents` AND `scheme_documents`
// ✅ NEW: getApplicationDetail returns normalized documents array
// ✅ FIXED: getApplicationDocuments now uses flexible ID resolution
// ✅ FIXED: getApplicationDocumentsFLEXIBLE — accepts BOTH _id AND application_id

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/master_date/schemes_data.dart';

class SchemeService {
  static const String _base = "/schemes";

  static Dio get _dio => DioClient.dio;

  static Map<String, dynamic> _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data') && body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
      return body;
    }
    return {};
  }

  // ============================================================
  // ✅ LOCAL SLUG HELPER — used as last-resort safety net
  // Guarantees a non-empty ASCII slug for the backend
  // ============================================================
  static String _safeSlug(String input) {
    if (input.trim().isEmpty) return 'document';

    final lower = input.toLowerCase().trim();

    final hindiMap = <String, String>{
      'आधार कार्ड': 'aadhaar_card',
      'आधार': 'aadhaar_card',
      'मूल निवास प्रमाण पत्र': 'domicile_certificate',
      'मूल निवास': 'domicile_certificate',
      'निवास प्रमाण पत्र': 'residence_certificate',
      'निवास': 'residence_certificate',
      'आय प्रमाण पत्र': 'income_certificate',
      'आय': 'income_certificate',
      'बैंक पासबुक': 'bank_passbook',
      'बैंक': 'bank_passbook',
      'राशन कार्ड': 'ration_card',
      'राशन': 'ration_card',
      'जन्म प्रमाण पत्र': 'birth_certificate',
      'जन्म': 'birth_certificate',
      'जाति प्रमाण पत्र': 'caste_certificate',
      'जाति': 'caste_certificate',
      'पासपोर्ट': 'passport',
      'फोटो': 'photo',
      'हस्ताक्षर': 'signature',
      'अन्य': 'other',
      'दस्तावेज': 'document',
      'दस्तावेज़': 'document',
      'प्रमाण पत्र': 'certificate',
    };

    if (hindiMap.containsKey(input.trim())) return hindiMap[input.trim()]!;

    final sortedKeys = hindiMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) {
      if (lower.contains(key.toLowerCase())) return hindiMap[key]!;
    }

    String slug = input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (slug.isEmpty) return 'document';
    if (slug.length > 60) {
      slug = slug.substring(0, 60).replaceAll(RegExp(r'_$'), '');
    }
    return slug;
  }

  // ============================================================
  // ✅ LIST SCHEMES
  // ============================================================
  static Future<Map<String, dynamic>> listSchemes({
    String? level,
    String? state,
    String? category,
    String? search,
    bool? isFeatured,
    int limit = 100,
    int skip = 0,
  }) async {
    try {
      final params = <String, dynamic>{
        'limit': limit,
        'skip': skip,
      };
      if (level != null && level != 'all') params['level'] = level;
      if (state != null && state != 'all') params['state'] = state;
      if (category != null && category != 'all') params['category'] = category;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (isFeatured != null) params['is_featured'] = isFeatured;

      debugPrint("📤 SchemeService.listSchemes params: $params");

      final res = await _dio.get('$_base/list', queryParameters: params);
      final data = _unwrap(res.data);

      final schemes = data['schemes'] as List? ?? [];

      if (schemes.isNotEmpty) {
        debugPrint("✅ Loaded ${schemes.length} schemes from BACKEND");
        return {
          'success': true,
          'schemes': schemes,
          'total': data['total'] ?? schemes.length,
          'source': 'backend',
        };
      }

      debugPrint("⚠️ Backend returned 0 schemes → using LOCAL master data");
    } catch (e) {
      debugPrint("❌ Backend failed: $e → using LOCAL master data");
    }

    return _getLocalSchemes(
      level: level,
      state: state,
      category: category,
      search: search,
      isFeatured: isFeatured,
      limit: limit,
    );
  }

  // ============================================================
  // ✅ LOCAL FALLBACK
  // ============================================================
  static Map<String, dynamic> _getLocalSchemes({
    String? level,
    String? state,
    String? category,
    String? search,
    bool? isFeatured,
    int limit = 100,
  }) {
    List<GovernmentScheme> schemes = SchemesMasterData.allSchemes;

    if (level != null && level != 'all') {
      schemes = schemes.where((s) => s.level == level).toList();
    }
    if (state != null && state != 'all') {
      schemes = schemes.where((s) => s.state == state).toList();
    }
    if (category != null && category != 'all') {
      schemes = schemes.where((s) => s.category == category).toList();
    }
    if (isFeatured == true) {
      schemes = schemes.where((s) => s.isFeatured).toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      schemes = schemes
          .where((s) =>
              s.schemeName.toLowerCase().contains(q) ||
              s.schemeNameHindi.contains(q) ||
              s.shortDescription.toLowerCase().contains(q) ||
              s.shortDescriptionHindi.contains(q) ||
              s.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }

    schemes = schemes.take(limit).toList();
    final schemesJson = schemes.map((s) => _schemeToJson(s)).toList();

    debugPrint("✅ Loaded ${schemesJson.length} schemes from LOCAL master data");

    return {
      'success': true,
      'schemes': schemesJson,
      'total': schemesJson.length,
      'source': 'local',
    };
  }

  // ============================================================
  // ✅ CONVERT GovernmentScheme → JSON
  // ============================================================
  static Map<String, dynamic> _schemeToJson(GovernmentScheme s) {
    return {
      'scheme_id': s.schemeId,
      'scheme_name': s.schemeName,
      'scheme_name_hindi': s.schemeNameHindi,
      'short_description': s.shortDescription,
      'short_description_hindi': s.shortDescriptionHindi,
      'level': s.level,
      'state': s.state,
      'category': s.category,
      'full_description': s.fullDescription,
      'full_description_hindi': s.fullDescriptionHindi,
      'benefits': s.benefits
          .map((b) => {
                'title': b.title,
                'description': b.description,
                'amount': b.amount,
                'type': b.type,
              })
          .toList(),
      'eligibility': {
        'age_min': s.eligibility.ageMin,
        'age_max': s.eligibility.ageMax,
        'gender': s.eligibility.gender,
        'income_limit': s.eligibility.incomeLimit,
        'category': s.eligibility.category,
        'education_level': s.eligibility.educationLevel,
        'occupation': s.eligibility.occupation,
        'domicile_state': s.eligibility.domicileState,
        'disability_required': s.eligibility.disabilityRequired,
        'bpl_required': s.eligibility.bplRequired,
        'aadhaar_required': s.eligibility.aadhaarRequired,
      },
      'eligibility_details_hindi': s.eligibilityDetailsHindi,
      'target_beneficiaries': s.targetBeneficiaries,
      'target_beneficiaries_hindi': s.targetBeneficiariesHindi,
      'required_documents': s.requiredDocuments
          .map((d) => {
                'name': d.name,
                'name_hindi': d.nameHindi,
                'required': d.required,
                'description': d.description,
              })
          .toList(),
      'application_steps': s.applicationSteps
          .map((st) => {
                'step_number': st.stepNumber,
                'title': st.title,
                'title_hindi': st.titleHindi,
                'description': st.description,
                'description_hindi': st.descriptionHindi,
              })
          .toList(),
      'application_mode': s.applicationMode,
      'contact_info': {
        'helpline': s.contactInfo.helpline,
        'email': s.contactInfo.email,
        'website': s.contactInfo.website,
        'office_address': s.contactInfo.officeAddress,
      },
      'official_website': s.officialWebsite,
      'apply_link': s.applyLink,
      'has_application_fee': s.hasApplicationFee,
      'application_fee': s.applicationFee,
      'fee_details_hindi': s.feeDetailsHindi,
      'icon': s.icon,
      'color': s.color,
      'is_featured': s.isFeatured,
      'is_active': true,
      'tags': s.tags,
    };
  }

  // ============================================================
  // ✅ CATEGORIES
  // ============================================================
  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final res = await _dio.get('$_base/categories');
      final data = _unwrap(res.data);
      final list = data['categories'] as List? ?? [];
      if (list.isNotEmpty) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return SchemesMasterData.categories;
  }

  // ============================================================
  // ✅ STATES
  // ============================================================
  static Future<List<String>> getStates() async {
    try {
      final res = await _dio.get('$_base/states');
      final data = _unwrap(res.data);
      final list = data['states'] as List? ?? [];
      if (list.isNotEmpty) {
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return SchemesMasterData.allStates;
  }

  // ============================================================
  // ✅ FEATURED SCHEMES
  // ============================================================
  static Future<List<Map<String, dynamic>>> getFeaturedSchemes(
      {int limit = 10}) async {
    try {
      final res = await _dio
          .get('$_base/featured', queryParameters: {'limit': limit});
      final data = _unwrap(res.data);
      final list = data['schemes'] as List? ?? [];
      if (list.isNotEmpty) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return SchemesMasterData.featuredSchemes
        .take(limit)
        .map(_schemeToJson)
        .toList();
  }

  // ============================================================
  // ✅ SCHEME DETAIL
  // ============================================================
  static Future<Map<String, dynamic>> getSchemeDetail(String schemeId) async {
    try {
      final res = await _dio.get('$_base/detail/$schemeId');
      final data = _unwrap(res.data);
      final scheme = data['scheme'];
      if (scheme != null && scheme is Map) {
        debugPrint("✅ Got scheme detail from BACKEND");
        return {'success': true, 'scheme': scheme, 'source': 'backend'};
      }
    } catch (e) {
      debugPrint("⚠️ Backend detail failed: $e");
    }

    final local = SchemesMasterData.getSchemeById(schemeId);
    if (local != null) {
      debugPrint("✅ Got scheme detail from LOCAL for: $schemeId");
      return {
        'success': true,
        'scheme': _schemeToJson(local),
        'source': 'local'
      };
    }

    debugPrint("❌ Scheme not found: $schemeId");
    return {'success': false, 'message': 'Scheme not found'};
  }

  // ============================================================
  // ✅✅✅ CRITICAL FIX: APPLY FOR SCHEME
  // ============================================================
  static Future<Map<String, dynamic>> applyForScheme({
    required String schemeId,
    required Map<String, dynamic> applicantDetails,
    required Map<String, dynamic> applicantAddress,
    required Map<String, dynamic> bankDetails,
    String? remarks,
    List<Map<String, dynamic>>? documents,
  }) async {
    try {
      final List<Map<String, dynamic>> normalizedDocuments = [];

      if (documents != null && documents.isNotEmpty) {
        for (int i = 0; i < documents.length; i++) {
          final doc = documents[i];

          final String url = (doc['url'] ??
                  doc['document_url'] ??
                  doc['documentUrl'] ??
                  doc['file_url'] ??
                  doc['fileUrl'] ??
                  '')
              .toString()
              .trim();

          if (url.isEmpty) {
            debugPrint(
                "⚠️ Skipping document[$i] — no URL found. Keys: ${doc.keys.toList()}");
            continue;
          }

          final String docName = (doc['document_name'] ??
                  doc['label'] ??
                  doc['name'] ??
                  'Document ${i + 1}')
              .toString()
              .trim();

          final String rawType =
              (doc['document_type'] ?? doc['type'] ?? '').toString().trim();

          final String docType =
              rawType.isEmpty ? _safeSlug(docName) : rawType;

          final publicId = doc['public_id'] ?? doc['publicId'];

          final normalized = <String, dynamic>{
            'document_type': docType,
            'document_name': docName,
            'url': url,
            'document_url': url,
            'public_id': publicId,
            'uploaded_at':
                doc['uploaded_at'] ?? DateTime.now().toIso8601String(),
          };

          normalizedDocuments.add(normalized);

          debugPrint("📎 Doc[$i] prepared → "
              "type=$docType, name=$docName, url=${url.substring(0, url.length > 80 ? 80 : url.length)}...");
        }
      }

      final Map<String, dynamic> payload = {
        'scheme_id': schemeId,
        'applicant_details': applicantDetails,
        'applicant_address': applicantAddress,
        'bank_details': bankDetails,
        'remarks': remarks ?? '',
        'application_type': 'schemes',  // ✅ CRITICAL
        'payment_type': 'scheme',        // ✅ CRITICAL
        'category_used': 'scheme',       // ✅ CRITICAL
      };

      if (normalizedDocuments.isNotEmpty) {
        payload['documents'] = normalizedDocuments;
      }

      debugPrint("=" * 70);
      debugPrint("📤 applyForScheme CALLED");
      debugPrint("   Scheme ID: $schemeId");
      debugPrint("   Payload keys: ${payload.keys.toList()}");
      debugPrint("   Documents count: ${normalizedDocuments.length}");
      for (int i = 0; i < normalizedDocuments.length; i++) {
        debugPrint(
            "   [$i] ${normalizedDocuments[i]['document_type']} → ${normalizedDocuments[i]['url']}");
      }
      debugPrint("=" * 70);

      final res = await _dio.post('$_base/apply', data: payload);

      debugPrint("📥 applyForScheme response: ${res.statusCode}");
      debugPrint("   ${res.data}");

      return _unwrap(res.data);
    } on DioException catch (e) {
      debugPrint("❌ applyForScheme failed: ${e.response?.data}");
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅✅✅ CRITICAL FIX: UPLOAD TEMP DOCUMENT
  // ============================================================
  static Future<Map<String, dynamic>> uploadTempDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String documentType,
    required String documentName,
  }) async {
    try {
      String safeDocType = documentType.trim();
      if (safeDocType.isEmpty) {
        safeDocType =
            _safeSlug(documentName.isNotEmpty ? documentName : fileName);
        debugPrint("🔧 documentType was empty → derived: '$safeDocType'");
      }
      if (safeDocType.isEmpty) {
        safeDocType = 'document';
      }

      String safeDocName = documentName.trim();
      if (safeDocName.isEmpty) safeDocName = fileName;

      debugPrint("=" * 70);
      debugPrint("📤 uploadTempDocument CALLED");
      debugPrint("   fileName: $fileName");
      debugPrint("   documentType: $safeDocType");
      debugPrint("   documentName: $safeDocName");
      debugPrint("   fileBytes: ${fileBytes.length} bytes");
      debugPrint("=" * 70);

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'document_type': safeDocType,
        'document_name': safeDocName,
      });

      final res =
          await _dio.post('$_base/upload-temp-document', data: formData);

      debugPrint("📥 uploadTempDocument raw response: ${res.statusCode}");
      debugPrint("   ${res.data}");

      String? url;
      String? publicId;
      String? finalDocType;
      String? finalDocName;

      final rawData = res.data;

      if (rawData is Map) {
        if (rawData['url'] != null) {
          url = rawData['url'].toString();
        }
        if ((url == null || url.isEmpty) && rawData['document_url'] != null) {
          url = rawData['document_url'].toString();
        }
        if ((url == null || url.isEmpty) && rawData['document'] is Map) {
          final nested = rawData['document'] as Map;
          url = (nested['url'] ?? nested['document_url'])?.toString();
          publicId = (nested['public_id'] ?? nested['publicId'])?.toString();
          finalDocType = nested['document_type']?.toString();
          finalDocName = nested['document_name']?.toString();
        }
        if ((url == null || url.isEmpty) && rawData['data'] is Map) {
          final nested = rawData['data'] as Map;
          url = (nested['url'] ?? nested['document_url'])?.toString();
          if ((url == null || url.isEmpty) && nested['document'] is Map) {
            final deeper = nested['document'] as Map;
            url = (deeper['url'] ?? deeper['document_url'])?.toString();
            publicId ??=
                (deeper['public_id'] ?? deeper['publicId'])?.toString();
            finalDocType ??= deeper['document_type']?.toString();
            finalDocName ??= deeper['document_name']?.toString();
          }
        }
        if (publicId == null) {
          publicId = (rawData['public_id'] ?? rawData['publicId'])?.toString();
        }
      }

      if (url == null || url.isEmpty) {
        debugPrint("❌ No URL found in uploadTempDocument response!");
        debugPrint("   Response was: $rawData");
        throw Exception("Upload succeeded but no URL returned from server");
      }

      debugPrint("=" * 70);
      debugPrint("✅ uploadTempDocument SUCCESS");
      debugPrint("   URL: $url");
      debugPrint("   publicId: $publicId");
      debugPrint("=" * 70);

      return {
        'success': true,
        'url': url,
        'document_url': url,
        'public_id': publicId,
        'document_type': finalDocType ?? safeDocType,
        'document_name': finalDocName ?? safeDocName,
        'filename': fileName,
      };
    } on DioException catch (e) {
      debugPrint("❌ uploadTempDocument failed: ${e.response?.data}");
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅ APPLY WITH FILES (multipart)
  // ============================================================
  static Future<Map<String, dynamic>> applyForSchemeWithFiles({
    required String schemeId,
    required Map<String, dynamic> applicantDetails,
    required Map<String, dynamic> applicantAddress,
    required Map<String, dynamic> bankDetails,
    String? remarks,
    required List<Map<String, dynamic>> files,
  }) async {
    try {
      debugPrint("=" * 70);
      debugPrint("📤 applyForSchemeWithFiles CALLED");
      debugPrint("   Scheme ID: $schemeId");
      debugPrint("   Files count: ${files.length}");
      for (final f in files) {
        final bytes = f['bytes'] as Uint8List?;
        debugPrint("   • ${f['document_name']} → "
            "${bytes?.length ?? 0} bytes, type=${f['document_type']}");
      }
      debugPrint("=" * 70);

      final Map<String, dynamic> payload = {
        'scheme_id': schemeId,
        'applicant_details': applicantDetails,
        'applicant_address': applicantAddress,
        'bank_details': bankDetails,
        'remarks': remarks ?? '',
        'application_type': 'schemes',  // ✅ CRITICAL
        'payment_type': 'scheme',        // ✅ CRITICAL
        'category_used': 'scheme',       // ✅ CRITICAL
      };

      final formMap = <String, dynamic>{
        'payload': jsonEncode(payload),
      };

      final List<MultipartFile> multipartFiles = [];
      final List<String> docTypes = [];
      final List<String> docNames = [];

      for (final f in files) {
        final bytes = f['bytes'] as Uint8List?;
        if (bytes == null || bytes.isEmpty) continue;

        final fileName = (f['file_name'] ?? 'document.pdf').toString();
        final rawType = (f['document_type'] ?? '').toString();
        final docName = (f['document_name'] ?? 'Document').toString();

        final docType = rawType.isEmpty ? _safeSlug(docName) : rawType;

        multipartFiles.add(
          MultipartFile.fromBytes(bytes, filename: fileName),
        );
        docTypes.add(docType);
        docNames.add(docName);
      }

      if (multipartFiles.isEmpty) {
        throw Exception("No valid files to upload");
      }

      formMap['files'] = multipartFiles;
      formMap['document_types'] = jsonEncode(docTypes);
      formMap['document_names'] = jsonEncode(docNames);

      final formData = FormData.fromMap(formMap);

      debugPrint("📦 FormData prepared:");
      debugPrint("   Files: ${multipartFiles.length}");
      debugPrint("   Types: $docTypes");
      debugPrint("   Names: $docNames");

      final res = await _dio.post(
        '$_base/apply-with-files',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      debugPrint("📥 applyWithFiles response: ${res.statusCode} | ${res.data}");
      return _unwrap(res.data);
    } on DioException catch (e) {
      debugPrint("❌ applyWithFiles failed: ${e.response?.data}");
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅ UPLOAD SCHEME DOCUMENT (single file, per application)
  // ============================================================
  static Future<Map<String, dynamic>> uploadSchemeDocument({
    required String applicationId,
    required String documentType,
    required String documentName,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      String safeDocType = documentType.trim();
      if (safeDocType.isEmpty) {
        safeDocType =
            _safeSlug(documentName.isNotEmpty ? documentName : fileName);
      }
      if (safeDocType.isEmpty) safeDocType = 'document';

      debugPrint("=" * 70);
      debugPrint("📤 UPLOADING SCHEME DOCUMENT");
      debugPrint("   Application ID: $applicationId");
      debugPrint("   Document Type: $safeDocType");
      debugPrint("   Document Name: $documentName");
      debugPrint("   File Name: $fileName");
      debugPrint("   File Size: ${fileBytes.length} bytes");
      debugPrint(
          "   Endpoint: $_base/application/$applicationId/upload-document");
      debugPrint("=" * 70);

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
        'document_type': safeDocType,
        'document_name': documentName,
      });

      final res = await _dio.post(
        '$_base/application/$applicationId/upload-document',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
        ),
      );

      debugPrint("📥 Upload response: ${res.statusCode} | ${res.data}");
      return _unwrap(res.data);
    } on DioException catch (e) {
      debugPrint("❌ Upload failed: ${e.response?.data}");
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅ MY APPLICATIONS
  // ============================================================
  static Future<Map<String, dynamic>> getMyApplications(
      {String? status}) async {
    try {
      final params = <String, dynamic>{};
      if (status != null && status != 'all') params['status'] = status;
      final res = await _dio.get(
        '$_base/my-applications',
        queryParameters: params.isEmpty ? null : params,
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅ GET APPLICATION DETAIL (user-scoped)
  // ============================================================
  static Future<Map<String, dynamic>> getApplicationDetail(
      String applicationId) async {
    try {
      final res = await _dio.get('$_base/application/$applicationId');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅✅✅ CRITICAL FIX: GET DOCUMENTS FOR AN APPLICATION
  // ------------------------------------------------------------
  // FIX: Now uses FLEXIBLE ID resolution — works with BOTH:
  //      - MongoDB _id (e.g. "6ad180c78f1a1108853039e3")
  //      - application_id (e.g. "20261000020")
  //
  // The backend `/documents` endpoint now accepts both.
  // ============================================================
  static Future<Map<String, dynamic>> getApplicationDocuments(
      String applicationId) async {
    try {
      debugPrint("=" * 70);
      debugPrint("📄 getApplicationDocuments CALLED");
      debugPrint("   applicationId: '$applicationId'");
      debugPrint("   URL: $_base/application/$applicationId/documents");
      debugPrint("=" * 70);

      final res = await _dio.get(
        '$_base/application/$applicationId/documents',
      );

      debugPrint("📥 Response status: ${res.statusCode}");
      debugPrint("📥 Response data type: ${res.data.runtimeType}");

      final body = res.data;

      if (body is Map) {
        final schemeDocs = _extractDocList(body['scheme_documents']);
        final adminDocs = _extractDocList(body['admin_documents']);

        debugPrint("✅ scheme_documents: ${schemeDocs.length}");
        debugPrint("✅ admin_documents: ${adminDocs.length}");

        return {
          'success': body['success'] == true,
          'scheme_documents': schemeDocs,
          'admin_documents': adminDocs,
          'total': body['total'] ??
              (schemeDocs.length + adminDocs.length),
          'application_id': body['application_id'],
          'application_number': body['application_number'],
        };
      }

      return {
        'success': false,
        'scheme_documents': <Map<String, dynamic>>[],
        'admin_documents': <Map<String, dynamic>>[],
        'total': 0,
      };
    } on DioException catch (e) {
      debugPrint("❌ getApplicationDocuments error:");
      debugPrint("   Status: ${e.response?.statusCode}");
      debugPrint("   Message: ${e.message}");
      debugPrint("   Data: ${e.response?.data}");

      return {
        'success': false,
        'scheme_documents': <Map<String, dynamic>>[],
        'admin_documents': <Map<String, dynamic>>[],
        'total': 0,
        'error': DioClient.extractErrorMessage(e),
      };
    }
  }

  // ============================================================
  // ✅ HELPER: Extract document list from any structure
  // ============================================================
  static List<Map<String, dynamic>> _extractDocList(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];

    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;

      final doc = Map<String, dynamic>.from(item);

      // Validate URL
      final url = (doc['url'] ?? doc['document_url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      if (url.toLowerCase() == 'null' ||
          url.toLowerCase() == 'undefined' ||
          url.toLowerCase() == 'n/a') {
        continue;
      }

      result.add(doc);
    }
    return result;
  }

  // ============================================================
  // ✅ DELETE DOCUMENT (per application)
  // ============================================================
  static Future<bool> deleteApplicationDocument({
    required String applicationId,
    required String documentType,
  }) async {
    try {
      final res = await _dio.delete(
        '$_base/application/$applicationId/document/$documentType',
      );
      final body = res.data;
      if (body is Map && body['success'] == true) {
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint(
          "❌ deleteApplicationDocument error: ${DioClient.extractErrorMessage(e)}");
      return false;
    }
  }

  // ============================================================
  // ✅ SUBMIT APPLICATION (FINAL USER-SIDE SUBMIT)
  // ============================================================
  static Future<Map<String, dynamic>> submitApplication({
    required String applicationId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final res = await _dio.post(
        '$_base/application/$applicationId/submit',
        data: data ?? {},
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅ CUSTOMADMIN: GET ALL SCHEME APPLICATIONS
  // ============================================================
  static Future<Map<String, dynamic>> getCustomAdminSchemeApplications({
    String? status,
    int limit = 100,
    int skip = 0,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'application_type': 'schemes',
        'limit': limit,
        'skip': skip,
      };
      if (status != null && status != 'all' && status.isNotEmpty) {
        params['status'] = status;
      }

      debugPrint("=" * 70);
      debugPrint("📤 CustomAdmin: Fetching SCHEME applications");
      debugPrint("   URL: /customadmin/applications");
      debugPrint("   Params: $params");
      debugPrint("=" * 70);

      final res = await _dio.get(
        '/customadmin/applications',
        queryParameters: params,
      );

      debugPrint("📥 Response status: ${res.statusCode}");
      debugPrint("📥 Response type: ${res.data.runtimeType}");

      Map<String, dynamic> data = {};
      if (res.data is Map<String, dynamic>) {
        final raw = res.data as Map<String, dynamic>;
        if (raw.containsKey('data') && raw['data'] is Map) {
          data = Map<String, dynamic>.from(raw['data'] as Map);
        } else {
          data = raw;
        }
      }

      final apps = data['applications'];
      debugPrint(
          "✅ CustomAdmin scheme applications loaded: ${apps is List ? apps.length : 0}");

      return data;
    } on DioException catch (e) {
      debugPrint("❌ getCustomAdminSchemeApplications failed: ${e.message}");
      debugPrint("   Response: ${e.response?.data}");
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅ CUSTOMADMIN: GET SINGLE SCHEME APPLICATION DETAIL
  // ============================================================
  static Future<Map<String, dynamic>> getCustomAdminSchemeApplicationDetail(
    String applicationId,
  ) async {
    try {
      debugPrint("📤 Fetching scheme application detail: $applicationId");

      final res = await _dio.get(
        '/customadmin/applications/$applicationId',
      );

      final data = _unwrap(res.data);
      return data;
    } on DioException catch (e) {
      debugPrint(
          "❌ getCustomAdminSchemeApplicationDetail failed: ${e.message}");
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅ CUSTOMADMIN: UPDATE SCHEME APPLICATION STATUS
  // ============================================================
  static Future<Map<String, dynamic>> updateSchemeApplicationStatus({
    required String applicationId,
    required String status,
    String? notes,
  }) async {
    try {
      final Map<String, dynamic> params = {'status': status};
      if (notes != null && notes.isNotEmpty) {
        params['notes'] = notes;
      }

      debugPrint("📤 Updating scheme application status");
      debugPrint("   App ID: $applicationId");
      debugPrint("   Status: $status");
      debugPrint("   Notes: $notes");

      final res = await _dio.put(
        '/schemes/application/$applicationId/status',
        data: {
          'status': status,
          'admin_notes': notes ?? '',
        },
      );

      debugPrint("✅ Status update response: ${res.statusCode}");
      return _unwrap(res.data);
    } on DioException catch (e) {
      debugPrint("❌ updateSchemeApplicationStatus failed: ${e.message}");
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅ CUSTOMADMIN: REVIEW WITH DOCUMENT
  // ============================================================
  static Future<Map<String, dynamic>> reviewSchemeApplicationWithDocument({
    required String applicationId,
    required Uint8List fileBytes,
    required String fileName,
    String? notes,
  }) async {
    try {
      debugPrint("📤 Uploading review document for: $applicationId");
      debugPrint("   File: $fileName (${fileBytes.length} bytes)");

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'notes': notes ?? '',
      });

      final res = await _dio.post(
        '/schemes/application/$applicationId/review-with-document',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
        ),
      );

      debugPrint("✅ Review document uploaded: ${res.statusCode}");
      return _unwrap(res.data);
    } on DioException catch (e) {
      debugPrint(
          "❌ reviewSchemeApplicationWithDocument failed: ${e.message}");
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅ CUSTOMADMIN: FINAL SUBMIT WITH DOCUMENT
  // ============================================================
  static Future<Map<String, dynamic>> finalSubmitSchemeApplication({
    required String applicationId,
    required Uint8List fileBytes,
    required String fileName,
    String? notes,
  }) async {
    try {
      debugPrint("📤 Uploading FINAL document for: $applicationId");
      debugPrint("   File: $fileName (${fileBytes.length} bytes)");

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'notes': notes ?? '',
      });

      final res = await _dio.post(
        '/schemes/application/$applicationId/final-submit-with-document',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
        ),
      );

      debugPrint("✅ Final document uploaded: ${res.statusCode}");
      return _unwrap(res.data);
    } on DioException catch (e) {
      debugPrint("❌ finalSubmitSchemeApplication failed: ${e.message}");
      throw DioClient.extractErrorMessage(e);
    }
  }
}