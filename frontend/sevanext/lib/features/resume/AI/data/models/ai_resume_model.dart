// lib/features/resume/AI/data/models/ai_resume_model.dart
// ✅ Model for AI-generated resume payload from backend

class AIResume {
  final Map<String, dynamic> userInfo;
  final Map<String, dynamic> contactInfo;
  final String professionalSummary;
  final String careerObjective;
  final List<Map<String, dynamic>> experience;
  final List<Map<String, dynamic>> education;
  final Map<String, dynamic> skills;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> certifications;
  final List<dynamic> languages;
  final Map<String, dynamic> socialLinks;
  final String generatedAt;
  final String style;
  final String? targetRole;
  final bool hasJd;
  final bool aiPowered;
  final Map<String, dynamic> statistics;

  AIResume({
    required this.userInfo,
    required this.contactInfo,
    required this.professionalSummary,
    required this.careerObjective,
    required this.experience,
    required this.education,
    required this.skills,
    required this.projects,
    required this.certifications,
    required this.languages,
    required this.socialLinks,
    required this.generatedAt,
    required this.style,
    required this.targetRole,
    required this.hasJd,
    required this.aiPowered,
    required this.statistics,
  });

  factory AIResume.fromJson(Map<String, dynamic> json) {
    return AIResume(
      userInfo: Map<String, dynamic>.from(json['user_info'] ?? {}),
      contactInfo: Map<String, dynamic>.from(json['contact_info'] ?? {}),
      professionalSummary: json['professional_summary']?.toString() ?? '',
      careerObjective: json['career_objective']?.toString() ?? '',
      experience: ((json['experience'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      education: ((json['education'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      skills: Map<String, dynamic>.from(json['skills'] ?? {}),
      projects: ((json['projects'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      certifications: ((json['certifications'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      languages: List<dynamic>.from(json['languages'] ?? []),
      socialLinks: Map<String, dynamic>.from(json['social_links'] ?? {}),
      generatedAt: json['generated_at']?.toString() ?? '',
      style: json['style']?.toString() ?? 'modern',
      targetRole: json['target_role']?.toString(),
      hasJd: json['has_jd'] == true,
      aiPowered: json['ai_powered'] == true,
      statistics: Map<String, dynamic>.from(json['statistics'] ?? {}),
    );
  }

  /// Convert to plain Map for PDF rendering (matching ResumeFormatBase interface)
  Map<String, dynamic> toResumeDataMap() {
    return {
      'user_info': userInfo,
      'contact_info': contactInfo,
      'professional_summary': professionalSummary,
      'career_objective': careerObjective,
      'experience': experience,
      'education': education,
      'skills': skills,
      'projects': projects,
      'certifications': certifications,
      'languages': languages,
      'social_links': socialLinks,
      'statistics': statistics,
    };
  }
}