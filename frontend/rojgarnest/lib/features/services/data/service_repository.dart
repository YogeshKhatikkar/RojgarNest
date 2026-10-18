// lib/features/services/data/service_repository.dart
// ✅ COMPLETE FIXED VERSION - Added debugPrint import

import 'package:flutter/foundation.dart' show debugPrint; // ✅ ADD THIS IMPORT
import 'package:dio/dio.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/features/services/models/service_types.dart';

class ServiceRepository {
  static const String _base = "/services";

  static Dio get _dio => DioClient.dio;

  // ==================== GET ALL SERVICES (LOCAL) ====================
  static List<ServiceType> getAllServices() {
    return ServiceMasterData.getAllServices();
  }

  // ==================== GET SERVICE BY ID ====================
  static ServiceType? getService(String id) {
    return ServiceMasterData.getServiceById(id);
  }

  // ==================== GET SUB-TYPE BY ID ====================
  static ServiceSubType? getSubType(String id) {
    return ServiceMasterData.getSubTypeById(id);
  }

  // ==================== GET SERVICE DETAILS FOR DISPLAY ====================
  static Map<String, String> getServiceDisplayDetails(String serviceId, String subTypeId) {
    final service = getService(serviceId);
    final subType = getSubType(subTypeId);
    
    return {
      'service_name': service?.name ?? serviceId,
      'service_icon': service?.icon ?? '📄',
      'sub_service_name': subType?.name ?? subTypeId,
      'sub_service_description': subType?.description ?? '',
    };
  }

  // ==================== SUBMIT SERVICE APPLICATION ====================
  static Future<Map<String, dynamic>> submitApplication(
    Map<String, dynamic> data,
  ) async {
    try {
      // Validate required user fields
      if (data['user_email'] == null || data['user_email'].toString().isEmpty) {
        throw Exception("User email is required");
      }
      
      // Ensure application_type is set correctly
      data['application_type'] = 'online_service';
      
      final response = await _dio.post(
        '$_base/apply',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== GET USER SERVICE APPLICATIONS ====================
  static Future<List<dynamic>> getUserApplications() async {
    try {
      final response = await _dio.get('$_base/my-applications');
      
      if (response.data is Map) {
        final data = response.data as Map;
        
        if (data.containsKey('applications')) {
          final apps = data['applications'];
          if (apps is List) {
            return apps.map((app) {
              if (app is Map) {
                return Map<String, dynamic>.from(app);
              }
              return app;
            }).toList();
          }
        }
      }
      return [];
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== GET SINGLE SERVICE APPLICATION ====================
  static Future<Map<String, dynamic>> getApplicationDetail(
    String applicationId,
  ) async {
    try {
      final response = await _dio.get('$_base/application/$applicationId');
      return response.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== UPDATE APPLICATION STATUS ====================
  static Future<Map<String, dynamic>> updateApplicationStatus(
    String applicationId,
    String status, {
    String? adminNotes,
  }) async {
    try {
      // Ensure we're sending a proper Map
      final Map<String, dynamic> requestData = {
        'status': status,
      };
      
      if (adminNotes != null && adminNotes.isNotEmpty) {
        requestData['admin_notes'] = adminNotes;
      }
      
      debugPrint("📤 Updating service application status:");
      debugPrint("   Application ID: $applicationId");
      debugPrint("   Status: $status");
      debugPrint("   Data: $requestData");
      
      final response = await _dio.put(
        '$_base/application/$applicationId/status',
        data: requestData,
      );
      
      debugPrint("📥 Response: ${response.data}");
      return response.data;
    } on DioException catch (e) {
      debugPrint("❌ Error updating status: ${e.response?.data}");
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== VERIFY PAYMENT ====================
  static Future<Map<String, dynamic>> verifyPayment(
    String applicationId,
    String transactionId,
  ) async {
    try {
      final response = await _dio.post(
        '$_base/application/$applicationId/verify-payment',
        data: {'transaction_id': transactionId},
      );
      return response.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== UPLOAD DOCUMENT ====================
  static Future<Map<String, dynamic>> uploadDocument({
    required String applicationId,
    required String documentType,
    required MultipartFile file,
  }) async {
    try {
      final formData = FormData.fromMap({
        'document_type': documentType,
        'file': file,
      });

      final response = await _dio.post(
        '$_base/application/$applicationId/upload-document',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== GET SERVICE FEES ====================
  static Future<Map<String, dynamic>> getServiceFees(
    String serviceType,
    String subTypeId,
  ) async {
    try {
      final response = await _dio.get(
        '$_base/fees/$serviceType/$subTypeId',
      );
      return response.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== DELETE APPLICATION ====================
  static Future<Map<String, dynamic>> deleteApplication(
    String applicationId,
  ) async {
    try {
      final response = await _dio.delete(
        '$_base/application/$applicationId',
      );
      return response.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== GET STATISTICS ====================
  static Future<Map<String, dynamic>> getStatistics() async {
    try {
      final response = await _dio.get('$_base/statistics');
      return response.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== REVIEW WITH DOCUMENT ====================
  static Future<Map<String, dynamic>> reviewApplicationWithDocument({
    required String applicationId,
    required MultipartFile file,
    String? notes,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': file,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      final response = await _dio.post(
        '$_base/application/$applicationId/review-with-document',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== FINAL SUBMIT WITH DOCUMENT ====================
  static Future<Map<String, dynamic>> finalSubmitWithDocument({
    required String applicationId,
    required MultipartFile file,
    String? notes,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': file,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      final response = await _dio.post(
        '$_base/application/$applicationId/final-submit-with-document',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }
}