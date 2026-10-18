// lib/features/resume/AI/presentation/screens/ai_resume_generator_screen.dart
// ✅ Full Auto AI Resume Generator Screen

import 'package:flutter/material.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/resume/AI/data/models/ai_resume_model.dart';
import 'package:rojgarnest/features/resume/AI/services/resume_ai_service.dart';
import 'package:rojgarnest/features/resume/AI/presentation/widgets/ai_loading_overlay.dart';
import 'package:rojgarnest/features/resume/services/resume_pdf_service.dart';

class AIResumeGeneratorScreen extends StatefulWidget {
  const AIResumeGeneratorScreen({super.key});

  @override
  State<AIResumeGeneratorScreen> createState() =>
      _AIResumeGeneratorScreenState();
}

class _AIResumeGeneratorScreenState extends State<AIResumeGeneratorScreen> {
  final TextEditingController _jdCtrl = TextEditingController();
  final TextEditingController _targetRoleCtrl = TextEditingController();

  String _style = 'modern';
  bool _isGenerating = false;
  AIResume? _generated;

  static const List<Map<String, String>> _styles = [
    {'value': 'classic', 'label': 'Classic', 'icon': '📄'},
    {'value': 'modern', 'label': 'Modern', 'icon': '🎨'},
    {'value': 'tech', 'label': 'Tech', 'icon': '💻'},
    {'value': 'executive', 'label': 'Executive', 'icon': '👔'},
    {'value': 'government', 'label': 'Government', 'icon': '🏛️'},
    {'value': 'fresher', 'label': 'Fresher', 'icon': '🎓'},
  ];

  @override
  void dispose() {
    _jdCtrl.dispose();
    _targetRoleCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);
    try {
      final data = await ResumeAIService.generateResume(
        jobDescription:
            _jdCtrl.text.trim().isEmpty ? null : _jdCtrl.text.trim(),
        targetRole: _targetRoleCtrl.text.trim().isEmpty
            ? null
            : _targetRoleCtrl.text.trim(),
        style: _style,
      );
      final resume = AIResume.fromJson(data);
      if (mounted) {
        setState(() => _generated = resume);
        showMessage(context, '✅ Resume generated successfully!');
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Generation failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_generated == null) return;
    try {
      final name = (_generated!.userInfo['full_name'] ?? 'Resume')
          .toString()
          .replaceAll(RegExp(r'[^\w]'), '_');
      await ResumePdfService.download(
        fileNameBase: name,
        data: _generated!.toResumeDataMap(),
        styleKey: _style,
        colorHex: '#6C63FF',
      );
      if (mounted) showMessage(context, '✅ PDF downloaded!');
    } catch (e) {
      if (mounted) showMessage(context, 'Download failed: $e', isError: true);
    }
  }

  Future<void> _sharePdf() async {
    if (_generated == null) return;
    try {
      final name = (_generated!.userInfo['full_name'] ?? 'Resume')
          .toString()
          .replaceAll(RegExp(r'[^\w]'), '_');
      await ResumePdfService.share(
        fileNameBase: name,
        data: _generated!.toResumeDataMap(),
        styleKey: _style,
        colorHex: '#6C63FF',
      );
      if (mounted) showMessage(context, '✅ Resume shared!');
    } catch (e) {
      if (mounted) showMessage(context, 'Share failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('AI Resume Generator'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isGenerating
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
                ),
              ),
              child: const AILoadingOverlay(
                message: 'AI is writing your resume...',
                subtitle:
                    'Enhancing summary, bullets, keywords and section ordering',
              ),
            )
          : _generated == null
              ? _buildForm()
              : _buildPreview(),
    );
  }

  // ============================================================
  // FORM
  // ============================================================
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIntroCard(),
          const SizedBox(height: 20),
          _buildCard(
            title: 'Target Role (optional)',
            icon: Icons.flag_outlined,
            child: TextField(
              controller: _targetRoleCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Backend Engineer, Data Scientist',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            title: 'Resume Style',
            icon: Icons.palette_outlined,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _styles.map((s) {
                final isSelected = _style == s['value'];
                return GestureDetector(
                  onTap: () => setState(() => _style = s['value']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s['icon']!,
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          s['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            title: 'Job Description (optional but recommended)',
            icon: Icons.work_outline,
            child: TextField(
              controller: _jdCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                hintText:
                    'Paste the JD here — AI will tailor keywords to match.',
                hintStyle:
                    TextStyle(fontSize: 12, color: Colors.grey.shade500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text(
                'Generate Resume with AI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fully Automatic AI Resume',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ATS-optimized · Keyword matched · Quantified bullets',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ============================================================
  // PREVIEW
  // ============================================================
  Widget _buildPreview() {
    final r = _generated!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _generated = null),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C63FF),
                    side: const BorderSide(color: Color(0xFF6C63FF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _downloadPdf,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _sharePdf,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _previewCard(
                    icon: Icons.person,
                    title: 'Contact',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _previewText(
                            r.userInfo['full_name']?.toString() ?? '',
                            bold: true,
                            size: 18),
                        if (r.contactInfo['email'] != null)
                          _previewText('📧 ${r.contactInfo['email']}'),
                        if (r.contactInfo['phone'] != null)
                          _previewText('📞 ${r.contactInfo['phone']}'),
                        if (r.contactInfo['location'] != null)
                          _previewText('📍 ${r.contactInfo['location']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (r.professionalSummary.isNotEmpty)
                    _previewCard(
                      icon: Icons.subject,
                      title: 'Professional Summary',
                      child: _previewText(r.professionalSummary),
                    ),
                  const SizedBox(height: 12),
                  if (r.careerObjective.isNotEmpty)
                    _previewCard(
                      icon: Icons.flag,
                      title: 'Career Objective',
                      child: _previewText(r.careerObjective),
                    ),
                  const SizedBox(height: 12),
                  if (r.experience.isNotEmpty)
                    _previewCard(
                      icon: Icons.work,
                      title: 'Experience (${r.experience.length})',
                      child: Column(
                        children: r.experience.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _previewText(
                                  e['role']?.toString() ?? '',
                                  bold: true,
                                  size: 14,
                                ),
                                _previewText(
                                  '${e['company']} · ${e['start_date']} - ${e['end_date']}',
                                  muted: true,
                                ),
                                const SizedBox(height: 6),
                                ...((e['achievements'] as List?) ?? [])
                                    .map((b) => Padding(
                                          padding: const EdgeInsets.only(
                                              left: 6, bottom: 3),
                                          child: _previewText('• $b'),
                                        )),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (r.education.isNotEmpty)
                    _previewCard(
                      icon: Icons.school,
                      title: 'Education (${r.education.length})',
                      child: Column(
                        children: r.education.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _previewText(
                                  e['degree']?.toString() ?? '',
                                  bold: true,
                                ),
                                _previewText(
                                  '${e['institute']} · ${e['year_of_passing']}',
                                  muted: true,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if ((r.skills['all'] as List?)?.isNotEmpty == true)
                    _previewCard(
                      icon: Icons.build,
                      title: 'Skills',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            (r.skills['all'] as List).map<Widget>((s) {
                          final name = (s is Map) ? s['name'] : s;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF6C63FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF6C63FF)
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              name.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (r.projects.isNotEmpty)
                    _previewCard(
                      icon: Icons.code,
                      title: 'Projects (${r.projects.length})',
                      child: Column(
                        children: r.projects.map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _previewText(
                                    p['title']?.toString() ?? '',
                                    bold: true),
                                _previewText(
                                    p['description']?.toString() ?? ''),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (r.certifications.isNotEmpty)
                    _previewCard(
                      icon: Icons.verified,
                      title: 'Certifications',
                      child: Column(
                        children: r.certifications.map((c) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _previewText(
                              '✓ ${c['name']} - ${c['issuer']} (${c['year']})',
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF6C63FF)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _previewText(String text,
      {bool bold = false, bool muted = false, double size = 13}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: TextStyle(
        fontSize: size,
        height: 1.4,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: muted ? Colors.grey.shade600 : Colors.black87,
      ),
    );
  }
}