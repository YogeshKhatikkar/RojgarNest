// lib/features/market/AI/market_ai_service.dart
import 'package:dio/dio.dart';
import 'package:rojgarnest/core/network/dio_client.dart';

class MarketAIService {
  static const String _base = "/market/ai";

  static Dio get _dio => DioClient.dio;

  static Future<Map<String, dynamic>> getTrendPrediction({
    String? industry,
  }) async {
    try {
      final res = await _dio.get(
        '$_base/trend-prediction',
        queryParameters: industry != null ? {'industry': industry} : null,
      );
      return res.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }

  static Future<Map<String, dynamic>> getSkillForecast(
    String skillName, {
    int months = 6,
  }) async {
    try {
      final res = await _dio.get(
        '$_base/skill-forecast',
        queryParameters: {'skill_name': skillName, 'months': months},
      );
      return res.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }
}
