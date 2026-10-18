// lib/features/services/data/service_data_source.dart

import 'package:dio/dio.dart';
import 'package:rojgarnest/core/network/dio_client.dart';

class ServiceDataSource {
  static const String _base = "/services";

  static Dio get _dio => DioClient.dio;

  // ==================== SUBMIT SERVICE APPLICATION ====================
  static Future<Map<String, dynamic>> submitServiceApplication(
    Map<String, dynamic> data,
  ) async {
    try {
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
  static Future<List<dynamic>> getUserServiceApplications() async {
    try {
      final response = await _dio.get('$_base/my-applications');
      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('applications')) {
          return data['applications'] as List<dynamic>;
        }
      }
      return [];
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== GET SINGLE SERVICE APPLICATION ====================
  static Future<Map<String, dynamic>> getServiceApplication(
    String applicationId,
  ) async {
    try {
      final response = await _dio.get('$_base/application/$applicationId');
      return response.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== GET SERVICE APPLICATION STATUS ====================
  static Future<Map<String, dynamic>> getServiceApplicationStatus(
    String applicationId,
  ) async {
    try {
      final response = await _dio.get(
        '$_base/application/$applicationId/status',
      );
      return response.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  // ==================== UPLOAD SERVICE DOCUMENT ====================
  static Future<Map<String, dynamic>> uploadServiceDocument({
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
}