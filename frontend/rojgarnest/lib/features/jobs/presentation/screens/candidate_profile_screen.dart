// lib/features/jobs/presentation/screens/candidate_profile_screen.dart
// ✅ MOUSE DRAG SELECT + COPY SUPPORT (Web / Desktop / Mobile)
// ✅ SelectionArea wraps entire screen — drag with mouse to select any text
// ✅ Custom right-click context menu → Copy button
// ✅ All text colors clearly visible
// ✅ All original functionality preserved — NO lines skipped

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CandidateProfileScreen extends StatefulWidget {
  final String email;
  final String candidateName;
  final VoidCallback? onBack;

  const CandidateProfileScreen({
    super.key,
    required this.email,
    required this.candidateName,
    this.onBack,
  });

  @override
  State<CandidateProfileScreen> createState() => _CandidateProfileScreenState();
}

class _CandidateProfileScreenState extends State<CandidateProfileScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _profile = {};
  String? _errorMessage;

  // ==================== ANIMATION CONTROLLERS ====================
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ✅ EXPLICIT COLOR CONSTANTS — guarantee visibility
  static const Color _kTextPrimary = Color(0xFF111827); // near-black
  static const Color _kTextSecondary = Color(0xFF374151); // dark grey
  static const Color _kTextMuted = Color(0xFF6B7280); // grey
  static const Color _kPrimary = Color(0xFF6C63FF);
  static const Color _kPink = Color(0xFFFF6588);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fetchProfile();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================
  // FETCH PROFILE
  // ============================================================
  Future<void> _fetchProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint("📋 Fetching candidate profile for email: ${widget.email}");

      final response = await DioClient.dio.get(
        '/user/user-profile-by-email?email=${widget.email}',
      );

      if (!mounted) return;

      if (response.data is Map) {
        final data = response.data;
        if (data.containsKey('data') && data['data'] is Map) {
          _profile = data['data'];
        } else {
          _profile = data;
        }
      }

      debugPrint("📋 Profile fetched successfully");
    } catch (e) {
      if (!mounted) return;
      debugPrint("❌ Error fetching profile: $e");
      setState(() {
        _errorMessage = e.toString();
      });
      showMessage(context, "Failed to load profile: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // ✅ CUSTOM CONTEXT MENU — right-click → Copy / Select All
  // ============================================================
  Widget _buildContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final buttonItems = selectableRegionState.contextMenuButtonItems;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  // ============================================================
  // PRINT PROFILE (PDF)
  // ============================================================
  Future<void> _printProfile() async {
    try {
      final pdf = await _generatePdf();
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'Candidate_Profile_${widget.candidateName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error printing: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e.toString()}",
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    final fullName = _getString('full_name');
    final email = widget.email;
    final phone = _getString('phone');
    final dob = _getString('dob');
    final gender = _getString('gender');
    final category = _getString('category');

    final address = _profile['current_address'] as Map? ?? {};
    final village = address['village_name'] ?? '';
    final district = address['district'] ?? '';
    final state = address['state'] ?? '';
    final pincode = address['pincode'] ?? '';

    final disability = _profile['disability'] as Map? ?? {};
    final isDisabled =
        disability['is_disabled'] == true || _profile['is_disable'] == true;
    final disabilityCategory = disability['disability_category'] ??
        _profile['disability_category'] ??
        '';
    final disabilityPercentage = disability['disability_percentage'] ??
        _profile['disability_percentage'];
    final disabilityDetails = disability['disability_details'] ?? '';

    final educationList = _getList('academic_records');
    final experienceList = _getList('experience');
    final skillsList = _getList('skills');
    final certList = _getList('certifications');
    final projectList = _getList('projects');
    final languagesKnown = _getList('languages_known');
    final summary = _getString('summary');
    final careerObjective = _getString('career_objective');

    final social = _profile['social_links'] as Map? ?? {};
    final linkedin = social['linkedin'] ?? '';
    final github = social['github'] ?? '';
    final portfolio = social['portfolio'] ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    fullName,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Candidate Profile - RojgarNest Job Portal',
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.grey),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Divider(thickness: 2, color: PdfColors.blue),
            pw.SizedBox(height: 20),
            pw.Text(
              'Personal Information',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildPdfRow('Full Name:', fullName),
                  _buildPdfRow('Email:', email),
                  _buildPdfRow(
                      'Phone:', phone.isNotEmpty ? phone : 'Not provided'),
                  _buildPdfRow(
                      'Date of Birth:', dob.isNotEmpty ? dob : 'Not provided'),
                  _buildPdfRow(
                      'Gender:', gender.isNotEmpty ? gender : 'Not provided'),
                  _buildPdfRow('Category:',
                      category.isNotEmpty ? category : 'Not provided'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            if (village.isNotEmpty || district.isNotEmpty || state.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Address',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (village.isNotEmpty)
                          _buildPdfRow('Village/City:', village),
                        if (district.isNotEmpty)
                          _buildPdfRow('District:', district),
                        if (state.isNotEmpty) _buildPdfRow('State:', state),
                        if (pincode.isNotEmpty)
                          _buildPdfRow('Pincode:', pincode),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
            if (isDisabled)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Disability Information',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfRow('Status:', 'Yes'),
                        if (disabilityCategory.isNotEmpty)
                          _buildPdfRow('Category:', disabilityCategory),
                        if (disabilityPercentage != null)
                          _buildPdfRow(
                              'Percentage:', '$disabilityPercentage%'),
                        if (disabilityDetails.isNotEmpty)
                          _buildPdfRow('Details:', disabilityDetails),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
            if (educationList.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Education',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  ...educationList.map((edu) => pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        margin: const pw.EdgeInsets.only(bottom: 10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              edu['degree'] ?? edu['level'] ?? 'Education',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 14),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                                '${edu['institute'] ?? ''} | Passing Year: ${edu['year_of_passing'] ?? ''}'),
                            if (edu['cgpa_percentage'] != null)
                              pw.Text(
                                  '${edu['result_type'] ?? 'Score'}: ${edu['cgpa_percentage']}'),
                            if (edu['board_university'] != null &&
                                edu['board_university'].toString().isNotEmpty)
                              pw.Text(
                                  'Board/University: ${edu['board_university']}'),
                          ],
                        ),
                      )),
                  pw.SizedBox(height: 20),
                ],
              ),
            if (experienceList.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Work Experience',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  ...experienceList.map((exp) => pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        margin: const pw.EdgeInsets.only(bottom: 10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              exp['role'] ?? 'Position',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 14),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text('${exp['company'] ?? ''}'),
                            pw.Text(
                                '${exp['start_date'] ?? ''} - ${exp['end_date'] ?? 'Present'}'),
                            if (exp['description'] != null &&
                                exp['description'].toString().isNotEmpty)
                              pw.Text(exp['description']),
                          ],
                        ),
                      )),
                  pw.SizedBox(height: 20),
                ],
              ),
            if (skillsList.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Skills',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: skillsList.map((skill) {
                      final skillName = skill is Map ? skill['name'] : skill;
                      return pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(skillName.toString(),
                            style: pw.TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
            if (certList.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Certifications',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: certList.map((cert) {
                      final certName = cert is Map ? cert['name'] : cert;
                      return pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.purple50,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(certName.toString(),
                            style: pw.TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
            if (projectList.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Projects',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  ...projectList.map((proj) => pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        margin: const pw.EdgeInsets.only(bottom: 10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              proj['title'] ?? 'Project',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 14),
                            ),
                            if (proj['description'] != null &&
                                proj['description'].toString().isNotEmpty)
                              pw.Text(proj['description']),
                            if (proj['technologies'] != null &&
                                (proj['technologies'] as List).isNotEmpty)
                              pw.Text(
                                  'Technologies: ${(proj['technologies'] as List).join(', ')}'),
                          ],
                        ),
                      )),
                  pw.SizedBox(height: 20),
                ],
              ),
            if (languagesKnown.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Languages',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: languagesKnown
                        .map((lang) => pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.cyan50,
                                borderRadius: pw.BorderRadius.circular(20),
                              ),
                              child: pw.Text(lang.toString(),
                                  style: pw.TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
            if (summary.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Professional Summary',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(summary,
                        style: pw.TextStyle(fontSize: 12, height: 1.5)),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
            if (careerObjective.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Career Objective',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(careerObjective,
                        style: pw.TextStyle(fontSize: 12, height: 1.5)),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
            if (linkedin.isNotEmpty ||
                github.isNotEmpty ||
                portfolio.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Social & Professional Links',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (linkedin.isNotEmpty)
                          _buildPdfRow('LinkedIn:', linkedin),
                        if (github.isNotEmpty) _buildPdfRow('GitHub:', github),
                        if (portfolio.isNotEmpty)
                          _buildPdfRow('Portfolio:', portfolio),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Generated by RojgarNest on ${DateTime.now().toString().split(' ')[0]}\nThis is an official document from RojgarNest Job Portal',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    // ✅ WRAP ENTIRE SCREEN IN SelectionArea
    // This enables mouse drag-to-select on web/desktop across ALL text
    return SelectionArea(
      contextMenuBuilder: _buildContextMenu,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Container(
          decoration: _buildGradientBackground(),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroCard(),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: "Personal Information",
                          icon: Icons.person,
                          color: const Color(0xFF6C63FF),
                          children: [
                            _buildSelectableInfoRow(
                              Icons.person_outline,
                              "Full Name",
                              _getString('full_name'),
                            ),
                            _buildDivider(),
                            _buildSelectableInfoRow(
                              Icons.email,
                              "Email",
                              widget.email,
                            ),
                            _buildDivider(),
                            _buildSelectableInfoRow(
                              Icons.phone,
                              "Phone",
                              _getString('phone'),
                            ),
                            _buildDivider(),
                            _buildSelectableInfoRow(
                              Icons.cake,
                              "Date of Birth",
                              _getString('dob'),
                            ),
                            _buildDivider(),
                            _buildSelectableInfoRow(
                              Icons.wc,
                              "Gender",
                              _getString('gender'),
                            ),
                            _buildDivider(),
                            _buildSelectableInfoRow(
                              Icons.category,
                              "Category",
                              _getString('category'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDisabilityCard(),
                        const SizedBox(height: 16),
                        _buildAddressCard(),
                        const SizedBox(height: 16),
                        if (_getList('academic_records').isNotEmpty)
                          _buildEducationSection(),
                        if (_getList('academic_records').isNotEmpty)
                          const SizedBox(height: 16),
                        if (_getList('experience').isNotEmpty)
                          _buildExperienceSection(),
                        if (_getList('experience').isNotEmpty)
                          const SizedBox(height: 16),
                        if (_getList('skills').isNotEmpty)
                          _buildSkillsSection(),
                        if (_getList('skills').isNotEmpty)
                          const SizedBox(height: 16),
                        if (_getList('certifications').isNotEmpty)
                          _buildCertificationsSection(),
                        if (_getList('certifications').isNotEmpty)
                          const SizedBox(height: 16),
                        if (_getList('projects').isNotEmpty)
                          _buildProjectsSection(),
                        if (_getList('projects').isNotEmpty)
                          const SizedBox(height: 16),
                        if (_getList('languages_known').isNotEmpty ||
                            _getList('languages').isNotEmpty)
                          _buildLanguagesSection(),
                        if (_getList('languages_known').isNotEmpty ||
                            _getList('languages').isNotEmpty)
                          const SizedBox(height: 16),
                        if (_getString('summary').isNotEmpty)
                          _buildSectionCard(
                            title: "Professional Summary",
                            icon: Icons.description,
                            color: Colors.teal,
                            children: [
                              _buildSelectableText(_getString('summary')),
                            ],
                          ),
                        if (_getString('summary').isNotEmpty)
                          const SizedBox(height: 16),
                        if (_getString('career_objective').isNotEmpty)
                          _buildSectionCard(
                            title: "Career Objective",
                            icon: Icons.track_changes,
                            color: Colors.orange,
                            children: [
                              _buildSelectableText(
                                  _getString('career_objective')),
                            ],
                          ),
                        if (_getString('career_objective').isNotEmpty)
                          const SizedBox(height: 16),
                        if (_hasSocialLinks()) _buildSocialLinksCard(),
                        if (_hasSocialLinks()) const SizedBox(height: 16),
                        if (_getString('resume_url').isNotEmpty)
                          _buildResumeCard(),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DESIGN HELPERS
  // ============================================================

  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
      ),
    );
  }

  BoxDecoration _buildGlassContainerDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: const Color(0xFFE5E7EB),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.12),
          blurRadius: 12,
          spreadRadius: 2,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: _buildGlassContainerDecoration(),
      child: child,
    );
  }

  // ============================================================
  // LOADING SCREEN — ANIMATED AI
  // ============================================================
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: _buildGradientBackground(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kPrimary, _kPink],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "AI is loading profile...",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_kPrimary),
              ),
              const SizedBox(height: 24),
              const Text(
                "Please wait while we prepare the candidate profile",
                style: TextStyle(
                  fontSize: 14,
                  color: _kTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================
  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Failed to load profile",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _errorMessage ?? "Unknown error",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _kTextSecondary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _fetchProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, _kPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          Material(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Candidate Profile",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.candidateName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _printProfile,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.print, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _fetchProfile,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.refresh, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO CARD
  // ============================================================
  Widget _buildHeroCard() {
    final fullName = _getString('full_name').isNotEmpty
        ? _getString('full_name')
        : widget.candidateName;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, _kPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                if (_getString('phone').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _getString('phone'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return _buildGlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Container(
                  width: 30,
                  height: 2,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(height: 1, color: Color(0xFFE5E7EB)),
    );
  }

  // ============================================================
  // SELECTABLE INFO ROW
  // ============================================================
  Widget _buildSelectableInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty || value == 'null') {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kPrimary),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SELECTABLE TEXT
  // ============================================================
  Widget _buildSelectableText(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(
          height: 1.5,
          fontSize: 14,
          color: _kTextPrimary,
        ),
      ),
    );
  }

  // ============================================================
  // DISABILITY CARD
  // ============================================================
  Widget _buildDisabilityCard() {
    final disability = _profile['disability'] as Map? ?? {};
    final isDisabled =
        disability['is_disabled'] == true || _profile['is_disable'] == true;
    final disabilityCategory = disability['disability_category'] ??
        _profile['disability_category'] ??
        'Not specified';
    final disabilityPercentage = disability['disability_percentage'] ??
        _profile['disability_percentage'];

    if (!isDisabled && disabilityCategory == 'Not specified') {
      return const SizedBox();
    }

    return _buildSectionCard(
      title: "Disability Information",
      icon: Icons.accessible,
      color: const Color(0xFFF59E0B),
      children: [
        _buildSelectableInfoRow(
          Icons.accessible,
          "Status",
          isDisabled ? "Yes" : "No",
        ),
        if (isDisabled) ...[
          _buildDivider(),
          _buildSelectableInfoRow(
            Icons.category,
            "Category",
            disabilityCategory,
          ),
          if (disabilityPercentage != null) ...[
            _buildDivider(),
            _buildSelectableInfoRow(
              Icons.percent,
              "Percentage",
              "$disabilityPercentage%",
            ),
          ],
          if (disability['disability_details'] != null &&
              disability['disability_details'].toString().isNotEmpty)
            Column(
              children: [
                _buildDivider(),
                _buildSelectableInfoRow(
                  Icons.description,
                  "Details",
                  disability['disability_details'],
                ),
              ],
            ),
        ],
      ],
    );
  }

  // ============================================================
  // ADDRESS CARD
  // ============================================================
  Widget _buildAddressCard() {
    final address = _profile['current_address'] as Map? ?? {};
    final hasAddress = address['district'] != null ||
        address['state'] != null ||
        address['village_name'] != null;

    if (!hasAddress) {
      return const SizedBox();
    }

    return _buildSectionCard(
      title: "Current Address",
      icon: Icons.location_on,
      color: const Color(0xFF10B981),
      children: [
        if (address['village_name'] != null &&
            address['village_name'].toString().isNotEmpty)
          _buildSelectableInfoRow(
            Icons.location_city,
            "Village/City",
            address['village_name'],
          ),
        if (address['district'] != null &&
            address['district'].toString().isNotEmpty)
          _buildSelectableInfoRow(
            Icons.map,
            "District",
            address['district'],
          ),
        if (address['state'] != null &&
            address['state'].toString().isNotEmpty)
          _buildSelectableInfoRow(
            Icons.location_on,
            "State",
            address['state'],
          ),
        if (address['pincode'] != null &&
            address['pincode'].toString().isNotEmpty)
          _buildSelectableInfoRow(
            Icons.pin_drop,
            "Pincode",
            address['pincode'],
          ),
        if (address['country'] != null &&
            address['country'].toString().isNotEmpty &&
            address['country'] != 'India')
          _buildSelectableInfoRow(
            Icons.public,
            "Country",
            address['country'],
          ),
      ],
    );
  }

  // ============================================================
  // EDUCATION SECTION
  // ============================================================
  Widget _buildEducationSection() {
    final educationList = _getList('academic_records');

    return _buildSectionCard(
      title: "Education",
      icon: Icons.school,
      color: const Color(0xFF8B5CF6),
      children: educationList.map((edu) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school,
                      color: Color(0xFF8B5CF6), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        edu['degree'] ?? edu['level'] ?? 'Education',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (edu['institute'] != null &&
                          edu['institute'].toString().isNotEmpty)
                        Text(
                          edu['institute'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: _kTextSecondary,
                          ),
                        ),
                      if (edu['board_university'] != null &&
                          edu['board_university'].toString().isNotEmpty)
                        Text(
                          edu['board_university'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kTextMuted,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (edu['year_of_passing'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Year: ${edu['year_of_passing']}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6D28D9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (edu['cgpa_percentage'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${edu['result_type'] ?? 'Score'}: ${edu['cgpa_percentage']}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF047857),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (educationList.indexOf(edu) != educationList.length - 1)
              const Divider(color: Color(0xFFE5E7EB)),
          ],
        );
      }).toList(),
    );
  }

  // ============================================================
  // EXPERIENCE SECTION
  // ============================================================
  Widget _buildExperienceSection() {
    final experienceList = _getList('experience');

    return _buildSectionCard(
      title: "Work Experience",
      icon: Icons.work,
      color: const Color(0xFFF97316),
      children: experienceList.map((exp) {
        final duration = _calculateDuration(
          exp['start_date'],
          exp['end_date'],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.work,
                      color: Color(0xFFF97316), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp['role'] ?? 'Position',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exp['company'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${exp['start_date']} - ${exp['end_date'] ?? 'Present'} ($duration)",
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kTextMuted,
                        ),
                      ),
                      if (exp['description'] != null &&
                          exp['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            exp['description'],
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: _kTextPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (experienceList.indexOf(exp) != experienceList.length - 1)
              const Divider(color: Color(0xFFE5E7EB)),
          ],
        );
      }).toList(),
    );
  }

  // ============================================================
  // SKILLS SECTION
  // ============================================================
  Widget _buildSkillsSection() {
    final skillsList = _getList('skills');

    return _buildSectionCard(
      title: "Skills",
      icon: Icons.build,
      color: const Color(0xFF3B82F6),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: skillsList.map((skill) {
            final skillName = skill is Map ? skill['name'] : skill;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.3)),
              ),
              child: Text(
                skillName.toString(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
        if (skillsList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.mouse, size: 14, color: _kTextMuted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "💡 Tip: Drag with mouse (or long-press) to select & copy any text",
                      style: TextStyle(
                        fontSize: 11,
                        color: _kTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // CERTIFICATIONS SECTION
  // ============================================================
  Widget _buildCertificationsSection() {
    final certList = _getList('certifications');

    return _buildSectionCard(
      title: "Certifications",
      icon: Icons.verified,
      color: const Color(0xFF7C3AED),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: certList.map((cert) {
            final certName = cert is Map ? cert['name'] : cert;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.3)),
              ),
              child: Text(
                certName.toString(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5B21B6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================================
  // PROJECTS SECTION
  // ============================================================
  Widget _buildProjectsSection() {
    final projectList = _getList('projects');

    return _buildSectionCard(
      title: "Projects",
      icon: Icons.code,
      color: const Color(0xFF4F46E5),
      children: projectList.map((proj) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.code,
                      color: Color(0xFF4F46E5), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proj['title'] ?? 'Project',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _kTextPrimary,
                        ),
                      ),
                      if (proj['description'] != null &&
                          proj['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            proj['description'],
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: _kTextSecondary,
                            ),
                          ),
                        ),
                      if (proj['technologies'] != null &&
                          (proj['technologies'] as List).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: (proj['technologies'] as List)
                                .map((tech) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        tech.toString(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF3730A3),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (projectList.indexOf(proj) != projectList.length - 1)
              const Divider(color: Color(0xFFE5E7EB)),
          ],
        );
      }).toList(),
    );
  }

  // ============================================================
  // LANGUAGES SECTION
  // ============================================================
  Widget _buildLanguagesSection() {
    final languagesKnown = _getList('languages_known');
    final languages = _getList('languages');

    if (languagesKnown.isEmpty && languages.isEmpty) {
      return const SizedBox();
    }

    return _buildSectionCard(
      title: "Languages",
      icon: Icons.language,
      color: const Color(0xFF0891B2),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...languagesKnown.map((lang) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF0891B2).withOpacity(0.3)),
                  ),
                  child: Text(
                    lang.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF155E75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )),
            ...languages.map((lang) {
              final langName = lang is Map ? lang['name'] : lang;
              final proficiency = lang is Map ? lang['proficiency'] : null;
              final langText = proficiency != null
                  ? "$langName ($proficiency)"
                  : langName.toString();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0891B2).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF0891B2).withOpacity(0.3)),
                ),
                child: Text(
                  langText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF155E75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // SOCIAL LINKS CARD
  // ============================================================
  bool _hasSocialLinks() {
    final social = _profile['social_links'] as Map? ?? {};
    return (social['linkedin'] != null &&
            social['linkedin'].toString().isNotEmpty) ||
        (social['github'] != null &&
            social['github'].toString().isNotEmpty) ||
        (social['portfolio'] != null &&
            social['portfolio'].toString().isNotEmpty);
  }

  Widget _buildSocialLinksCard() {
    final social = _profile['social_links'] as Map? ?? {};

    return _buildSectionCard(
      title: "Social & Professional Links",
      icon: Icons.link,
      color: const Color(0xFF2563EB),
      children: [
        if (social['linkedin'] != null &&
            social['linkedin'].toString().isNotEmpty)
          _buildSelectableLinkTile(
            Icons.linked_camera,
            "LinkedIn",
            social['linkedin'],
          ),
        if (social['github'] != null &&
            social['github'].toString().isNotEmpty)
          _buildSelectableLinkTile(
            Icons.code,
            "GitHub",
            social['github'],
          ),
        if (social['portfolio'] != null &&
            social['portfolio'].toString().isNotEmpty)
          _buildSelectableLinkTile(
            Icons.web,
            "Portfolio",
            social['portfolio'],
          ),
      ],
    );
  }

  Widget _buildSelectableLinkTile(IconData icon, String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  url,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: const Color(0xFF2563EB).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final Uri uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(8),
                child:
                    Icon(Icons.open_in_new, size: 16, color: Color(0xFF2563EB)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESUME CARD
  // ============================================================
  Widget _buildResumeCard() {
    final resumeUrl = _getString('resume_url');
    if (resumeUrl.isEmpty) {
      return const SizedBox();
    }

    return _buildSectionCard(
      title: "Resume / CV",
      icon: Icons.picture_as_pdf,
      color: const Color(0xFFDC2626),
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _launchResume(resumeUrl),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf,
                        size: 28, color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Resume Available",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resumeUrl,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kTextSecondary,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.open_in_new,
                        color: Color(0xFF2563EB), size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.mouse, size: 14, color: _kTextMuted),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "💡 Tip: Drag with mouse (or long-press) to select & copy any text",
                  style: TextStyle(fontSize: 11, color: _kTextMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Future<void> _launchResume(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          showMessage(context, "Could not open resume", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Error opening resume: $e", isError: true);
      }
    }
  }

  String _getString(String key) {
    final value = _profile[key];
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  List<dynamic> _getList(String key) {
    final value = _profile[key];
    if (value is List) return value;
    return [];
  }

  String _calculateDuration(String? startDate, String? endDate) {
    if (startDate == null) return 'N/A';
    try {
      final start = DateTime.parse(startDate);
      final end = endDate != null ? DateTime.parse(endDate) : DateTime.now();
      final years = end.year - start.year;
      final months = end.month - start.month;
      if (years > 0) {
        return "$years yr${years > 1 ? 's' : ''} ${months > 0 ? '$months mon' : ''}";
      }
      if (months > 0) {
        return "$months month${months > 1 ? 's' : ''}";
      }
      final days = end.difference(start).inDays;
      return "$days day${days > 1 ? 's' : ''}";
    } catch (e) {
      return 'N/A';
    }
  }
}