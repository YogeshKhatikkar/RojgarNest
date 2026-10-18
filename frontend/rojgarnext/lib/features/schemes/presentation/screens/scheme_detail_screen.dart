// lib/features/schemes/presentation/screens/scheme_detail_screen.dart
// ============================================================
// SCHEME DETAIL SCREEN — Full details in Hindi
// Shows: benefits, eligibility, documents, steps, target beneficiaries
// Has "Apply" button → SchemeApplyScreen
// ============================================================
// ✅ NEW: isEmbedded mode — renders WITHOUT Scaffold/AppBar
// ✅ NEW: onBack callback for embedded mode
// ✅ NEW: onApply callback for embedded mode
// ============================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/core/master_date/schemes_data.dart';
import 'package:rojgarnext/features/schemes/data/scheme_service.dart';
import 'package:rojgarnext/features/schemes/presentation/screens/scheme_apply_screen.dart';

class SchemeDetailScreen extends StatefulWidget {
  final String schemeId;
  final String schemeName;

  /// ✅ NEW: When true, renders WITHOUT Scaffold/AppBar
  /// so it can be embedded in the right panel of UserDashboard.
  final bool isEmbedded;

  /// ✅ NEW: Optional back callback (for embedded mode)
  final VoidCallback? onBack;

  /// ✅ NEW: Optional apply callback — if provided, called instead of Navigator.push
  final VoidCallback? onApply;

  const SchemeDetailScreen({
    super.key,
    required this.schemeId,
    required this.schemeName,
    this.isEmbedded = false,
    this.onBack,
    this.onApply,
  });

  @override
  State<SchemeDetailScreen> createState() => _SchemeDetailScreenState();
}

class _SchemeDetailScreenState extends State<SchemeDetailScreen>
    with SingleTickerProviderStateMixin {
  // ==================== STATE ====================
  Map<String, dynamic>? _scheme;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isApplying = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _loadSchemeDetail();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ==================== LOAD DATA ====================
  Future<void> _loadSchemeDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await SchemeService.getSchemeDetail(widget.schemeId);

      if (!mounted) return;

      final schemeData = result['scheme'] as Map<String, dynamic>? ??
          _getMasterDataAsMap();

      setState(() {
        _scheme = schemeData;
        _isLoading = false;
      });

      _animController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        // Fallback to master data
        _scheme = _getMasterDataAsMap();
      });
    }
  }

  Map<String, dynamic>? _getMasterDataAsMap() {
    final scheme = SchemesMasterData.getSchemeById(widget.schemeId);
    if (scheme == null) return null;

    return {
      'scheme_id': scheme.schemeId,
      'scheme_name': scheme.schemeName,
      'scheme_name_hindi': scheme.schemeNameHindi,
      'short_description': scheme.shortDescription,
      'short_description_hindi': scheme.shortDescriptionHindi,
      'level': scheme.level,
      'state': scheme.state,
      'category': scheme.category,
      'full_description': scheme.fullDescription,
      'full_description_hindi': scheme.fullDescriptionHindi,
      'icon': scheme.icon,
      'color': scheme.color,
      'is_featured': scheme.isFeatured,
      'benefits': scheme.benefits.map((b) => {
        'title': b.title,
        'description': b.description,
        'amount': b.amount,
        'type': b.type,
      }).toList(),
      'eligibility': {
        'age_min': scheme.eligibility.ageMin,
        'age_max': scheme.eligibility.ageMax,
        'gender': scheme.eligibility.gender,
        'income_limit': scheme.eligibility.incomeLimit,
        'category': scheme.eligibility.category,
        'occupation': scheme.eligibility.occupation,
        'domicile_state': scheme.eligibility.domicileState,
        'disability_required': scheme.eligibility.disabilityRequired,
        'bpl_required': scheme.eligibility.bplRequired,
        'aadhaar_required': scheme.eligibility.aadhaarRequired,
      },
      'eligibility_details_hindi': scheme.eligibilityDetailsHindi,
      'target_beneficiaries_hindi': scheme.targetBeneficiariesHindi,
      'required_documents': scheme.requiredDocuments.map((d) => {
        'name': d.name,
        'name_hindi': d.nameHindi,
        'required': d.required,
        'description': d.description,
      }).toList(),
      'application_steps': scheme.applicationSteps.map((st) => {
        'step_number': st.stepNumber,
        'title': st.title,
        'title_hindi': st.titleHindi,
        'description': st.description,
        'description_hindi': st.descriptionHindi,
      }).toList(),
      'application_mode': scheme.applicationMode,
      'contact_info': {
        'helpline': scheme.contactInfo.helpline,
        'email': scheme.contactInfo.email,
        'website': scheme.contactInfo.website,
      },
      'official_website': scheme.officialWebsite,
      'apply_link': scheme.applyLink,
      'has_application_fee': scheme.hasApplicationFee,
      'application_fee': scheme.applicationFee,
      'fee_details_hindi': scheme.feeDetailsHindi,
    };
  }

  // ==================== NAVIGATION ====================
  void _openApplyScreen() {
    if (_scheme == null) return;

    // ✅ If onApply callback provided, use it (embedded mode)
    if (widget.onApply != null) {
      widget.onApply!();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SchemeApplyScreen(scheme: _scheme!),
      ),
    );
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) {
      showMessage(context, 'लिंक उपलब्ध नहीं है', isError: true);
      return;
    }
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          showMessage(context, 'लिंक नहीं खुल सका', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'लिंक खोलने में त्रुटि: $e', isError: true);
      }
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    // ✅ Build the main content
    final Widget content = _isLoading
        ? _buildLoadingScreen()
        : _scheme == null
            ? _buildErrorScreen()
            : _buildContent();

    // ✅ EMBEDDED MODE: No Scaffold, no AppBar
    if (widget.isEmbedded) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildEmbeddedHeader(),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    // ✅ FULL SCREEN MODE: With Scaffold
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
          ),
        ),
        child: SafeArea(child: content),
      ),
    );
  }

  // ============================================================
  // EMBEDDED HEADER (with back button)
  // ============================================================
  Widget _buildEmbeddedHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x336C63FF),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onBack ?? () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'योजना विवरण',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.schemeName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================
  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
          SizedBox(height: 16),
          Text(
            'योजना विवरण लोड हो रहा है...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================
  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'योजना लोड नहीं हो सकी',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadSchemeDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('पुनः प्रयास करें'),
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

  // ============================================================
  // MAIN CONTENT
  // ============================================================
  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Only show full header in non-embedded mode
          if (!widget.isEmbedded) _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 16),
                  _buildFullDescriptionCard(),
                  const SizedBox(height: 16),
                  _buildTargetBeneficiariesCard(),
                  const SizedBox(height: 16),
                  _buildBenefitsCard(),
                  const SizedBox(height: 16),
                  _buildEligibilityCard(),
                  const SizedBox(height: 16),
                  _buildRequiredDocumentsCard(),
                  const SizedBox(height: 16),
                  _buildApplicationStepsCard(),
                  const SizedBox(height: 16),
                  _buildFeeCard(),
                  const SizedBox(height: 16),
                  _buildContactCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Bottom action bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER (only in full screen mode)
  // ============================================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onBack ?? () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'योजना विवरण',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.schemeName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
    final icon = _scheme!['icon']?.toString() ?? '📋';
    final schemeNameHindi = _scheme!['scheme_name_hindi']?.toString() ??
        _scheme!['scheme_name']?.toString() ?? '';
    final schemeNameEn = _scheme!['scheme_name']?.toString() ?? '';
    final level = _scheme!['level']?.toString() ?? 'central';
    final state = _scheme!['state']?.toString();
    final isFeatured = _scheme!['is_featured'] == true;

    final levelLabel = level == 'central'
        ? 'केंद्रीय सरकार योजना'
        : 'राज्य सरकार योजना${state != null ? " • $state" : ""}';

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
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 34),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 12, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              'Featured',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      schemeNameHindi,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      schemeNameEn,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  levelLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FULL DESCRIPTION CARD
  // ============================================================
  Widget _buildFullDescriptionCard() {
    final fullDescHindi = _scheme!['full_description_hindi']?.toString() ??
        _scheme!['full_description']?.toString() ?? '';

    if (fullDescHindi.isEmpty) return const SizedBox();

    return _buildSection(
      title: 'योजना का विवरण',
      titleEn: 'Scheme Description',
      icon: Icons.info_outline,
      color: const Color(0xFF6C63FF),
      children: [
        Text(
          fullDescHindi,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TARGET BENEFICIARIES CARD
  // ============================================================
  Widget _buildTargetBeneficiariesCard() {
    final beneficiaries = _scheme!['target_beneficiaries_hindi'] as List?;
    if (beneficiaries == null || beneficiaries.isEmpty) {
      return const SizedBox();
    }

    return _buildSection(
      title: 'यह योजना किसके लिए है?',
      titleEn: 'Who is this scheme for?',
      icon: Icons.people_alt,
      color: const Color(0xFF10B981),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: beneficiaries.map((b) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    b.toString(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================================
  // BENEFITS CARD
  // ============================================================
  Widget _buildBenefitsCard() {
    final benefits = _scheme!['benefits'] as List?;
    if (benefits == null || benefits.isEmpty) return const SizedBox();

    return _buildSection(
      title: 'योजना के लाभ',
      titleEn: 'Scheme Benefits',
      icon: Icons.card_giftcard,
      color: const Color(0xFFF59E0B),
      children: benefits.map((benefit) {
        final b = benefit as Map;
        final amount = b['amount']?.toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFF59E0B).withOpacity(0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.stars,
                  size: 20,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b['title']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b['description']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                    if (amount != null && amount.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          amount,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // ELIGIBILITY CARD
  // ============================================================
  Widget _buildEligibilityCard() {
    final eligibilityDetails =
        _scheme!['eligibility_details_hindi']?.toString() ?? '';
    final eligibility = _scheme!['eligibility'] as Map? ?? {};

    final ageMin = eligibility['age_min'];
    final ageMax = eligibility['age_max'];
    final gender = eligibility['gender'];
    final incomeLimit = eligibility['income_limit'];

    final List<Widget> items = [];

    // Hindi text first (if available)
    if (eligibilityDetails.isNotEmpty) {
      items.add(
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF4F46E5).withOpacity(0.2),
            ),
          ),
          child: Text(
            eligibilityDetails,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.7,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      );
    }

    // Structured eligibility
    if (ageMin != null || ageMax != null) {
      items.add(_buildEligibilityRow(
        Icons.cake,
        'आयु सीमा',
        'Age Limit',
        '${ageMin ?? 'कोई नहीं'} - ${ageMax ?? 'कोई नहीं'} वर्ष',
      ));
    }

    if (gender != null && gender != 'all') {
      final genderHindi = gender == 'female'
          ? 'महिला'
          : gender == 'male'
              ? 'पुरुष'
              : 'सभी';
      items.add(_buildEligibilityRow(
        Icons.wc,
        'लिंग',
        'Gender',
        genderHindi,
      ));
    }

    if (incomeLimit != null) {
      final incomeLakh = (incomeLimit / 100000).toStringAsFixed(1);
      items.add(_buildEligibilityRow(
        Icons.currency_rupee,
        'आय सीमा',
        'Income Limit',
        '₹$incomeLakh लाख/वर्ष तक',
      ));
    }

    if (items.isEmpty) return const SizedBox();

    return _buildSection(
      title: 'पात्रता',
      titleEn: 'Eligibility',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF4F46E5),
      children: items,
    );
  }

  Widget _buildEligibilityRow(
    IconData icon,
    String labelHindi,
    String labelEn,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labelHindi,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUIRED DOCUMENTS CARD
  // ============================================================
  Widget _buildRequiredDocumentsCard() {
    final documents = _scheme!['required_documents'] as List?;
    if (documents == null || documents.isEmpty) return const SizedBox();

    return _buildSection(
      title: 'आवश्यक दस्तावेज',
      titleEn: 'Required Documents',
      icon: Icons.description,
      color: const Color(0xFFEC4899),
      children: [
        ...documents.asMap().entries.map((entry) {
          final doc = entry.value as Map;
          final nameHindi = doc['name_hindi']?.toString() ??
              doc['name']?.toString() ?? '';
          final nameEn = doc['name']?.toString() ?? '';
          final isRequired = doc['required'] != false;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file,
                    size: 18,
                    color: Color(0xFFEC4899),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nameHindi,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        nameEn,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isRequired
                        ? Colors.red.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isRequired ? 'आवश्यक' : 'वैकल्पिक',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isRequired
                          ? Colors.red.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ============================================================
  // APPLICATION STEPS CARD
  // ============================================================
  Widget _buildApplicationStepsCard() {
    final steps = _scheme!['application_steps'] as List?;
    if (steps == null || steps.isEmpty) return const SizedBox();

    return _buildSection(
      title: 'आवेदन प्रक्रिया',
      titleEn: 'Application Process',
      icon: Icons.list_alt,
      color: const Color(0xFF14B8A6),
      children: [
        ...steps.asMap().entries.map((entry) {
          final step = entry.value as Map;
          final stepNum = step['step_number'] ?? (entry.key + 1);
          final titleHindi = step['title_hindi']?.toString() ??
              step['title']?.toString() ?? '';
          final descHindi = step['description_hindi']?.toString() ??
              step['description']?.toString() ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$stepNum',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleHindi,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (descHindi.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            descHindi,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF6B7280),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ============================================================
  // FEE CARD
  // ============================================================
  Widget _buildFeeCard() {
    final hasFee = _scheme!['has_application_fee'] == true;
    final fee = _scheme!['application_fee'] ?? 0;
    final feeDetailsHindi = _scheme!['fee_details_hindi']?.toString() ?? '';

    return _buildSection(
      title: 'आवेदन शुल्क',
      titleEn: 'Application Fee',
      icon: Icons.currency_rupee,
      color: const Color(0xFFD97706),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasFee
                ? const Color(0xFFD97706).withOpacity(0.1)
                : const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasFee
                  ? const Color(0xFFD97706).withOpacity(0.3)
                  : const Color(0xFF10B981).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasFee ? Icons.payments : Icons.check_circle,
                size: 24,
                color: hasFee
                    ? const Color(0xFFD97706)
                    : const Color(0xFF10B981),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasFee ? '₹$fee' : 'निःशुल्क (Free)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: hasFee
                            ? const Color(0xFFD97706)
                            : const Color(0xFF10B981),
                      ),
                    ),
                    if (feeDetailsHindi.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        feeDetailsHindi,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CONTACT CARD
  // ============================================================
  Widget _buildContactCard() {
    final contactInfo = _scheme!['contact_info'] as Map? ?? {};
    final helpline = contactInfo['helpline']?.toString();
    final email = contactInfo['email']?.toString();
    final website = contactInfo['website']?.toString() ??
        _scheme!['official_website']?.toString();

    final List<Widget> items = [];

    if (helpline != null && helpline.isNotEmpty) {
      items.add(_buildContactRow(
        Icons.phone,
        'हेल्पलाइन',
        helpline,
        onTap: null,
      ));
    }

    if (email != null && email.isNotEmpty) {
      items.add(_buildContactRow(
        Icons.email,
        'ईमेल',
        email,
        onTap: null,
      ));
    }

    if (website != null && website.isNotEmpty) {
      items.add(_buildContactRow(
        Icons.public,
        'वेबसाइट',
        website,
        onTap: () => _openUrl(website),
      ));
    }

    if (items.isEmpty) return const SizedBox();

    return _buildSection(
      title: 'संपर्क जानकारी',
      titleEn: 'Contact Information',
      icon: Icons.contact_phone,
      color: const Color(0xFF2563EB),
      children: items,
    );
  }

  Widget _buildContactRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
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
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.open_in_new,
                size: 16,
                color: Color(0xFF2563EB),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REUSABLE SECTION
  // ============================================================
  Widget _buildSection({
    required String title,
    required String titleEn,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.12),
                  color.withOpacity(0.03),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
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
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        titleEn,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM ACTION BAR
  // ============================================================
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openUrl(_scheme!['official_website']?.toString()),
                  icon: const Icon(Icons.public, size: 18),
                  label: const Text(
                    'आधिकारिक वेबसाइट',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C63FF),
                    side: const BorderSide(
                      color: Color(0xFF6C63FF),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isApplying ? null : _openApplyScreen,
                    icon: _isApplying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(
                      _isApplying ? 'Processing...' : 'आवेदन करें / Apply',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}