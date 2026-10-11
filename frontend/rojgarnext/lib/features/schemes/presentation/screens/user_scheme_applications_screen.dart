// lib/features/schemes/presentation/screens/user_scheme_applications_screen.dart
// ============================================================
// USER SCHEME APPLICATIONS — WITH EMBEDDED DETAIL VIEW
// ============================================================
// ✅ Contains BOTH screens in one file:
//    1. UserSchemeApplicationsScreen — list of applications
//    2. _SchemeApplicationDetailView — full detail (rendered inline
//       inside the right panel, NOT as a new route)
// ✅ isEmbedded mode supported
// ✅ "View Application" button → opens detail in right panel
// ✅ Detail view fetches from GET /schemes/application/{id}
// ✅ Documents are STRICTLY the ones uploaded during scheme apply
//    + admin review/final docs
// ✅ NEVER mixes in user profile documents (aadhaar/pan/resume)
// ============================================================

import 'package:flutter/material.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/core/widgets/file_viewer_screen.dart';
import 'package:rojgarnext/features/schemes/data/scheme_service.dart';
import 'package:rojgarnext/features/schemes/presentation/screens/scheme_detail_screen.dart';

// ============================================================================
// ============================================================================
// SCREEN 1: USER SCHEME APPLICATIONS (LIST + EMBEDDED DETAIL)
// ============================================================================
// ============================================================================

class UserSchemeApplicationsScreen extends StatefulWidget {
  /// ✅ When true, renders WITHOUT Scaffold
  final bool isEmbedded;

  /// ✅ Optional callback when a scheme is selected (embedded mode)
  final Function(Map<String, dynamic>)? onSchemeSelected;

  /// ✅ Optional back callback (for embedded mode)
  final VoidCallback? onBack;

  const UserSchemeApplicationsScreen({
    super.key,
    this.isEmbedded = false,
    this.onSchemeSelected,
    this.onBack,
  });

  @override
  State<UserSchemeApplicationsScreen> createState() =>
      _UserSchemeApplicationsScreenState();
}

class _UserSchemeApplicationsScreenState
    extends State<UserSchemeApplicationsScreen> {
  // ==================== STATE ====================
  List<dynamic> _applications = [];
  List<dynamic> _filteredApplications = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all';

  // ============================================================
  // ✅ EMBEDDED DETAIL STATE
  // ============================================================
  bool _showDetail = false;
  String? _selectedApplicationId;
  Map<String, dynamic>? _selectedApplicationSeed;

  final List<Map<String, dynamic>> _filterButtons = [
    {
      'value': 'all',
      'label': 'सभी',
      'labelEn': 'All',
      'icon': Icons.apps,
      'color': Colors.grey,
    },
    {
      'value': 'pending',
      'label': 'लंबित',
      'labelEn': 'Pending',
      'icon': Icons.hourglass_empty,
      'color': Colors.orange,
    },
    {
      'value': 'under_review',
      'label': 'समीक्षा',
      'labelEn': 'Review',
      'icon': Icons.rate_review,
      'color': Colors.blue,
    },
    {
      'value': 'approved',
      'label': 'स्वीकृत',
      'labelEn': 'Approved',
      'icon': Icons.check_circle,
      'color': Colors.green,
    },
    {
      'value': 'rejected',
      'label': 'अस्वीकृत',
      'labelEn': 'Rejected',
      'icon': Icons.cancel,
      'color': Colors.red,
    },
  ];

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  // ==================== DATA LOADING ====================
  Future<void> _loadApplications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await SchemeService.getMyApplications();

      if (!mounted) return;

      final apps = (result['applications'] as List?) ?? [];
      setState(() {
        _applications = apps;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        _applications = [];
        _filteredApplications = [];
      });
    }
  }

  // ==================== FILTER ====================
  void _applyFilter() {
    List<dynamic> result = List.from(_applications);

    if (_selectedFilter != 'all') {
      result = result
          .where((a) =>
              a['status']?.toString().toLowerCase() ==
              _selectedFilter.toLowerCase())
          .toList();
    }

    if (!mounted) return;
    setState(() => _filteredApplications = result);
  }

  void _onFilterSelected(String value) {
    if (_selectedFilter == value) return;
    setState(() => _selectedFilter = value);
    _applyFilter();
  }

  // ============================================================
  // ✅ NAVIGATION — EMBEDDED DETAIL IN RIGHT PANEL
  // ============================================================
  void _openApplicationDetails(Map<String, dynamic> app) {
    final applicationId = app['application_id']?.toString() ?? '';

    if (applicationId.isEmpty) {
      showMessage(
        context,
        'आवेदन संख्या उपलब्ध नहीं',
        isError: true,
      );
      return;
    }

    setState(() {
      _selectedApplicationId = applicationId;
      _selectedApplicationSeed = app;
      _showDetail = true;
    });
  }

  void _closeDetail() {
    setState(() {
      _showDetail = false;
      _selectedApplicationId = null;
      _selectedApplicationSeed = null;
    });
  }

  void _openSchemeDetails(Map<String, dynamic> app) {
    final schemeId = app['scheme_id']?.toString() ?? '';
    final schemeNameHindi = app['scheme_name_hindi']?.toString() ??
        app['scheme_name']?.toString() ??
        'योजना';

    if (schemeId.isEmpty) {
      showMessage(context, 'योजना आईडी उपलब्ध नहीं', isError: true);
      return;
    }

    if (widget.onSchemeSelected != null) {
      widget.onSchemeSelected!({
        'scheme_id': schemeId,
        'scheme_name': schemeNameHindi,
        'scheme': app,
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SchemeDetailScreen(
          schemeId: schemeId,
          schemeName: schemeNameHindi,
        ),
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    // ============================================================
    // ✅ If detail is open — render the detail view IN PLACE
    //    (this is what makes it show in the right panel)
    // ============================================================
    if (_showDetail && _selectedApplicationId != null) {
      return _SchemeApplicationDetailView(
        applicationId: _selectedApplicationId!,
        initialData: _selectedApplicationSeed,
        onBack: _closeDetail,
        isEmbedded: widget.isEmbedded,
      );
    }

    // ============================================================
    // LIST VIEW
    // ============================================================
    final Widget content = _isLoading && _applications.isEmpty
        ? _buildLoadingScreen()
        : Column(
            children: [
              _buildHeader(),
              _buildFilterChips(),
              Expanded(
                child: _filteredApplications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadApplications,
                        color: const Color(0xFF6C63FF),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredApplications.length,
                          itemBuilder: (context, index) =>
                              _buildApplicationCard(
                                  _filteredApplications[index], index),
                        ),
                      ),
              ),
            ],
          );

    if (widget.isEmbedded) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
          ),
        ),
        child: SafeArea(child: content),
      );
    }

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
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
      child: Row(
        children: [
          if (widget.isEmbedded && widget.onBack != null)
            Material(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onBack,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child:
                      Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
            ),
          if (widget.isEmbedded && widget.onBack != null)
            const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.description,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'मेरे योजना आवेदन',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'कुल ${_applications.length} आवेदन',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _loadApplications,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.refresh, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER CHIPS
  // ============================================================
  Widget _buildFilterChips() {
    return Container(
      height: 56,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filterButtons.length,
        itemBuilder: (context, index) {
          final filter = _filterButtons[index];
          final isSelected = _selectedFilter == filter['value'];
          final Color color = filter['color'] as Color;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 14,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter['label'] as String,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              onSelected: (_) =>
                  _onFilterSelected(filter['value'] as String),
              backgroundColor: Colors.white,
              selectedColor: color,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              elevation: isSelected ? 4 : 0,
            ),
          );
        },
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
            'आवेदन लोड हो रहे हैं...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.1),
                    const Color(0xFFFF6588).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 60,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'कोई आवेदन नहीं',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'आपने अभी तक किसी योजना के लिए आवेदन नहीं किया है।',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // APPLICATION CARD
  // ============================================================
  Widget _buildApplicationCard(Map<String, dynamic> app, int index) {
    final schemeNameHindi = app['scheme_name_hindi']?.toString() ??
        app['scheme_name']?.toString() ??
        'योजना';
    final schemeName = app['scheme_name']?.toString() ?? 'Scheme';
    final status = app['status']?.toString() ?? 'pending';
    final applicationId = app['application_id']?.toString() ?? '';
    final createdAt = app['created_at']?.toString() ?? '';
    final level = app['scheme_level']?.toString() ?? 'central';
    final state = app['scheme_state']?.toString();

    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusLabelHindi(status);

    final levelLabel = level == 'central'
        ? 'केंद्रीय'
        : 'राज्य${state != null ? " • $state" : ""}';

    return GestureDetector(
      onTap: () => _openApplicationDetails(app),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: statusColor.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schemeNameHindi,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        schemeName,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              levelLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6C63FF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
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

            if (applicationId.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_number,
                        size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    const Text(
                      'आवेदन संख्या:',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SelectableText(
                        applicationId,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 13, color: Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Text(
                    'आवेदन तिथि: ${_formatDate(createdAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () => _openApplicationDetails(app),
                      icon: const Icon(Icons.description, size: 16),
                      label: const Text(
                        'आवेदन विवरण देखें',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 42,
                  width: 42,
                  child: OutlinedButton(
                    onPressed: () => _openSchemeDetails(app),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6C63FF),
                      padding: EdgeInsets.zero,
                      side: const BorderSide(
                        color: Color(0xFF6C63FF),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Icon(Icons.info_outline, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'approved_application':
      case 'verification_successful':
      case 'payment_verified':
      case 'completed':
      case 'final_submitted':
        return const Color(0xFF10B981);
      case 'rejected':
      case 'verification_rejected':
      case 'update_rejected':
        return const Color(0xFFEF4444);
      case 'under_review':
      case 'review_application':
      case 'pending_verification':
        return const Color(0xFF3B82F6);
      case 'update_application':
        return const Color(0xFF8B5CF6);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _getStatusLabelHindi(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'approved_application':
        return 'स्वीकृत';
      case 'verification_successful':
      case 'payment_verified':
        return 'सत्यापित';
      case 'completed':
      case 'final_submitted':
        return 'पूर्ण';
      case 'rejected':
      case 'verification_rejected':
      case 'update_rejected':
        return 'अस्वीकृत';
      case 'under_review':
      case 'review_application':
        return 'समीक्षाधीन';
      case 'pending_verification':
        return 'सत्यापन लंबित';
      case 'update_application':
        return 'अपडेट लंबित';
      case 'pending':
      default:
        return 'लंबित';
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ============================================================================
// ============================================================================
// SCREEN 2: SCHEME APPLICATION DETAIL (RENDERED INLINE)
// ============================================================================
// ============================================================================

class _SchemeApplicationDetailView extends StatefulWidget {
  final String applicationId;
  final Map<String, dynamic>? initialData;
  final VoidCallback? onBack;
  final bool isEmbedded;

  const _SchemeApplicationDetailView({
    required this.applicationId,
    this.initialData,
    this.onBack,
    this.isEmbedded = true,
  });

  @override
  State<_SchemeApplicationDetailView> createState() =>
      _SchemeApplicationDetailViewState();
}

class _SchemeApplicationDetailViewState
    extends State<_SchemeApplicationDetailView> {
  // ==================== STATE ====================
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _application;
  Map<String, dynamic>? _scheme;

  // ============================================================
  // ✅ DOCUMENTS — STRICTLY SPLIT
  // ============================================================
  List<Map<String, dynamic>> _userDocuments = [];
  List<Map<String, dynamic>> _adminDocuments = [];

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _loadApplicationDetail();
  }

    // ==================== DATA LOADING ====================
  Future<void> _loadApplicationDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await DioClient.dio.get(
        '/schemes/application/${widget.applicationId}',
      );

      if (!mounted) return;

      final body = res.data;
      Map<String, dynamic> data;
      if (body is Map<String, dynamic> && body['data'] is Map) {
        data = Map<String, dynamic>.from(body['data'] as Map);
      } else if (body is Map<String, dynamic>) {
        data = body;
      } else {
        throw Exception('Invalid response format');
      }

      final app = data['application'] as Map?;
      final scheme = data['scheme'] as Map?;

      // ============================================================
      // ✅ STRICT DOCUMENT EXTRACTION
      //    Your DB stores docs in `documents` array.
      //    Each entry has: document_type, document_name, url,
      //                    public_id, source, uploaded_at
      // ============================================================
      final List<Map<String, dynamic>> userDocs = [];
      final List<Map<String, dynamic>> adminDocs = [];

      if (app != null) {
        final appMap = Map<String, dynamic>.from(app);

        // ---------- A. Read from `documents` array (YOUR SCHEMA) ----------
        final docsArray = appMap['documents'];
        if (docsArray is List) {
          for (final raw in docsArray) {
            if (raw is! Map) continue;
            final d = Map<String, dynamic>.from(raw);

            final url = (d['url'] ?? d['document_url'] ?? '').toString().trim();
            if (!_isValidDocUrl(url)) continue;

            final source = (d['source'] ?? '').toString();

            final entry = {
              'key': (d['document_type'] ?? 'document').toString(),
              'label': (d['document_name'] ?? d['document_type'] ?? 'Document')
                  .toString(),
              'url': url,
              'download_url': (d['download_url'] ?? url).toString(),
              'source': source.isEmpty ? 'service_application' : source,
              'is_application_doc': true,
              'uploaded_at': d['uploaded_at'],
            };

            // Route to admin or user bucket
            if (source == 'admin_review' || source == 'admin_final') {
              adminDocs.add({
                ...entry,
                'is_admin_doc': true,
                'is_user_doc': false,
                'badge': source == 'admin_review' ? 'ADMIN REVIEW' : 'ADMIN FINAL',
                'badgeColor': source == 'admin_review'
                    ? Colors.orange
                    : Colors.deepPurple,
              });
            } else {
              // Everything else → user uploaded during scheme apply
              userDocs.add({
                ...entry,
                'is_admin_doc': false,
                'is_user_doc': true,
              });
            }
          }
        }

        // ---------- B. Also read legacy `service_documents` if present ----------
        final serviceDocs = appMap['service_documents'];
        if (serviceDocs is List) {
          for (final raw in serviceDocs) {
            if (raw is! Map) continue;
            final d = Map<String, dynamic>.from(raw);

            final url = (d['url'] ?? '').toString().trim();
            if (!_isValidDocUrl(url)) continue;

            // Skip if already added from `documents` array
            if (userDocs.any((x) => x['url'] == url)) continue;

            final source = (d['source'] ?? '').toString();
            if (source.isNotEmpty && source != 'service_application') {
              continue;
            }

            userDocs.add({
              'key': (d['document_type'] ?? 'document').toString(),
              'label': (d['label'] ?? d['document_type'] ?? 'Document').toString(),
              'url': url,
              'download_url': (d['download_url'] ?? url).toString(),
              'source': 'service_application',
              'is_application_doc': true,
              'is_admin_doc': false,
              'is_user_doc': true,
              'uploaded_at': d['uploaded_at'],
            });
          }
        }

        // ---------- C. Legacy top-level submitted_document_url ----------
        final submittedUrl = appMap['submitted_document_url'];
        if (_isValidDocUrl(submittedUrl)) {
          final urlStr = submittedUrl.toString().trim();
          if (!adminDocs.any((d) => d['url'] == urlStr)) {
            adminDocs.add({
              'key': 'submitted_document_url',
              'label': appMap['submitted_document_name']?.toString() ??
                  'Review Document (from Admin)',
              'url': urlStr,
              'download_url': appMap['submitted_document_download_url'],
              'source': 'admin_review',
              'is_application_doc': true,
              'is_admin_doc': true,
              'badge': 'ADMIN REVIEW',
              'badgeColor': Colors.orange,
            });
          }
        }

        // ---------- D. Legacy top-level final_document_url ----------
        final finalUrl = appMap['final_document_url'];
        if (_isValidDocUrl(finalUrl)) {
          final urlStr = finalUrl.toString().trim();
          if (!adminDocs.any((d) => d['url'] == urlStr)) {
            adminDocs.add({
              'key': 'final_document_url',
              'label': appMap['final_document_name']?.toString() ??
                  'Final Submission Document (from Admin)',
              'url': urlStr,
              'download_url': appMap['final_document_download_url'],
              'source': 'admin_final',
              'is_application_doc': true,
              'is_admin_doc': true,
              'badge': 'ADMIN FINAL',
              'badgeColor': Colors.deepPurple,
            });
          }
        }
      }

      setState(() {
        _application = app != null ? Map<String, dynamic>.from(app) : null;
        _scheme = scheme != null ? Map<String, dynamic>.from(scheme) : null;
        _userDocuments = userDocs;
        _adminDocuments = adminDocs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ============================================================
  // ✅ STRICT URL VALIDATOR
  // ============================================================
  bool _isValidDocUrl(dynamic value) {
    if (value == null) return false;
    if (value is Map && value.isEmpty) return false;
    if (value is List && value.isEmpty) return false;

    final str = value.toString().trim();
    if (str.isEmpty) return false;

    final lower = str.toLowerCase();
    if (lower == 'null' ||
        lower == 'undefined' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == '-' ||
        lower == 'none' ||
        lower == 'false' ||
        lower == 'true' ||
        lower == '0' ||
        lower == '{}' ||
        lower == '[]') {
      return false;
    }

    if (!str.startsWith('http://') &&
        !str.startsWith('https://') &&
        !str.startsWith('file:') &&
        !str.startsWith('blob:')) {
      return false;
    }

    if (str.length < 12) return false;
    return true;
  }

  // ==================== HELPERS ====================
  Map<String, dynamic> get _app {
    if (_application != null) return _application!;
    if (widget.initialData != null) return widget.initialData!;
    return {};
  }

  String _str(dynamic v, {String fallback = '—'}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      final hour = date.hour > 12 ? date.hour - 12 : date.hour;
      final ampm = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.day}/${date.month}/${date.year} • '
          '${hour == 0 ? 12 : hour}:'
          '${date.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'approved_application':
      case 'verification_successful':
      case 'payment_verified':
      case 'completed':
      case 'final_submitted':
        return const Color(0xFF10B981);
      case 'rejected':
      case 'verification_rejected':
      case 'update_rejected':
        return const Color(0xFFEF4444);
      case 'under_review':
      case 'review_application':
      case 'pending_verification':
        return const Color(0xFF3B82F6);
      case 'update_application':
        return const Color(0xFF8B5CF6);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _getStatusLabelHindi(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'approved_application':
        return 'स्वीकृत / Approved';
      case 'verification_successful':
      case 'payment_verified':
        return 'सत्यापित / Verified';
      case 'completed':
      case 'final_submitted':
        return 'पूर्ण / Completed';
      case 'rejected':
      case 'verification_rejected':
      case 'update_rejected':
        return 'अस्वीकृत / Rejected';
      case 'under_review':
      case 'review_application':
        return 'समीक्षाधीन / Under Review';
      case 'pending_verification':
        return 'सत्यापन लंबित / Pending Verification';
      case 'update_application':
        return 'अपडेट लंबित / Update Pending';
      case 'pending':
      default:
        return 'लंबित / Pending';
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
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
            _buildTopHeader(),
            Expanded(
              child: _isLoading
                  ? _buildLoading()
                  : _errorMessage != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _loadApplicationDetail,
                          color: const Color(0xFF6C63FF),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildApplicationHeaderCard(),
                                const SizedBox(height: 14),
                                _buildSchemeInfoCard(),
                                const SizedBox(height: 14),
                                _buildApplicantCard(),
                                const SizedBox(height: 14),
                                _buildAddressCard(),
                                const SizedBox(height: 14),
                                _buildBankCard(),
                                const SizedBox(height: 14),
                                _buildAdminDocumentsCard(),
                                const SizedBox(height: 14),
                                _buildUserDocumentsCard(),
                                const SizedBox(height: 14),
                                _buildTimelineCard(),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP HEADER (with back button)
  // ============================================================
  Widget _buildTopHeader() {
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'आवेदन विवरण',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Application Details',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _loadApplicationDetail,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.refresh, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================
  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
          SizedBox(height: 16),
          Text(
            'आवेदन विवरण लोड हो रहा है...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'विवरण लोड नहीं हो सका',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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
              onPressed: _loadApplicationDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('फिर से कोशिश करें'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER CARD
  // ============================================================
  Widget _buildApplicationHeaderCard() {
    final status = _str(_app['status'], fallback: 'pending').toLowerCase();
    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusLabelHindi(status);
    final appId = _str(_app['application_id']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor,
            statusColor.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.35),
            blurRadius: 20,
            spreadRadius: 4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'आवेदन संख्या / Application Number',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  appId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
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
  // SCHEME INFO CARD
  // ============================================================
  Widget _buildSchemeInfoCard() {
    final schemeId = _str(_app['scheme_id']);
    final schemeName = _str(_app['scheme_name']);
    final schemeNameHindi = _str(_app['scheme_name_hindi']);
    final level = _str(_app['scheme_level']);
    final state = _str(_app['scheme_state']);
    final category = _str(_app['scheme_category']);

    return _buildCard(
      title: 'योजना जानकारी',
      titleEn: 'Scheme Information',
      icon: Icons.account_balance,
      iconColor: const Color(0xFF6C63FF),
      children: [
        _buildRow('योजना आईडी', schemeId, isMono: true),
        if (schemeNameHindi != '—')
          _buildRow('योजना का नाम (हिंदी)', schemeNameHindi),
        if (schemeName != '—') _buildRow('Scheme Name', schemeName),
        _buildRow('स्तर / Level', level == 'central' ? 'केंद्रीय' : 'राज्य'),
        if (state != '—') _buildRow('राज्य / State', state),
        if (category != '—') _buildRow('श्रेणी / Category', category),
      ],
    );
  }

  // ============================================================
  // APPLICANT CARD
  // ============================================================
  Widget _buildApplicantCard() {
    final details = (_app['applicant_details'] as Map?) ?? {};

    final fullName = _str(details['full_name']);
    final fatherName = _str(details['father_name']);
    final motherName = _str(details['mother_name']);
    final dob = _str(details['date_of_birth']);
    final gender = _str(details['gender']);
    final category = _str(details['category']);
    final marital = _str(details['marital_status']);
    final aadhaar = _str(details['aadhaar_number']);
    final mobile = _str(details['mobile']);
    final email = _str(details['email']);
    final income = _str(details['annual_income']);
    final bpl = details['bpl_status'] == true;
    final disability = details['disability_status'] == true;
    final disabilityPct = _str(details['disability_percentage']);

    return _buildCard(
      title: 'आवेदक विवरण',
      titleEn: 'Applicant Details',
      icon: Icons.person,
      iconColor: const Color(0xFF3B82F6),
      children: [
        _buildRow('पूरा नाम / Full Name', fullName, isBold: true),
        _buildRow('पिता का नाम / Father', fatherName),
        _buildRow('माता का नाम / Mother', motherName),
        _buildRow('जन्म तिथि / DOB', _formatDate(dob)),
        _buildRow('लिंग / Gender',
            gender == '—' ? '—' : gender.toString().toUpperCase()),
        _buildRow('श्रेणी / Category', category),
        _buildRow('वैवाहिक स्थिति / Marital', marital),
        _buildRow('आधार नंबर / Aadhaar', aadhaar, isMono: true),
        _buildRow('मोबाइल / Mobile', mobile, isMono: true),
        _buildRow('ईमेल / Email', email),
        _buildRow('वार्षिक आय / Income', income == '—' ? '—' : '₹$income'),
        _buildRow('BPL स्थिति', bpl ? 'हाँ / Yes' : 'नहीं / No'),
        _buildRow('विकलांगता', disability ? 'हाँ / Yes' : 'नहीं / No'),
        if (disability && disabilityPct != '—')
          _buildRow('विकलांगता प्रतिशत', '$disabilityPct%'),
      ],
    );
  }

  // ============================================================
  // ADDRESS CARD
  // ============================================================
  Widget _buildAddressCard() {
    final address = (_app['applicant_address'] as Map?) ?? {};

    final line1 = _str(address['address_line1']);
    final line2 = _str(address['address_line2']);
    final village = _str(address['village_city']);
    final district = _str(address['district']);
    final state = _str(address['state']);
    final pincode = _str(address['pincode']);
    final country = _str(address['country'], fallback: 'India');

    return _buildCard(
      title: 'पता',
      titleEn: 'Address',
      icon: Icons.location_on,
      iconColor: const Color(0xFF10B981),
      children: [
        _buildRow('पता पंक्ति 1 / Line 1', line1),
        if (line2 != '—') _buildRow('पता पंक्ति 2 / Line 2', line2),
        _buildRow('गाँव/शहर / Village', village),
        _buildRow('जिला / District', district),
        _buildRow('राज्य / State', state),
        _buildRow('पिनकोड / Pincode', pincode, isMono: true),
        _buildRow('देश / Country', country),
      ],
    );
  }

  // ============================================================
  // BANK CARD
  // ============================================================
  Widget _buildBankCard() {
    final bank = (_app['bank_details'] as Map?) ?? {};

    final holder = _str(bank['account_holder_name']);
    final bankName = _str(bank['bank_name']);
    final accNo = _str(bank['account_number']);
    final ifsc = _str(bank['ifsc_code']);
    final branch = _str(bank['branch_name']);
    final accType = _str(bank['account_type']);

    final maskedAcc = accNo.length > 4
        ? '${"*" * (accNo.length - 4)}${accNo.substring(accNo.length - 4)}'
        : accNo;

    return _buildCard(
      title: 'बैंक विवरण',
      titleEn: 'Bank Details',
      icon: Icons.account_balance_wallet,
      iconColor: const Color(0xFFF59E0B),
      children: [
        _buildRow('खाताधारक / Holder', holder),
        _buildRow('बैंक का नाम / Bank', bankName),
        _buildRow('खाता संख्या / Account', maskedAcc, isMono: true),
        _buildRow('IFSC कोड', ifsc, isMono: true),
        if (branch != '—') _buildRow('शाखा / Branch', branch),
        if (accType != '—')
          _buildRow('खाता प्रकार / Type',
              accType.toString().toUpperCase()),
      ],
    );
  }

  // ============================================================
  // ADMIN DOCUMENTS CARD
  // ============================================================
  Widget _buildAdminDocumentsCard() {
    final count = _adminDocuments.length;

    return _buildCard(
      title: 'एडमिन दस्तावेज़',
      titleEn: 'Admin Uploaded Documents',
      icon: Icons.admin_panel_settings,
      iconColor: const Color(0xFF7C3AED),
      badgeText: '$count ${count == 1 ? 'File' : 'Files'}',
      badgeColor: Colors.purple.shade50,
      badgeTextColor: Colors.purple,
      children: [
        if (count == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'कोई एडमिन दस्तावेज़ अपलोड नहीं किया गया।\n(Uploaded via Review / Final Submit will appear here)',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7280),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ..._adminDocuments.map((d) => _buildDocumentTile(d, isAdmin: true)),
      ],
    );
  }

  // ============================================================
  // USER DOCUMENTS CARD
  // ============================================================
  Widget _buildUserDocumentsCard() {
    final count = _userDocuments.length;

    return _buildCard(
      title: 'आपके दस्तावेज़',
      titleEn: 'Your Uploaded Documents (during scheme apply)',
      icon: Icons.folder_copy,
      iconColor: const Color(0xFF2563EB),
      badgeText: '$count ${count == 1 ? 'File' : 'Files'}',
      badgeColor: Colors.blue.shade50,
      badgeTextColor: Colors.blue,
      children: [
        if (count == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'कोई दस्तावेज़ अपलोड नहीं किया गया।\n(Only documents uploaded during scheme apply appear here)',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7280),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ..._userDocuments.map((d) => _buildDocumentTile(d, isAdmin: false)),
      ],
    );
  }

  // ============================================================
  // DOCUMENT TILE
  // ============================================================
  Widget _buildDocumentTile(
    Map<String, dynamic> doc, {
    required bool isAdmin,
  }) {
    final String label = doc['label']?.toString() ?? 'Document';
    final String url = doc['url']?.toString() ?? '';
    final String? downloadUrl = doc['download_url']?.toString();
    final String badge = doc['badge']?.toString() ??
        (isAdmin ? 'ADMIN' : 'USER');
    final Color badgeColor = doc['badgeColor'] is Color
        ? doc['badgeColor'] as Color
        : (isAdmin ? Colors.purple : Colors.green);

    final icon = _iconForUrl(url);
    final color = _colorForUrl(url);
    final fileType = _fileTypeForUrl(url);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAdmin ? Colors.purple.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdmin ? Colors.purple.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: badgeColor.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      fileType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.visibility,
                color: isAdmin ? Colors.purple : Colors.blue),
            tooltip: "View",
            onPressed: () => _openDocumentViewer(
              url,
              title: label,
              downloadUrl: downloadUrl,
              fileType: fileType,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TIMELINE CARD
  // ============================================================
  Widget _buildTimelineCard() {
    final createdAt = _str(_app['created_at']);
    final appliedAt = _str(_app['applied_at']);
    final submittedAt = _str(_app['submitted_at']);
    final reviewedAt = _str(_app['reviewed_at']);
    final updatedAt = _str(_app['updated_at']);

    return _buildCard(
      title: 'समयरेखा',
      titleEn: 'Timeline',
      icon: Icons.timeline,
      iconColor: const Color(0xFFEF4444),
      children: [
        if (createdAt != '—')
          _buildTimelineItem('आवेदन बनाया गया', createdAt,
              Icons.add_circle, Colors.blue),
        if (appliedAt != '—' && appliedAt != createdAt)
          _buildTimelineItem('आवेदन सबमिट किया गया', appliedAt,
              Icons.check_circle, Colors.green),
        if (submittedAt != '—' && submittedAt != createdAt)
          _buildTimelineItem('दस्तावेज़ सबमिट किए गए', submittedAt,
              Icons.upload_file, Colors.purple),
        if (reviewedAt != '—')
          _buildTimelineItem('समीक्षा की गई', reviewedAt,
              Icons.rate_review, Colors.orange),
        if (updatedAt != '—' && updatedAt != createdAt)
          _buildTimelineItem('अंतिम अपडेट', updatedAt,
              Icons.update, Colors.teal),
      ],
    );
  }

  Widget _buildTimelineItem(
    String label,
    String timestamp,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
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
  // FILE HELPERS
  // ============================================================
  IconData _iconForUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.pdf') || u.contains('/raw/')) {
      return Icons.picture_as_pdf;
    }
    if (u.contains('.jpg') ||
        u.contains('.jpeg') ||
        u.contains('.png') ||
        u.contains('.webp') ||
        u.contains('.gif') ||
        u.contains('/image/')) {
      return Icons.image;
    }
    if (u.contains('.doc')) return Icons.description;
    if (u.contains('.xls')) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  Color _colorForUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.pdf') || u.contains('/raw/')) return Colors.red;
    if (u.contains('.jpg') ||
        u.contains('.jpeg') ||
        u.contains('.png') ||
        u.contains('.webp') ||
        u.contains('.gif') ||
        u.contains('/image/')) {
      return Colors.blue;
    }
    if (u.contains('.doc')) return Colors.indigo;
    if (u.contains('.xls')) return Colors.green;
    return Colors.blueGrey;
  }

  String _fileTypeForUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.pdf') || u.contains('/raw/')) return 'pdf';
    if (u.contains('.jpg') ||
        u.contains('.jpeg') ||
        u.contains('.png') ||
        u.contains('.webp') ||
        u.contains('.gif') ||
        u.contains('/image/')) return 'image';
    if (u.contains('.doc')) return 'word';
    if (u.contains('.xls')) return 'excel';
    return 'file';
  }

  Future<void> _openDocumentViewer(
    String url, {
    String title = 'Document',
    String? downloadUrl,
    String? fileType,
  }) async {
    if (url.isEmpty) {
      showMessage(context, "Document URL not available", isError: true);
      return;
    }
    String finalUrl = url.trim();
    if (!finalUrl.startsWith('http') &&
        !finalUrl.startsWith('file') &&
        !finalUrl.startsWith('blob:')) {
      finalUrl = 'https://$finalUrl';
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileViewerScreen(
          url: finalUrl,
          title: title,
          downloadUrl: downloadUrl ?? finalUrl,
          fileType: fileType,
        ),
      ),
    );
  }

  // ============================================================
  // SHARED WIDGETS
  // ============================================================
  Widget _buildCard({
    required String title,
    required String titleEn,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  iconColor.withOpacity(0.12),
                  iconColor.withOpacity(0.04),
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
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
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
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor ?? Colors.grey.shade700,
                      ),
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

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    bool isMono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: const Color(0xFF111827),
                fontFamily: isMono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}