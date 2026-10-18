// lib/features/schemes/data/scheme_service.dart
// ============================================================
// GOVERNMENT SCHEMES API SERVICE
// ============================================================
// Handles all API calls for government schemes
// Uses master data as fallback when backend is unavailable
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
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

      _log("📤 Fetching schemes from backend...");
      final response = await _dio.get(
        "$_base/list",
        queryParameters: params,
      );

      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _log("❌ Scheme list fetch failed: $e");
      // ✅ Fallback to master data
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

  // ============================================================
  // FALLBACK — Uses master data when API fails
  // ============================================================
  static Map<String, dynamic> _fallbackListSchemes({
    String? level,
    String? state,
    String? category,
    String? search,
    bool? isFeatured,
    required int limit,
    required int skip,
  }) {
    _log("⚠️ Using fallback master data for schemes");

    List<GovernmentScheme> schemes = SchemesMasterData.allSchemes;

    // Apply filters
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

    // Paginate
    final total = schemes.length;
    final pagedSchemes = schemes.skip(skip).take(limit).toList();

    return {
      "success": true,
      "schemes": pagedSchemes.map(_schemeToJson).toList(),
      "total": total,
      "skip": skip,
      "limit": limit,
      "source": "master_data",
    };
  }

  // ============================================================
  // Convert GovernmentScheme object → JSON-compatible Map
  // ============================================================
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
      _log("📤 Fetching scheme detail: $schemeId");
      final response = await _dio.get("$_base/detail/$schemeId");
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      _log("❌ Scheme detail fetch failed: $e");
      // ✅ Fallback to master data
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
      _log("❌ Scheme detail error: $e");
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
  // GET FEATURED SCHEMES
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
      _log("⚠️ Featured schemes fallback");
      return SchemesMasterData.featuredSchemes
          .take(limit)
          .map(_schemeToJson)
          .toList();
    }
  }

  // ============================================================
  // GET CATEGORIES
  // ============================================================
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

  // ============================================================
  // GET STATES
  // ============================================================
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
  // APPLY FOR SCHEME
  // ============================================================
  static Future<Map<String, dynamic>> applyForScheme({
    required String schemeId,
    required Map<String, dynamic> applicantDetails,
    required Map<String, dynamic> applicantAddress,
    Map<String, dynamic>? bankDetails,
    Map<String, dynamic>? additionalInfo,
    String? remarks,
  }) async {
    try {
      _log("📤 Applying for scheme: $schemeId");
      final response = await _dio.post(
        "$_base/apply",
        data: {
          "scheme_id": schemeId,
          "applicant_details": applicantDetails,
          "applicant_address": applicantAddress,
          "bank_details": bankDetails,
          "additional_info": additionalInfo,
          "remarks": remarks,
        },
      );
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
  // GET MY SCHEME APPLICATIONS
  // ============================================================
  static Future<Map<String, dynamic>> getMyApplications({
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (status != null && status != 'all') params['status'] = status;

      _log("📤 Fetching my scheme applications...");
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
      _log("❌ Fetch my applications error: $e");
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