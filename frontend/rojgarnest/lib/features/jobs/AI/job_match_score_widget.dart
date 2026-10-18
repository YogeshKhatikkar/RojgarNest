// lib/features/jobs/AI/job_match_score_widget.dart
import 'package:flutter/material.dart';
import 'package:rojgarnest/features/jobs/AI/job_ai_service.dart';

class JobMatchScoreWidget extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const JobMatchScoreWidget({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<JobMatchScoreWidget> createState() => _JobMatchScoreWidgetState();
}

class _JobMatchScoreWidgetState extends State<JobMatchScoreWidget> {
  bool _isLoading = true;
  Map<String, dynamic>? _matchData;

  @override
  void initState() {
    super.initState();
    _loadMatchScore();
  }

  Future<void> _loadMatchScore() async {
    try {
      final data = await JobAIService.getMatchScore(widget.jobId);
      if (mounted) {
        setState(() {
          _matchData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_matchData == null) {
      return const SizedBox.shrink();
    }

    final matchScore = _matchData!['match_score'] ?? 0;
    final skillMatch = _matchData!['skill_match'] ?? 0;
    final expMatch = _matchData!['experience_match'] ?? 0;
    final recommendation = _matchData!['recommendation'] ?? 'Consider';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getScoreColor(matchScore).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "AI Match Score",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "$matchScore%",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(matchScore),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: matchScore / 100,
            backgroundColor: Colors.grey.shade200,
            color: _getScoreColor(matchScore),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSubMetric("Skills", skillMatch)),
              Expanded(child: _buildSubMetric("Experience", expMatch)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getRecommendationColor(
                recommendation,
              ).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Recommendation: $recommendation",
              style: TextStyle(
                color: _getRecommendationColor(recommendation),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_matchData!['missing_skills'] != null &&
              (_matchData!['missing_skills'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              "Missing Skills:",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Wrap(
              spacing: 4,
              children: (_matchData!['missing_skills'] as List)
                  .map(
                    (skill) => Chip(
                      label: Text(
                        skill.toString(),
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.red.shade100,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubMetric(String label, int score) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          "$score%",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _getScoreColor(score),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Color _getRecommendationColor(String recommendation) {
    switch (recommendation.toLowerCase()) {
      case 'apply':
        return Colors.green;
      case 'consider':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}
