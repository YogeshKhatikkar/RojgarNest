// lib/features/resume/AI/resume_ai_service.dart
import 'package:dio/dio.dart';
import 'package:rojgarnest/core/network/dio_client.dart';

class ResumeAIService {
  static const String _base = "/resume/ai";

  static Dio get _dio => DioClient.dio;

  static Future<Map<String, dynamic>> getResumeScore() async {
    try {
      final res = await _dio.get('$_base/score');
      return res.data;
    } on DioException catch (e) {
      throw DioClient.extractErrorMessage(e);
    }
  }
}
