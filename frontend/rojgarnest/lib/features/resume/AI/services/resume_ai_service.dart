// lib/features/resume/AI/services/resume_ai_service.dart
// ✅ AI Resume Service — talks to backend /resume/ai/* routes

import 'package:dio/dio.dart';
import 'package:rojgarnest/core/network/dio_client.dart';

class ResumeAIService {
  static Dio get _dio => DioClient.dio;

  // ============================================================
  // 1. ATS SCORE (with optional JD)
  // ============================================================
  static Future<Map<String, dynamic>> scoreResume({
    String? jobDescription,
    List<String>? jobSkills,
  }) async {
    final res = await _dio.post(
      '/resume/ai/score',
      data: {
        if (jobDescription != null && jobDescription.isNotEmpty)
          'job_description': jobDescription,
        if (jobSkills != null && jobSkills.isNotEmpty)
          'job_skills': jobSkills,
      },
    );
    return Map<String, dynamic>.from(res.data['data']);
  }

  // ============================================================
  // 2. FULL AUTO GENERATE
  // ============================================================
  static Future<Map<String, dynamic>> generateResume({
    String? jobDescription,
    String? targetRole,
    String style = 'modern',
  }) async {
    final res = await _dio.post(
      '/resume/ai/generate',
      data: {
        if (jobDescription != null && jobDescription.isNotEmpty)
          'job_description': jobDescription,
        if (targetRole != null && targetRole.isNotEmpty)
          'target_role': targetRole,
        'style': style,
      },
    );
    return Map<String, dynamic>.from(res.data['data']);
  }

  // ============================================================
  // 3. GENERATE + SCORE (combined)
  // ============================================================
  static Future<Map<String, dynamic>> generateAndScore({
    String? jobDescription,
    String? targetRole,
    String style = 'modern',
  }) async {
    final res = await _dio.post(
      '/resume/ai/generate-and-score',
      data: {
        if (jobDescription != null && jobDescription.isNotEmpty)
          'job_description': jobDescription,
        if (targetRole != null && targetRole.isNotEmpty)
          'target_role': targetRole,
        'style': style,
      },
    );
    return Map<String, dynamic>.from(res.data['data']);
  }

  // ============================================================
  // 4. ENHANCE BULLETS
  // ============================================================
  static Future<List<String>> enhanceBullets({
    required List<String> bullets,
    String? role,
    String? jobDescription,
    int count = 5,
  }) async {
    final res = await _dio.post(
      '/resume/ai/enhance-bullets',
      data: {
        'bullets': bullets,
        if (role != null && role.isNotEmpty) 'role': role,
        if (jobDescription != null && jobDescription.isNotEmpty)
          'job_description': jobDescription,
        'count': count,
      },
    );
    return List<String>.from(res.data['data']['bullets']);
  }

  // ============================================================
  // 5. ENHANCE SUMMARY
  // ============================================================
  static Future<String> enhanceSummary({
    required String baseSummary,
    required String role,
    required List<String> skills,
    required int yearsExperience,
    String? jobDescription,
  }) async {
    final res = await _dio.post(
      '/resume/ai/enhance-summary',
      data: {
        'base_summary': baseSummary,
        'role': role,
        'skills': skills,
        'years_experience': yearsExperience,
        if (jobDescription != null && jobDescription.isNotEmpty)
          'job_description': jobDescription,
      },
    );
    return res.data['data']['summary'] as String;
  }

  // ============================================================
  // 6. QUICK ATS SCORE (no JD)
  // ============================================================
  static Future<Map<String, dynamic>> quickScore() async {
    final res = await _dio.get('/resume/ai/quick-score');
    return Map<String, dynamic>.from(res.data['data']);
  }
}