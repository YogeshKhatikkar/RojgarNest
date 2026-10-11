// lib/features/schemes/data/scheme_service.dart
// ✅ COMPLETE FIXED - Always returns schemes from local master data as fallback
// ✅ Maps all fields correctly for UI
// ✅ FIXED: uploadSchemeDocument now sends ALL required fields

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
  // ✅ LIST SCHEMES — Always returns local data if backend fails
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
  // ✅ LOCAL FALLBACK — Uses SchemesMasterData
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
  // ✅ CONVERT GovernmentScheme → JSON map (COMPLETE)
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
  // ✅ SCHEME DETAIL — Always returns from local if backend fails
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
  // ✅ APPLY FOR SCHEME
  // ============================================================
  static Future<Map<String, dynamic>> applyForScheme({
    required String schemeId,
    required Map<String, dynamic> applicantDetails,
    required Map<String, dynamic> applicantAddress,
    required Map<String, dynamic> bankDetails,
    String? remarks,
  }) async {
    try {
      final res = await _dio.post('$_base/apply', data: {
        'scheme_id': schemeId,
        'applicant_details': applicantDetails,
        'applicant_address': applicantAddress,
        'bank_details': bankDetails,
        'remarks': remarks ?? '',
      });
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ============================================================
  // ✅ FIXED: UPLOAD SCHEME DOCUMENT
  // ✅ Now sends document_type AND document_name as required fields
  // ✅ Works on WEB and MOBILE
  // ============================================================
  static Future<Map<String, dynamic>> uploadSchemeDocument({
    required String applicationId,
    required String documentType,
    required String documentName,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      debugPrint("=" * 70);
      debugPrint("📤 UPLOADING SCHEME DOCUMENT");
      debugPrint("   Application ID: $applicationId");
      debugPrint("   Document Type: $documentType");
      debugPrint("   Document Name: $documentName");
      debugPrint("   File Name: $fileName");
      debugPrint("   File Size: ${fileBytes.length} bytes");
      debugPrint("   Endpoint: $_base/application/$applicationId/upload-document");
      debugPrint("=" * 70);

      // ✅ CRITICAL FIX: Build FormData with ALL required fields
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
        'document_type': documentType,  // ✅ REQUIRED by backend
        'document_name': documentName,  // ✅ Also sent
      });

      // ✅ Debug: Log what we're sending
      debugPrint("📦 FormData fields:");
      debugPrint("   document_type: $documentType");
      debugPrint("   document_name: $documentName");
      debugPrint("   file filename: $fileName");

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
  // ✅ UPLOAD TEMP DOCUMENT
  // ============================================================
  static Future<Map<String, dynamic>> uploadTempDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String documentType,
    required String documentName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'document_type': documentType,
        'document_name': documentName,
      });
      final res = await _dio.post('$_base/upload-temp-document', data: formData);
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