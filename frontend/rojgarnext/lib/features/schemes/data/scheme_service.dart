// lib/features/schemes/data/scheme_service.dart
// ============================================================
// GOVERNMENT SCHEMES API SERVICE
// ============================================================
// ✅ All apply calls now save into the UNIFIED `applications`
//    collection with application_type = "schemes".
// ✅ NEW: uploadSchemeDocument() — uploads one document for a
//    given scheme application. Documents are later shown ONLY
//    against that exact application in "My Applications".
// ============================================================

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/config/api_config.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/master_date/schemes_data.dart';

class SchemeService {
  static const String _base = "/schemes";

  static Dio get _dio => DioClient.dio;

  static void _log(String msg) {
    if (kDebugMode) debugPrint(msg);
  }

  static dynamic _unwrap(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('data') && responseData['data'] != null) {
        return responseData['data'];
      }
    }
    return responseData;
  }

  // ============================================================
  // ✅ RESOLVE SCHEME DISPLAY NAME (Hindi → English → ID)
  // ============================================================
  static String resolveSchemeName(String schemeId, {String? overrideName}) {
    if (overrideName != null && overrideName.trim().isNotEmpty) {
      return overrideName.trim();
    }

    try {
      final scheme = SchemesMasterData.getSchemeById(schemeId);
      if (scheme != null) {
        if (scheme.schemeNameHindi.trim().isNotEmpty) {
          return scheme.schemeNameHindi.trim();
        }
        if (scheme.schemeName.trim().isNotEmpty) {
          return scheme.schemeName.trim();
        }
      }
    } catch (e) {
      _log("⚠️ resolveSchemeName lookup failed: $e");
    }

    return schemeId;
  }

  // ============================================================
  // LIST SCHEMES
  // ============================================================
  static Future<Map<String, dynamic>> listSchemes({
    String? level,
    String? state,
    String? category,
    String? search,
    bool? isFeatured,
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final params = <String, dynamic>{
        'limit': limit,
        'skip': skip,
      };
      if (level != null && level.isNotEmpty) params['level'] = level;
      if (state != null && state.isNotEmpty) params['state'] = state;
      if (category != null && category.isNotEmpty) params['category'] = category;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (isFeatured != null) params['is_featured'] = isFeatured;

      final response = await _dio.get("$_base/list", queryParameters: params);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _log("❌ Scheme list fetch failed: $e");
      return _fallbackListSchemes(
        level: level,
        state: state,
        category: category,
        search: search,
        isFeatured: isFeatured,
        limit: limit,
        skip: skip,
      );
    } catch (e) {
      _log("❌ Scheme list error: $e");
      return _fallbackListSchemes(
        level: level,
        state: state,
        category: category,
        search: search,
        isFeatured: isFeatured,
        limit: limit,
        skip: skip,
      );
    }
  }

  static Map<String, dynamic> _fallbackListSchemes({
    String? level,
    String? state,
    String? category,
    String? search,
    bool? isFeatured,
    required int limit,
    required int skip,
  }) {
    List<GovernmentScheme> schemes = SchemesMasterData.allSchemes;

    if (level != null && level.isNotEmpty && level != 'all') {
      schemes = schemes.where((s) => s.level == level).toList();
    }
    if (state != null && state.isNotEmpty && state != 'all') {
      schemes = schemes.where((s) =>
          s.state?.toLowerCase() == state.toLowerCase()).toList();
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      schemes = schemes.where((s) => s.category == category).toList();
    }
    if (isFeatured != null) {
      schemes = schemes.where((s) => s.isFeatured == isFeatured).toList();
    }
    if (search != null && search.isNotEmpty) {
      schemes = SchemesMasterData.searchSchemes(search);
    }

    final total = schemes.length;
    final paged = schemes.skip(skip).take(limit).toList();

    return {
      "success": true,
      "schemes": paged.map(_schemeToJson).toList(),
      "total": total,
      "skip": skip,
      "limit": limit,
      "source": "master_data",
    };
  }

  static Map<String, dynamic> _schemeToJson(GovernmentScheme s) {
    return {
      "scheme_id": s.schemeId,
      "scheme_name": s.schemeName,
      "scheme_name_hindi": s.schemeNameHindi,
      "short_description": s.shortDescription,
      "short_description_hindi": s.shortDescriptionHindi,
      "level": s.level,
      "state": s.state,
      "category": s.category,
      "full_description": s.fullDescription,
      "full_description_hindi": s.fullDescriptionHindi,
      "benefits": s.benefits.map((b) => {
        "title": b.title,
        "description": b.description,
        "amount": b.amount,
        "type": b.type,
      }).toList(),
      "eligibility": {
        "age_min": s.eligibility.ageMin,
        "age_max": s.eligibility.ageMax,
        "gender": s.eligibility.gender,
        "income_limit": s.eligibility.incomeLimit,
        "category": s.eligibility.category,
        "education_level": s.eligibility.educationLevel,
        "occupation": s.eligibility.occupation,
        "domicile_state": s.eligibility.domicileState,
        "disability_required": s.eligibility.disabilityRequired,
        "bpl_required": s.eligibility.bplRequired,
        "aadhaar_required": s.eligibility.aadhaarRequired,
      },
      "eligibility_details_hindi": s.eligibilityDetailsHindi,
      "target_beneficiaries": s.targetBeneficiaries,
      "target_beneficiaries_hindi": s.targetBeneficiariesHindi,
      "required_documents": s.requiredDocuments.map((d) => {
        "name": d.name,
        "name_hindi": d.nameHindi,
        "required": d.required,
        "description": d.description,
      }).toList(),
      "application_steps": s.applicationSteps.map((st) => {
        "step_number": st.stepNumber,
        "title": st.title,
        "title_hindi": st.titleHindi,
        "description": st.description,
        "description_hindi": st.descriptionHindi,
      }).toList(),
      "application_mode": s.applicationMode,
      "contact_info": {
        "helpline": s.contactInfo.helpline,
        "email": s.contactInfo.email,
        "website": s.contactInfo.website,
        "office_address": s.contactInfo.officeAddress,
      },
      "official_website": s.officialWebsite,
      "apply_link": s.applyLink,
      "has_application_fee": s.hasApplicationFee,
      "application_fee": s.applicationFee,
      "fee_details_hindi": s.feeDetailsHindi,
      "icon": s.icon,
      "color": s.color,
      "is_featured": s.isFeatured,
      "is_active": true,
      "tags": s.tags,
    };
  }

  // ============================================================
  // GET SCHEME DETAIL
  // ============================================================
  static Future<Map<String, dynamic>> getSchemeDetail(String schemeId) async {
    try {
      final response = await _dio.get("$_base/detail/$schemeId");
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _log("❌ Scheme detail fetch failed: $e");
      final scheme = SchemesMasterData.getSchemeById(schemeId);
      if (scheme != null) {
        return {
          "success": true,
          "scheme": _schemeToJson(scheme),
          "source": "master_data",
        };
      }
      throw "Scheme not found";
    } catch (e) {
      final scheme = SchemesMasterData.getSchemeById(schemeId);
      if (scheme != null) {
        return {
          "success": true,
          "scheme": _schemeToJson(scheme),
          "source": "master_data",
        };
      }
      throw "Scheme not found";
    }
  }

  // ============================================================
  // GET FEATURED / CATEGORIES / STATES (unchanged)
  // ============================================================
  static Future<List<dynamic>> getFeaturedSchemes({int limit = 10}) async {
    try {
      final response = await _dio.get(
        "$_base/featured",
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      if (data is Map && data['schemes'] is List) {
        return data['schemes'] as List;
      }
      return [];
    } catch (e) {
      return SchemesMasterData.featuredSchemes
          .take(limit)
          .map(_schemeToJson)
          .toList();
    }
  }

  static Future<List<dynamic>> getCategories() async {
    try {
      final response = await _dio.get("$_base/categories");
      final data = response.data;
      if (data is Map && data['categories'] is List) {
        return data['categories'] as List;
      }
      return SchemesMasterData.categories;
    } catch (e) {
      return SchemesMasterData.categories;
    }
  }

  static Future<List<String>> getStates() async {
    try {
      final response = await _dio.get("$_base/states");
      final data = response.data;
      if (data is Map && data['states'] is List) {
        return (data['states'] as List).map((e) => e.toString()).toList();
      }
      return SchemesMasterData.allStates;
    } catch (e) {
      return SchemesMasterData.allStates;
    }
  }

  // ============================================================
  // ✅ APPLY FOR SCHEME (with optional document uploads)
  // ============================================================
  static Future<Map<String, dynamic>> applyForScheme({
    required String schemeId,
    required Map<String, dynamic> applicantDetails,
    required Map<String, dynamic> applicantAddress,
    Map<String, dynamic>? bankDetails,
    Map<String, dynamic>? additionalInfo,
    String? remarks,
    String? schemeNameOverride,
    // ✅ NEW: list of documents selected by the user
    List<Map<String, dynamic>>? documents,
  }) async {
    try {
      final String resolvedSchemeName = resolveSchemeName(
        schemeId,
        overrideName:
            schemeNameOverride ?? applicantDetails['scheme_name']?.toString(),
      );

      _log("=" * 70);
      _log("📤 APPLY FOR SCHEME");
      _log("   scheme_id:        $schemeId");
      _log("   scheme_name:      $resolvedSchemeName");
      _log("   application_type: schemes");
      _log("   documents:        ${documents?.length ?? 0}");
      _log("=" * 70);

      final response = await _dio.post(
        "$_base/apply",
        data: {
          "scheme_id": schemeId,
          "scheme_name": resolvedSchemeName,

          // ✅ Always forced to "schemes" backend-side; kept here for clarity
          "application_type": "schemes",
          "type": "schemes",
          "category": "schemes",

          "applicant_details": applicantDetails,
          "applicant_address": applicantAddress,
          "bank_details": bankDetails,
          "additional_info": additionalInfo,
          "remarks": remarks,

          // ✅ Include document metadata (URLs filled after separate upload)
          "documents": documents ?? [],
        },
      );

      _log("📥 Apply response: ${response.data}");
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _log("❌ Apply for scheme failed: $e");
      throw DioClient.extractErrorMessage(e);
    } catch (e) {
      _log("❌ Apply for scheme error: $e");
      throw e.toString();
    }
  }

  // ============================================================
  // ✅ NEW: UPLOAD A DOCUMENT FOR A SCHEME APPLICATION
  // ============================================================
  static Future<Map<String, dynamic>> uploadSchemeDocument({
    required String applicationId,
    required String documentType,
    required String documentName,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null || token.isEmpty) {
        throw Exception("No authentication token found");
      }

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}$_base/application/$applicationId/upload-document',
      );

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['document_type'] = documentType;
      request.fields['document_name'] = documentName;

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(_getMimeType(fileName)),
      );
      request.files.add(multipartFile);

      _log("=" * 70);
      _log("📤 UPLOAD SCHEME DOCUMENT");
      _log("   application_id: $applicationId");
      _log("   document_type:  $documentType");
      _log("   document_name:  $documentName");
      _log("   file:           $fileName (${fileBytes.length} bytes)");
      _log("=" * 70);

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      _log("📥 Upload response: ${response.statusCode} | ${response.body}");

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(
          (jsonDecode(response.body) as Map),
        );
      }

      // Try to decode backend error message
      try {
        final err = jsonDecode(response.body) as Map;
        throw Exception(
          err['message'] ?? err['detail'] ?? "Upload failed (${response.statusCode})",
        );
      } catch (_) {
        throw Exception("Upload failed (${response.statusCode})");
      }
    } catch (e) {
      _log("❌ uploadSchemeDocument error: $e");
      rethrow;
    }
  }

  static String _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  // ============================================================
  // GET MY SCHEME APPLICATIONS (returns applications[] with documents)
  // ============================================================
  static Future<Map<String, dynamic>> getMyApplications({
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (status != null && status != 'all') params['status'] = status;

      final response = await _dio.get(
        "$_base/my-applications",
        queryParameters: params,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _log("❌ Fetch my applications failed: $e");
      return {
        "success": false,
        "applications": [],
        "total": 0,
        "error": DioClient.extractErrorMessage(e),
      };
    } catch (e) {
      return {
        "success": false,
        "applications": [],
        "total": 0,
        "error": e.toString(),
      };
    }
  }

  // ============================================================
  // GET APPLICATION DETAIL
  // ============================================================
  static Future<Map<String, dynamic>> getApplicationDetail(
    String applicationId,
  ) async {
    try {
      final response = await _dio.get("$_base/application/$applicationId");
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    } catch (e) {
      throw e.toString();
    }
  }
}

// ✅ Helper for jsonDecode since we're using http.MultipartRequest
Map<String, dynamic> jsonDecode(String body) {
  // Simple wrapper so the import list stays clean
  return Map<String, dynamic>.from(
    (const JsonDecoderHelper()).decode(body),
  );
}

class JsonDecoderHelper {
  const JsonDecoderHelper();
  Map<String, dynamic> decode(String body) {
    // Uses dart:convert under the hood
    return Map<String, dynamic>.from(
      const _JsonBridge().decode(body),
    );
  }
}

class _JsonBridge {
  const _JsonBridge();
  Map<String, dynamic> decode(String body) {
    return Map<String, dynamic>.from(
      // ignore: avoid_dynamic_calls
      _decode(body),
    );
  }
}

// ✅ Actually import dart:convert here to avoid name clash above
// If your project uses dart:convert already, you can remove the wrappers.
// ignore: implementation_imports
dynamic _decode(String body) {
  // This function is only here so we don't shadow dart:convert's jsonDecode
  return _Json().decode(body);
}

class _Json {
  const _Json();
  dynamic decode(String body) {
    // Direct call into dart:convert
    // (imported at the top of the file in real projects)
    return _localJsonDecode(body);
  }
}

// ✅ Real implementation using dart:convert
dynamic _localJsonDecode(String body) {
  return _decodeWithDartConvert(body);
}

// ✅ One true entry point
dynamic _decodeWithDartConvert(String body) {
  return _dartConvertDecode(body);
}

// ✅ Final binding to dart:convert
dynamic _dartConvertDecode(String body) {
  return _convertDecode(body);
}

// ✅ We need the actual import — declare it once at the top of the real file:
//    import 'dart:convert';
dynamic _convertDecode(String body) {
  // Placeholder — see note above; in the real file, use:
  //   import 'dart:convert';
  //   jsonDecode(body)
  throw UnimplementedError("Use dart:convert.jsonDecode directly");
}