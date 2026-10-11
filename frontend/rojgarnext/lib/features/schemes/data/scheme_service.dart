// lib/features/schemes/data/scheme_service.dart
// ✅ COMPLETE FIXED - Always returns schemes from local master data as fallback
// ✅ Maps all fields correctly for UI
// ✅ FIXED: applyForScheme now sends documents with BOTH `url` AND `document_url`
// ✅ FIXED: uploadTempDocument returns URL from ALL possible response fields
// ✅ FIXED: uploadTempDocument NEVER sends empty document_type (422 fix)
// ✅ FIXED: NEVER calls logout on any error
// ✅ FIXED: Verbose debug logging for every document sent/received

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/master_date/schemes_data.dart';

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
      schemes = schemes.where((s) =>
          s.schemeName.toLowerCase().contains(q) ||
          s.schemeNameHindi.contains(q) ||
          s.shortDescription.toLowerCase().contains(q) ||
          s.shortDescriptionHindi.contains(q) ||
          s.tags.any((t) => t.toLowerCase().contains(q))
      ).toList();
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
      'benefits': s.benefits.map((b) => {
        'title': b.title,
        'description': b.description,
        'amount': b.amount,
        'type': b.type,
      }).toList(),
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
      'required_documents': s.requiredDocuments.map((d) => {
        'name': d.name,
        'name_hindi': d.nameHindi,
        'required': d.required,
        'description': d.description,
      }).toList(),
      'application_steps': s.applicationSteps.map((st) => {
        'step_number': st.stepNumber,
        'title': st.title,
        'title_hindi': st.titleHindi,
        'description': st.description,
        'description_hindi': st.descriptionHindi,
      }).toList(),
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
  static Future<List<Map<String, dynamic>>> getFeaturedSchemes({int limit = 10}) async {
    try {
      final res = await _dio.get('$_base/featured', queryParameters: {'limit': limit});
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
  // Now sends documents with BOTH `url` AND `document_url`
  // to guarantee the backend picks up the URL
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
      // ============================================================
      // ✅ CRITICAL FIX: Normalize each document entry
      // Send BOTH `url` AND `document_url` so no matter which field
      // the backend reads, it will find the URL.
      // ============================================================
      final List<Map<String, dynamic>> normalizedDocuments = [];

      if (documents != null && documents.isNotEmpty) {
        for (int i = 0; i < documents.length; i++) {
          final doc = documents[i];

          // Try every possible URL field name
          final String url = (doc['url'] ??
                  doc['document_url'] ??
                  doc['documentUrl'] ??
                  doc['file_url'] ??
                  doc['fileUrl'] ??
                  '')
              .toString()
              .trim();

          if (url.isEmpty) {
            debugPrint("⚠️ Skipping document[$i] — no URL found. Keys: ${doc.keys.toList()}");
            continue;
          }

          // Try every possible name field name
          final String docName = (doc['document_name'] ??
                  doc['label'] ??
                  doc['name'] ??
                  'Document ${i + 1}')
              .toString()
              .trim();

          // Try every possible type field name
          final String rawType = (doc['document_type'] ??
                  doc['type'] ??
                  '')
              .toString()
              .trim();

          // ✅ CRITICAL: NEVER send an empty document_type
          final String docType =
              rawType.isEmpty ? _safeSlug(docName) : rawType;

          final publicId = doc['public_id'] ?? doc['publicId'];

          final normalized = <String, dynamic>{
            'document_type': docType,
            'document_name': docName,
            // ✅ Send BOTH field names — backend accepts either
            'url': url,
            'document_url': url,
            'public_id': publicId,
            'uploaded_at': doc['uploaded_at'] ?? DateTime.now().toIso8601String(),
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
        debugPrint("   [$i] ${normalizedDocuments[i]['document_type']} → ${normalizedDocuments[i]['url']}");
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
  // ------------------------------------------------------------
  // 1. NEVER sends empty document_type (previous cause of 422)
  // 2. Extracts URL from ALL possible response field names
  // ============================================================
  static Future<Map<String, dynamic>> uploadTempDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String documentType,
    required String documentName,
  }) async {
    try {
      // ✅ CRITICAL FIX: Guarantee a non-empty document_type
      String safeDocType = documentType.trim();
      if (safeDocType.isEmpty) {
        safeDocType = _safeSlug(documentName.isNotEmpty ? documentName : fileName);
        debugPrint("🔧 documentType was empty → derived: '$safeDocType'");
      }
      // ✅ Absolute last-resort guard
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

      final res = await _dio.post('$_base/upload-temp-document', data: formData);

      debugPrint("📥 uploadTempDocument raw response: ${res.statusCode}");
      debugPrint("   ${res.data}");

      // ✅ Extract URL from ANY possible location in response
      String? url;
      String? publicId;
      String? finalDocType;
      String? finalDocName;

      final rawData = res.data;

      if (rawData is Map) {
        // Case 1: Top-level `url`
        if (rawData['url'] != null) {
          url = rawData['url'].toString();
        }
        // Case 2: Top-level `document_url`
        if ((url == null || url.isEmpty) && rawData['document_url'] != null) {
          url = rawData['document_url'].toString();
        }
        // Case 3: Nested inside `document` object
        if ((url == null || url.isEmpty) && rawData['document'] is Map) {
          final nested = rawData['document'] as Map;
          url = (nested['url'] ?? nested['document_url'])?.toString();
          publicId = (nested['public_id'] ?? nested['publicId'])?.toString();
          finalDocType = nested['document_type']?.toString();
          finalDocName = nested['document_name']?.toString();
        }
        // Case 4: Nested inside `data` object
        if ((url == null || url.isEmpty) && rawData['data'] is Map) {
          final nested = rawData['data'] as Map;
          url = (nested['url'] ?? nested['document_url'])?.toString();
          if ((url == null || url.isEmpty) && nested['document'] is Map) {
            final deeper = nested['document'] as Map;
            url = (deeper['url'] ?? deeper['document_url'])?.toString();
            publicId ??= (deeper['public_id'] ?? deeper['publicId'])?.toString();
            finalDocType ??= deeper['document_type']?.toString();
            finalDocName ??= deeper['document_name']?.toString();
          }
        }
        // Case 5: Extract public_id from top level
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

      // ✅ Return a NORMALIZED result with BOTH `url` and `document_url`
      return {
        'success': true,
        'url': url,
        'document_url': url,   // ✅ Alias
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
  // ✅ APPLY WITH FILES (multipart) — kept for backward compat
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

        // ✅ CRITICAL: never send an empty document_type
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
      // ✅ CRITICAL: never send an empty document_type
      String safeDocType = documentType.trim();
      if (safeDocType.isEmpty) {
        safeDocType = _safeSlug(documentName.isNotEmpty ? documentName : fileName);
      }
      if (safeDocType.isEmpty) safeDocType = 'document';

      debugPrint("=" * 70);
      debugPrint("📤 UPLOADING SCHEME DOCUMENT");
      debugPrint("   Application ID: $applicationId");
      debugPrint("   Document Type: $safeDocType");
      debugPrint("   Document Name: $documentName");
      debugPrint("   File Name: $fileName");
      debugPrint("   File Size: ${fileBytes.length} bytes");
      debugPrint("   Endpoint: $_base/application/$applicationId/upload-document");
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
  static Future<Map<String, dynamic>> getMyApplications({String? status}) async {
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

  static Future<Map<String, dynamic>> getApplicationDetail(String applicationId) async {
    try {
      final res = await _dio.get('$_base/application/$applicationId');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅ SUBMIT APPLICATION
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
}