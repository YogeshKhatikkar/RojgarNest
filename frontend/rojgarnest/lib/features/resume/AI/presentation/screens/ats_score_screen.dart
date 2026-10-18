// lib/features/resume/AI/presentation/screens/ats_score_screen.dart
// ✅ ATS Score Screen — full flow with JD comparison

import 'package:flutter/material.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/resume/AI/data/models/ats_report_model.dart';
import 'package:rojgarnest/features/resume/AI/services/resume_ai_service.dart';
import 'package:rojgarnest/features/resume/AI/presentation/widgets/ats_score_gauge.dart';
import 'package:rojgarnest/features/resume/AI/presentation/widgets/ats_section_breakdown.dart';
import 'package:rojgarnest/features/resume/AI/presentation/widgets/ats_keyword_chips.dart';
import 'package:rojgarnest/features/resume/AI/presentation/widgets/ats_fixes_card.dart';
import 'package:rojgarnest/features/resume/AI/presentation/widgets/ai_loading_overlay.dart';

class ATSScoreScreen extends StatefulWidget {
  const ATSScoreScreen({super.key});

  @override
  State<ATSScoreScreen> createState() => _ATSScoreScreenState();
}

class _ATSScoreScreenState extends State<ATSScoreScreen> {
  final TextEditingController _jdCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isScoring = false;
  ATSReport? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runQuickScore();
  }

  @override
  void dispose() {
    _jdCtrl.dispose();
    super.dispose();
  }

  // ---------- 1. QUICK SCORE (no JD) ----------
  Future<void> _runQuickScore() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ResumeAIService.quickScore();
      final report = ATSReport(
        overallScore: (data['overall_score'] ?? 0).toDouble(),
        grade: data['grade'] ?? '',
        sectionScores: Map<String, int>.from(
          (data['section_scores'] as Map? ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
          ),
        ),
        keywordAnalysis: KeywordAnalysis.fromJson({}),
        formatting: FormattingReport.fromJson({}),
        actionVerbs: ActionVerbReport.fromJson({}),
        quantification: QuantificationReport.fromJson({}),
        prioritizedFixes: ((data['top_fixes'] as List?) ?? [])
            .map((e) => ATSFix.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        aiSummary: data['ai_summary'] ?? '',
        scoredAt: '',
      );
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- 2. FULL SCORE (with JD) ----------
  Future<void> _runFullScore() async {
    final jd = _jdCtrl.text.trim();
    if (jd.isEmpty) {
      showMessage(context, 'Please paste a job description first',
          isError: true);
      return;
    }
    setState(() {
      _isScoring = true;
      _error = null;
    });
    try {
      final data = await ResumeAIService.scoreResume(jobDescription: jd);
      final report = ATSReport.fromJson(data);
      if (mounted) setState(() => _report = report);
      if (mounted) showMessage(context, 'ATS analysis complete! ✅');
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Failed: $e', isError: true);
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isScoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('ATS Score Analyzer'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runQuickScore,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading || _isScoring
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
                ),
              ),
              child: AILoadingOverlay(
                message: _isScoring
                    ? 'AI is analyzing against JD...'
                    : 'AI is scoring your resume...',
                subtitle: _isScoring
                    ? 'Extracting keywords, comparing skills, checking ATS compatibility'
                    : 'Running 8-dimension ATS analysis',
              ),
            )
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_report != null)
            Center(
              child: ATSScoreGauge(
                score: _report!.overallScore,
                grade: _report!.grade,
              ),
            ),
          if (_report != null) const SizedBox(height: 20),
          if (_report != null && _report!.aiSummary.isNotEmpty)
            _buildAISummaryCard(_report!.aiSummary),
          if (_report != null) const SizedBox(height: 20),
          _buildJDInputCard(),
          const SizedBox(height: 20),
          if (_report != null && _report!.sectionScores.isNotEmpty)
            _buildSectionCard(
              title: 'Section-wise Score',
              icon: Icons.bar_chart,
              child: ATSSectionBreakdown(
                sectionScores: _report!.sectionScores,
              ),
            ),
          if (_report != null) const SizedBox(height: 20),
          if (_report != null)
            _buildSectionCard(
              title: 'Keyword Match Analysis',
              icon: Icons.vpn_key,
              child: ATSKeywordChips(
                matched: _report!.keywordAnalysis.matchedKeywords,
                missing: _report!.keywordAnalysis.missingKeywords,
                priorityMissing:
                    _report!.keywordAnalysis.topPriorityMissing,
              ),
            ),
          if (_report != null) const SizedBox(height: 20),
          if (_report != null && _report!.prioritizedFixes.isNotEmpty) ...[
            _buildSectionHeader('Priority Fixes', Icons.build_circle),
            const SizedBox(height: 12),
            ATSFixesCard(fixes: _report!.prioritizedFixes),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildJDInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8B7FFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.work_outline, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Compare with Job Description',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Paste the JD to get keyword matching & score boost tips.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.85), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _jdCtrl,
              maxLines: 5,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              decoration: const InputDecoration(
                hintText:
                    'e.g. We are looking for a Python developer with 3+ years...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isScoring ? null : _runFullScore,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text(
                'Analyze against JD',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISummaryCard(String summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.08),
            const Color(0xFFFF6588).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title, icon),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline,
                  size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            const Text(
              'Failed to score resume',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _runQuickScore,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}