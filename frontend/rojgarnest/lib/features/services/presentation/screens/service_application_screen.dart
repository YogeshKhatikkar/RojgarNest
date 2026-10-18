// lib/features/services/presentation/screens/service_application_screen.dart
// ⚡ ULTRA-FAST VERSION
// ✅ Cache-First Strategy + Background Refresh
// ✅ AI-Based Modern Design
// ✅ FIXED: Document upload on Review & Final Submit works on WEB + MOBILE
//    - Uses `withData: true` for web (required)
//    - Falls back to reading from `file.path` on mobile
//    - Never accesses `file.path` on web (was crashing)
//    - File is now MANDATORY (button disabled until picked)
//    - Clear debug logs for every step

import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/core/widgets/file_viewer_screen.dart';
import 'package:rojgarnest/features/services/models/service_types.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';

class ServiceApplicationScreen extends StatefulWidget {
  const ServiceApplicationScreen({super.key});

  @override
  State<ServiceApplicationScreen> createState() =>
      _ServiceApplicationScreenState();
}

class _ServiceApplicationScreenState extends State<ServiceApplicationScreen>
    with TickerProviderStateMixin {
  // ==================== CACHE KEYS ====================
  static const String _cacheKey = 'admin_service_apps_cache_v1';
  static const String _cacheTimeKey = 'admin_service_apps_cache_time_v1';
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
  String? _adminEmail;

  // ============================================================
  // ✅ TWO SEPARATE DOCUMENT LISTS
  // ============================================================
  List<Map<String, dynamic>> _adminDocuments = [];
  List<Map<String, dynamic>> _userDocuments = [];

  bool _isLoadingServiceDocs = false;
  final Map<String, List<Map<String, dynamic>>> _serviceDocsCache = {};

  final Map<String, Map<String, String>> _serviceDetailsCache = {};
  final Map<String, List<dynamic>> _filterCache = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const List<Map<String, String>> _documentKeyMap = [
    {'key': 'resume_url', 'label': 'Resume / CV'},
    {'key': 'profile_photo_url', 'label': 'Profile Photo'},
    {'key': 'aadhaar_url', 'label': 'Aadhaar Card'},
    {'key': 'pan_url', 'label': 'PAN Card'},
    {'key': 'passport_url', 'label': 'Passport'},
    {'key': 'driving_license_url', 'label': 'Driving License'},
    {'key': 'voter_id_url', 'label': 'Voter ID'},
    {'key': 'degree_certificate_url', 'label': 'Degree Certificate'},
    {'key': 'experience_letter_url', 'label': 'Experience Letter'},
    {'key': 'salary_slip_url', 'label': 'Salary Slip'},
    {'key': 'offer_letter_url', 'label': 'Offer Letter'},
    {'key': 'disability_certificate_url', 'label': 'Disability Certificate'},
    {'key': 'caste_certificate_url', 'label': 'Caste Certificate'},
    {'key': 'income_certificate_url', 'label': 'Income Certificate'},
    {'key': 'other_document_url', 'label': 'Other Document'},
  ];

  static const List<Map<String, dynamic>> _filterButtons = [
    {'value': 'all', 'label': 'All', 'icon': Icons.list, 'color': Colors.grey},
    {'value': 'payment_pending', 'label': 'Payment', 'icon': Icons.payment, 'color': Colors.purple},
    {'value': 'pending_verification', 'label': 'Verifying', 'icon': Icons.hourglass_empty, 'color': Colors.orange},
    {'value': 'review_application', 'label': 'Review', 'icon': Icons.rate_review, 'color': Colors.blue},
    {'value': 'approved', 'label': 'Approved', 'icon': Icons.verified, 'color': Colors.teal},
    {'value': 'rejected', 'label': 'Rejected', 'icon': Icons.cancel, 'color': Colors.red},
    {'value': 'completed', 'label': 'Completed', 'icon': Icons.celebration, 'color': Colors.green},
  ];

  String _selectedFilter = 'all';

  // ====================================================================
  // ✅ STRICT document URL validator
  // ====================================================================
  bool _isValidDocUrl(dynamic value) {
    if (value == null) return false;

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
        lower == '0') {
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

  // ==================== UNIFIED LOADING ====================
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
          debugPrint("⚡ Loaded ${cachedList.length} admin apps from CACHE!");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Admin cache load error: $e");
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
          'payment_status': m['payment_status'],
          'amount': m['amount'],
          'payment_amount': m['payment_amount'],
          'razorpay_payment_id': m['razorpay_payment_id'],
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
      debugPrint("💾 Saved ${slimApps.length} admin apps to cache");
    } catch (e) {
      debugPrint("⚠️ Admin cache save error: $e");
    }
  }

  Future<void> _refreshInBackground() async {
    if (_adminEmail == null) {
      try {
        _adminEmail = await SecureStorage.getEmail();
      } catch (_) {}
    }
    if (!mounted) return;

    try {
      final response = await DioClient.dio.get('/services/all-applications');
      if (!mounted) return;

      List<dynamic> apps = [];
      if (response.data is Map) {
        final data = response.data as Map;
        if (data.containsKey('applications')) {
          apps = data['applications'] as List<dynamic>;
        }
      }

      debugPrint("📋 Loaded ${apps.length} admin service applications");

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
        _errorMessage = null;
        _filterCache.clear();
      });
      _applyFilter(fast: true);
      _saveToCache(enrichedApps);
    } catch (e) {
      debugPrint("❌ Admin refresh error: $e");
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          if (_applications.isEmpty) _errorMessage = e.toString();
        });
      }
    }
  }

  void _applyFilter({bool fast = false}) {
    if (_filterCache.containsKey(_selectedFilter)) {
      setState(() => _filteredApplications = _filterCache[_selectedFilter]!);
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

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });
    await _refreshInBackground();
  }

  // ============================================================
  // ✅ Application details + document fetch
  // ============================================================
  void _showApplicationDetails(Map<String, dynamic> app) {
    final appId = (app['_id'] ?? '').toString();
    setState(() {
      _selectedApplication = app;
      _adminDocuments = [];
      _userDocuments = [];
    });
    if (appId.isNotEmpty) {
      _fetchServiceApplicationDocuments(appId);
    }
  }

  void _closeDetails() {
    setState(() {
      _selectedApplication = null;
      _adminDocuments = [];
      _userDocuments = [];
    });
    _refreshInBackground();
  }

  Future<void> _fetchServiceApplicationDocuments(String applicationId) async {
    if (!mounted || applicationId.isEmpty) return;

    if (_serviceDocsCache.containsKey(applicationId)) {
      final cached = _serviceDocsCache[applicationId]!;
      setState(() {
        _userDocuments = cached
            .where((d) => d['is_admin_doc'] != true)
            .map((d) => Map<String, dynamic>.from(d))
            .toList();
        _adminDocuments = cached
            .where((d) => d['is_admin_doc'] == true)
            .map((d) => Map<String, dynamic>.from(d))
            .toList();
        _isLoadingServiceDocs = false;
      });
      return;
    }

    setState(() {
      _isLoadingServiceDocs = true;
      _adminDocuments = [];
      _userDocuments = [];
    });

    final List<Map<String, dynamic>> userDocs = [];
    final List<Map<String, dynamic>> adminDocs = [];

    try {
      debugPrint("📄 Fetching service application docs → $applicationId");

      final res = await DioClient.dio.get(
        '/services/application/$applicationId/documents',
      );

      if (res.data is Map && res.data['success'] == true) {
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
            'is_user_doc': true,
            'uploaded_at': d['uploaded_at'],
          });
        }

        final List<dynamic> adminRaw =
            (res.data['admin_documents'] as List?) ?? [];
        for (final raw in adminRaw) {
          if (raw is! Map) continue;
          final d = Map<String, dynamic>.from(raw);

          final url = (d['url'] ?? '').toString().trim();
          if (!_isValidDocUrl(url)) continue;

          final source = (d['source'] ?? '').toString();
          final isAdminReview = source == 'admin_review';
          final isAdminFinal = source == 'admin_final';

          adminDocs.add({
            'key': (d['document_type'] ?? 'admin_doc').toString(),
            'label': (d['label'] ?? 'Admin Document').toString(),
            'url': url,
            'download_url': (d['download_url'] ?? url).toString(),
            'source': source,
            'is_application_doc': true,
            'is_admin_doc': isAdminReview || isAdminFinal,
            'uploaded_at': d['uploaded_at'],
          });
        }
      }
    } catch (e) {
      debugPrint("⚠️ Failed to fetch service application docs: $e");
    }

    final combined = <Map<String, dynamic>>[];
    combined.addAll(userDocs);
    combined.addAll(adminDocs);
    _serviceDocsCache[applicationId] = combined;

    if (mounted) {
      setState(() {
        _userDocuments = userDocs;
        _adminDocuments = adminDocs;
        _isLoadingServiceDocs = false;
      });
    }
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

      final newStatus = enrichedApp['status']?.toString() ?? 'unknown';

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
        _adminDocuments = [];
        _userDocuments = [];
      });

      _serviceDocsCache.remove(applicationId);
      await _fetchServiceApplicationDocuments(applicationId);

      _applyFilter(fast: true);
      _saveToCache(_applications);
      if (mounted) showMessage(context, "✅ Status: ${newStatus.toUpperCase()}");
    } catch (e) {
      debugPrint("❌ Refresh single error: $e");
    }
  }

  Future<void> _approvePayment(String paymentId, String applicationId) async {
    if (!mounted || _isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);
    try {
      final response = await DioClient.dio.post(
        '/services/application/$applicationId/verify-payment',
        data: {
          'action': 'approve',
          'notes': 'Payment verified and approved by admin',
        },
      );
      if (!mounted) return;
      if (response.data['success'] == true) {
        showMessage(context, "✅ Payment approved! Status → APPROVED.");
        await _refreshCurrentApplication(applicationId);
        _sendBellNotification(
          applicationId: applicationId,
          status: 'approved',
          userEmail: _selectedApplication?['user_email'] ?? '',
          adminName: 'Admin',
          notes: 'Payment approved',
        );
      } else {
        showMessage(context,
            response.data['message'] ?? "Failed to approve payment",
            isError: true);
      }
    } catch (e) {
      if (mounted) showMessage(context, "Failed: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _rejectPayment(String paymentId, String applicationId) async {
    if (!mounted) return;
    final TextEditingController reasonController = TextEditingController();

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cancel, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Reject Payment",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please provide a reason for rejecting this payment:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Enter rejection reason...",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: const Icon(Icons.edit_note, color: Colors.red),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "This reason will be sent to the applicant.",
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                showMessage(dialogContext,
                    "Please enter a reason for rejection",
                    isError: true);
                return;
              }
              Navigator.pop(dialogContext, true);
              _executeRejectPayment(paymentId, applicationId, reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Reject Payment"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeRejectPayment(
      String paymentId, String applicationId, String reason) async {
    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);
    try {
      final response = await DioClient.dio.post(
        '/services/application/$applicationId/verify-payment',
        data: {
          'action': 'reject',
          'notes': reason,
        },
      );
      if (!mounted) return;
      if (response.data['success'] == true) {
        showMessage(context, "❌ Payment rejected. Status → REJECTED.");
        await _refreshCurrentApplication(applicationId);
        _sendBellNotification(
          applicationId: applicationId,
          status: 'rejected',
          userEmail: _selectedApplication?['user_email'] ?? '',
          adminName: 'Admin',
          notes: reason,
        );
      } else {
        showMessage(context,
            response.data['message'] ?? "Failed to reject payment",
            isError: true);
      }
    } catch (e) {
      if (mounted) showMessage(context, "Failed: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
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

  Future<void> _sendBellNotification({
    required String applicationId,
    required String status,
    required String userEmail,
    required String adminName,
    String? notes,
  }) async {
    try {
      final statusMessages = {
        'approved': '✅ Payment verified! Your application is now APPROVED.',
        'rejected': '❌ Payment rejected. Reason: ${notes ?? "Please contact support"}',
        'under_review': '📋 Your application is under review.',
        'completed': '✅ FINAL SUBMISSION completed! Application COMPLETED.',
        'payment_pending': '⏳ Payment pending. Please complete payment.',
        'pending_verification': '⏳ Payment pending verification.',
        'confirmed_application': '✅ Application confirmed!',
        'update_application': '📝 Update submitted for review.',
      };
      final metadata = {
        'application_id': applicationId,
        'status': status,
        'admin_name': adminName,
        'service_name': _selectedApplication?['display_service_name'] ?? 'Service',
        'sub_service_name': _selectedApplication?['display_sub_service_name'] ?? '',
        'show_blue_bell': true,
        if (notes != null && notes.isNotEmpty) 'admin_notes': notes,
      };
      DioClient.dio.post(
        '/notification/admin/broadcast',
        data: {
          'title': statusMessages[status] ??
              "Application Status: ${status.toUpperCase()}",
          'message': statusMessages[status] ??
              "Your application status: ${status.toUpperCase()}.",
          'metadata': metadata,
        },
      ).catchError((e) {
        debugPrint("⚠️ Bell notification failed: $e");
        return Response(requestOptions: RequestOptions(path: ''));
      });
      debugPrint("🔔 Bell notification → $userEmail");
    } catch (e) {
      debugPrint("❌ Bell error: $e");
    }
  }

  // ====================================================================
  // ✅ SAFE FILE PICKER HELPER
  // ====================================================================
  Future<Uint8List?> _readPickedFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes;
    }

    if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      try {
        final f = File(file.path!);
        if (await f.exists()) {
          final data = await f.readAsBytes();
          debugPrint(
              "📱 Read ${data.length} bytes from mobile path: ${file.path}");
          return data;
        } else {
          debugPrint("❌ File does not exist at path: ${file.path}");
        }
      } catch (e) {
        debugPrint("❌ Failed to read file from path: $e");
      }
    }

    return null;
  }

  // ====================================================================
  // ✅ REVIEW DIALOG - FIXED
  // ====================================================================
  Future<void> _showReviewDialog(String applicationId) async {
    debugPrint("=" * 70);
    debugPrint("📝 OPENING SERVICE REVIEW DIALOG");
    debugPrint("   Application ID: $applicationId");
    debugPrint("   Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}");
    debugPrint("=" * 70);

    final TextEditingController notesController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ReviewDialogContent(
        notesController: notesController,
      ),
    );

    if (result == null) {
      debugPrint("❌ Review dialog cancelled");
      return;
    }

    debugPrint("=" * 70);
    debugPrint("✅ REVIEW DIALOG RETURNED");
    debugPrint("   Has File: ${result['hasFile']}");
    debugPrint("   File Name: ${result['fileName']}");
    debugPrint("   Notes: ${result['notes']}");
    debugPrint("=" * 70);

    final bool hasFile = result['hasFile'] == true;
    final Uint8List? fileBytes = result['fileBytes'] as Uint8List?;
    final String? fileName = result['fileName'] as String?;
    final String notes = (result['notes'] ?? '').toString().trim();

    setState(() => _isUpdatingStatus = true);

    try {
      // ✅ VALIDATE: File is MANDATORY for review
      if (!hasFile || fileBytes == null || fileBytes.isEmpty || fileName == null) {
        if (mounted) {
          showMessage(context,
              "⚠️ Please select a document to submit review",
              isError: true);
        }
        return;
      }

      debugPrint("📤 Uploading review document...");
      debugPrint("   File: $fileName");
      debugPrint("   Size: ${fileBytes.length} bytes");
      debugPrint("   Endpoint: /services/application/$applicationId/review-with-document");

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
        'notes': notes,
      });

      final uploadResponse = await DioClient.dio.post(
        '/services/application/$applicationId/review-with-document',
        data: formData,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      debugPrint("📥 Upload response status: ${uploadResponse.statusCode}");
      debugPrint("📥 Upload response data: ${uploadResponse.data}");

      if (!mounted) return;

      if (uploadResponse.data['success'] != true) {
        showMessage(
          context,
          uploadResponse.data['message'] ?? "Failed to upload document",
          isError: true,
        );
        return;
      }

      showMessage(context, "✅ Document uploaded & moved to REVIEW!");
      await _refreshCurrentApplication(applicationId);
    } catch (e) {
      debugPrint("❌ Error in review submit: $e");
      if (mounted) {
        showMessage(context, "Failed: ${e.toString()}", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  // ====================================================================
  // ✅ FINAL SUBMIT DIALOG - FIXED
  // ====================================================================
  Future<void> _showFinalSubmitDialog(String applicationId) async {
    debugPrint("=" * 70);
    debugPrint("📝 OPENING SERVICE FINAL SUBMIT DIALOG");
    debugPrint("   Application ID: $applicationId");
    debugPrint("   Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}");
    debugPrint("=" * 70);

    final TextEditingController notesController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _FinalSubmitDialogContent(
        notesController: notesController,
      ),
    );

    if (result == null) {
      debugPrint("❌ Final submit dialog cancelled");
      return;
    }

    debugPrint("=" * 70);
    debugPrint("✅ FINAL SUBMIT DIALOG RETURNED");
    debugPrint("   Has File: ${result['hasFile']}");
    debugPrint("   File Name: ${result['fileName']}");
    debugPrint("   Notes: ${result['notes']}");
    debugPrint("=" * 70);

    final bool hasFile = result['hasFile'] == true;
    final Uint8List? fileBytes = result['fileBytes'] as Uint8List?;
    final String? fileName = result['fileName'] as String?;
    final String notes = (result['notes'] ?? '').toString().trim();

    setState(() => _isUpdatingStatus = true);

    try {
      // ✅ VALIDATE: File is MANDATORY for final submit
      if (!hasFile || fileBytes == null || fileBytes.isEmpty || fileName == null) {
        if (mounted) {
          showMessage(context,
              "⚠️ Please select a document for final submission",
              isError: true);
        }
        return;
      }

      debugPrint("📤 Uploading final document...");
      debugPrint("   File: $fileName");
      debugPrint("   Size: ${fileBytes.length} bytes");
      debugPrint("   Endpoint: /services/application/$applicationId/final-submit-with-document");

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
        'notes': notes,
      });

      final uploadResponse = await DioClient.dio.post(
        '/services/application/$applicationId/final-submit-with-document',
        data: formData,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      debugPrint("📥 Upload response status: ${uploadResponse.statusCode}");
      debugPrint("📥 Upload response data: ${uploadResponse.data}");

      if (!mounted) return;

      if (uploadResponse.data['success'] != true) {
        showMessage(
          context,
          uploadResponse.data['message'] ?? "Failed to upload final document",
          isError: true,
        );
        return;
      }

      showMessage(context, "✅ FINAL SUBMISSION completed!");
      await _refreshCurrentApplication(applicationId);
    } catch (e) {
      debugPrint("❌ Error in final submit: $e");
      if (mounted) {
        showMessage(context, "Failed: ${e.toString()}", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _updateStatus(String applicationId, String newStatus,
      [String? notes]) async {
    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);
    try {
      final response = await DioClient.dio.put(
        '/services/application/$applicationId/status',
        data: {'status': newStatus, 'admin_notes': notes ?? ''},
      );
      if (!mounted) return;
      if (response.data['success'] == true) {
        debugPrint("✅ Status → $newStatus");
      } else {
        showMessage(context,
            response.data['message'] ?? "Failed to update status",
            isError: true);
      }
    } catch (e) {
      if (mounted) showMessage(context, "Failed: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  void _viewDocument(String url, String title) {
    _showFileDialog(url, title);
  }

  String _getFileType(String url) {
    final urlLower = url.toLowerCase();
    if (urlLower.endsWith('.pdf') || urlLower.contains('.pdf')) return 'pdf';
    if (urlLower.endsWith('.jpg') ||
        urlLower.endsWith('.jpeg') ||
        urlLower.endsWith('.png') ||
        urlLower.endsWith('.webp')) return 'image';
    if (urlLower.contains('cloudinary.com')) return 'cloudinary';
    return 'unknown';
  }

  void _viewAcknowledgmentReceipt() {
    final app = _selectedApplication!;
    final documentUrl = _isValidDocUrl(app['submitted_document_url'])
        ? app['submitted_document_url']
        : _isValidDocUrl(app['final_document_url'])
            ? app['final_document_url']
            : null;

    final documentName = app['submitted_document_name'] ??
        app['final_document_name'] ??
        'Service Document';

    if (documentUrl == null || documentUrl.toString().isEmpty) {
      showMessage(context, "No document available.", isError: true);
      return;
    }
    _showFileDialog(documentUrl.toString(), documentName);
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
    debugPrint("📄 Opening document viewer: $finalUrl");
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

  // ====================================================================
  // ✅ Documents sections
  // ====================================================================
  Widget _buildDocumentsSection(Map<String, dynamic> app) {
    final List<Map<String, dynamic>> adminDocs = <Map<String, dynamic>>[];
    for (final d in _adminDocuments) {
      final url = d['url']?.toString() ?? '';
      if (!_isValidDocUrl(url)) continue;
      if (adminDocs.any((x) => x['url'] == url)) continue;
      adminDocs.add(d);
    }

    final List<Map<String, dynamic>> userDocs = <Map<String, dynamic>>[];
    for (final d in _userDocuments) {
      final url = d['url']?.toString() ?? '';
      if (!_isValidDocUrl(url)) continue;
      if (userDocs.any((x) => x['url'] == url)) continue;
      userDocs.add(d);
    }

    final receiptUrl = app['payment_receipt_url'];
    if (_isValidDocUrl(receiptUrl)) {
      final urlStr = receiptUrl.toString().trim();
      if (!userDocs.any((d) => d['url'] == urlStr)) {
        userDocs.add({
          'key': 'payment_receipt_url',
          'label': 'Payment Receipt',
          'url': urlStr,
          'download_url': app['payment_receipt_download_url'],
          'source': 'user_application',
          'is_application_doc': true,
          'is_user_doc': true,
        });
      }
    }

    final screenshotUrl = app['screenshot_url'];
    if (_isValidDocUrl(screenshotUrl)) {
      final urlStr = screenshotUrl.toString().trim();
      if (!userDocs.any((d) => d['url'] == urlStr)) {
        userDocs.add({
          'key': 'screenshot_url',
          'label': 'Payment Screenshot',
          'url': urlStr,
          'source': 'user_application',
          'is_application_doc': true,
          'is_user_doc': true,
        });
      }
    }

    final docUrl = app['document_url'];
    if (_isValidDocUrl(docUrl)) {
      final urlStr = docUrl.toString().trim();
      if (!userDocs.any((d) => d['url'] == urlStr)) {
        userDocs.add({
          'key': 'document_url',
          'label': 'Uploaded Document',
          'url': urlStr,
          'source': 'user_application',
          'is_application_doc': true,
          'is_user_doc': true,
        });
      }
    }

    if (adminDocs.isEmpty && userDocs.isEmpty && !_isLoadingServiceDocs) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAdminDocumentsCard(adminDocs),
        const SizedBox(height: 16),
        _buildUserDocumentsCard(userDocs),
      ],
    );
  }

  Widget _buildAdminDocumentsCard(List<Map<String, dynamic>> adminDocs) {
    final int count = adminDocs.length;

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
                    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
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
                      "Admin Uploaded Documents",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Uploaded via Review / Final Submit",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$count ${count == 1 ? 'File' : 'Files'}",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
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
          else if (count == 0)
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
                    "No admin documents uploaded yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Documents uploaded via Review or Final Submit will appear here",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: adminDocs
                  .asMap()
                  .entries
                  .map((e) => _buildAdminDocumentRow(e.key, e.value))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildUserDocumentsCard(List<Map<String, dynamic>> userDocs) {
    final int count = userDocs.length;

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
                    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "User Uploaded Documents",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Uploaded by user for this application",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$count ${count == 1 ? 'File' : 'Files'}",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
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
          else if (count == 0)
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
                    "No user documents uploaded yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Documents uploaded by the user will appear here",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: userDocs
                  .asMap()
                  .entries
                  .map((e) => _buildUserDocumentRow(e.key, e.value))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminDocumentRow(int index, Map<String, dynamic> doc) {
    final String label =
        doc['label']?.toString() ?? 'Admin Document ${index + 1}';
    final String url = doc['url']?.toString() ?? '';
    final String? downloadUrl = doc['download_url']?.toString();
    final String source = doc['source']?.toString() ?? '';
    final dynamic uploadedAt = doc['uploaded_at'];

    final icon = _iconForUrl(url);
    final color = _colorForUrl(url);
    final fileType = _fileTypeForUrl(url);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
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
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "ADMIN",
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                    if (source.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        "• $source",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (uploadedAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    "At: $uploadedAt",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.visibility, color: Colors.purple),
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

  Widget _buildUserDocumentRow(int index, Map<String, dynamic> doc) {
    final String label = doc['label']?.toString() ?? 'Document ${index + 1}';
    final String url = doc['url']?.toString() ?? '';
    final String? downloadUrl = doc['download_url']?.toString();
    final bool isAppDoc = doc['is_application_doc'] == true;
    final String source = doc['source']?.toString() ?? '';

    final icon = _iconForUrl(url);
    final color = _colorForUrl(url);
    final fileType = _fileTypeForUrl(url);

    String badgeLabel = "USER";
    Color badgeColor = Colors.green;
    if (source == 'service_application') {
      badgeLabel = "UPLOADED";
      badgeColor = Colors.green;
    } else if (source == 'user_application') {
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

  IconData _iconForUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.pdf') || u.contains('/raw/')) return Icons.picture_as_pdf;
    if (u.contains('.jpg') ||
        u.contains('.jpeg') ||
        u.contains('.png') ||
        u.contains('.webp') ||
        u.contains('.gif') ||
        u.contains('/image/')) return Icons.image;
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
        u.contains('/image/')) return Colors.blue;
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

  // ==================== STATUS HELPERS ====================
  static const Map<String, Color> _statusColors = {
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
  };

  static const Map<String, String> _statusLabels = {
    'payment_pending': 'PAYMENT PENDING',
    'pending_verification': 'PENDING VERIFICATION',
    'under_review': 'UNDER REVIEW',
    'review_application': 'UNDER REVIEW',
    'approved': 'APPROVED',
    'rejected': 'REJECTED',
    'completed': 'COMPLETED',
    'submitted': 'SUBMITTED',
    'update_application': 'UPDATE SUBMITTED',
    'final_submit': 'FINAL SUBMITTED',
    'confirmed_application': 'CONFIRMED',
  };

  static const Map<String, IconData> _statusIcons = {
    'payment_pending': Icons.payment,
    'pending_verification': Icons.hourglass_empty,
    'under_review': Icons.rate_review,
    'review_application': Icons.rate_review,
    'approved': Icons.verified,
    'rejected': Icons.cancel,
    'completed': Icons.celebration,
    'submitted': Icons.check_circle,
    'update_application': Icons.edit_note,
    'final_submit': Icons.send_and_archive,
    'confirmed_application': Icons.check_circle_outline,
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
      case 'payment_pending': return 'Waiting for user to complete payment';
      case 'pending_verification':
        return 'Payment receipt submitted, waiting for verification';
      case 'under_review':
      case 'review_application': return 'Application is being reviewed by admin';
      case 'approved': return 'Payment verified and application approved';
      case 'rejected': return 'Payment verification failed';
      case 'completed': return 'Application completed successfully';
      case 'confirmed_application': return 'User has confirmed the application';
      default: return 'Status updated';
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
                  "AI is loading service applications...",
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
            child: const Icon(Icons.admin_panel_settings,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Service Applications",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_filteredApplications.length} applications • Admin view",
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
              "No service applications",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Applications submitted by users will appear here",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

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
    final paymentStatus = app['payment_status'] ?? 'pending';
    final amount = app['amount'] ?? app['payment_amount'];
    final hasScreenshot = _isValidDocUrl(app['screenshot_url']);
    final hasDocument = _isValidDocUrl(app['document_url']);

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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                      Icons.calendar_today, "Applied", appliedDate, Colors.blue),
                  if (amount != null)
                    _buildInfoChip(Icons.currency_rupee, "Fee", "₹$amount",
                        Colors.green),
                  _buildInfoChip(Icons.payment, "Payment",
                      paymentStatus.toUpperCase(),
                      _getPaymentStatusColor(paymentStatus)),
                  if (hasScreenshot)
                    _buildInfoChip(Icons.image, "Screenshot", "Uploaded",
                        Colors.orange),
                  if (hasDocument)
                    _buildInfoChip(Icons.upload_file, "Doc", "Uploaded",
                        Colors.teal),
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

  // ==================== APPLICATION DETAIL VIEW ====================
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
    final hasDocument = _isValidDocUrl(app['document_url']);
    final hasScreenshot = _isValidDocUrl(app['screenshot_url']);
    final fields = app['fields'] as Map<String, dynamic>? ?? {};

    final hasSubmittedDocument = _isValidDocUrl(app['submitted_document_url']);
    final hasFinalDocument = _isValidDocUrl(app['final_document_url']);
    final hasAnyDocument = hasSubmittedDocument || hasFinalDocument;

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
                      _buildStatusCard(app['_id'], status, statusColor),
                      const SizedBox(height: 16),
                      _buildUserCard(userName, userEmail, appliedDate),
                      const SizedBox(height: 16),
                      _buildServiceCard(
                          serviceName, subServiceName, serviceIcon, app),
                      const SizedBox(height: 16),
                      _buildFieldsCard(fields),
                      if (fields.isNotEmpty) const SizedBox(height: 16),
                      _buildPaymentVerificationSection(
                        app['payment_id'],
                        app['transaction_id'],
                        app['transaction_date'],
                        app['payment_receipt_url'] ?? app['screenshot_url'],
                        app['payment_amount'] ?? app['amount'],
                        app['payment_category_used'],
                        status,
                        app['_id'],
                      ),
                      if (hasScreenshot) ...[
                        _buildScreenshotCard(app['screenshot_url']),
                        const SizedBox(height: 16),
                      ],
                      if (hasDocument) ...[
                        _buildDocumentCard(app['document_url']),
                        const SizedBox(height: 16),
                      ],
                      if (hasAnyDocument) ...[
                        _buildViewAcknowledgmentReceiptButton(),
                        const SizedBox(height: 16),
                      ],
                      _buildDocumentsSection(app),
                      const SizedBox(height: 16),
                      _buildQuickActionButtons(app['_id'], status),
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

  Widget _buildStatusCard(String appId, String status, Color statusColor) {
    final bool isFinal = status == 'rejected' || status == 'completed';

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
                child: Icon(
                  isFinal
                      ? (status == 'completed'
                          ? Icons.check_circle
                          : Icons.cancel)
                      : _getStatusIcon(status),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFinal ? "Payment Status" : "Application Status",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
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
                        fontSize: 11.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isFinal) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status == 'completed'
                          ? "✅ Application completed. No further action needed."
                          : "❌ Payment rejected. User may need to re-apply.",
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isFinal) ...[
            const SizedBox(height: 16),
            if (status == 'pending_verification')
              _buildPaymentVerificationButtons(appId),
            if (status != 'payment_pending')
              _buildReviewActionButtons(appId),
            if (status == 'payment_pending') _buildPaymentPendingInfo(),
          ],
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

  Widget _buildPaymentVerificationButtons(String appId) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Verify Payment:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUpdatingStatus
                    ? null
                    : () => _approvePayment(
                        _selectedApplication!['payment_id'], appId),
                icon: const Icon(Icons.check, size: 18),
                label: const Text("Approve",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUpdatingStatus
                    ? null
                    : () => _rejectPayment(
                        _selectedApplication!['payment_id'], appId),
                icon: const Icon(Icons.close, size: 18),
                label: const Text("Reject",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "✅ Approve: Status → APPROVED\n❌ Reject: Status → REJECTED",
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewActionButtons(String appId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Next Steps:",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed:
                    _isUpdatingStatus ? null : () => _showReviewDialog(appId),
                icon: const Icon(Icons.rate_review, size: 18),
                label: const Text("Review",
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 3,
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _isUpdatingStatus
                    ? null
                    : () => _showFinalSubmitDialog(appId),
                icon: const Icon(Icons.send_and_archive, size: 18),
                label: const Text("Final Submit",
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "📝 REVIEW: Upload doc & move to UNDER REVIEW\n"
                  "✅ FINAL SUBMIT: Complete the application",
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentPendingInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "⏳ Waiting for user to complete payment.",
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildServiceCard(String serviceName, String subServiceName,
      String serviceIcon, Map<String, dynamic> app) {
    final amount = app['amount'];

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
          _buildInfoRow(Icons.category, "Payment Type", "Service Fee",
              color: Colors.teal),
        ],
      ),
    );
  }

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

    if (keyLower == 'documents' ||
        keyLower == 'document' ||
        keyLower.endsWith('_documents') ||
        keyLower.endsWith('_document') ||
        keyLower.contains('uploaded_documents')) {
      return true;
    }

    if (value is Map) {
      for (final v in value.values) {
        final s = v?.toString() ?? '';
        if (s.contains('http://') || s.contains('https://')) return true;
      }
    }

    final str = value.toString();
    if (str.contains('http://') || str.contains('https://')) {
      if (str.contains('cloudinary') ||
          str.contains('/documents/') ||
          str.contains('/uploads/') ||
          str.contains('/raw/upload/') ||
          str.contains('/image/upload/') ||
          str.contains('/auto/upload/')) {
        if (str.contains(': ') && (str.contains('{') || str.contains(', '))) {
          return true;
        }
      }
    }

    return false;
  }

  Widget _buildPaymentVerificationSection(
    String? paymentId,
    String? transactionId,
    String? transactionDate,
    String? paymentReceiptUrl,
    int? paymentAmount,
    String? paymentCategory,
    String status,
    String applicationId,
  ) {
    if (status != 'pending_verification') return const SizedBox();

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
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Pending Payment Verification",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (transactionId != null)
            _buildInfoRow(Icons.receipt, "Transaction ID", transactionId),
          if (transactionDate != null)
            _buildInfoRow(Icons.calendar_today, "Transaction Date",
                _formatDate(transactionDate)),
          if (paymentAmount != null)
            _buildInfoRow(Icons.currency_rupee, "Amount", "₹$paymentAmount",
                color: Colors.green),
          if (paymentCategory != null)
            _buildInfoRow(Icons.category, "Payment Type", "Service Fee"),
          const SizedBox(height: 14),
          if (paymentReceiptUrl != null && paymentReceiptUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showPaymentReceiptDialog(paymentReceiptUrl),
                    icon: const Icon(Icons.receipt, size: 18),
                    label: const Text(
                      "View Payment Receipt",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isUpdatingStatus
                          ? null
                          : () => _approvePayment(paymentId!, applicationId),
                      icon: _isUpdatingStatus
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text(
                        "Approve",
                        style: TextStyle(fontWeight: FontWeight.bold),
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
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _rejectPayment(paymentId!, applicationId),
                    icon: _isUpdatingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close, size: 18),
                    label: const Text(
                      "Reject",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshotCard(String? screenshotUrl) {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Payment Screenshot", Icons.image),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.image,
                    color: Colors.orange.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Screenshot uploaded for verification",
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _viewDocument(screenshotUrl!, "Payment Screenshot"),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text("View",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(String? documentUrl) {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Uploaded Document", Icons.upload_file),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.upload_file,
                    color: Colors.teal.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Document uploaded with application",
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _viewDocument(documentUrl!, "Document"),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text("View",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewAcknowledgmentReceiptButton() {
    final app = _selectedApplication!;
    final documentName = app['submitted_document_name'] ??
        app['final_document_name'] ??
        'Service Document';

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
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Acknowledgment Receipt",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.description,
                    size: 16, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    documentName,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.indigo,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _viewAcknowledgmentReceipt,
                icon: const Icon(Icons.visibility, size: 20),
                label: const Text(
                  "View Receipt Document",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(String appId, String currentStatus) {
    final bool showButtons =
        currentStatus != 'rejected' && currentStatus != 'completed';
    if (!showButtons) return const SizedBox();

    if (currentStatus == 'payment_pending') {
      return _buildGlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Status Information", Icons.info_outline),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.purple, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "PAYMENT PENDING",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "⏳ Waiting for user to complete payment",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
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
      );
    }

    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Quick Actions", Icons.touch_app),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8B7FFF)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _showReviewDialog(appId),
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const Text(
                      "Review",
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _showFinalSubmitDialog(appId),
                    icon: const Icon(Icons.send_and_archive, size: 18),
                    label: const Text(
                      "Final Submit",
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
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
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "📝 REVIEW: Upload document and change to UNDER REVIEW\n"
                    "✅ FINAL SUBMIT: Complete the application",
                    style:
                        TextStyle(fontSize: 11, color: Colors.blue, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

// ============================================================================
// ✅ REVIEW DIALOG CONTENT — FIXED for WEB + MOBILE
// ============================================================================
class _ReviewDialogContent extends StatefulWidget {
  final TextEditingController notesController;

  const _ReviewDialogContent({
    required this.notesController,
  });

  @override
  State<_ReviewDialogContent> createState() => _ReviewDialogContentState();
}

class _ReviewDialogContentState extends State<_ReviewDialogContent> {
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  bool _isPicking = false;

  // ====================================================================
  // ✅ SAFE FILE PICKER — WORKS ON WEB + MOBILE
  // ====================================================================
  Future<void> _pickFile() async {
    debugPrint("=" * 70);
    debugPrint("📁 REVIEW _pickFile called");
    debugPrint("   Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}");
    debugPrint("   _isPicking: $_isPicking");
    debugPrint("=" * 70);

    if (_isPicking) return;

    setState(() => _isPicking = true);

    try {
      debugPrint("📁 Calling FilePicker.platform.pickFiles...");

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // ✅ REQUIRED for web
      );

      debugPrint("📁 FilePicker returned: ${result?.files.length ?? 0} files");

      if (result == null || result.files.isEmpty) {
        debugPrint("⚠️ No file selected");
        if (mounted) setState(() => _isPicking = false);
        return;
      }

      final file = result.files.first;

      debugPrint("=" * 60);
      debugPrint("📁 REVIEW FILE PICKED");
      debugPrint("   Name: ${file.name}");
      debugPrint("   Size: ${file.size} bytes");
      debugPrint("   Bytes available: ${file.bytes != null}");
      debugPrint("   Path: ${kIsWeb ? '(web - not available)' : file.path}");
      debugPrint("   Extension: ${file.extension}");
      debugPrint("=" * 60);

      Uint8List? bytes = file.bytes;

      // ✅ MOBILE FALLBACK: read from path if bytes null
      // NEVER access .path on web (throws UnimplementedError)
      if ((bytes == null || bytes.isEmpty) && !kIsWeb) {
        if (file.path != null && file.path!.isNotEmpty) {
          try {
            final f = File(file.path!);
            if (await f.exists()) {
              bytes = await f.readAsBytes();
              debugPrint("📱 MOBILE: Read ${bytes.length} bytes from path");
            }
          } catch (e) {
            debugPrint("❌ MOBILE: Failed to read from path: $e");
          }
        }
      }

      // ✅ WEB FALLBACK: if bytes still null
      if (bytes == null || bytes.isEmpty) {
        debugPrint("❌ No file bytes available");
        if (mounted) {
          showMessage(
            context,
            kIsWeb
                ? "Could not read file. Please try a different browser or file."
                : "Could not read file. Please try again.",
            isError: true,
          );
          setState(() => _isPicking = false);
        }
        return;
      }

      // ✅ File size check (10 MB max)
      const maxSize = 10 * 1024 * 1024;
      if (bytes.length > maxSize) {
        if (mounted) {
          showMessage(
            context,
            "File too large. Max: 10MB, Your file: ${(bytes.length / (1024 * 1024)).toStringAsFixed(1)}MB",
            isError: true,
          );
          setState(() => _isPicking = false);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = bytes;
          _isPicking = false;
        });
        debugPrint("✅ REVIEW file ready: ${file.name} (${bytes.length} bytes)");
      }
    } catch (e) {
      debugPrint("❌ REVIEW _pickFile error: $e");
      if (mounted) {
        showMessage(context, "Error picking file: $e", isError: true);
        setState(() => _isPicking = false);
      }
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFileName = null;
      _selectedFileBytes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.9 > 500 ? 500.0 : screenWidth * 0.9;
    final bool canSubmit =
        _selectedFileName != null && _selectedFileBytes != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20),
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== HEADER ====================
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.rate_review,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    "Review Application",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ],
            ),
            const Divider(height: 24),

            // ==================== INFO BANNER ====================
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
                      "This will change status to REVIEW. Document is required.",
                      style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF6C63FF).withOpacity(0.9)),
                    ),
                  ),
                ],
              ),
            ),

            // ==================== SCROLLABLE CONTENT ====================
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "📄 Upload Document (PDF or Image) *",
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Upload relevant document for review. (Required)",
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),

                    // ==================== FILE PICKER UI ====================
                    GestureDetector(
                      onTap: _isPicking ? null : _pickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedFileName != null
                              ? Colors.green.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedFileName != null
                                ? Colors.green
                                : Colors.blue,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (_isPicking)
                              const CircularProgressIndicator()
                            else
                              Icon(
                                _selectedFileName != null
                                    ? Icons.check_circle
                                    : Icons.cloud_upload,
                                size: 44,
                                color: _selectedFileName != null
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            const SizedBox(height: 12),
                            Text(
                              _isPicking
                                  ? "Loading file..."
                                  : (_selectedFileName ??
                                      "Tap to select document"),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedFileName != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedFileName != null
                                    ? Colors.green.shade700
                                    : Colors.blue.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_selectedFileName != null &&
                                _selectedFileBytes != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                "${(_selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _clearFile,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.red.shade200),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.close,
                                          size: 12, color: Colors.red),
                                      SizedBox(width: 4),
                                      Text(
                                        "Remove",
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==================== NOTES ====================
                    const Text(
                      "Review Notes (Optional)",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: widget.notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Add review comments or notes...",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ==================== ACTION BUTTONS ====================
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
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
                      gradient: LinearGradient(
                        colors: canSubmit
                            ? [const Color(0xFF6C63FF), const Color(0xFF8B7FFF)]
                            : [Colors.grey.shade300, Colors.grey.shade400],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: canSubmit
                          ? [
                              BoxShadow(
                                color: const Color(0xFF6C63FF)
                                    .withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: ElevatedButton(
                      onPressed: canSubmit
                          ? () {
                              debugPrint("=" * 60);
                              debugPrint("📤 REVIEW SUBMITTING");
                              debugPrint("   File: $_selectedFileName");
                              debugPrint(
                                  "   Bytes: ${_selectedFileBytes!.length}");
                              debugPrint(
                                  "   Notes: ${widget.notesController.text}");
                              debugPrint("=" * 60);

                              Navigator.pop(context, {
                                'hasFile': true,
                                'fileBytes': _selectedFileBytes,
                                'fileName': _selectedFileName,
                                'notes': widget.notesController.text,
                              });
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rate_review, size: 18),
                          SizedBox(width: 8),
                          Text("Submit Review",
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

// ============================================================================
// ✅ FINAL SUBMIT DIALOG CONTENT — FIXED for WEB + MOBILE
// ============================================================================
class _FinalSubmitDialogContent extends StatefulWidget {
  final TextEditingController notesController;

  const _FinalSubmitDialogContent({
    required this.notesController,
  });

  @override
  State<_FinalSubmitDialogContent> createState() =>
      _FinalSubmitDialogContentState();
}

class _FinalSubmitDialogContentState extends State<_FinalSubmitDialogContent> {
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  bool _isPicking = false;

  // ====================================================================
  // ✅ SAFE FILE PICKER — WORKS ON WEB + MOBILE
  // ====================================================================
  Future<void> _pickFile() async {
    debugPrint("=" * 70);
    debugPrint("📁 FINAL SUBMIT _pickFile called");
    debugPrint("   Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}");
    debugPrint("   _isPicking: $_isPicking");
    debugPrint("=" * 70);

    if (_isPicking) return;

    setState(() => _isPicking = true);

    try {
      debugPrint("📁 Calling FilePicker.platform.pickFiles...");

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // ✅ REQUIRED for web
      );

      debugPrint("📁 FilePicker returned: ${result?.files.length ?? 0} files");

      if (result == null || result.files.isEmpty) {
        debugPrint("⚠️ No file selected");
        if (mounted) setState(() => _isPicking = false);
        return;
      }

      final file = result.files.first;

      debugPrint("=" * 60);
      debugPrint("📁 FINAL SUBMIT FILE PICKED");
      debugPrint("   Name: ${file.name}");
      debugPrint("   Size: ${file.size} bytes");
      debugPrint("   Bytes available: ${file.bytes != null}");
      debugPrint("   Path: ${kIsWeb ? '(web - not available)' : file.path}");
      debugPrint("   Extension: ${file.extension}");
      debugPrint("=" * 60);

      Uint8List? bytes = file.bytes;

      // ✅ MOBILE FALLBACK: read from path if bytes null
      if ((bytes == null || bytes.isEmpty) && !kIsWeb) {
        if (file.path != null && file.path!.isNotEmpty) {
          try {
            final f = File(file.path!);
            if (await f.exists()) {
              bytes = await f.readAsBytes();
              debugPrint("📱 MOBILE: Read ${bytes.length} bytes from path");
            }
          } catch (e) {
            debugPrint("❌ MOBILE: Failed to read from path: $e");
          }
        }
      }

      // ✅ WEB FALLBACK: if bytes still null
      if (bytes == null || bytes.isEmpty) {
        debugPrint("❌ No file bytes available");
        if (mounted) {
          showMessage(
            context,
            kIsWeb
                ? "Could not read file. Please try a different browser or file."
                : "Could not read file. Please try again.",
            isError: true,
          );
          setState(() => _isPicking = false);
        }
        return;
      }

      // ✅ File size check (10 MB max)
      const maxSize = 10 * 1024 * 1024;
      if (bytes.length > maxSize) {
        if (mounted) {
          showMessage(
            context,
            "File too large. Max: 10MB, Your file: ${(bytes.length / (1024 * 1024)).toStringAsFixed(1)}MB",
            isError: true,
          );
          setState(() => _isPicking = false);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = bytes;
          _isPicking = false;
        });
        debugPrint(
            "✅ FINAL SUBMIT file ready: ${file.name} (${bytes.length} bytes)");
      }
    } catch (e) {
      debugPrint("❌ FINAL SUBMIT _pickFile error: $e");
      if (mounted) {
        showMessage(context, "Error picking file: $e", isError: true);
        setState(() => _isPicking = false);
      }
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFileName = null;
      _selectedFileBytes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.9 > 500 ? 500.0 : screenWidth * 0.9;
    final bool canSubmit =
        _selectedFileName != null && _selectedFileBytes != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20),
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== HEADER ====================
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.send_and_archive,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    "Final Submission",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ],
            ),
            const Divider(height: 24),

            // ==================== WARNING BANNER ====================
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "⚠️ Final step. Status will change to COMPLETED. Document is required.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================== SCROLLABLE CONTENT ====================
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "📄 Upload Final Document (PDF or Image) *",
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "This document will be stored securely. (Required)",
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),

                    // ==================== FILE PICKER UI ====================
                    GestureDetector(
                      onTap: _isPicking ? null : _pickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedFileName != null
                              ? Colors.deepPurple.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedFileName != null
                                ? Colors.deepPurple
                                : Colors.blue,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (_isPicking)
                              const CircularProgressIndicator()
                            else
                              Icon(
                                _selectedFileName != null
                                    ? Icons.check_circle
                                    : Icons.cloud_upload,
                                size: 44,
                                color: _selectedFileName != null
                                    ? Colors.deepPurple
                                    : Colors.blue,
                              ),
                            const SizedBox(height: 12),
                            Text(
                              _isPicking
                                  ? "Loading file..."
                                  : (_selectedFileName ??
                                      "Tap to select final document"),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedFileName != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedFileName != null
                                    ? Colors.deepPurple
                                    : Colors.blue.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_selectedFileName != null &&
                                _selectedFileBytes != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                "${(_selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _clearFile,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.red.shade200),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.close,
                                          size: 12, color: Colors.red),
                                      SizedBox(width: 4),
                                      Text(
                                        "Remove",
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==================== NOTES ====================
                    const Text(
                      "Additional Notes (Optional)",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: widget.notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Add any final remarks or notes...",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ==================== ACTION BUTTONS ====================
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
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
                      gradient: LinearGradient(
                        colors: canSubmit
                            ? [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)]
                            : [Colors.grey.shade300, Colors.grey.shade400],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: canSubmit
                          ? [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: ElevatedButton(
                      onPressed: canSubmit
                          ? () {
                              debugPrint("=" * 60);
                              debugPrint("📤 FINAL SUBMIT SUBMITTING");
                              debugPrint("   File: $_selectedFileName");
                              debugPrint(
                                  "   Bytes: ${_selectedFileBytes!.length}");
                              debugPrint(
                                  "   Notes: ${widget.notesController.text}");
                              debugPrint("=" * 60);

                              Navigator.pop(context, {
                                'hasFile': true,
                                'fileBytes': _selectedFileBytes,
                                'fileName': _selectedFileName,
                                'notes': widget.notesController.text,
                              });
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_and_archive, size: 18),
                          SizedBox(width: 8),
                          Text("Confirm Final Submit",
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