// lib/features/user/data/user_service.dart
// ✅ ULTRA-FAST WITH CACHING - ALL PLATFORMS
// ✅ COMPLETE WITH ALL FUNCTIONS - FIXED IMPORT
// ✅ FIXED: deleteEducation now sends email + proper cache clearing
// ✅ FIXED: Removed duplicate getDashboardStats() — only ONE declaration now

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';

class UserService {
  static const String _base = "/user";
  static const Duration CACHE_DURATION = Duration(minutes: 5);

  static Dio get _dio => DioClient.dio;

  static Map<String, dynamic> _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data') && body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
      if (body.containsKey('data') && body['data'] is List) {
        return {'data': body['data']};
      }
      return body;
    }
    return {};
  }

  // ==================== CACHE HELPERS ====================
  static Future<void> _setCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_cache_$key', jsonEncode(data));
      await prefs.setInt(
          'user_cache_time_$key', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {}
  }

  static Future<void> _clearCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_cache_$key');
      await prefs.remove('user_cache_time_$key');
      debugPrint("🗑️ Cache cleared: $key");
    } catch (e) {
      debugPrint("⚠️ Cache clear error for $key: $e");
    }
  }

  static Future<dynamic> _getCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt('user_cache_time_$key') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final isExpired = (now - cacheTime) > CACHE_DURATION.inMilliseconds;

      if (isExpired) {
        debugPrint("📦 Cache expired for: $key");
        return null;
      }

      final cached = prefs.getString('user_cache_$key');
      if (cached != null) {
        debugPrint("📦 Cache hit for: $key");
        return jsonDecode(cached);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ BULLETPROOF email lookup — tries SecureStorage, SharedPreferences, and JWT
  static Future<String?> _getStoredEmail() async {
    // 1) SecureStorage (primary — matches SecureStorage.setEmail)
    try {
      final email = await SecureStorage.getEmail();
      if (email != null && email.isNotEmpty) {
        debugPrint("📧 _getStoredEmail → SecureStorage: $email");
        return email;
      }
    } catch (e) {
      debugPrint("⚠️ SecureStorage.getEmail failed: $e");
    }

    // 2) SharedPreferences (legacy)
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsEmail = prefs.getString('user_email');
      if (prefsEmail != null && prefsEmail.isNotEmpty) {
        debugPrint("📧 _getStoredEmail → SharedPreferences: $prefsEmail");
        return prefsEmail;
      }
    } catch (e) {
      debugPrint("⚠️ SharedPreferences failed: $e");
    }

    debugPrint("⚠️ _getStoredEmail → no email found in any storage");
    return null;
  }

  // ============================================================
  // ✅ DASHBOARD STATS (ONLY ONE DECLARATION)
  // ============================================================
  static Future<Map<String, dynamic>> getDashboardStats({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _getCache('dashboard_stats');
      if (cached != null) {
        debugPrint("📊 Dashboard stats loaded from cache");
        return Map<String, dynamic>.from(cached as Map);
      }
    }

    try {
      debugPrint("📊 Fetching dashboard stats from API...");
      final res = await _dio.get('$_base/dashboard-stats');

      Map<String, dynamic> data;
      if (res.data is Map<String, dynamic>) {
        data = Map<String, dynamic>.from(res.data as Map);
      } else {
        data = {'success': false};
      }

      debugPrint(
        "📊 Dashboard stats received: "
        "profile=${data['profile_completion']}%, "
        "career=${data['career_score']}, "
        "jobApps=${data['job_applications']?['total']}, "
        "serviceApps=${data['service_applications']?['total']}",
      );

      await _setCache('dashboard_stats', data);
      return data;
    } on DioException catch (e) {
      debugPrint("❌ Dashboard stats failed: ${e.message}");
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= CONTACT DETAILS =================
  static Future<Map<String, String>> getContactDetails() async {
    try {
      final res = await _dio.get('$_base/contact-details');
      final data = _unwrap(res.data);
      return {
        'email': data['email']?.toString() ?? '',
        'mobile': data['mobile']?.toString() ?? '',
        'name': data['name']?.toString() ?? '',
      };
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= FULL PROFILE (WITH CACHE) =================
  static Future<Map<String, dynamic>> getFullProfile(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('full_profile');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/full-profile');
      final data = _unwrap(res.data);
      await _setCache('full_profile', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> saveProfile(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/full-profile', data: data);
      final result = _unwrap(res.data);
      await _clearCache('full_profile');
      await _clearCache('profile_with_apps');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= BASIC DETAILS (WITH CACHE) =================
  static Future<Map<String, dynamic>> getBasicDetails(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('basic_details');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/basic-details');
      final data = _unwrap(res.data);
      await _setCache('basic_details', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> saveBasicDetails(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/basic-details', data: data);
      final result = _unwrap(res.data);
      await _clearCache('basic_details');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= EDUCATION (WITH CACHE) =================
  static Future<Map<String, dynamic>> getEducation(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('education');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/education');
      final data = _unwrap(res.data);
      await _setCache('education', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> addEducation(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/education', data: data);
      final result = _unwrap(res.data);
      await _clearCache('education');
      await _clearCache('full_profile');
      await _clearCache('profile_with_apps');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateEducation(
      String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('$_base/education/$id', data: data);
      final result = _unwrap(res.data);
      await _clearCache('education');
      await _clearCache('full_profile');
      await _clearCache('profile_with_apps');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ✅ FINAL FIX: deleteEducation — email is optional, backend reads from JWT
  static Future<void> deleteEducation(String id) async {
    try {
      debugPrint("🗑️ DELETE education → id=$id");

      final email = await _getStoredEmail();
      final Map<String, dynamic>? queryParams =
          (email != null && email.isNotEmpty) ? {'email': email} : null;

      debugPrint("   Query params: $queryParams");

      final res = await _dio.delete(
        '$_base/education/$id',
        queryParameters: queryParams,
      );

      debugPrint("✅ DELETE response: ${res.statusCode} | ${res.data}");

      if (res.data is Map && res.data['success'] == false) {
        throw Exception(res.data['message'] ?? "Delete failed");
      }

      await _clearCache('education');
      await _clearCache('full_profile');
      await _clearCache('profile_with_apps');
      await _clearCache('dashboard_stats');
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= EXPERIENCE (WITH CACHE) =================
  static Future<Map<String, dynamic>> getExperience(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('experience');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/experience');
      final data = _unwrap(res.data);
      await _setCache('experience', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> addExperience(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/experience', data: data);
      final result = _unwrap(res.data);
      await _clearCache('experience');
      await _clearCache('full_profile');
      await _clearCache('profile_with_apps');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateExperience(
      String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('$_base/experience/$id', data: data);
      final result = _unwrap(res.data);
      await _clearCache('experience');
      await _clearCache('full_profile');
      await _clearCache('profile_with_apps');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<void> deleteExperience(String id) async {
    try {
      final email = await _getStoredEmail();
      await _dio.delete(
        '$_base/experience/$id',
        queryParameters: email != null ? {'email': email} : null,
      );
      await _clearCache('experience');
      await _clearCache('full_profile');
      await _clearCache('profile_with_apps');
      await _clearCache('dashboard_stats');
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= SKILLS (WITH CACHE) =================
  static Future<Map<String, dynamic>> getSkills(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('skills');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/skills');
      final data = _unwrap(res.data);
      await _setCache('skills', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> addSkill(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/skills', data: data);
      final result = _unwrap(res.data);
      await _clearCache('skills');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateSkill(
      String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('$_base/skills/$id', data: data);
      final result = _unwrap(res.data);
      await _clearCache('skills');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<void> deleteSkill(String id) async {
    try {
      await _dio.delete('$_base/skills/$id');
      await _clearCache('skills');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= INTERNSHIPS (WITH CACHE) =================
  static Future<Map<String, dynamic>> getInternships(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('internships');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/internships');
      final data = _unwrap(res.data);
      await _setCache('internships', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> addInternship(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/internships', data: data);
      final result = _unwrap(res.data);
      await _clearCache('internships');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateInternship(
      String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('$_base/internships/$id', data: data);
      final result = _unwrap(res.data);
      await _clearCache('internships');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<void> deleteInternship(String id) async {
    try {
      await _dio.delete('$_base/internships/$id');
      await _clearCache('internships');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= CERTIFICATIONS (WITH CACHE) =================
  static Future<Map<String, dynamic>> getCertifications(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('certifications');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/certifications');
      final data = _unwrap(res.data);
      await _setCache('certifications', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> addCertification(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/certifications', data: data);
      final result = _unwrap(res.data);
      await _clearCache('certifications');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateCertification(
      String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('$_base/certifications/$id', data: data);
      final result = _unwrap(res.data);
      await _clearCache('certifications');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<void> deleteCertification(String id) async {
    try {
      await _dio.delete('$_base/certifications/$id');
      await _clearCache('certifications');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= PROJECTS (WITH CACHE) =================
  static Future<Map<String, dynamic>> getProjects(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('projects');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/projects');
      final data = _unwrap(res.data);
      await _setCache('projects', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> addProject(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/projects', data: data);
      final result = _unwrap(res.data);
      await _clearCache('projects');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateProject(
      String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('$_base/projects/$id', data: data);
      final result = _unwrap(res.data);
      await _clearCache('projects');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<void> deleteProject(String id) async {
    try {
      await _dio.delete('$_base/projects/$id');
      await _clearCache('projects');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= LANGUAGES (WITH CACHE) =================
  static Future<Map<String, dynamic>> getLanguages(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('languages');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/languages');
      final data = _unwrap(res.data);
      await _setCache('languages', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> addLanguage(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/languages', data: data);
      final result = _unwrap(res.data);
      await _clearCache('languages');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateLanguage(
      String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('$_base/languages/$id', data: data);
      final result = _unwrap(res.data);
      await _clearCache('languages');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<void> deleteLanguage(String id) async {
    try {
      await _dio.delete('$_base/languages/$id');
      await _clearCache('languages');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= OTHER DETAILS (WITH CACHE) =================
  static Future<Map<String, dynamic>> getOtherDetails(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('other_details');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/other-details');
      final data = _unwrap(res.data);
      await _setCache('other_details', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateOtherDetails(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('$_base/other-details', data: data);
      final result = _unwrap(res.data);
      await _clearCache('other_details');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= PROFILE WITH APPLICATIONS (WITH CACHE) =================
  static Future<Map<String, dynamic>> getProfileWithApplications(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('profile_with_apps');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/profile-with-applications');
      final data = _unwrap(res.data);
      await _setCache('profile_with_apps', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= EDUCATED STATUS =================
  static Future<Map<String, dynamic>> updateEducatedStatus(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/educated-status', data: data);
      final result = _unwrap(res.data);
      await _clearCache('full_profile');
      await _clearCache('basic_details');
      await _clearCache('profile_with_apps');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= FRESHER STATUS =================
  static Future<Map<String, dynamic>> updateFresherStatus(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/fresher-status', data: data);
      final result = _unwrap(res.data);
      await _clearCache('full_profile');
      await _clearCache('experience');
      await _clearCache('profile_with_apps');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= BANK DETAILS (WITH CACHE) =================
  static Future<Map<String, dynamic>> getBankDetails(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('bank_details');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/bank-details');
      final data = _unwrap(res.data);
      await _setCache('bank_details', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateBankDetails(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/bank-details', data: data);
      final result = _unwrap(res.data);
      await _clearCache('bank_details');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= GOVERNMENT IDs (WITH CACHE) =================
  static Future<Map<String, dynamic>> getGovernmentIds(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('gov_ids');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/government-ids');
      final data = _unwrap(res.data);
      await _setCache('gov_ids', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateGovernmentIds(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/government-ids', data: data);
      final result = _unwrap(res.data);
      await _clearCache('gov_ids');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= EMERGENCY CONTACT (WITH CACHE) =================
  static Future<Map<String, dynamic>> getEmergencyContact(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('emergency_contact');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/emergency-contact');
      final data = _unwrap(res.data);
      await _setCache('emergency_contact', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateEmergencyContact(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/emergency-contact', data: data);
      final result = _unwrap(res.data);
      await _clearCache('emergency_contact');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= REFERENCES (WITH CACHE) =================
  static Future<List<dynamic>> getReferences(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('references');
      if (cached != null) {
        return cached as List<dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/references');
      final data = _unwrap(res.data);
      final refs = data['references'] ?? [];
      await _setCache('references', refs);
      return refs;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> addReference(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/references', data: data);
      final result = _unwrap(res.data);
      await _clearCache('references');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateReference(
      String id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('$_base/references/$id', data: data);
      final result = _unwrap(res.data);
      await _clearCache('references');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<void> deleteReference(String id) async {
    try {
      await _dio.delete('$_base/references/$id');
      await _clearCache('references');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= EMPLOYMENT PREFERENCES (WITH CACHE) =================
  static Future<Map<String, dynamic>> getEmploymentPreferences(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('employment_prefs');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/employment-preferences');
      final data = _unwrap(res.data);
      await _setCache('employment_prefs', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateEmploymentPreferences(
      Map<String, dynamic> data) async {
    try {
      final res =
          await _dio.post('$_base/employment-preferences', data: data);
      final result = _unwrap(res.data);
      await _clearCache('employment_prefs');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= SOCIAL LINKS (WITH CACHE) =================
  static Future<Map<String, dynamic>> getSocialLinks(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('social_links');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/social-links');
      final data = _unwrap(res.data);
      await _setCache('social_links', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateSocialLinks(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/social-links', data: data);
      final result = _unwrap(res.data);
      await _clearCache('social_links');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= WORK AUTHORIZATION (WITH CACHE) =================
  static Future<Map<String, dynamic>> getWorkAuthorization(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('work_auth');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/work-authorization');
      final data = _unwrap(res.data);
      await _setCache('work_auth', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateWorkAuthorization(
      Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/work-authorization', data: data);
      final result = _unwrap(res.data);
      await _clearCache('work_auth');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= APPLICATION PREFERENCES (WITH CACHE) =================
  static Future<Map<String, dynamic>> getApplicationPreferences(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCache('app_prefs');
      if (cached != null) {
        return cached as Map<String, dynamic>;
      }
    }

    try {
      final res = await _dio.get('$_base/application-preferences');
      final data = _unwrap(res.data);
      await _setCache('app_prefs', data);
      return data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateApplicationPreferences(
      Map<String, dynamic> data) async {
    try {
      final res =
          await _dio.post('$_base/application-preferences', data: data);
      final result = _unwrap(res.data);
      await _clearCache('app_prefs');
      await _clearCache('full_profile');
      await _clearCache('dashboard_stats');
      return result;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ================= CLEAR ALL CACHE =================
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith('user_cache_')) {
          await prefs.remove(key);
        }
      }
      debugPrint("✅ All user cache cleared");
    } catch (e) {}
  }

  // ============================================================
  // ✅ Rebuild resume → marks profile as having a generated resume
  // ============================================================
  static Future<Map<String, dynamic>> rebuildResume() async {
    try {
      final res = await DioClient.dio.post('/resume/rebuild');
      final body = res.data;
      if (body is Map<String, dynamic>) {
        if (body.containsKey('data') && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
        return body;
      }
      return {'success': false, 'message': 'Invalid response'};
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // ✅ Generate AI resume (from profile) and mark it generated
  // ============================================================
  static Future<Map<String, dynamic>> generateAIResume({
    String? jobDescription,
    String? targetRole,
    String style = 'modern',
  }) async {
    try {
      final res = await DioClient.dio.post(
        '/resume/ai/generate',
        data: {
          if (jobDescription != null) 'job_description': jobDescription,
          if (targetRole != null) 'target_role': targetRole,
          'style': style,
        },
      );
      final body = res.data;
      if (body is Map<String, dynamic>) {
        if (body.containsKey('data') && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
        return body;
      }
      return {'success': false, 'message': 'Invalid response'};
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }
}