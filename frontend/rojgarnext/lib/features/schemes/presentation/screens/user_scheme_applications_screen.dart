// lib/features/schemes/presentation/screens/user_scheme_applications_screen.dart
// ============================================================
// USER SCHEME APPLICATIONS — "Scheme Application" page
// Shows all schemes the user has applied to
// ============================================================
// ✅ NEW: isEmbedded mode — renders WITHOUT Scaffold
// ✅ NEW: onSchemeSelected callback for embedded mode
// ✅ NEW: onBack callback for embedded mode
// ============================================================

import 'package:flutter/material.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/schemes/data/scheme_service.dart';
import 'package:rojgarnext/features/schemes/presentation/screens/scheme_detail_screen.dart';

class UserSchemeApplicationsScreen extends StatefulWidget {
  /// ✅ NEW: When true, renders WITHOUT Scaffold
  /// so it can be embedded in the right panel of UserDashboard.
  final bool isEmbedded;

  /// ✅ NEW: Optional callback when a scheme is selected (embedded mode)
  final Function(Map<String, dynamic>)? onSchemeSelected;

  /// ✅ NEW: Optional back callback (for embedded mode)
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

  final List<Map<String, dynamic>> _filterButtons = [
    {'value': 'all', 'label': 'सभी', 'labelEn': 'All', 'icon': Icons.apps, 'color': Colors.grey},
    {'value': 'pending', 'label': 'लंबित', 'labelEn': 'Pending', 'icon': Icons.hourglass_empty, 'color': Colors.orange},
    {'value': 'under_review', 'label': 'समीक्षा', 'labelEn': 'Review', 'icon': Icons.rate_review, 'color': Colors.blue},
    {'value': 'approved', 'label': 'स्वीकृत', 'labelEn': 'Approved', 'icon': Icons.check_circle, 'color': Colors.green},
    {'value': 'rejected', 'label': 'अस्वीकृत', 'labelEn': 'Rejected', 'icon': Icons.cancel, 'color': Colors.red},
  ];

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  // ==================== DATA LOADING ====================
  Future<void> _loadApplications() async {
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

    setState(() => _filteredApplications = result);
  }

  void _onFilterSelected(String value) {
    if (_selectedFilter == value) return;
    setState(() => _selectedFilter = value);
    _applyFilter();
  }

  // ==================== NAVIGATION ====================
  void _openSchemeDetails(Map<String, dynamic> app) {
    final schemeId = app['scheme_id']?.toString() ?? '';
    final schemeNameHindi = app['scheme_name_hindi']?.toString() ??
        app['scheme_name']?.toString() ?? 'योजना';

    if (schemeId.isEmpty) {
      showMessage(context, 'योजना आईडी उपलब्ध नहीं', isError: true);
      return;
    }

    // ✅ If onSchemeSelected callback provided, use it (embedded mode)
    if (widget.onSchemeSelected != null) {
      widget.onSchemeSelected!({
        'scheme_id': schemeId,
        'scheme_name': schemeNameHindi,
        'scheme': app,
      });
      return;
    }

    // Full screen mode
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
    // ✅ Build the main content
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

    // ✅ EMBEDDED MODE: No Scaffold
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
          // ✅ BACK BUTTON (only in embedded mode)
          if (widget.isEmbedded && widget.onBack != null)
            Material(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onBack,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w500,
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
            valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
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
        app['scheme_name']?.toString() ?? 'योजना';
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
      onTap: () => _openSchemeDetails(app),
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
            // Header
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

            // Application ID
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

            // Date
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

            // View details button
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () => _openSchemeDetails(app),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text(
                  'योजना विवरण देखें',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                  side: const BorderSide(
                    color: Color(0xFF6C63FF),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
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