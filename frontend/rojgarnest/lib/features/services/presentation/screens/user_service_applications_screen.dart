// lib/features/services/presentation/screens/user_service_applications_screen.dart
// ⚡ Cache-First + Background Refresh
// ✅ FIXED: Service application documents now STRICTLY separated
// ✅ FIXED: Documents uploaded via apply_service_screen → show ONLY here
// ✅ FIXED: Documents from user_documents_screen → NEVER show here
// ✅ FIXED: Documents in job applications → NEVER show here
// ✅ FIXED: Payment status now driven by MAIN `status` field first
// ✅ FIXED: _buildPaymentInformationCard now reads directly from DB app map
// ✅ UPDATED: Admin review/final docs shown SEPARATELY near Confirm/Update buttons
// ✅ NEW: "Take Action" card moved to TOP (right below Status card)
//         so user can directly see and act without scrolling.
// ✅ NEW: APPLICATION NUMBER now displayed in BOTH list card and detail view
//         - List card: "Application No:" row
//         - Detail view: dedicated gradient card with copy button
//         - Cache: application_id / application_number saved & restored
//         - Fallback: application_number > application_id > short _id

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ NEW — for Clipboard
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/core/widgets/file_viewer_screen.dart';
import 'package:rojgarnest/features/services/models/service_types.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/features/services/data/service_repository.dart';

// ============================================================
// HELPERS — Normalize payment + application status
// ============================================================
class AppStatusHelper {
  static String _norm(dynamic v) =>
      (v ?? '').toString().trim().toLowerCase();

  /// Returns: 'approved' | 'pending' | 'rejected' | 'not_submitted'
  static String paymentStatus(Map<String, dynamic> app) {
    // ============================================================
    // ✅ STEP 1: MAIN STATUS FIRST — most authoritative source of truth
    // ============================================================
    final mainStatus = _norm(app['status']);

    const mainApproved = {
      'payment_verified',
      'verification_successful',
      'approved',
      'approved_application',
      'completed',
      'confirmed_application',
      'final_submit',
      'final_submitted',
      'review_application',
      'under_review',
      'submitted',
      'shortlisted',
      'interview',
      'offered',
      'pending_admin_review',
      'update_application',
    };
    if (mainApproved.contains(mainStatus)) return 'approved';

    const mainRejected = {
      'verification_rejected',
      'payment_rejected',
      'rejected',
      'update_rejected',
    };
    if (mainRejected.contains(mainStatus)) return 'rejected';

    const mainPending = {
      'payment_pending',
      'pending_verification',
      'pending',
    };
    if (mainPending.contains(mainStatus)) return 'pending';

    // ============================================================
    // ✅ STEP 2: Fall back to payment_verification_status
    // ============================================================
    final pvs = _norm(app['payment_verification_status']);
    if ([
      'approved', 'verified', 'success', 'completed',
      'paid', 'captured', 'settled'
    ].contains(pvs)) {
      return 'approved';
    }
    if (['rejected', 'failed', 'declined', 'cancelled'].contains(pvs)) {
      return 'rejected';
    }
    if ([
      'pending', 'pending_verification', 'under_review',
      'created', 'processing'
    ].contains(pvs)) {
      return 'pending';
    }

    // ============================================================
    // ✅ STEP 3: Fall back to payment_status
    // ============================================================
    final ps = _norm(app['payment_status']);
    if ([
      'approved', 'verified', 'success', 'completed',
      'paid', 'captured', 'settled'
    ].contains(ps)) {
      return 'approved';
    }
    if (['rejected', 'failed', 'declined', 'cancelled'].contains(ps)) {
      return 'rejected';
    }
    if (['pending', 'created', 'processing', 'initiated'].contains(ps)) {
      return 'pending';
    }

    // ============================================================
    // ✅ STEP 4: Razorpay fallback
    // ============================================================
    final razorpayId = _norm(app['razorpay_payment_id']);
    final paymentId = _norm(app['payment_id']);
    final transactionId = _norm(app['transaction_id']);
    if (razorpayId.isNotEmpty ||
        paymentId.isNotEmpty ||
        transactionId.isNotEmpty) {
      return 'approved';
    }

    return 'not_submitted';
  }

  static String displayPaymentStatus(Map<String, dynamic> app) {
    switch (paymentStatus(app)) {
      case 'approved':
        return 'VERIFIED';
      case 'pending':
        return 'PENDING';
      case 'rejected':
        return 'REJECTED';
      default:
        return 'NOT SUBMITTED';
    }
  }

  static Color paymentStatusColor(Map<String, dynamic> app) {
    switch (paymentStatus(app)) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String displayMainStatus(Map<String, dynamic> app) {
    final s = _norm(app['status']);
    switch (s) {
      case 'payment_pending':
        return 'PAYMENT PENDING';
      case 'pending_verification':
        return 'PENDING VERIFICATION';
      case 'payment_verified':
        return 'PAYMENT VERIFIED';
      case 'verification_successful':
        return 'VERIFICATION SUCCESSFUL';
      case 'verification_rejected':
        return 'VERIFICATION REJECTED';
      case 'approved':
        return 'APPROVED';
      case 'approved_application':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      case 'update_rejected':
        return 'UPDATE REJECTED';
      case 'completed':
        return 'COMPLETED';
      case 'submitted':
        return 'SUBMITTED';
      case 'review_application':
        return 'UNDER REVIEW';
      case 'under_review':
        return 'UNDER REVIEW';
      case 'update_application':
        return 'UPDATE SUBMITTED';
      case 'final_submit':
        return 'FINAL SUBMITTED';
      case 'final_submitted':
        return 'FINAL SUBMITTED';
      case 'confirmed_application':
        return 'CONFIRMED';
      case 'shortlisted':
        return 'SHORTLISTED';
      case 'interview':
        return 'INTERVIEW';
      case 'offered':
        return 'OFFERED';
      default:
        return s.toUpperCase();
    }
  }

  static Color mainStatusColor(Map<String, dynamic> app) {
    final s = _norm(app['status']);
    if ([
      'completed',
      'approved',
      'approved_application',
      'confirmed_application',
      'offered',
      'payment_verified',
      'verification_successful'
    ].contains(s)) {
      return Colors.green;
    }
    if ([
      'rejected',
      'verification_rejected',
      'update_rejected',
      'payment_rejected'
    ].contains(s)) {
      return Colors.red;
    }
    if (['payment_pending', 'pending_verification', 'update_application']
        .contains(s)) {
      return Colors.orange;
    }
    if ([
      'review_application',
      'under_review',
      'submitted',
      'final_submit',
      'final_submitted'
    ].contains(s)) {
      return Colors.blue;
    }
    if (['shortlisted', 'interview'].contains(s)) {
      return Colors.purple;
    }
    return Colors.grey;
  }
}

class UserServiceApplicationScreen extends StatefulWidget {
  const UserServiceApplicationScreen({super.key});

  @override
  State<UserServiceApplicationScreen> createState() =>
      _UserServiceApplicationScreenState();
}

class _UserServiceApplicationScreenState
    extends State<UserServiceApplicationScreen>
    with TickerProviderStateMixin {
  // ==================== CACHE KEYS ====================
  static const String _cacheKey = 'user_service_apps_cache_v1';
  static const String _cacheTimeKey = 'user_service_apps_cache_time_v1';
  static const Duration _cacheValidity = Duration(minutes: 5);
  static const int _minLoadingMs = 600;

  // ==================== STATE ====================
  List<dynamic> _applications = [];
  List<dynamic> _filteredApplications = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isUpdatingStatus = false;
  Map<String, dynamic>? _selectedApplication;
  String? _errorMessage;
  String? _userEmail;

  // ============================================================
  // ✅ Service application documents
  // ============================================================
  List<Map<String, dynamic>> _serviceDocuments = [];
  bool _isLoadingServiceDocs = false;
  final Map<String, List<Map<String, dynamic>>> _serviceDocsCache = {};

  final Map<String, Map<String, String>> _serviceDetailsCache = {};
  final Map<String, List<dynamic>> _filterCache = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const List<Map<String, dynamic>> _filterButtons = [
    {'value': 'all', 'label': 'All', 'icon': Icons.list, 'color': Colors.grey},
    {
      'value': 'payment_pending',
      'label': 'Payment',
      'icon': Icons.payment,
      'color': Colors.purple
    },
    {
      'value': 'pending_verification',
      'label': 'Verifying',
      'icon': Icons.hourglass_empty,
      'color': Colors.orange
    },
    {
      'value': 'review_application',
      'label': 'Review',
      'icon': Icons.rate_review,
      'color': Colors.blue
    },
    {
      'value': 'approved',
      'label': 'Approved',
      'icon': Icons.verified,
      'color': Colors.teal
    },
    {
      'value': 'rejected',
      'label': 'Rejected',
      'icon': Icons.cancel,
      'color': Colors.red
    },
    {
      'value': 'completed',
      'label': 'Completed',
      'icon': Icons.celebration,
      'color': Colors.green
    },
  ];

  String _selectedFilter = 'all';

  // ==================== LIFECYCLE ====================
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

    _loadWithMinDelay();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ==================== ⚡ UNIFIED LOADING ====================
  Future<void> _loadWithMinDelay() async {
    final startTime = DateTime.now().millisecondsSinceEpoch;

    await Future.wait([
      _loadFromCacheInstant(),
      _refreshInBackground(),
    ]);

    final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
    if (elapsed < _minLoadingMs) {
      await Future.delayed(Duration(milliseconds: _minLoadingMs - elapsed));
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ==================== ⚡ CACHE-FIRST LOADING ====================
  Future<void> _loadFromCacheInstant() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);

      if (cachedJson != null && cachedJson.isNotEmpty) {
        final cachedList = jsonDecode(cachedJson) as List<dynamic>;
        if (mounted && cachedList.isNotEmpty) {
          setState(() {
            _applications = cachedList;
            _applyFilter(fast: true);
          });
          debugPrint("⚡ Loaded ${cachedList.length} apps from CACHE!");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Cache load error: $e");
    }
  }

  Future<void> _saveToCache(List<dynamic> apps) async {
    try {
      final slimApps = apps.map((app) {
        final m = app as Map;
        return {
          '_id': m['_id'],
          'service_id': m['service_id'],
          'sub_type_id': m['sub_type_id'],
          'service_name': m['service_name'],
          'sub_service_name': m['sub_service_name'],
          'user_name': m['user_name'],
          'user_email': m['user_email'],
          'status': m['status'],
          // ✅ NEW: cache application_id / application_number
          'application_id': m['application_id'],
          'application_number': m['application_number'],
          'payment_status': m['payment_status'],
          'payment_verification_status': m['payment_verification_status'],
          'amount': m['amount'],
          'payment_amount': m['payment_amount'],
          'razorpay_payment_id': m['razorpay_payment_id'],
          'razorpay_order_id': m['razorpay_order_id'],
          'transaction_id': m['transaction_id'],
          'transaction_date': m['transaction_date'],
          'payment_verified_at': m['payment_verified_at'],
          'payment_category_used': m['payment_category_used'],
          'payment_receipt_url': m['payment_receipt_url'],
          'screenshot_url': m['screenshot_url'],
          'document_url': m['document_url'],
          'submitted_document_url': m['submitted_document_url'],
          'submitted_document_name': m['submitted_document_name'],
          'final_document_url': m['final_document_url'],
          'final_document_name': m['final_document_name'],
          'applied_at': m['applied_at'],
          'created_at': m['created_at'],
          'rejection_reason': m['rejection_reason'],
          'verification_notes': m['verification_notes'],
          'fields': m['fields'],
          'payment_id': m['payment_id'],
          'user_category': m['user_category'],
          'display_service_name': m['display_service_name'],
          'display_service_icon': m['display_service_icon'],
          'display_sub_service_name': m['display_sub_service_name'],
        };
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(slimApps));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint("💾 Saved ${slimApps.length} apps to cache");
    } catch (e) {
      debugPrint("⚠️ Cache save error: $e");
    }
  }

  Future<void> _refreshInBackground() async {
    if (_userEmail == null) {
      try {
        _userEmail = await SecureStorage.getEmail();
      } catch (_) {}
    }

    if (!mounted) return;

    try {
      final apps = await ServiceRepository.getUserApplications();
      if (!mounted) return;

      final enrichedApps = apps.map((app) {
        final appMap = app is Map<String, dynamic>
            ? app
            : Map<String, dynamic>.from(app as Map);

        final serviceId = appMap['service_id']?.toString() ?? '';
        final subTypeId = appMap['sub_type_id']?.toString() ?? '';
        final details = _getServiceDisplayDetails(serviceId, subTypeId);

        return {
          ...appMap,
          'display_service_name': details['service_name'],
          'display_service_icon': details['service_icon'],
          'display_sub_service_name': details['sub_service_name'],
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _applications = enrichedApps;
        _isRefreshing = false;
        _filterCache.clear();
      });

      _applyFilter(fast: true);
      _saveToCache(enrichedApps);
      debugPrint("🔄 Background refresh complete: ${enrichedApps.length} apps");
    } catch (e) {
      debugPrint("❌ Refresh error: $e");
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          if (_applications.isEmpty) _errorMessage = e.toString();
        });
      }
    }
  }

  // ==================== ⚡ FAST FILTER ====================
  void _applyFilter({bool fast = false}) {
    if (_filterCache.containsKey(_selectedFilter)) {
      setState(() {
        _filteredApplications = _filterCache[_selectedFilter]!;
      });
      return;
    }

    List<dynamic> result;
    if (_selectedFilter == 'all') {
      result = _applications;
    } else {
      result = _applications
          .where((app) =>
              (app['status'] ?? '').toString().toLowerCase() ==
              _selectedFilter.toLowerCase())
          .toList();
    }

    _filterCache[_selectedFilter] = result;
    if (mounted) setState(() => _filteredApplications = result);
  }

  void _onFilterSelected(String filterValue) {
    if (_selectedFilter == filterValue) return;
    setState(() => _selectedFilter = filterValue);
    _applyFilter(fast: true);
  }

  // ==================== SERVICE DETAILS (CACHED) ====================
  Map<String, String> _getServiceDisplayDetails(
      String serviceId, String subTypeId) {
    final cacheKey = '$serviceId:$subTypeId';
    final cached = _serviceDetailsCache[cacheKey];
    if (cached != null) return cached;

    final service = ServiceMasterData.getServiceById(serviceId);
    final subType = ServiceMasterData.getSubTypeById(subTypeId);

    final details = {
      'service_name': service?.name ?? serviceId,
      'service_icon': service?.icon ?? '📄',
      'sub_service_name': subType?.name ?? subTypeId,
      'sub_service_description': subType?.description ?? '',
    };

    _serviceDetailsCache[cacheKey] = details;
    return details;
  }

  // ==================== MANUAL REFRESH ====================
  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });
    await _refreshInBackground();
  }

  // ============================================================
  // ✅ NEW: APPLICATION NUMBER HELPER
  // ============================================================
  // Priority:
  //   1. application_number  (best — human-readable)
  //   2. application_id      (human-readable on this backend)
  //   3. short form of _id   (fallback — Mongo ObjectId abbreviated)
  //
  // Returns "N/A" if nothing usable exists.
  // ============================================================
  String _getApplicationNumber(Map<String, dynamic> app) {
    // 1. Best: explicit application_number
    final appNumber = (app['application_number'] ?? '').toString().trim();
    if (appNumber.isNotEmpty &&
        appNumber.toLowerCase() != 'null' &&
        appNumber.toLowerCase() != 'undefined' &&
        appNumber.toLowerCase() != 'n/a') {
      return appNumber;
    }

    // 2. Next: application_id (this backend uses it as human-readable number)
    final appId = (app['application_id'] ?? '').toString().trim();
    if (appId.isNotEmpty &&
        appId.toLowerCase() != 'null' &&
        appId.toLowerCase() != 'undefined' &&
        appId.toLowerCase() != 'n/a') {
      return appId;
    }

    // 3. Fallback: short form of _id (Mongo ObjectId)
    final mongoId = (app['_id'] ?? '').toString().trim();
    if (mongoId.isNotEmpty) {
      if (mongoId.length > 12) {
        return '${mongoId.substring(0, 8)}...${mongoId.substring(mongoId.length - 4)}';
      }
      return mongoId;
    }

    return 'N/A';
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

  // ============================================================
  // ✅ FETCH SERVICE APPLICATION DOCUMENTS (STRICT)
  // ============================================================
  Future<void> _fetchServiceApplicationDocuments(String applicationId) async {
    if (!mounted || applicationId.isEmpty) return;

    if (_serviceDocsCache.containsKey(applicationId)) {
      setState(() {
        _serviceDocuments = _serviceDocsCache[applicationId]!;
        _isLoadingServiceDocs = false;
      });
      return;
    }

    setState(() {
      _isLoadingServiceDocs = true;
      _serviceDocuments = [];
    });

    final List<Map<String, dynamic>> userDocs = [];
    final List<Map<String, dynamic>> adminDocs = [];

    try {
      debugPrint("📄 Fetching service application docs → $applicationId");

      final res = await DioClient.dio.get(
        '/services/application/$applicationId/documents',
      );

      if (res.data is Map && res.data['success'] == true) {
        // ============================================================
        // A. USER-UPLOADED SERVICE DOCUMENTS
        // ============================================================
        final List<dynamic> serviceDocs =
            (res.data['service_documents'] as List?) ?? [];
        for (final raw in serviceDocs) {
          if (raw is! Map) continue;
          final d = Map<String, dynamic>.from(raw);

          final url = (d['url'] ?? '').toString().trim();
          if (!_isValidDocUrl(url)) continue;

          final source = (d['source'] ?? '').toString();
          if (source.isNotEmpty && source != 'service_application') {
            debugPrint("⏭️ Skipping non-service doc: $source");
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
            'uploaded_at': d['uploaded_at'],
          });
        }

        // ============================================================
        // B. ADMIN REVIEW / FINAL DOCUMENTS
        // ============================================================
        final List<dynamic> adminDocsRaw =
            (res.data['admin_documents'] as List?) ?? [];
        for (final raw in adminDocsRaw) {
          if (raw is! Map) continue;
          final d = Map<String, dynamic>.from(raw);

          final url = (d['url'] ?? '').toString().trim();
          if (!_isValidDocUrl(url)) continue;

          final source = (d['source'] ?? '').toString();
          final isAdminReview = source == 'admin_review';

          adminDocs.add({
            'key': (d['document_type'] ?? 'admin_doc').toString(),
            'label': (d['label'] ?? 'Admin Document').toString(),
            'url': url,
            'download_url': (d['download_url'] ?? url).toString(),
            'source': source,
            'is_application_doc': true,
            'is_admin_doc': true,
            'badge': isAdminReview ? 'ADMIN REVIEW' : 'ADMIN FINAL',
            'badgeColor': isAdminReview ? Colors.orange : Colors.deepPurple,
          });
        }
      }
    } catch (e) {
      debugPrint("⚠️ Failed to fetch service application docs: $e");
    }

    final combined = <Map<String, dynamic>>[...userDocs, ...adminDocs];

    _serviceDocsCache[applicationId] = combined;

    if (mounted) {
      setState(() {
        _serviceDocuments = combined;
        _isLoadingServiceDocs = false;
      });
    }
  }

  // ==================== NAVIGATION ====================
  void _showApplicationDetails(Map<String, dynamic> app) {
    final appId = (app['_id'] ?? '').toString();
    setState(() {
      _selectedApplication = app;
      _serviceDocuments = [];
    });
    if (appId.isNotEmpty) {
      _fetchServiceApplicationDocuments(appId);
    }
  }

  void _closeDetails() {
    setState(() {
      _selectedApplication = null;
      _serviceDocuments = [];
    });
    _refreshInBackground();
  }

  Future<void> _refreshCurrentApplication(String applicationId) async {
    try {
      final response =
          await DioClient.dio.get('/services/application/$applicationId');
      if (!mounted) return;

      Map<String, dynamic> updatedApp = {};

      if (response.data != null && response.data is Map) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data as Map);

        if (data.containsKey('data') && data['data'] is Map) {
          updatedApp = Map<String, dynamic>.from(data['data'] as Map);
        } else {
          updatedApp = data;
        }
      }

      if (updatedApp.isEmpty || updatedApp['_id'] == null) {
        _refreshInBackground();
        return;
      }

      final serviceId = updatedApp['service_id']?.toString() ?? '';
      final subTypeId = updatedApp['sub_type_id']?.toString() ?? '';
      final details = _getServiceDisplayDetails(serviceId, subTypeId);

      final enrichedApp = {
        ...updatedApp,
        'display_service_name': details['service_name'] ?? serviceId,
        'display_service_icon': details['service_icon'] ?? '📄',
        'display_sub_service_name': details['sub_service_name'] ?? subTypeId,
      };

      setState(() {
        final index = _applications.indexWhere((app) {
          final appMap = app is Map ? Map<String, dynamic>.from(app) : {};
          return appMap['_id']?.toString() == applicationId;
        });

        if (index != -1) _applications[index] = enrichedApp;

        if (_selectedApplication != null &&
            _selectedApplication!['_id']?.toString() == applicationId) {
          _selectedApplication = enrichedApp;
        }
        _filterCache.clear();
      });

      _serviceDocsCache.remove(applicationId);
      await _fetchServiceApplicationDocuments(applicationId);

      _applyFilter(fast: true);
      _saveToCache(_applications);
    } catch (e) {
      debugPrint("❌ Refresh single error: $e");
    }
  }

  // ==================== CONFIRM APPLICATION ====================
  Future<void> _confirmApplication(String applicationId) async {
    if (!mounted || _isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final response = await DioClient.dio.put(
        '/services/application/$applicationId/user-confirm',
        data: {'notes': 'Application confirmed by user'},
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(context, "✅ Application confirmed!");
        await _refreshCurrentApplication(applicationId);
        _sendBellNotification(
          applicationId: applicationId,
          status: 'confirmed_application',
          userEmail: _selectedApplication?['user_email'] ?? '',
          userName: _selectedApplication?['user_name'] ?? 'User',
          notes: 'Application confirmed by user',
        );
      } else {
        showMessage(context,
            response.data['message'] ?? "Failed to confirm application",
            isError: true);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed: ${e.toString()}", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  // ==================== UPDATE APPLICATION ====================
  void _showUpdateApplicationDialog() async {
    final status = _selectedApplication?['status'] ?? '';

    if (status != 'review_application' && status != 'under_review') {
      showMessage(context, "Application is not in review status",
          isError: true);
      return;
    }

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _UpdateApplicationDialog(),
    );

    if (result != null && mounted) {
      await _submitApplicationUpdate(result);
    }
  }

  Future<void> _submitApplicationUpdate(Map<String, dynamic> updateData) async {
    final applicationId = _selectedApplication!['_id'];
    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final response = await DioClient.dio.post(
        '/services/application/$applicationId/user-update',
        data: {
          'updates': updateData['fields'],
          'notes': updateData['notes'] ?? '',
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(context, "✅ Update submitted!");
        await _refreshCurrentApplication(applicationId);
        _sendBellNotification(
          applicationId: applicationId,
          status: 'update_application',
          userEmail: _selectedApplication?['user_email'] ?? '',
          userName: _selectedApplication?['user_name'] ?? 'User',
          notes: 'Application update submitted by user',
        );
      } else {
        showMessage(context,
            response.data['message'] ?? "Failed to submit update",
            isError: true);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed: ${e.toString()}", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  // ==================== BELL NOTIFICATION ====================
  Future<void> _sendBellNotification({
    required String applicationId,
    required String status,
    required String userEmail,
    required String userName,
    String? notes,
  }) async {
    try {
      final statusMessages = {
        'confirmed_application':
            '✅ Your service application has been confirmed!',
        'update_application':
            '📝 Your update has been submitted for admin review.',
        'approved': '✅ Your service application has been approved!',
        'rejected': '❌ Your service application has been rejected.',
        'completed': '✅ Your service application has been completed!',
      };

      final metadata = {
        'application_id': applicationId,
        'status': status,
        'service_name':
            _selectedApplication?['display_service_name'] ?? 'Service',
        'sub_service_name':
            _selectedApplication?['display_sub_service_name'] ?? '',
        'show_blue_bell': true,
        'user_name': userName,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      DioClient.dio.post(
        '/notification/admin/broadcast',
        data: {
          'title': statusMessages[status] ?? "Status: ${status.toUpperCase()}",
          'message': statusMessages[status] ??
              "Your application status: ${status.toUpperCase()}.",
          'metadata': metadata,
        },
      ).catchError((e) {
        debugPrint("⚠️ Bell notification failed: $e");
        return Response(requestOptions: RequestOptions(path: ''));
      });
    } catch (e) {
      debugPrint("❌ Bell notification error: $e");
    }
  }

  // ==================== FILE VIEWERS ====================
  String _getFileType(String url) {
    final urlLower = url.toLowerCase();
    if (urlLower.endsWith('.pdf') || urlLower.contains('.pdf')) return 'pdf';
    if (urlLower.endsWith('.jpg') ||
        urlLower.endsWith('.jpeg') ||
        urlLower.endsWith('.png') ||
        urlLower.endsWith('.webp')) {
      return 'image';
    }
    if (urlLower.contains('cloudinary.com')) return 'cloudinary';
    return 'unknown';
  }

  void _viewAcknowledgmentReceipt() {
    final app = _selectedApplication!;
    final documentUrl =
        app['submitted_document_url'] ?? app['final_document_url'];
    final documentName = app['submitted_document_name'] ??
        app['final_document_name'] ??
        'Service Document';

    if (documentUrl == null || documentUrl.isEmpty) {
      showMessage(context, "No document available.", isError: true);
      return;
    }
    _showFileDialog(documentUrl, documentName);
  }

  void _viewDocument(String url, String title) {
    _showFileDialog(url, title);
  }

  void _showFileDialog(String url, String title) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.9,
          height: MediaQuery.of(dialogContext).size.height * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FileViewerScreen(
              url: url,
              title: title,
              downloadUrl: url,
              fileType: _getFileType(url),
              fileName: title,
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentReceiptDialog(String? receiptUrl) {
    if (receiptUrl == null || receiptUrl.isEmpty) {
      showMessage(context, "No payment receipt available", isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.9,
          height: MediaQuery.of(dialogContext).size.height * 0.8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Payment Receipt",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FileViewerScreen(
                    url: receiptUrl, title: "Payment Receipt"),
              ),
            ],
          ),
        ),
      ),
    );
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.95,
          height: MediaQuery.of(dialogContext).size.height * 0.9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: FileViewerScreen(
            url: finalUrl,
            title: title,
            downloadUrl: downloadUrl ?? finalUrl,
            fileType: fileType,
          ),
        ),
      ),
    );
  }

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

  // ============================================================
  // ✅ "Uploaded Documents" section (user + payment only)
  // ============================================================
  Widget _buildDocumentsSection(Map<String, dynamic> app) {
    final List<Map<String, dynamic>> allDocs = [];

    for (final d in _serviceDocuments) {
      if (d['is_admin_doc'] == true) continue;
      final url = d['url']?.toString() ?? '';
      if (!_isValidDocUrl(url)) continue;
      if (allDocs.any((x) => x['url'] == url)) continue;
      allDocs.add(d);
    }

    final receiptUrl = app['payment_receipt_url'];
    if (_isValidDocUrl(receiptUrl)) {
      final urlStr = receiptUrl.toString().trim();
      if (!allDocs.any((x) => x['url'] == urlStr)) {
        allDocs.add({
          'key': 'payment_receipt_url',
          'label': 'Payment Receipt',
          'url': urlStr,
          'download_url': app['payment_receipt_download_url'],
          'source': 'application',
          'is_application_doc': true,
        });
      }
    }

    final screenshotUrl = app['screenshot_url'];
    if (_isValidDocUrl(screenshotUrl)) {
      final urlStr = screenshotUrl.toString().trim();
      if (!allDocs.any((x) => x['url'] == urlStr)) {
        allDocs.add({
          'key': 'screenshot_url',
          'label': 'Payment Screenshot',
          'url': urlStr,
          'source': 'application',
          'is_application_doc': true,
        });
      }
    }

    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_copy,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Your Uploaded Documents",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${allDocs.length} Files",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingServiceDocs)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (allDocs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.folder_off, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    "No documents uploaded for this application",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            Column(
              children: allDocs
                  .asMap()
                  .entries
                  .map((entry) => _buildDocumentRow(entry.key, entry.value))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(int index, Map<String, dynamic> doc) {
    final String label = doc['label']?.toString() ?? 'Document ${index + 1}';
    final String url = doc['url']?.toString() ?? '';
    final String? downloadUrl = doc['download_url']?.toString();
    final bool isAppDoc = doc['is_application_doc'] == true;
    final bool isAdminDoc = doc['is_admin_doc'] == true;
    final String source = doc['source']?.toString() ?? '';

    final icon = _iconForUrl(url);
    final color = _colorForUrl(url);
    final fileType = _fileTypeForUrl(url);

    String badgeLabel = "";
    Color badgeColor = Colors.blue;
    if (source == 'service_application') {
      badgeLabel = "UPLOADED";
      badgeColor = Colors.green;
    } else if (isAdminDoc) {
      badgeLabel = "ADMIN";
      badgeColor = Colors.purple;
    } else if (source == 'application') {
      badgeLabel = "PAYMENT";
      badgeColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAppDoc ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAppDoc ? Colors.blue.shade200 : Colors.grey.shade300,
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
                    if (badgeLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: badgeColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    if (badgeLabel.isNotEmpty) const SizedBox(width: 6),
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
            icon: const Icon(Icons.visibility, color: Colors.blue),
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
  // ✅ Admin Documents Section
  // ============================================================
  Widget _buildAdminDocumentsSection(Map<String, dynamic> app) {
    final List<Map<String, dynamic>> adminDocs = [];

    for (final d in _serviceDocuments) {
      if (d['is_admin_doc'] != true) continue;
      final url = d['url']?.toString() ?? '';
      if (!_isValidDocUrl(url)) continue;
      if (adminDocs.any((x) => x['url'] == url)) continue;
      adminDocs.add(d);
    }

    final submittedUrl = app['submitted_document_url'];
    if (_isValidDocUrl(submittedUrl)) {
      final urlStr = submittedUrl.toString().trim();
      if (!adminDocs.any((d) => d['url'] == urlStr)) {
        adminDocs.add({
          'key': 'submitted_document_url',
          'label': app['submitted_document_name']?.toString() ??
              'Review Document (from Admin)',
          'url': urlStr,
          'download_url': app['submitted_document_download_url'],
          'badge': 'ADMIN REVIEW',
          'badgeColor': Colors.orange,
          'is_admin_doc': true,
        });
      }
    }

    final finalUrl = app['final_document_url'];
    if (_isValidDocUrl(finalUrl)) {
      final urlStr = finalUrl.toString().trim();
      if (!adminDocs.any((d) => d['url'] == urlStr)) {
        adminDocs.add({
          'key': 'final_document_url',
          'label': app['final_document_name']?.toString() ??
              'Final Submission Document (from Admin)',
          'url': urlStr,
          'download_url': app['final_document_download_url'],
          'badge': 'ADMIN FINAL',
          'badgeColor': Colors.deepPurple,
          'is_admin_doc': true,
        });
      }
    }

    if (adminDocs.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.deepPurple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
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
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.deepPurple],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Documents from Admin",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "Uploaded during review / final submission",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${adminDocs.length} File${adminDocs.length > 1 ? 's' : ''}",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...adminDocs.map((doc) => _buildAdminDocumentRow(doc)),
        ],
      ),
    );
  }

  Widget _buildAdminDocumentRow(Map<String, dynamic> doc) {
    final String label = doc['label']?.toString() ?? 'Admin Document';
    final String url = doc['url']?.toString() ?? '';
    final String? downloadUrl = doc['download_url']?.toString();
    final String badge = doc['badge']?.toString() ??
        (doc['source'] == 'admin_review' ? 'ADMIN REVIEW' : 'ADMIN FINAL');
    final Color badgeColor = doc['badgeColor'] is Color
        ? doc['badgeColor'] as Color
        : (doc['source'] == 'admin_review'
            ? Colors.orange
            : Colors.deepPurple);

    final icon = _iconForUrl(url);
    final color = _colorForUrl(url);
    final fileType = _fileTypeForUrl(url);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.35), width: 1.5),
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
                        border: Border.all(color: badgeColor.withOpacity(0.4)),
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
            icon: const Icon(Icons.visibility, color: Colors.blue),
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

  // ==================== STATUS HELPERS ====================
  static const Map<String, Color> _statusColors = {
    'draft': Colors.grey,
    'payment_pending': Colors.purple,
    'pending_verification': Colors.orange,
    'under_review': Colors.blue,
    'review_application': Colors.blue,
    'approved': Colors.teal,
    'payment_verified': Colors.teal,
    'rejected': Colors.red,
    'completed': Colors.green,
    'submitted': Colors.green,
    'update_application': Colors.orange,
    'final_submit': Colors.deepPurple,
    'confirmed_application': Colors.green,
    'verification_successful': Colors.teal,
    'verification_rejected': Colors.red,
    'approved_application': Colors.green,
    'update_rejected': Colors.red,
    'final_submitted': Colors.deepPurple,
    'shortlisted': Colors.blue,
    'interview': Colors.orange,
    'offered': Colors.teal,
  };

  static const Map<String, String> _statusLabels = {
    'draft': 'DRAFT',
    'payment_pending': 'PAYMENT PENDING',
    'pending_verification': 'PENDING VERIFICATION',
    'under_review': 'UNDER REVIEW',
    'review_application': 'UNDER REVIEW',
    'approved': 'APPROVED',
    'rejected': 'REJECTED',
    'completed': 'COMPLETED',
    'payment_verified': 'PAYMENT VERIFIED',
    'submitted': 'SUBMITTED',
    'update_application': 'UPDATE SUBMITTED',
    'final_submit': 'FINAL SUBMITTED',
    'final_submitted': 'FINAL SUBMITTED',
    'confirmed_application': 'CONFIRMED',
    'verification_successful': 'VERIFICATION SUCCESSFUL',
    'verification_rejected': 'VERIFICATION REJECTED',
    'approved_application': 'APPROVED',
    'update_rejected': 'UPDATE REJECTED',
    'shortlisted': 'SHORTLISTED',
    'interview': 'INTERVIEW',
    'offered': 'OFFERED',
  };

  static const Map<String, IconData> _statusIcons = {
    'draft': Icons.edit,
    'payment_pending': Icons.payment,
    'pending_verification': Icons.hourglass_empty,
    'under_review': Icons.rate_review,
    'review_application': Icons.rate_review,
    'approved': Icons.verified,
    'rejected': Icons.cancel,
    'completed': Icons.celebration,
    'payment_verified': Icons.verified,
    'submitted': Icons.check_circle,
    'update_application': Icons.edit_note,
    'final_submit': Icons.send_and_archive,
    'final_submitted': Icons.send_and_archive,
    'confirmed_application': Icons.check_circle_outline,
    'verification_successful': Icons.verified,
    'verification_rejected': Icons.cancel_outlined,
    'approved_application': Icons.verified,
    'update_rejected': Icons.cancel,
    'shortlisted': Icons.star,
    'interview': Icons.people,
    'offered': Icons.celebration,
  };

  String _getStatusDisplay(String status) =>
      _statusLabels[status.toLowerCase()] ?? status.toUpperCase();

  Color _getStatusColor(String status) =>
      _statusColors[status.toLowerCase()] ?? Colors.grey;

  IconData _getStatusIcon(String status) =>
      _statusIcons[status.toLowerCase()] ?? Icons.pending;

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Draft — complete payment to submit';
      case 'payment_pending':
        return 'Waiting for payment completion';
      case 'pending_verification':
        return 'Payment receipt submitted, waiting for verification';
      case 'under_review':
      case 'review_application':
        return 'Application is being reviewed by admin';
      case 'approved':
        return 'Payment verified and application approved!';
      case 'payment_verified':
        return 'Payment verified successfully!';
      case 'verification_successful':
        return 'Payment verified successfully!';
      case 'rejected':
        return 'Payment verification failed. You can re-apply.';
      case 'verification_rejected':
        return 'Payment rejected. You can re-apply.';
      case 'completed':
        return 'Application completed successfully!';
      case 'confirmed_application':
        return 'You have confirmed your application!';
      case 'update_application':
        return 'Your update has been submitted for admin review';
      case 'final_submit':
      case 'final_submitted':
        return 'Final submission completed!';
      case 'shortlisted':
        return 'Congratulations! You have been shortlisted';
      case 'interview':
        return 'You have been selected for interview';
      case 'offered':
        return 'Congratulations! You have received an offer';
      default:
        return 'Status updated';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  // ==================== DESIGN HELPERS ====================
  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, IconData icon, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                width: 30,
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 4),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (_selectedApplication != null) {
      return _buildApplicationDetailView(_selectedApplication!);
    }
    if (_isLoading && _applications.isEmpty) return _buildAILoadingScreen();
    if (_errorMessage != null && _applications.isEmpty) return _buildErrorScreen();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildFilterChips(),
              Expanded(
                child: _filteredApplications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        color: const Color(0xFF6C63FF),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredApplications.length,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          cacheExtent: 300,
                          itemBuilder: (context, index) {
                            final app = _filteredApplications[index];
                            return RepaintBoundary(
                              key: ValueKey(app['_id'] ?? index),
                              child: _buildApplicationCard(app, index),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAILoadingScreen() {
    return Scaffold(
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
                      colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
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
                  child: const Center(
                    child: Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                ).createShader(bounds),
                child: const Text(
                  "AI is loading your applications...",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: Center(
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
                  "Failed to load applications",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? "Unknown error",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
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
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.assignment_turned_in,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "My Service Applications",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_filteredApplications.length} applications • AI tracked",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          if (_isRefreshing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 56,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filterButtons.length,
        addAutomaticKeepAlives: false,
        cacheExtent: 300,
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
                    filter['icon'],
                    size: 14,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(width: 6),
                  Text(filter['label']),
                ],
              ),
              onSelected: (selected) {
                _onFilterSelected(
                    selected ? filter['value'] as String : 'all');
              },
              backgroundColor: Colors.white.withOpacity(0.9),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              child: const Icon(Icons.assignment_turned_in,
                  size: 60, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 20),
            const Text(
              "No service applications yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Applications you submit will appear here",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ✅ Application card (list view) — WITH APPLICATION NUMBER
  // ============================================================
  Widget _buildApplicationCard(Map<String, dynamic> app, int index) {
    final serviceName =
        app['display_service_name'] ?? app['service_name'] ?? 'Service';
    final subServiceName =
        app['display_sub_service_name'] ?? app['sub_service_name'] ?? '';
    final serviceIcon = app['display_service_icon'] ?? '📄';
    final userName = app['user_name'] ?? 'Unknown';
    final userEmail = app['user_email'] ?? 'N/A';

    final status = app['status'] ?? 'payment_pending';
    final statusColor = _getStatusColor(status);
    final appliedDate = _formatDate(app['applied_at'] ?? app['created_at']);

    final paymentStatusText = AppStatusHelper.displayPaymentStatus(app);
    final paymentStatusColor = AppStatusHelper.paymentStatusColor(app);

    final amount = app['amount'] ?? app['payment_amount'];

    final hasSubmittedDocument = _isValidDocUrl(app['submitted_document_url']);
    final hasFinalDocument = _isValidDocUrl(app['final_document_url']);
    final hasReceipt = hasSubmittedDocument || hasFinalDocument;

    return GestureDetector(
      onTap: () => _showApplicationDetails(app),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withOpacity(0.15),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withOpacity(0.2),
                          statusColor.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _getStatusDisplay(status),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withOpacity(0.06),
                      const Color(0xFFFF6588).withOpacity(0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.1),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(serviceIcon,
                          style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subServiceName.isNotEmpty)
                            Text(
                              subServiceName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ============================================================
              // ✅ APPLICATION NUMBER — shown in the list card
              // ============================================================
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_number,
                        size: 16, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 8),
                    const Text(
                      'Application No:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        _getApplicationNumber(app),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                          fontFamily: 'monospace',
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ============================================================

              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(Icons.calendar_today, "Applied", appliedDate,
                      Colors.blue),
                  if (amount != null)
                    _buildInfoChip(Icons.currency_rupee, "Fee", "₹$amount",
                        Colors.green),
                  _buildInfoChip(
                    Icons.payment,
                    "Payment",
                    paymentStatusText,
                    paymentStatusColor,
                  ),
                  if (hasReceipt)
                    _buildInfoChip(Icons.receipt_long, "Receipt", "Ready",
                        Colors.indigo),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _showApplicationDetails(app),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text(
                      "View Details",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            "$label: $value",
            style: TextStyle(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ APPLICATION DETAIL VIEW — WITH APPLICATION NUMBER CARD
  // ✅ "Take Action" card ab STATUS CARD ke turant baad (TOP) hai.
  // ============================================================
  Widget _buildApplicationDetailView(Map<String, dynamic> app) {
    final serviceName =
        app['display_service_name'] ?? app['service_name'] ?? 'Service';
    final subServiceName =
        app['display_sub_service_name'] ?? app['sub_service_name'] ?? '';
    final serviceIcon = app['display_service_icon'] ?? '📄';

    final status = app['status'] ?? 'payment_pending';
    final statusColor = _getStatusColor(status);
    final userName = app['user_name'] ?? 'Unknown';
    final userEmail = app['user_email'] ?? 'N/A';
    final appliedDate = _formatDate(app['applied_at'] ?? app['created_at']);
    final fields = app['fields'] as Map<String, dynamic>? ?? {};

    // ✅ Action buttons only for review states
    final showActions =
        status == 'review_application' || status == 'under_review';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _buildDetailHeader(serviceIcon, serviceName),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ============================================================
                      // ✅ 1) STATUS CARD — always at top
                      // ============================================================
                      _buildStatusCard(app['_id'], status, statusColor),
                      const SizedBox(height: 16),

                      // ============================================================
                      // ✅ 2) APPLICATION NUMBER CARD
                      // ============================================================
                      _buildApplicationNumberCard(app),
                      const SizedBox(height: 16),

                      // ============================================================
                      // ✅ 3) TAKE ACTION CARD — right below
                      // ============================================================
                      if (showActions) ...[
                        _buildUserActionButtons(app['_id'], status),
                        const SizedBox(height: 16),
                      ],

                      // 4) Applicant
                      _buildUserCard(userName, userEmail, appliedDate),
                      const SizedBox(height: 16),

                      // 5) Service details
                      _buildServiceCard(
                          serviceName, subServiceName, serviceIcon, app),
                      const SizedBox(height: 16),

                      // 6) Submitted fields
                      _buildFieldsCard(fields),
                      if (fields.isNotEmpty) const SizedBox(height: 16),

                      // 7) Payment information
                      _buildPaymentInformationCard(app: app),
                      const SizedBox(height: 16),

                      // 8) User-uploaded documents
                      _buildDocumentsSection(app),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ NEW: APPLICATION NUMBER CARD (detail view)
  // ============================================================
  Widget _buildApplicationNumberCard(Map<String, dynamic> app) {
    final appNumber = _getApplicationNumber(app);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.08),
            const Color(0xFFFF6588).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6C63FF),
                  Color(0xFFFF6588),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.confirmation_number,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'APPLICATION NUMBER',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C63FF),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  appNumber,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                    fontFamily: 'monospace',
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Color(0xFF6C63FF)),
            tooltip: 'Copy',
            onPressed: () {
              if (appNumber != 'N/A') {
                Clipboard.setData(ClipboardData(text: appNumber));
                showMessage(context, "Application number copied");
              }
            },
          ),
        ],
      ),
    );
  }

  // ==================== DETAIL HEADER ====================
  Widget _buildDetailHeader(String serviceIcon, String serviceName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _closeDetails,
            tooltip: "Back",
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(serviceIcon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Application Details",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  serviceName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
            tooltip: "Refresh",
          ),
        ],
      ),
    );
  }

  // ==================== STATUS CARD ====================
  Widget _buildStatusCard(String appId, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 5,
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getStatusIcon(status),
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Application Status",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          letterSpacing: 0.5),
                    ),
                    Text(
                      _getStatusDisplay(status),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _getStatusDescription(status),
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isUpdatingStatus)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== USER CARD ====================
  Widget _buildUserCard(String name, String email, String appliedDate) {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Applicant", Icons.person_outline),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF6C63FF).withOpacity(0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(email,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 11, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            "Applied: $appliedDate",
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== SERVICE CARD ====================
  Widget _buildServiceCard(String serviceName, String subServiceName,
      String serviceIcon, Map<String, dynamic> app) {
    final amount = app['amount'] ?? app['payment_amount'];
    final userCategory = app['user_category'] ?? 'General/UR';

    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Service Details", Icons.workspace_premium),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C63FF).withOpacity(0.08),
                  const Color(0xFFFF6588).withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.12),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(serviceIcon,
                      style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      if (subServiceName.isNotEmpty)
                        Text(subServiceName,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.currency_rupee, "Fee",
              amount != null ? "₹$amount" : "N/A",
              color: Colors.green),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.category, "User Category",
              userCategory.toUpperCase(),
              color: const Color(0xFF6C63FF)),
        ],
      ),
    );
  }

  // ====================================================================
  // ✅ FIELDS CARD — ONLY plain text/object fields
  // ====================================================================
  Widget _buildFieldsCard(Map<String, dynamic> fields) {
    if (fields.isEmpty) return const SizedBox();

    final List<Map<String, dynamic>> flatFields = [];

    fields.forEach((key, value) {
      if (_isDocumentField(key, value)) {
        return;
      }

      final entries = _expandFieldValue(value);

      if (entries.length == 1 && entries.first['key'].toString().isEmpty) {
        flatFields.add({
          'key': key,
          'value': entries.first['value'],
        });
      } else {
        flatFields.add({
          'key': key,
          'value': null,
          'group': entries,
        });
      }
    });

    if (flatFields.isEmpty) return const SizedBox();

    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Submitted Information", Icons.description_outlined),
          ...flatFields.map((f) {
            if (f['group'] != null) {
              return _buildFieldGroupBlock(
                f['key'].toString(),
                f['group'] as List<Map<String, String>>,
              );
            }
            return _buildFieldInfoRow(
              f['key'].toString(),
              f['value']?.toString() ?? '',
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFieldInfoRow(String key, String value) {
    final label = _prettyFieldLabel(key);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.label_outline,
                color: Colors.white, size: 12),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? 'N/A' : value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldGroupBlock(String groupKey, List<Map<String, String>> items) {
    final label = _prettyFieldLabel(groupKey);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.05),
            const Color(0xFFFF6588).withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.list_alt,
                    color: Colors.white, size: 12),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.asMap().entries.map((e) {
            final item = e.value;
            final k = item['key']?.toString() ?? '';
            final v = item['value']?.toString() ?? '';
            return Padding(
              padding: EdgeInsets.only(
                  bottom: e.key == items.length - 1 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 22),
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C63FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _prettyFieldLabel(k).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          v.isEmpty ? 'N/A' : v,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, String>> _expandFieldValue(dynamic value) {
    final result = <Map<String, String>>[];
    if (value == null) return result;

    if (value is Map) {
      value.forEach((k, v) {
        result.add({
          'key': k.toString(),
          'value': v?.toString() ?? '',
        });
      });
      return result;
    }

    if (value is List) {
      for (final item in value) {
        if (item is Map) {
          final k = item['key']?.toString() ??
              item['name']?.toString() ??
              item['label']?.toString() ??
              '';
          final v = item['value']?.toString() ??
              item['text']?.toString() ??
              item.toString();
          result.add({'key': k, 'value': v});
        } else {
          result.add({'key': '', 'value': item.toString()});
        }
      }
      return result;
    }

    final str = value.toString().trim();
    if (str.startsWith('{') && str.endsWith('}') && str.contains(': ')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            result.add({'key': k.toString(), 'value': v?.toString() ?? ''});
          });
          return result;
        }
      } catch (_) {}

      final inner = str.substring(1, str.length - 1);
      final parts = inner.split(', ');
      for (final part in parts) {
        final idx = part.indexOf(': ');
        if (idx > 0) {
          final k = part.substring(0, idx).trim();
          final v = part.substring(idx + 2).trim();
          result.add({'key': k, 'value': v});
        } else if (part.trim().isNotEmpty) {
          result.add({'key': '', 'value': part.trim()});
        }
      }
      return result;
    }

    result.add({'key': '', 'value': str});
    return result;
  }

  String _prettyFieldLabel(String key) {
    if (key.isEmpty) return '';
    return key
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  bool _isDocumentField(String key, dynamic value) {
    if (value == null) return false;

    final keyLower = key.toLowerCase();

    if (keyLower.contains('service_documents') ||
        keyLower.contains('attached_documents') ||
        keyLower.contains('document_url') ||
        keyLower.contains('_url') ||
        keyLower.endsWith('_documents') ||
        keyLower.endsWith('_document')) {
      return false;
    }
    return false;
  }

  // ============================================================
  // ✅ PAYMENT INFORMATION CARD (DB-Driven)
  // ============================================================
  Widget _buildPaymentInformationCard({
    required Map<String, dynamic> app,
  }) {
    final paymentStatusKey = AppStatusHelper.paymentStatus(app);
    final paymentStatusText = AppStatusHelper.displayPaymentStatus(app);
    final paymentStatusColor = AppStatusHelper.paymentStatusColor(app);

    final transactionId = (app['razorpay_payment_id'] ??
            app['transaction_id'] ??
            app['payment_id'] ??
            'N/A')
        .toString();

    final paymentAmount = app['payment_amount'] ?? app['amount'];

    final paymentCategory = (app['payment_category_used'] ??
            app['payment_method'] ??
            'N/A')
        .toString()
        .toUpperCase();

    final verifiedAt = app['payment_verified_at'] ??
        app['payment_verified_on'] ??
        app['transaction_date'] ??
        app['applied_at'];

    final verifiedAtStr = verifiedAt != null
        ? _formatDate(verifiedAt.toString())
        : 'N/A';

    final receiptUrl = app['screenshot_url'] ??
        app['payment_receipt_url'] ??
        app['receipt_url'];

    final rejectionReason = app['payment_rejection_reason'] ??
        app['verification_notes'] ??
        '';

    final razorpayOrderId = app['razorpay_order_id']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            paymentStatusColor.withOpacity(0.08),
            paymentStatusColor.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: paymentStatusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      paymentStatusColor,
                      paymentStatusColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  paymentStatusKey == 'approved'
                      ? Icons.verified
                      : paymentStatusKey == 'rejected'
                          ? Icons.cancel
                          : Icons.hourglass_empty,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Payment Information",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: paymentStatusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: paymentStatusColor.withOpacity(0.4)),
                ),
                child: Text(
                  paymentStatusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: paymentStatusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoRow(Icons.receipt_long, "Transaction ID", transactionId),
          const Divider(height: 20),

          _buildInfoRow(
            Icons.calendar_today,
            "Date",
            verifiedAtStr,
          ),
          const Divider(height: 20),

          _buildInfoRow(
            Icons.currency_rupee,
            "Amount",
            paymentAmount != null ? "₹$paymentAmount" : "N/A",
            color: Colors.green,
          ),
          const Divider(height: 20),

          _buildInfoRow(
            Icons.category,
            "Category",
            paymentCategory,
          ),

          if (razorpayOrderId.isNotEmpty) ...[
            const Divider(height: 20),
            _buildInfoRow(
              Icons.shopping_cart,
              "Razorpay Order",
              razorpayOrderId,
            ),
          ],

          if (paymentStatusKey == 'rejected' && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        "Rejection Reason",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rejectionReason,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ),
            ),
          ],

          if (receiptUrl != null && receiptUrl.toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showPaymentReceiptDialog(receiptUrl.toString()),
                icon: const Icon(Icons.receipt, size: 18),
                label: const Text(
                  "View Payment Receipt",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: paymentStatusColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // ✅ User Action Buttons — shown at TOP of detail view
  // ============================================================
  Widget _buildUserActionButtons(String appId, String currentStatus) {
    final app = _selectedApplication ?? {};
    final adminDocsCount = _serviceDocuments
        .where((d) => d['is_admin_doc'] == true)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.08),
            const Color(0xFF6C63FF).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.touch_app,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Take Action",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "ACTION REQUIRED",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Your application is under review. Confirm it or submit updates:",
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),

          // Admin documents (agar hain)
          if (adminDocsCount > 0) ...[
            const SizedBox(height: 16),
            _buildAdminDocumentsSection(app),
          ],

          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              // CONFIRM
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isUpdatingStatus
                          ? null
                          : () => _confirmApplication(appId),
                      icon: _isUpdatingStatus
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle, size: 18),
                      label: const Text(
                        "Confirm",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // UPDATE
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isUpdatingStatus
                          ? null
                          : _showUpdateApplicationDialog,
                      icon: _isUpdatingStatus
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.edit_note, size: 18),
                      label: const Text(
                        "Update",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "✅ CONFIRM: Accept application as is\n"
                    "✏️ UPDATE: Provide corrections or more info",
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade900,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== INFO ROW ====================
  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? color}) {
    if (value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== UPDATE APPLICATION DIALOG ====================
class _UpdateApplicationDialog extends StatefulWidget {
  const _UpdateApplicationDialog();

  @override
  State<_UpdateApplicationDialog> createState() =>
      _UpdateApplicationDialogState();
}

class _UpdateApplicationDialogState extends State<_UpdateApplicationDialog> {
  final List<Map<String, dynamic>> _fields = [];
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addNewField();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _addNewField() {
    setState(() {
      _fields.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': '',
        'value': '',
      });
    });
  }

  void _removeField(String id) {
    setState(() {
      _fields.removeWhere((field) => field['id'] == id);
    });
  }

  void _updateField(String id, String key, String value) {
    setState(() {
      final index = _fields.indexWhere((field) => field['id'] == id);
      if (index != -1) _fields[index][key] = value;
    });
  }

  void _submit() {
    final validFields = _fields
        .where((field) =>
            field['name'].toString().trim().isNotEmpty &&
            field['value'].toString().trim().isNotEmpty)
        .toList();

    if (validFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add at least one field"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'fields': validFields
          .map((field) => {
                'field_name': field['name'].toString().trim(),
                'field_value': field['value'].toString().trim(),
              })
          .toList(),
      'notes': _notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.edit_note,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    "Update Application",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF6C63FF), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Add fields you want to update. Click + to add multiple.",
                      style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF6C63FF).withOpacity(0.9)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text("Field Name",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87)),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Text("Value",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87)),
                        ),
                        SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._fields.asMap().entries.map((entry) {
                      final index = entry.key;
                      final field = entry.value;
                      final fieldId = field['id'] as String;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.grey.shade300),
                                ),
                                child: TextFormField(
                                  initialValue: field['name'],
                                  decoration: const InputDecoration(
                                    hintText: "Field Name",
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                  ),
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87),
                                  onChanged: (value) =>
                                      _updateField(fieldId, 'name', value),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.grey.shade300),
                                ),
                                child: TextFormField(
                                  initialValue: field['value'],
                                  decoration: const InputDecoration(
                                    hintText: "Enter Value",
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                  ),
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87),
                                  onChanged: (value) =>
                                      _updateField(fieldId, 'value', value),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                if (index == _fields.length - 1)
                                  InkWell(
                                    onTap: _addNewField,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.add,
                                          color: Colors.green, size: 18),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                if (_fields.length > 1)
                                  InkWell(
                                    onTap: () => _removeField(fieldId),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.remove,
                                          color: Colors.red, size: 18),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Additional Notes (Optional)",
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText:
                              "Add any additional information or comments...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: const Text("Cancel",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, size: 18),
                          SizedBox(width: 8),
                          Text("Submit Update",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}