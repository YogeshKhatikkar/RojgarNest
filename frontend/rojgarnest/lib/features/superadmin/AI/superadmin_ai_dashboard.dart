// lib/features/jobs/AI/job_ai_service.dart
import 'package:dio/dio.dart';
import 'package:rojgarnest/core/network/dio_client.dart';

class JobAIService {
  static const String _base = "/jobs/ai";

  static Dio get _dio => DioClient.dio;

  static Future<Map<String, dynamic>> getMatchScore(String jobId) async {
    try {
      final res = await _dio.get(
        '$_base/match-score',
        queryParameters: {'job_id': jobId},
      );
      return res.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> parseDescription(String jobId) async {
    try {
      final res = await _dio.get(
        '$_base/parse-description',
        queryParameters: {'job_id': jobId},
      );
      return res.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> checkFakeJob(
    Map<String, dynamic> jobData,
  ) async {
    try {
      final res = await _dio.post('$_base/fake-job-detection', data: jobData);
      return res.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> predictSalary(
    Map<String, dynamic> jobData,
  ) async {
    try {
      final res = await _dio.post('$_base/salary-prediction', data: jobData);
      return res.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }
}
