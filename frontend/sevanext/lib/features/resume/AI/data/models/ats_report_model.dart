// lib/features/resume/AI/data/models/ats_report_model.dart
// ✅ Complete ATS Report Model — matches backend response

class ATSReport {
  final double overallScore;
  final String grade;
  final Map<String, int> sectionScores;
  final KeywordAnalysis keywordAnalysis;
  final FormattingReport formatting;
  final ActionVerbReport actionVerbs;
  final QuantificationReport quantification;
  final List<ATSFix> prioritizedFixes;
  final String aiSummary;
  final String scoredAt;

  ATSReport({
    required this.overallScore,
    required this.grade,
    required this.sectionScores,
    required this.keywordAnalysis,
    required this.formatting,
    required this.actionVerbs,
    required this.quantification,
    required this.prioritizedFixes,
    required this.aiSummary,
    required this.scoredAt,
  });

  factory ATSReport.fromJson(Map<String, dynamic> json) {
    return ATSReport(
      overallScore: (json['overall_score'] ?? 0).toDouble(),
      grade: json['grade']?.toString() ?? 'N/A',
      sectionScores: Map<String, int>.from(
        (json['section_scores'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
        ),
      ),
      keywordAnalysis: KeywordAnalysis.fromJson(
        json['keyword_analysis'] as Map<String, dynamic>? ?? {},
      ),
      formatting: FormattingReport.fromJson(
        json['formatting_issues'] as Map<String, dynamic>? ?? {},
      ),
      actionVerbs: ActionVerbReport.fromJson(
        json['action_verbs'] as Map<String, dynamic>? ?? {},
      ),
      quantification: QuantificationReport.fromJson(
        json['quantification'] as Map<String, dynamic>? ?? {},
      ),
      prioritizedFixes: ((json['prioritized_fixes'] as List?) ?? [])
          .map((e) => ATSFix.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      aiSummary: json['ai_summary']?.toString() ?? '',
      scoredAt: json['scored_at']?.toString() ?? '',
    );
  }

  bool get isGood => overallScore >= 70;
  bool get isExcellent => overallScore >= 85;
}

// ---------- Keyword Analysis ----------
class KeywordAnalysis {
  final bool hasJobDescription;
  final int jdTotalKeywords;
  final List<String> matchedKeywords;
  final List<String> missingKeywords;
  final List<String> topPriorityMissing;
  final double matchPercentage;
  final double keywordDensity;
  final String recommendedDensity;

  KeywordAnalysis({
    required this.hasJobDescription,
    required this.jdTotalKeywords,
    required this.matchedKeywords,
    required this.missingKeywords,
    required this.topPriorityMissing,
    required this.matchPercentage,
    required this.keywordDensity,
    required this.recommendedDensity,
  });

  factory KeywordAnalysis.fromJson(Map<String, dynamic> json) {
    return KeywordAnalysis(
      hasJobDescription: json['has_job_description'] == true,
      jdTotalKeywords: (json['jd_total_keywords'] as num?)?.toInt() ?? 0,
      matchedKeywords: List<String>.from(json['matched_keywords'] ?? []),
      missingKeywords: List<String>.from(json['missing_keywords'] ?? []),
      topPriorityMissing:
          List<String>.from(json['top_priority_missing'] ?? []),
      matchPercentage:
          (json['match_percentage'] as num?)?.toDouble() ?? 0.0,
      keywordDensity: (json['keyword_density'] as num?)?.toDouble() ?? 0.0,
      recommendedDensity:
          json['recommended_density']?.toString() ?? '1.5% – 2.5%',
    );
  }
}

// ---------- Formatting ----------
class FormattingReport {
  final int score;
  final List<Map<String, dynamic>> criticalIssues;
  final List<Map<String, dynamic>> issues;
  final List<String> warnings;
  final bool atsCompatible;

  FormattingReport({
    required this.score,
    required this.criticalIssues,
    required this.issues,
    required this.warnings,
    required this.atsCompatible,
  });

  factory FormattingReport.fromJson(Map<String, dynamic> json) {
    return FormattingReport(
      score: (json['score'] as num?)?.toInt() ?? 0,
      criticalIssues: ((json['critical_issues'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      issues: ((json['issues'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      warnings: List<String>.from(json['warnings'] ?? []),
      atsCompatible: json['ats_compatible'] == true,
    );
  }
}

// ---------- Action Verbs ----------
class ActionVerbReport {
  final int score;
  final List<String> strongVerbsFound;
  final List<String> weakVerbsFound;
  final List<String> suggestions;

  ActionVerbReport({
    required this.score,
    required this.strongVerbsFound,
    required this.weakVerbsFound,
    required this.suggestions,
  });

  factory ActionVerbReport.fromJson(Map<String, dynamic> json) {
    return ActionVerbReport(
      score: (json['score'] as num?)?.toInt() ?? 0,
      strongVerbsFound: List<String>.from(json['strong_verbs_found'] ?? []),
      weakVerbsFound: List<String>.from(json['weak_verbs_found'] ?? []),
      suggestions: List<String>.from(json['suggestions'] ?? []),
    );
  }
}

// ---------- Quantification ----------
class QuantificationReport {
  final int score;
  final int quantifiedMentions;
  final List<String> samples;
  final List<String> suggestions;

  QuantificationReport({
    required this.score,
    required this.quantifiedMentions,
    required this.samples,
    required this.suggestions,
  });

  factory QuantificationReport.fromJson(Map<String, dynamic> json) {
    return QuantificationReport(
      score: (json['score'] as num?)?.toInt() ?? 0,
      quantifiedMentions:
          (json['quantified_mentions'] as num?)?.toInt() ?? 0,
      samples: List<String>.from(json['samples'] ?? []),
      suggestions: List<String>.from(json['suggestions'] ?? []),
    );
  }
}

// ---------- Fix ----------
class ATSFix {
  final int priority;
  final String category;
  final String issue;
  final String impact;
  final String fix;

  ATSFix({
    required this.priority,
    required this.category,
    required this.issue,
    required this.impact,
    required this.fix,
  });

  factory ATSFix.fromJson(Map<String, dynamic> json) {
    return ATSFix(
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      category: json['category']?.toString() ?? 'General',
      issue: json['issue']?.toString() ?? '',
      impact: json['impact']?.toString() ?? 'Low',
      fix: json['fix']?.toString() ?? '',
    );
  }
}