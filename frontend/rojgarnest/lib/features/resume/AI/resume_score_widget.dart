// lib/features/resume/AI/resume_score_widget.dart
import 'package:flutter/material.dart';
import 'package:rojgarnest/features/resume/AI/resume_ai_service.dart';

class ResumeScoreWidget extends StatefulWidget {
  const ResumeScoreWidget({super.key});

  @override
  State<ResumeScoreWidget> createState() => _ResumeScoreWidgetState();
}

class _ResumeScoreWidgetState extends State<ResumeScoreWidget> {
  bool _isLoading = true;
  Map<String, dynamic>? _scoreData;

  @override
  void initState() {
    super.initState();
    _loadScore();
  }

  Future<void> _loadScore() async {
    try {
      final data = await ResumeAIService.getResumeScore();
      if (mounted) {
        setState(() {
          _scoreData = data;
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_scoreData == null) {
      return const SizedBox.shrink();
    }

    final score = _scoreData!['resume_score'] ?? 0;
    final rating = _scoreData!['rating'] ?? 'Needs Improvement';
    final suggestions = _scoreData!['suggestions'] ?? [];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Resume AI Score",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: _getScoreColor(score),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$score%",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        rating,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getScoreColor(score),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Suggestions to Improve:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...suggestions.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.toString())),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}
