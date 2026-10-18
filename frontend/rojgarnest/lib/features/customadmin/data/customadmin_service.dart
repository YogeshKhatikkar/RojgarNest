// lib/features/customadmin/data/customadmin_service.dart
// ✅ COMPLETE - Now includes SCHEME APPLICATIONS support
// ✅ No lines skipped

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:rojgarnest/core/network/dio_client.dart';

class CustomAdminService {
  static const String _base = "/customadmin";

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

  // ====================== VERIFY ACCESS ======================
  static Future<bool> verifyAccess() async {
    try {
      final res = await _dio.get('$_base/verify-access');
      final data = _unwrap(res.data);
      return data['has_access'] == true;
    } on DioException {
      return false;
    }
  }

  // ====================== DASHBOARD ======================
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final res = await _dio.get('$_base/dashboard');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await _dio.get('$_base/stats');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ====================== JOB MANAGEMENT ======================
  static Future<Map<String, dynamic>> getJobs() async {
    try {
      final res = await _dio.get('$_base/jobs');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> getJobDetail(String jobId) async {
    try {
      final res = await _dio.get('$_base/jobs/$jobId');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> addJob(
    Map<String, dynamic> jobData,
  ) async {
    try {
      final res = await _dio.post('$_base/jobs', data: jobData);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateJob(
    String jobId,
    Map<String, dynamic> jobData,
  ) async {
    try {
      final res = await _dio.put('$_base/jobs/$jobId', data: jobData);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> deleteJob(String jobId) async {
    try {
      final res = await _dio.delete('$_base/jobs/$jobId');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ====================== APPLICATION MANAGEMENT ======================
  static Future<Map<String, dynamic>> getApplications({String? status}) async {
    try {
      final queryParams = status != null && status != 'all'
          ? {'status': status}
          : null;
      final res = await _dio.get(
        '$_base/applications',
        queryParameters: queryParams,
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ====================== ✅ SCHEME APPLICATIONS (NEW) ======================
  // Fetches all scheme applications from unified applications collection
  // Uses application_type=schemes query param
  static Future<Map<String, dynamic>> getSchemeApplications({
    String? status,
    int limit = 100,
    int skip = 0,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'application_type': 'schemes', // ✅ CRITICAL
        'limit': limit,
        'skip': skip,
      };
      if (status != null && status != 'all' && status.isNotEmpty) {
        params['status'] = status;
      }

      debugPrint("📤 CustomAdminService.getSchemeApplications");
      debugPrint("   Params: $params");

      final res = await _dio.get(
        '$_base/applications',
        queryParameters: params,
      );

      debugPrint("📥 Response: ${res.statusCode}");
      return _unwrap(res.data);
    } on DioException catch (e) {
      debugPrint("❌ getSchemeApplications error: ${e.message}");
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> getApplicationDetail(
    String applicationId,
  ) async {
    try {
      final res = await _dio.get('$_base/applications/$applicationId');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateApplicationStatus(
    String applicationId,
    String status, {
    String? notes,
  }) async {
    try {
      final queryParams = {'status': status};
      if (notes != null && notes.isNotEmpty) {
        queryParams['notes'] = notes;
      }
      final res = await _dio.put(
        '$_base/applications/$applicationId/status',
        queryParameters: queryParams,
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> bulkUpdateStatus(
    List<String> applicationIds,
    String status, {
    String? notes,
  }) async {
    try {
      final res = await _dio.post(
        '$_base/applications/bulk-status',
        data: {
          'application_ids': applicationIds,
          'status': status,
          'notes': notes,
        },
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ====================== USER MANAGEMENT (Read-only) ======================
  static Future<Map<String, dynamic>> searchUsers(
    String query, {
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get(
        '$_base/users/search',
        queryParameters: {'query': query, 'limit': limit},
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> getUserProfile(String email) async {
    try {
      final res = await _dio.get('$_base/users/$email');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ====================== REPORTS ======================
  static Future<Map<String, dynamic>> generateReport(String reportType) async {
    try {
      final res = await _dio.get('$_base/reports/$reportType');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ====================== SETTINGS ======================
  static Future<Map<String, dynamic>> getSettings() async {
    try {
      final res = await _dio.get('$_base/settings');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> settingsData,
  ) async {
    try {
      final res = await _dio.put('$_base/settings', data: settingsData);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ====================== NOTIFICATIONS ======================
  static Future<Map<String, dynamic>> getNotificationCount() async {
    try {
      final res = await _dio.get('$_base/notifications/count');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> getNotifications({
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get(
        '$_base/notifications',
        queryParameters: {'skip': skip, 'limit': limit},
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> markNotificationRead(
    String notificationId,
  ) async {
    try {
      final res = await _dio.post(
        '$_base/notifications/mark-read/$notificationId',
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ====================== ✅ PENDING PAYMENTS ======================
  static Future<Map<String, dynamic>> getPendingPayments() async {
    try {
      final res = await _dio.get('$_base/pending-payments');
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> verifyPayment(
    String paymentId,
    String action, {
    String? notes,
  }) async {
    try {
      final res = await _dio.post(
        '$_base/verify-payment/$paymentId',
        queryParameters: {
          'action': action,
          'notes': notes ?? '',
        },
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }
}