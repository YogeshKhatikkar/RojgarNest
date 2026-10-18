// lib/features/admin/data/admin_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';

class AdminService {
  static const String _base = "/admin";

  static void _log(String msg) {
    if (kDebugMode) debugPrint(msg);
  }

  static String _err(DioException e) {
    final msg = DioClient.extractErrorMessage(e);
    _log("❌ AdminService: $msg");
    return msg;
  }

  static dynamic _unwrap(dynamic responseData) {
    // Unwrap the standard API response {success: true, data: ...}
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('data')) {
        return responseData['data'];
      }
    }
    return responseData;
  }

  // ====================== JOB MANAGEMENT ======================
  static Future<dynamic> addJob(Map<String, dynamic> jobData) async {
    try {
      _log("📤 Adding job: ${jobData['post_name']}");
      final res = await DioClient.dio.post("$_base/add-job", data: jobData);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> getJobs() async {
    try {
      final res = await DioClient.dio.get("$_base/jobs");
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> getJobDetail(String jobId) async {
    try {
      final res = await DioClient.dio.get("$_base/jobs/$jobId");
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> updateJob(
    String jobId,
    Map<String, dynamic> jobData,
  ) async {
    try {
      final res = await DioClient.dio.put("$_base/jobs/$jobId", data: jobData);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> deleteJob(String jobId) async {
    try {
      final res = await DioClient.dio.delete("$_base/jobs/$jobId");
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  // ====================== APPLICATION MANAGEMENT ======================
  static Future<dynamic> getApplications({String? status}) async {
    try {
      final params = status != null ? {'status': status} : null;
      final res = await DioClient.dio.get(
        "$_base/applications",
        queryParameters: params,
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> updateApplicationStatus(
    String applicationId,
    String status, {
    String? notes,
  }) async {
    try {
      final params = {'status': status};
      if (notes != null) params['notes'] = notes;
      final res = await DioClient.dio.put(
        "$_base/applications/$applicationId/status",
        queryParameters: params,
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> bulkUpdateStatus(
    List<String> applicationIds,
    String status, {
    String? notes,
  }) async {
    try {
      final res = await DioClient.dio.post(
        "$_base/applications/bulk-status",
        data: {
          'application_ids': applicationIds,
          'status': status,
          'notes': notes,
        },
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> getApplicationDetail(String applicationId) async {
    try {
      final res = await DioClient.dio.get(
        "$_base/applications/$applicationId/detail",
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> searchApplications(
    String query, {
    String? status,
  }) async {
    try {
      final params = {'query': query};
      if (status != null) params['status'] = status;
      final res = await DioClient.dio.get(
        "$_base/applications/fast-search",
        queryParameters: params,
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  // ====================== USER MANAGEMENT ======================
  static Future<dynamic> getUsers() async {
    try {
      final res = await DioClient.dio.get("$_base/users");
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> updateUserStatus(String userId, bool isActive) async {
    try {
      final res = await DioClient.dio.put(
        "$_base/users/$userId/status",
        data: {'is_active': isActive},
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  // ====================== AI FEATURES ======================
  static Future<dynamic> getAIDashboard() async {
    try {
      final res = await DioClient.dio.get("$_base/ai/dashboard");
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> getRankedApplications({int limit = 50}) async {
    try {
      final res = await DioClient.dio.get(
        "$_base/ai/applications/ranked",
        queryParameters: {'limit': limit},
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> checkFraud(String applicationId) async {
    try {
      final res = await DioClient.dio.get(
        "$_base/ai/fraud-detection",
        queryParameters: {'application_id': applicationId},
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  static Future<dynamic> getHiringTrends({int days = 30}) async {
    try {
      final res = await DioClient.dio.get(
        "$_base/ai/hiring-trends",
        queryParameters: {'days': days},
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  // ====================== REPORTS ======================
  static Future<dynamic> getReports() async {
    try {
      final res = await DioClient.dio.get("$_base/reports");
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }
}
