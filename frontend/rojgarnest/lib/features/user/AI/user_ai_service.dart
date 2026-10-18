// lib/features/user/AI/user_ai_service.dart
import 'package:dio/dio.dart';
import 'package:rojgarnest/core/network/dio_client.dart';

class UserAIService {
  static const String _base = "/user/ai";

  static Dio get _dio => DioClient.dio;

  static Future<Map<String, dynamic>> getCareerAnalysis() async {
    try {
      final response = await _dio.get('$_base/career-analysis');
      // Extract data from the response structure
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        // Check if data is wrapped in 'data' key
        if (data.containsKey('data')) {
          return data['data'] as Map<String, dynamic>;
        }
        return data;
      }
      return {};
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> getJobRecommendations({
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '$_base/job-recommendations',
        queryParameters: {'limit': limit},
      );
      // Extract data from the response structure
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        // Check if data is wrapped in 'data' key
        if (data.containsKey('data')) {
          return {'data': data['data']};
        }
        return data;
      }
      return {'data': []};
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> getSkillGapAnalysis() async {
    try {
      final response = await _dio.get('$_base/skill-gap-analysis');
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        if (data.containsKey('data')) {
          return data['data'] as Map<String, dynamic>;
        }
        return data;
      }
      return {};
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> getProfileComparison() async {
    try {
      final response = await _dio.get('$_base/profile-comparison');
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        if (data.containsKey('data')) {
          return data['data'] as Map<String, dynamic>;
        }
        return data;
      }
      return {};
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> getAllInsights() async {
    try {
      final response = await _dio.get('$_base/all-insights');
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        if (data.containsKey('data')) {
          return data['data'] as Map<String, dynamic>;
        }
        return data;
      }
      return {};
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> getCareerRoadmap(
    String targetCareer,
  ) async {
    try {
      final response = await _dio.post(
        '$_base/career-roadmap',
        data: {'target_career': targetCareer},
      );
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        if (data.containsKey('data')) {
          return data['data'] as Map<String, dynamic>;
        }
        return data;
      }
      return {};
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }
}
