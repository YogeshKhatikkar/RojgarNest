// lib/features/schemes/presentation/screens/customadmin_scheme_applications_screen.dart
// ============================================================
// CUSTOM ADMIN SCHEME APPLICATIONS SCREEN
// ============================================================
// ✅ Displays all scheme applications submitted by users
// ✅ Admin can view, approve, reject, and manage scheme applications
// ✅ Uses the same UI pattern as Job/Service applications
// ✅ Full detail view with documents, status updates
// ✅ Works in both embedded and full-screen modes
// ============================================================
// ✅ FIXED: Added missing imports (dart:typed_data, dart:io)
// ✅ FIXED: Documents now properly fetched from backend
// ✅ FIXED: User documents and Admin documents now show separately
// ✅ FIXED: Review and Final Submit buttons now work EXACTLY like
//           Service Application Screen and Job Application Screen
// ✅ FIXED: Document upload now works on BOTH Web and Mobile
// ✅ FIXED: File is now MANDATORY before submit
// ✅ FIXED: Status update now correctly changes to review/final_submit
// ✅ FIXED: Action buttons now shown for ALL non-final statuses
// ✅ FIXED: Quick Actions now show ONLY Review and Final Submit buttons
//           (matching Service Application Screen layout exactly)
// ✅ FIXED (NEW): After Review/Final Submit, the UI updates INSTANTLY
//           with the new status and new admin document, WITHOUT waiting
//           for any network refresh or page reload.
// ✅ FIXED (NEW): _selectedApplication and _applications are patched
//           locally with the server's response before any re-fetch.
// ✅ FIXED (NEW): New admin document is prepended to _adminDocuments
//           immediately so the "Admin Uploaded Documents" card shows it.
// ✅ FIXED (NEW): Universal ID matcher handles _id / application_id /
//           application_number so patching never misses.
// ============================================================

import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/core/widgets/file_viewer_screen.dart';
import 'package:rojgarnest/features/schemes/data/scheme_service.dart';

// ============================================================
// MAIN SCREEN
// ============================================================

class CustomAdminSchemeApplicationsScreen extends StatefulWidget {
  const CustomAdminSchemeApplicationsScreen({super.key});

  @override
  State<CustomAdminSchemeApplicationsScreen> createState() =>
      _CustomAdminSchemeApplicationsScreenState();
}

class _CustomAdminSchemeApplicationsScreenState
    extends State<CustomAdminSchemeApplicationsScreen>
    with SingleTickerProviderStateMixin {
  // ==================== STATE ====================
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _filteredApplications = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isUpdatingStatus = false;
  String? _errorMessage;
  String _selectedFilter = 'all';

  // ==================== SELECTED APPLICATION FOR DETAIL VIEW ====================
  Map<String, dynamic>? _selectedApplication;

  // ✅ TWO SEPARATE DOCUMENT LISTS (like jobs/services)
  List<Map<String, dynamic>> _userDocuments = [];
  List<Map<String, dynamic>> _adminDocuments = [];
  bool _isLoadingDocuments = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ============================================================
  // FILTER BUTTONS
  // ============================================================
  final List<Map<String, dynamic>> _filterButtons = [
    {
      'value': 'all',
      'label': 'All',
      'icon': Icons.list,
      'color': Colors.grey,
    },
    {
      'value': 'pending',
      'label': 'Pending',
      'icon': Icons.hourglass_empty,
      'color': Colors.orange,
    },
    {
      'value': 'under_review',
      'label': 'Review',
      'icon': Icons.rate_review,
      'color': Colors.blue,
    },
    {
      'value': 'approved',
      'label': 'Approved',
      'icon': Icons.verified,
      'color': Colors.teal,
    },
    {
      'value': 'rejected',
      'label': 'Rejected',
      'icon': Icons.cancel,
      'color': Colors.red,
    },
    {
      'value': 'completed',
      'label': 'Completed',
      'icon': Icons.celebration,
      'color': Colors.green,
    },
  ];

  // ============================================================
  // LIFECYCLE
  // ============================================================
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
    _loadApplications();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD APPLICATIONS
  // ============================================================
  Future<void> _loadApplications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint("=" * 70);
      debugPrint("📤 LOADING SCHEME APPLICATIONS (CustomAdmin)");
      debugPrint("   URL: /customadmin/applications");
      debugPrint("   Query: application_type=schemes");
      debugPrint("=" * 70);

      final response = await DioClient.dio.get(
        '/customadmin/applications',
        queryParameters: {
          'application_type': 'schemes',
        },
      );

      if (!mounted) return;

      debugPrint("📥 Response status: ${response.statusCode}");
      debugPrint("📥 Response data type: ${response.data.runtimeType}");

      List<dynamic> apps = [];

      if (response.data is Map) {
        final data = response.data as Map;
        if (data.containsKey('applications') && data['applications'] is List) {
          apps = data['applications'] as List<dynamic>;
        } else if (data.containsKey('data')) {
          final inner = data['data'];
          if (inner is List) {
            apps = inner;
          } else if (inner is Map &&
              inner.containsKey('applications') &&
              inner['applications'] is List) {
            apps = inner['applications'] as List<dynamic>;
          }
        }
      } else if (response.data is List) {
        apps = response.data as List;
      }

      debugPrint("✅ Loaded ${apps.length} scheme applications");

      final enrichedApps = apps.map((app) {
        final appMap = app is Map<String, dynamic>
            ? app
            : Map<String, dynamic>.from(app as Map);
        return _enrichApplication(appMap);
      }).toList();

      if (!mounted) return;
      setState(() {
        _applications = enrichedApps;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
      _applyFilter();
    } catch (e) {
      debugPrint("❌ Failed to load scheme applications: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = e.toString();
          _applications = [];
          _filteredApplications = [];
        });
      }
    }
  }

  // ============================================================
  // ENRICH APPLICATION WITH DISPLAY DATA
  // ============================================================
  Map<String, dynamic> _enrichApplication(Map<String, dynamic> app) {
    final schemeName = app['scheme_name']?.toString() ?? 'Government Scheme';
    final schemeNameHindi =
        app['scheme_name_hindi']?.toString().isNotEmpty == true
            ? app['scheme_name_hindi'].toString()
            : schemeName;
    final schemeLevel = app['scheme_level']?.toString() ?? 'central';
    final schemeState = app['scheme_state']?.toString();
    final schemeCategory = app['scheme_category']?.toString() ?? 'other';

    final applicationNumber =
        app['application_number']?.toString().isNotEmpty == true
            ? app['application_number'].toString()
            : (app['application_id']?.toString().isNotEmpty == true
                ? app['application_id'].toString()
                : (app['_id']?.toString() ?? ''));

    final applicantDetails = app['applicant_details'] is Map
        ? Map<String, dynamic>.from(app['applicant_details'] as Map)
        : <String, dynamic>{};
    final applicantName = app['user_name']?.toString().isNotEmpty == true
        ? app['user_name'].toString()
        : (applicantDetails['full_name']?.toString() ?? 'Unknown');
    final applicantEmail = app['user_email']?.toString() ?? 'N/A';
    final applicantMobile = app['user_mobile']?.toString() ??
        (applicantDetails['mobile']?.toString() ?? '');

    String icon = '📋';
    switch (schemeCategory.toLowerCase()) {
      case 'agriculture':
        icon = '🌾';
        break;
      case 'health':
        icon = '🏥';
        break;
      case 'housing':
        icon = '🏠';
        break;
      case 'education':
        icon = '📚';
        break;
      case 'employment':
        icon = '💼';
        break;
      case 'women_child':
        icon = '👩';
        break;
      case 'pension':
        icon = '👴';
        break;
      case 'insurance':
        icon = '🛡️';
        break;
      case 'entrepreneurship':
        icon = '🚀';
        break;
      case 'financial_inclusion':
        icon = '💰';
        break;
      default:
        icon = '📋';
    }

    return {
      ...app,
      'application_id': applicationNumber,
      'application_number': applicationNumber,
      'applicant_name': applicantName,
      'applicant_email': applicantEmail,
      'applicant_mobile': applicantMobile,
      'display_scheme_name': schemeName,
      'display_scheme_name_hindi': schemeNameHindi,
      'display_scheme_icon': icon,
      'display_scheme_level': schemeLevel == 'central' ? 'Central' : 'State',
      'display_scheme_state': schemeState,
      'display_scheme_category': schemeCategory,
    };
  }

  // ============================================================
  // APPLY FILTER
  // ============================================================
  void _applyFilter() {
    List<Map<String, dynamic>> result;

    if (_selectedFilter == 'all') {
      result = List.from(_applications);
    } else {
      result = _applications.where((app) {
        final status = (app['status'] ?? '').toString().toLowerCase();
        final filterLower = _selectedFilter.toLowerCase();

        if (filterLower == 'under_review') {
          return status == 'under_review' ||
              status == 'review_application' ||
              status == 'pending_verification';
        }
        if (filterLower == 'approved') {
          return status == 'approved' ||
              status == 'approved_application' ||
              status == 'verification_successful' ||
              status == 'payment_verified';
        }
        if (filterLower == 'pending') {
          return status == 'pending' ||
              status == 'payment_pending' ||
              status == 'submitted';
        }
        if (filterLower == 'completed') {
          return status == 'completed' ||
              status == 'final_submitted';
        }
        return status == filterLower;
      }).toList();
    }

    if (mounted) {
      setState(() {
        _filteredApplications = result;
      });
    }
  }

  void _onFilterSelected(String value) {
    if (_selectedFilter == value) return;
    setState(() => _selectedFilter = value);
    _applyFilter();
  }

  // ============================================================
  // REFRESH
  // ============================================================
  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _loadApplications();
  }

  // ============================================================
  // STRICT URL VALIDATOR
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
  // ✅ UNIVERSAL ID MATCHER
  // ------------------------------------------------------------
  // Matches an application against ANY of its identifier fields:
  //   - _id          (MongoDB ObjectId string)
  //   - application_id  (normalized application number)
  //   - application_number (same value as application_id)
  // ------------------------------------------------------------
  bool _matchesApplicationId(Map<String, dynamic> app, String id) {
    if (id.isEmpty) return false;
    return app['application_id']?.toString() == id ||
        app['_id']?.toString() == id ||
        app['application_number']?.toString() == id;
  }

  // ============================================================
  // ✅ FETCH APPLICATION DOCUMENTS - CRITICAL FIX
  // ------------------------------------------------------------
  // ✅ Uses the CORRECT endpoint: /schemes/application/{id}/documents
  // ✅ This endpoint returns BOTH scheme_documents[] AND admin_documents[]
  // ✅ Falls back to the detail endpoint only if /documents fails
  // ============================================================
  Future<void> _fetchApplicationDocuments(String applicationId) async {
    if (!mounted || applicationId.isEmpty) return;

    setState(() {
      _isLoadingDocuments = true;
      _userDocuments = [];
      _adminDocuments = [];
    });

    final List<Map<String, dynamic>> userDocs = [];
    final List<Map<String, dynamic>> adminDocs = [];

    try {
      debugPrint("=" * 70);
      debugPrint("📄 FETCHING SCHEME APPLICATION DOCUMENTS");
      debugPrint("   Application ID: $applicationId");
      debugPrint("   Endpoint: /schemes/application/$applicationId/documents");
      debugPrint("=" * 70);

      // ============================================================
      // ✅ STEP 1: PRIMARY — Use the dedicated /documents endpoint
      // ============================================================
      try {
        final docsResponse = await DioClient.dio.get(
          '/schemes/application/$applicationId/documents',
        );

        if (mounted) {
          debugPrint("📥 /documents status: ${docsResponse.statusCode}");
          debugPrint("📥 /documents data: ${docsResponse.data}");

          if (docsResponse.data is Map) {
            final body = Map<String, dynamic>.from(docsResponse.data as Map);

            final rawUserDocs = body['scheme_documents'];
            final rawAdminDocs = body['admin_documents'];

            // ---------- USER DOCS ----------
            if (rawUserDocs is List) {
              debugPrint("📄 scheme_documents: ${rawUserDocs.length}");
              for (final raw in rawUserDocs) {
                if (raw is! Map) continue;
                final doc = Map<String, dynamic>.from(raw);

                final url =
                    (doc['url'] ?? doc['document_url'] ?? '').toString().trim();
                if (!_isValidDocUrl(url)) {
                  debugPrint("⏭️ Skipping user doc (invalid URL): $url");
                  continue;
                }

                userDocs.add({
                  'key': (doc['document_type'] ?? 'document').toString(),
                  'label': (doc['document_name'] ??
                          doc['label'] ??
                          doc['document_type'] ??
                          'Document')
                      .toString(),
                  'url': url,
                  'download_url': (doc['download_url'] ?? url).toString(),
                  'source': (doc['source'] ?? 'schemes_application').toString(),
                  'is_application_doc': true,
                  'is_admin_doc': false,
                  'is_user_doc': true,
                  'uploaded_at': doc['uploaded_at'],
                });
              }
            }

            // ---------- ADMIN DOCS ----------
            if (rawAdminDocs is List) {
              debugPrint("📄 admin_documents: ${rawAdminDocs.length}");
              for (final raw in rawAdminDocs) {
                if (raw is! Map) continue;
                final doc = Map<String, dynamic>.from(raw);

                final url =
                    (doc['url'] ?? doc['document_url'] ?? '').toString().trim();
                if (!_isValidDocUrl(url)) {
                  debugPrint("⏭️ Skipping admin doc (invalid URL): $url");
                  continue;
                }

                final source = (doc['source'] ?? 'admin_review').toString();
                final badge = (doc['badge'] ??
                        (source == 'admin_final'
                            ? 'ADMIN FINAL'
                            : 'ADMIN REVIEW'))
                    .toString();

                adminDocs.add({
                  'key': (doc['document_type'] ?? 'admin_doc').toString(),
                  'label': (doc['document_name'] ??
                          doc['label'] ??
                          doc['document_type'] ??
                          'Admin Document')
                      .toString(),
                  'url': url,
                  'download_url': (doc['download_url'] ?? url).toString(),
                  'source': source,
                  'is_application_doc': true,
                  'is_admin_doc': true,
                  'badge': badge,
                  'badgeColor': source == 'admin_final'
                      ? Colors.deepPurple
                      : Colors.orange,
                  'uploaded_at': doc['uploaded_at'],
                });
              }
            }

            debugPrint("✅ From /documents → "
                "userDocs=${userDocs.length}, adminDocs=${adminDocs.length}");
          }
        }
      } catch (primaryError) {
        debugPrint("⚠️ /documents endpoint failed: $primaryError");
        debugPrint("   Falling back to detail endpoint...");
      }

      // ============================================================
      // ✅ STEP 2: FALLBACK — Use /application/{id} detail endpoint
      // ============================================================
      if (userDocs.isEmpty && adminDocs.isEmpty) {
        debugPrint("=" * 70);
        debugPrint("📄 FALLBACK: Using /schemes/application/$applicationId");
        debugPrint("=" * 70);

        try {
          final response = await DioClient.dio.get(
            '/schemes/application/$applicationId',
          );

          if (mounted) {
            debugPrint("📥 Detail status: ${response.statusCode}");

            Map<String, dynamic> appData = {};
            if (response.data is Map) {
              final data = response.data as Map;

              if (data.containsKey('application') &&
                  data['application'] is Map) {
                appData =
                    Map<String, dynamic>.from(data['application'] as Map);
              } else if (data.containsKey('data') && data['data'] is Map) {
                final innerData = data['data'] as Map;
                if (innerData.containsKey('application') &&
                    innerData['application'] is Map) {
                  appData = Map<String, dynamic>.from(
                      innerData['application'] as Map);
                } else {
                  appData = Map<String, dynamic>.from(innerData);
                }
              } else {
                appData = Map<String, dynamic>.from(data);
              }
            }

            debugPrint("📄 Detail appData keys: ${appData.keys.toList()}");

            // ---------- A. scheme_documents[] (NEW format) ----------
            final schemeDocsArray = appData['scheme_documents'];
            if (schemeDocsArray is List) {
              debugPrint("📄 scheme_documents[]: ${schemeDocsArray.length}");
              for (final raw in schemeDocsArray) {
                if (raw is! Map) continue;
                final doc = Map<String, dynamic>.from(raw);
                final url = (doc['url'] ?? doc['document_url'] ?? '')
                    .toString()
                    .trim();
                if (!_isValidDocUrl(url)) continue;

                userDocs.add({
                  'key': (doc['document_type'] ?? 'document').toString(),
                  'label': (doc['document_name'] ??
                          doc['label'] ??
                          doc['document_type'] ??
                          'Document')
                      .toString(),
                  'url': url,
                  'download_url': (doc['download_url'] ?? url).toString(),
                  'source': (doc['source'] ?? 'schemes_application').toString(),
                  'is_application_doc': true,
                  'is_admin_doc': false,
                  'is_user_doc': true,
                  'uploaded_at': doc['uploaded_at'],
                });
              }
            }

            // ---------- B. documents[] (LEGACY format) ----------
            final documentsArray = appData['documents'];
            if (documentsArray is List) {
              debugPrint("📄 documents[] (legacy): ${documentsArray.length}");
              for (final raw in documentsArray) {
                if (raw is! Map) continue;
                final doc = Map<String, dynamic>.from(raw);

                final url =
                    (doc['url'] ?? doc['document_url'] ?? '').toString().trim();
                if (!_isValidDocUrl(url)) {
                  debugPrint("⏭️ Skipping legacy doc (invalid URL): $url");
                  continue;
                }

                if (userDocs.any((d) => d['url'] == url)) {
                  debugPrint("⏭️ Skipping duplicate legacy doc: $url");
                  continue;
                }

                userDocs.add({
                  'key': (doc['document_type'] ?? 'document').toString(),
                  'label': (doc['document_name'] ??
                          doc['label'] ??
                          doc['document_type'] ??
                          'Document')
                      .toString(),
                  'url': url,
                  'download_url': (doc['download_url'] ?? url).toString(),
                  'source': 'schemes_application',
                  'is_application_doc': true,
                  'is_admin_doc': false,
                  'is_user_doc': true,
                  'uploaded_at': doc['uploaded_at'],
                });
              }
            }

            // ---------- C. submitted_document_url (Admin Review) ----------
            final submittedUrl = appData['submitted_document_url'];
            if (_isValidDocUrl(submittedUrl)) {
              final urlStr = submittedUrl.toString().trim();
              if (!adminDocs.any((d) => d['url'] == urlStr)) {
                adminDocs.add({
                  'key': 'submitted_document_url',
                  'label': appData['submitted_document_name']?.toString() ??
                      'Review Document (Admin)',
                  'url': urlStr,
                  'download_url':
                      appData['submitted_document_download_url'] ?? urlStr,
                  'source': 'admin_review',
                  'is_application_doc': true,
                  'is_admin_doc': true,
                  'badge': 'ADMIN REVIEW',
                  'badgeColor': Colors.orange,
                  'uploaded_at': appData['submitted_at'],
                });
              }
            }

            // ---------- D. final_document_url (Admin Final) ----------
            final finalUrl = appData['final_document_url'];
            if (_isValidDocUrl(finalUrl)) {
              final urlStr = finalUrl.toString().trim();
              if (!adminDocs.any((d) => d['url'] == urlStr)) {
                adminDocs.add({
                  'key': 'final_document_url',
                  'label': appData['final_document_name']?.toString() ??
                      'Final Submission Document (Admin)',
                  'url': urlStr,
                  'download_url':
                      appData['final_document_download_url'] ?? urlStr,
                  'source': 'admin_final',
                  'is_application_doc': true,
                  'is_admin_doc': true,
                  'badge': 'ADMIN FINAL',
                  'badgeColor': Colors.deepPurple,
                  'uploaded_at': appData['final_submitted_at'],
                });
              }
            }
          }
        } catch (fallbackError) {
          debugPrint("⚠️ Fallback detail endpoint also failed: $fallbackError");
        }
      }

      debugPrint("=" * 70);
      debugPrint("✅ FINAL TOTALS:");
      debugPrint("   USER documents: ${userDocs.length}");
      debugPrint("   ADMIN documents: ${adminDocs.length}");
      debugPrint("=" * 70);
    } catch (e) {
      debugPrint("❌ FATAL: _fetchApplicationDocuments error: $e");
      debugPrint("   Stack: ${StackTrace.current}");
    } finally {
      if (mounted) {
        setState(() {
          _userDocuments = userDocs;
          _adminDocuments = adminDocs;
          _isLoadingDocuments = false;
        });
      }
    }
  }

  // ============================================================
  // VIEW APPLICATION DETAILS
  // ============================================================
  void _showApplicationDetails(Map<String, dynamic> app) {
    final applicationId = app['application_id']?.toString() ?? '';

    setState(() {
      _selectedApplication = app;
      _userDocuments = [];
      _adminDocuments = [];
    });

    if (applicationId.isNotEmpty) {
      _fetchApplicationDocuments(applicationId);
    }
  }

  void _closeDetails() {
    setState(() {
      _selectedApplication = null;
      _userDocuments = [];
      _adminDocuments = [];
    });
    _refresh();
  }

  // ============================================================
  // ✅ REFRESH APPLICATION DETAIL — BULLETPROOF VERSION
  // ------------------------------------------------------------
  // ✅ FIRST: extract the fresh application map
  // ✅ THEN:  patch _selectedApplication and _applications locally
  // ✅ THEN:  re-fetch documents so new admin docs appear
  // ✅ The UI is already correct BEFORE the document refetch
  // ============================================================
  Future<void> _refreshApplicationDetail(String applicationId) async {
    if (!mounted || applicationId.isEmpty) return;

    debugPrint("=" * 70);
    debugPrint("🔄 REFRESHING APPLICATION DETAIL");
    debugPrint("   Application ID: $applicationId");
    debugPrint("=" * 70);

    try {
      final response = await DioClient.dio.get(
        '/schemes/application/$applicationId',
      );

      if (!mounted) return;

      // ---------- Extract the raw application map ----------
      Map<String, dynamic> updatedApp = {};
      if (response.data is Map) {
        final data = response.data as Map;

        if (data.containsKey('application') && data['application'] is Map) {
          updatedApp = Map<String, dynamic>.from(data['application'] as Map);
        } else if (data.containsKey('data') && data['data'] is Map) {
          final innerData = data['data'] as Map;
          if (innerData.containsKey('application') &&
              innerData['application'] is Map) {
            updatedApp =
                Map<String, dynamic>.from(innerData['application'] as Map);
          } else {
            updatedApp = Map<String, dynamic>.from(innerData);
          }
        } else {
          updatedApp = Map<String, dynamic>.from(data);
        }
      }

      if (updatedApp.isEmpty) {
        debugPrint("⚠️ Empty updated app from server");
        // Still re-fetch documents so admin docs show up
        await _fetchApplicationDocuments(applicationId);
        return;
      }

      // ---------- Preserve display fields ----------
      final oldApp = _selectedApplication ?? {};
      final enrichedApp = _enrichApplication({
        ...oldApp,
        ...updatedApp,
      });

      debugPrint("✅ New status from server: ${enrichedApp['status']}");

      if (!mounted) return;

      // ============================================================
      // ✅ CRITICAL: Update local state IMMEDIATELY
      // ============================================================
      setState(() {
        // 1. Update in the main list
        final index = _applications.indexWhere(
          (app) => _matchesApplicationId(app, applicationId),
        );
        if (index != -1) {
          _applications[index] = enrichedApp;
        }

        // 2. Update the selected application — THIS is what the
        //    detail view reads on rebuild
        if (_selectedApplication != null) {
          _selectedApplication = enrichedApp;
        }

        // 3. Reset documents so loading spinner shows
        _userDocuments = [];
        _adminDocuments = [];
        _isLoadingDocuments = true;
      });

      // 4. Re-apply filter so list view is in sync
      _applyFilter();

      // 5. Re-fetch documents (new admin doc will now appear)
      await _fetchApplicationDocuments(applicationId);

      debugPrint("✅ Application detail refreshed successfully");
    } catch (e) {
      debugPrint("❌ Failed to refresh application detail: $e");
    }
  }

  // ============================================================
  // UPDATE APPLICATION STATUS (Approve / Reject)
  // ============================================================
  Future<void> _updateStatus(String applicationId, String newStatus) async {
    if (!mounted || _isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      debugPrint("📤 Updating application $applicationId to status: $newStatus");

      final response = await DioClient.dio.put(
        '/schemes/application/$applicationId/status',
        data: {
          'status': newStatus,
          'admin_notes': 'Status updated by custom admin',
        },
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        // ✅ Patch local state immediately
        if (_selectedApplication != null) {
          final patched = Map<String, dynamic>.from(_selectedApplication!)
            ..['status'] = newStatus
            ..['admin_notes'] = 'Status updated by custom admin'
            ..['updated_at'] = DateTime.now().toIso8601String();

          setState(() {
            _selectedApplication = patched;
            final index = _applications.indexWhere(
              (a) => _matchesApplicationId(a, applicationId),
            );
            if (index != -1) {
              _applications[index] = patched;
            }
          });
          _applyFilter();
        }

        showMessage(context, "✅ Status updated to ${newStatus.toUpperCase()}");
        _refreshApplicationDetail(applicationId);
      } else {
        showMessage(
          context,
          response.data['message'] ?? "Failed to update status",
          isError: true,
        );
      }
    } catch (e) {
      debugPrint("❌ Failed to update status: $e");
      if (mounted) {
        showMessage(context, "Failed to update status: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  // ============================================================
  // ✅ REVIEW WITH DOCUMENT — INSTANT UI UPDATE
  // ------------------------------------------------------------
  // After successful upload, we FIRST patch _selectedApplication
  // locally with status = 'review_application' and the new doc URL,
  // THEN trigger the server refresh in the background.
  // ============================================================
  Future<void> _showReviewDialog(String applicationId) async {
    debugPrint("=" * 70);
    debugPrint("📝 OPENING SCHEME REVIEW DIALOG");
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

    if (!hasFile || fileBytes == null || fileBytes.isEmpty || fileName == null) {
      showMessage(context, "⚠️ Please select a document for review",
          isError: true);
      return;
    }

    setState(() => _isUpdatingStatus = true);

    try {
      debugPrint("📤 Uploading review document...");
      debugPrint("   File: $fileName");
      debugPrint("   Size: ${fileBytes.length} bytes");

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'notes': notes,
      });

      final uploadResponse = await DioClient.dio.post(
        '/schemes/application/$applicationId/review-with-document',
        data: formData,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      if (!mounted) return;

      debugPrint("📥 Upload response: ${uploadResponse.statusCode}");
      debugPrint("📥 Upload response data: ${uploadResponse.data}");

      final body = uploadResponse.data is Map
          ? Map<String, dynamic>.from(uploadResponse.data as Map)
          : <String, dynamic>{};

      if (body['success'] == true) {
        // ============================================================
        // ✅ INSTANT LOCAL UPDATE — no network wait needed
        // ============================================================
        final newStatus = body['status']?.toString().isNotEmpty == true
            ? body['status'].toString()
            : 'review_application';

        final newDocUrl =
            body['submitted_document_url']?.toString().isNotEmpty == true
                ? body['submitted_document_url'].toString()
                : '';
        final newDocName =
            body['submitted_document_name']?.toString().isNotEmpty == true
                ? body['submitted_document_name'].toString()
                : fileName;

        if (_selectedApplication != null) {
          final patched = Map<String, dynamic>.from(_selectedApplication!)
            ..['status'] = newStatus
            ..['submitted_document_url'] = newDocUrl
            ..['submitted_document_name'] = newDocName
            ..['submitted_at'] = DateTime.now().toIso8601String()
            ..['admin_notes'] =
                notes.isNotEmpty ? notes : 'Review document uploaded'
            ..['updated_at'] = DateTime.now().toIso8601String();

          setState(() {
            _selectedApplication = patched;

            // Also patch main list
            final index = _applications.indexWhere(
              (a) => _matchesApplicationId(a, applicationId),
            );
            if (index != -1) {
              _applications[index] = patched;
            }

            // ✅ Add the new admin doc immediately so it shows
            // without waiting for the document refetch
            if (newDocUrl.isNotEmpty &&
                !_adminDocuments.any((d) => d['url'] == newDocUrl)) {
              _adminDocuments = [
                {
                  'key': 'submitted_document_url',
                  'label': newDocName,
                  'url': newDocUrl,
                  'download_url':
                      body['submitted_document_download_url']?.toString() ??
                          newDocUrl,
                  'source': 'admin_review',
                  'is_admin_doc': true,
                  'badge': 'ADMIN REVIEW',
                  'badgeColor': Colors.orange,
                  'uploaded_at': DateTime.now().toIso8601String(),
                },
                ..._adminDocuments,
              ];
            }
          });

          _applyFilter();

          showMessage(
            context,
            "✅ Document uploaded. Status: UNDER REVIEW",
          );

          debugPrint("✅ Local UI patched — status = $newStatus");

          // Optional: re-fetch fresh data from server (non-blocking)
          _refreshApplicationDetail(applicationId);
        } else {
          // No selected app — just refresh list
          showMessage(context, "✅ Document uploaded & moved to REVIEW!");
          await _refreshApplicationDetail(applicationId);
        }
      } else {
        showMessage(
          context,
          body['message']?.toString() ?? "Failed to upload document",
          isError: true,
        );
      }
    } catch (e) {
      debugPrint("❌ Error in review submit: $e");
      if (mounted) {
        showMessage(context, "Failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  // ============================================================
  // ✅ FINAL SUBMIT WITH DOCUMENT — INSTANT UI UPDATE
  // ------------------------------------------------------------
  // After successful upload, we FIRST patch _selectedApplication
  // locally with status = 'final_submitted' and the new doc URL,
  // THEN trigger the server refresh in the background.
  // ============================================================
  Future<void> _showFinalSubmitDialog(String applicationId) async {
    debugPrint("=" * 70);
    debugPrint("📝 OPENING SCHEME FINAL SUBMIT DIALOG");
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

    if (!hasFile || fileBytes == null || fileBytes.isEmpty || fileName == null) {
      showMessage(context, "⚠️ Please select a document for final submission",
          isError: true);
      return;
    }

    setState(() => _isUpdatingStatus = true);

    try {
      debugPrint("📤 Uploading final document...");
      debugPrint("   File: $fileName");
      debugPrint("   Size: ${fileBytes.length} bytes");

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'notes': notes,
      });

      final uploadResponse = await DioClient.dio.post(
        '/schemes/application/$applicationId/final-submit-with-document',
        data: formData,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      if (!mounted) return;

      debugPrint("📥 Upload response: ${uploadResponse.statusCode}");
      debugPrint("📥 Upload response data: ${uploadResponse.data}");

      final body = uploadResponse.data is Map
          ? Map<String, dynamic>.from(uploadResponse.data as Map)
          : <String, dynamic>{};

      if (body['success'] == true) {
        // ============================================================
        // ✅ INSTANT LOCAL UPDATE
        // ============================================================
        final newStatus = body['status']?.toString().isNotEmpty == true
            ? body['status'].toString()
            : 'final_submitted';

        final newDocUrl = body['final_document_url']?.toString().isNotEmpty ==
                true
            ? body['final_document_url'].toString()
            : (body['submitted_document_url']?.toString().isNotEmpty == true
                ? body['submitted_document_url'].toString()
                : '');

        final newDocName = body['document_name']?.toString().isNotEmpty == true
            ? body['document_name'].toString()
            : (body['submitted_document_name']?.toString().isNotEmpty == true
                ? body['submitted_document_name'].toString()
                : fileName);

        if (_selectedApplication != null) {
          final patched = Map<String, dynamic>.from(_selectedApplication!)
            ..['status'] = newStatus
            ..['final_document_url'] = newDocUrl
            ..['submitted_document_url'] = newDocUrl
            ..['submitted_document_name'] = newDocName
            ..['final_submitted_at'] = DateTime.now().toIso8601String()
            ..['admin_notes'] = notes.isNotEmpty ? notes : 'Final submission'
            ..['updated_at'] = DateTime.now().toIso8601String();

          setState(() {
            _selectedApplication = patched;

            final index = _applications.indexWhere(
              (a) => _matchesApplicationId(a, applicationId),
            );
            if (index != -1) {
              _applications[index] = patched;
            }

            // ✅ Add the new admin final doc immediately
            if (newDocUrl.isNotEmpty &&
                !_adminDocuments.any((d) => d['url'] == newDocUrl)) {
              _adminDocuments = [
                {
                  'key': 'final_document_url',
                  'label': newDocName,
                  'url': newDocUrl,
                  'download_url':
                      body['final_document_download_url']?.toString() ??
                          newDocUrl,
                  'source': 'admin_final',
                  'is_admin_doc': true,
                  'badge': 'ADMIN FINAL',
                  'badgeColor': Colors.deepPurple,
                  'uploaded_at': DateTime.now().toIso8601String(),
                },
                ..._adminDocuments,
              ];
            }
          });

          _applyFilter();

          showMessage(
            context,
            "✅ FINAL SUBMISSION completed!",
          );

          debugPrint("✅ Local UI patched — status = $newStatus");

          // Optional: re-fetch fresh data from server (non-blocking)
          _refreshApplicationDetail(applicationId);
        } else {
          showMessage(context, "✅ FINAL SUBMISSION completed!");
          await _refreshApplicationDetail(applicationId);
        }
      } else {
        showMessage(
          context,
          body['message']?.toString() ?? "Failed to upload final document",
          isError: true,
        );
      }
    } catch (e) {
      debugPrint("❌ Error in final submit: $e");
      if (mounted) {
        showMessage(context, "Failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  // ============================================================
  // DOCUMENT VIEWER
  // ============================================================
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

  // ============================================================
  // HELPER METHODS
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
      case 'payment_pending':
      case 'submitted':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _getStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'approved_application':
        return 'APPROVED';
      case 'verification_successful':
      case 'payment_verified':
        return 'VERIFIED';
      case 'completed':
      case 'final_submitted':
        return 'COMPLETED';
      case 'rejected':
      case 'verification_rejected':
      case 'update_rejected':
        return 'REJECTED';
      case 'under_review':
      case 'review_application':
        return 'UNDER REVIEW';
      case 'pending_verification':
        return 'PENDING VERIFICATION';
      case 'update_application':
        return 'UPDATE PENDING';
      case 'payment_pending':
        return 'PAYMENT PENDING';
      case 'submitted':
        return 'SUBMITTED';
      case 'pending':
      default:
        return 'PENDING';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'approved_application':
      case 'verification_successful':
      case 'payment_verified':
        return Icons.verified;
      case 'completed':
      case 'final_submitted':
        return Icons.celebration;
      case 'rejected':
      case 'verification_rejected':
      case 'update_rejected':
        return Icons.cancel;
      case 'under_review':
      case 'review_application':
        return Icons.rate_review;
      case 'pending_verification':
      case 'payment_pending':
        return Icons.hourglass_empty;
      default:
        return Icons.pending;
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
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_selectedApplication != null) {
      return _buildApplicationDetailView(_selectedApplication!);
    }

    if (_isLoading && _applications.isEmpty) {
      return _buildLoadingScreen();
    }

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
                          itemBuilder: (context, index) {
                            final app = _filteredApplications[index];
                            return _buildApplicationCard(app, index);
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

  // ============================================================
  // LOADING SCREEN
  // ============================================================
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    child: Icon(
                      Icons.account_balance,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                ).createShader(bounds),
                child: const Text(
                  "Loading Scheme Applications...",
                  style: TextStyle(
                    fontSize: 20,
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

  // ============================================================
  // GRADIENT BACKGROUND
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

  // ============================================================
  // HEADER
  // ============================================================
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
            child: const Icon(
              Icons.account_balance,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Scheme Applications",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_filteredApplications.length} applications • Custom Admin View",
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
            GestureDetector(
              onTap: _refresh,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 20,
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
                  Text(filter['label'] as String),
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

  // ============================================================
  // EMPTY STATE
  // ============================================================
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
              child: const Icon(
                Icons.account_balance_outlined,
                size: 60,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "No scheme applications",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'all'
                  ? "Applications will appear here when users apply for schemes"
                  : "No applications with status \"$_selectedFilter\"",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 20),
            if (_selectedFilter != 'all')
              ElevatedButton.icon(
                onPressed: () => _onFilterSelected('all'),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text("Clear Filter"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
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
  // APPLICATION CARD
  // ============================================================
  Widget _buildApplicationCard(Map<String, dynamic> app, int index) {
    final schemeName = app['display_scheme_name'] ?? 'Government Scheme';
    final schemeNameHindi = app['display_scheme_name_hindi'] ?? schemeName;
    final schemeIcon = app['display_scheme_icon'] ?? '📋';
    final schemeLevel = app['display_scheme_level'] ?? 'Central';
    final schemeState = app['display_scheme_state'];
    final applicantName = app['applicant_name'] ?? 'Unknown';
    final applicantEmail = app['applicant_email'] ?? 'N/A';
    final status = app['status'] ?? 'pending';
    final applicationId = app['application_id']?.toString() ?? '';
    final createdAt = app['created_at'] ?? app['applied_at'];
    final statusColor = _getStatusColor(status);

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
              // Header Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Text(
                      schemeIcon,
                      style: const TextStyle(fontSize: 22),
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
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          schemeName,
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

              // Applicant Info
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
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF6C63FF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            applicantName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            applicantEmail,
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
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Info Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    Icons.calendar_today,
                    "Applied",
                    _formatDate(createdAt),
                    Colors.blue,
                  ),
                  _buildInfoChip(
                    Icons.account_balance,
                    "Level",
                    schemeLevel,
                    schemeLevel == 'Central' ? Colors.green : Colors.purple,
                  ),
                  if (schemeState != null && schemeState.isNotEmpty)
                    _buildInfoChip(
                      Icons.location_on,
                      "State",
                      schemeState,
                      Colors.orange,
                    ),
                  if (applicationId.isNotEmpty)
                    _buildInfoChip(
                      Icons.confirmation_number,
                      "ID",
                      applicationId.length > 12
                          ? '${applicationId.substring(0, 12)}...'
                          : applicationId,
                      Colors.teal,
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // View Details Button
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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
  // ✅ APPLICATION DETAIL VIEW - READS FRESH _selectedApplication
  // ============================================================
  Widget _buildApplicationDetailView(Map<String, dynamic> app) {
    final schemeName = app['display_scheme_name'] ?? 'Government Scheme';
    final schemeNameHindi = app['display_scheme_name_hindi'] ?? schemeName;
    final schemeIcon = app['display_scheme_icon'] ?? '📋';
    final schemeLevel = app['display_scheme_level'] ?? 'Central';
    final schemeState = app['display_scheme_state'];
    final schemeCategory = app['display_scheme_category'] ?? 'other';

    final status = app['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final applicantName = app['applicant_name'] ?? 'Unknown';
    final applicantEmail = app['applicant_email'] ?? 'N/A';
    final appliedDate = _formatDate(app['created_at'] ?? app['applied_at']);

    final applicantDetails = app['applicant_details'] as Map? ?? {};
    final applicantAddress = app['applicant_address'] as Map? ?? {};
    final bankDetails = app['bank_details'] as Map? ?? {};

    // ✅ Determine which buttons to show based on status
    final statusLower = status.toLowerCase();
    final bool isFinalStatus = statusLower == 'rejected' ||
        statusLower == 'completed' ||
        statusLower == 'final_submitted' ||
        statusLower == 'verification_rejected';

    // Show review/final buttons for any non-final status
    final bool showActionButtons = !isFinalStatus;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _buildDetailHeader(schemeIcon, schemeNameHindi),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card - updates automatically after refresh
                      _buildStatusCard(
                          app['application_id'], status, statusColor),
                      const SizedBox(height: 16),

                      // ✅ ACTION BUTTONS - Shown for ALL non-final statuses
                      if (showActionButtons) ...[
                        _buildAdminActionButtons(
                            app['application_id'], status),
                        const SizedBox(height: 16),
                      ],

                      // Scheme Information
                      _buildSchemeInfoCard(
                        schemeName,
                        schemeNameHindi,
                        schemeIcon,
                        schemeLevel,
                        schemeState,
                        schemeCategory,
                      ),
                      const SizedBox(height: 16),

                      // Applicant Information
                      _buildApplicantCard(
                        applicantName,
                        applicantEmail,
                        appliedDate,
                        applicantDetails,
                      ),
                      const SizedBox(height: 16),

                      // Address Information
                      if (applicantAddress.isNotEmpty)
                        _buildAddressCard(applicantAddress),
                      if (applicantAddress.isNotEmpty)
                        const SizedBox(height: 16),

                      // Bank Details
                      if (bankDetails.isNotEmpty) _buildBankCard(bankDetails),
                      if (bankDetails.isNotEmpty) const SizedBox(height: 16),

                      // ✅ ADMIN DOCUMENTS CARD - auto-refreshes after action
                      _buildAdminDocumentsCard(),
                      const SizedBox(height: 16),

                      // ✅ USER DOCUMENTS CARD
                      _buildUserDocumentsCard(),
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
  // DETAIL HEADER
  // ============================================================
  Widget _buildDetailHeader(String schemeIcon, String schemeName) {
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
            child: Text(schemeIcon, style: const TextStyle(fontSize: 18)),
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
                  schemeName,
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
            onPressed: () {
              final applicationId =
                  _selectedApplication?['application_id']?.toString() ?? '';
              if (applicationId.isNotEmpty) {
                _refreshApplicationDetail(applicationId);
              }
            },
            tooltip: "Refresh",
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================
  Widget _buildStatusCard(
      String? applicationId, String status, Color statusColor) {
    final statusLower = status.toLowerCase();

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
                  _getStatusIcon(status),
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
                      "Application Status",
                      style: TextStyle(
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
                  ],
                ),
              ),
            ],
          ),
          if (applicationId != null && applicationId.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Application Number",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    applicationId,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
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

  // ============================================================
  // ✅ ADMIN ACTION BUTTONS (Review & Final Submit)
  // ============================================================
  Widget _buildAdminActionButtons(
      String? applicationId, String currentStatus) {
    if (applicationId == null || applicationId.isEmpty) {
      return const SizedBox();
    }

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
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.touch_app,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Admin Actions",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
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
            "Review the application and take appropriate action:",
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),

          // ✅ Review & Final Submit Row - ONLY TWO BUTTONS
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Review Button
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
                        : () => _showReviewDialog(applicationId),
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
              // Final Submit Button
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
                        : () => _showFinalSubmitDialog(applicationId),
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
                    "📝 REVIEW: Upload doc & move to UNDER REVIEW\n"
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

  // ============================================================
  // SCHEME INFO CARD
  // ============================================================
  Widget _buildSchemeInfoCard(
    String schemeName,
    String schemeNameHindi,
    String schemeIcon,
    String schemeLevel,
    String? schemeState,
    String schemeCategory,
  ) {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Scheme Information", Icons.account_balance),
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
                color: const Color(0xFF6C63FF).withOpacity(0.12),
              ),
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
                  child: Text(
                    schemeIcon,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schemeNameHindi,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        schemeName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.account_balance, "Level", schemeLevel),
          if (schemeState != null && schemeState.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_on, "State", schemeState),
          ],
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.category,
            "Category",
            schemeCategory.replaceAll('_', ' ').toUpperCase(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APPLICANT CARD
  // ============================================================
  Widget _buildApplicantCard(
    String name,
    String email,
    String appliedDate,
    Map applicantDetails,
  ) {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Applicant Information", Icons.person),
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
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 11,
                            color: Colors.blue.shade700,
                          ),
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
          if (applicantDetails.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            if (applicantDetails['father_name'] != null &&
                applicantDetails['father_name'].toString().isNotEmpty)
              _buildInfoRow(
                Icons.family_restroom,
                "Father's Name",
                applicantDetails['father_name'].toString(),
              ),
            if (applicantDetails['date_of_birth'] != null &&
                applicantDetails['date_of_birth'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.cake,
                "Date of Birth",
                _formatDate(applicantDetails['date_of_birth'].toString()),
              ),
            ],
            if (applicantDetails['gender'] != null &&
                applicantDetails['gender'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.wc,
                "Gender",
                applicantDetails['gender'].toString().toUpperCase(),
              ),
            ],
            if (applicantDetails['category'] != null &&
                applicantDetails['category'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.category,
                "Category",
                applicantDetails['category'].toString(),
              ),
            ],
            if (applicantDetails['mobile'] != null &&
                applicantDetails['mobile'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.phone,
                "Mobile",
                applicantDetails['mobile'].toString(),
              ),
            ],
            if (applicantDetails['annual_income'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.currency_rupee,
                "Annual Income",
                "₹${applicantDetails['annual_income']}",
                color: Colors.green,
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ============================================================
  // ADDRESS CARD
  // ============================================================
  Widget _buildAddressCard(Map address) {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Address", Icons.location_on),
          if (address['address_line1'] != null &&
              address['address_line1'].toString().isNotEmpty)
            _buildInfoRow(
              Icons.home,
              "Address Line 1",
              address['address_line1'].toString(),
            ),
          if (address['address_line2'] != null &&
              address['address_line2'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.home_outlined,
              "Address Line 2",
              address['address_line2'].toString(),
            ),
          ],
          if (address['village_city'] != null &&
              address['village_city'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.location_city,
              "Village/City",
              address['village_city'].toString(),
            ),
          ],
          if (address['district'] != null &&
              address['district'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.map,
              "District",
              address['district'].toString(),
            ),
          ],
          if (address['state'] != null &&
              address['state'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.public,
              "State",
              address['state'].toString(),
            ),
          ],
          if (address['pincode'] != null &&
              address['pincode'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.pin_drop,
              "Pincode",
              address['pincode'].toString(),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // BANK CARD
  // ============================================================
  Widget _buildBankCard(Map bankDetails) {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Bank Details", Icons.account_balance_wallet),
          if (bankDetails['account_holder_name'] != null &&
              bankDetails['account_holder_name'].toString().isNotEmpty)
            _buildInfoRow(
              Icons.person,
              "Account Holder",
              bankDetails['account_holder_name'].toString(),
            ),
          if (bankDetails['bank_name'] != null &&
              bankDetails['bank_name'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.account_balance,
              "Bank Name",
              bankDetails['bank_name'].toString(),
            ),
          ],
          if (bankDetails['account_number'] != null &&
              bankDetails['account_number'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.numbers,
              "Account Number",
              _maskAccountNumber(bankDetails['account_number'].toString()),
            ),
          ],
          if (bankDetails['ifsc_code'] != null &&
              bankDetails['ifsc_code'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.code,
              "IFSC Code",
              bankDetails['ifsc_code'].toString(),
            ),
          ],
          if (bankDetails['branch_name'] != null &&
              bankDetails['branch_name'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.location_on,
              "Branch",
              bankDetails['branch_name'].toString(),
            ),
          ],
        ],
      ),
    );
  }

  String _maskAccountNumber(String accountNumber) {
    if (accountNumber.length > 4) {
      return '${'*' * (accountNumber.length - 4)}${accountNumber.substring(accountNumber.length - 4)}';
    }
    return accountNumber;
  }

  // ============================================================
  // ✅ ADMIN DOCUMENTS CARD
  // ============================================================
  Widget _buildAdminDocumentsCard() {
    final int count = _adminDocuments.length;

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
                child: const Icon(
                  Icons.admin_panel_settings,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
          if (_isLoadingDocuments)
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
              children: _adminDocuments
                  .asMap()
                  .entries
                  .map((e) => _buildAdminDocumentRow(e.key, e.value))
                  .toList(),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ USER DOCUMENTS CARD
  // ============================================================
  Widget _buildUserDocumentsCard() {
    final int count = _userDocuments.length;

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
                child: const Icon(
                  Icons.person,
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
                      "User Uploaded Documents",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Uploaded by candidate for this application",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
          if (_isLoadingDocuments)
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
                    "Candidate has not uploaded any documents",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: _userDocuments
                  .asMap()
                  .entries
                  .map((e) => _buildUserDocumentRow(e.key, e.value))
                  .toList(),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ ADMIN DOCUMENT ROW
  // ============================================================
  Widget _buildAdminDocumentRow(int index, Map<String, dynamic> doc) {
    final String label =
        doc['label']?.toString() ?? 'Admin Document ${index + 1}';
    final String url = doc['url']?.toString() ?? '';
    final String? downloadUrl = doc['download_url']?.toString();
    final String badge = doc['badge']?.toString() ?? 'ADMIN';
    final Color badgeColor = doc['badgeColor'] is Color
        ? doc['badgeColor'] as Color
        : Colors.purple;

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
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
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
                  ],
                ),
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

  // ============================================================
  // ✅ USER DOCUMENT ROW
  // ============================================================
  Widget _buildUserDocumentRow(int index, Map<String, dynamic> doc) {
    final String label = doc['label']?.toString() ?? 'Document ${index + 1}';
    final String url = doc['url']?.toString() ?? '';
    final String? downloadUrl = doc['download_url']?.toString();

    final icon = _iconForUrl(url);
    final color = _colorForUrl(url);
    final fileType = _fileTypeForUrl(url);

    const badgeLabel = "UPLOADED";
    const badgeColor = Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
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
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: badgeColor.withOpacity(0.4),
                        ),
                      ),
                      child: const Text(
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

  // ============================================================
  // SECTION HEADER
  // ============================================================
  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================
  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? color}) {
    if (value.isEmpty || value == 'N/A') return const SizedBox();
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
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
              ),
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

  // ============================================================
  // GLASS CONTAINER
  // ============================================================
  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
}

// ============================================================================
// ✅ REVIEW DIALOG CONTENT - FIXED for WEB + MOBILE
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
        withData: true,
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
                  child: const Icon(
                    Icons.rate_review,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    "Review Application",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.pop(context, null),
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
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF6C63FF),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "This will change status to REVIEW. Document is required.",
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF6C63FF).withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "📄 Upload Document (PDF or Image) *",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Upload relevant document for review. (Required)",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap: _isPicking ? null : _pickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
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
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _clearFile,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Remove",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red,
                                        ),
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

                    const Text(
                      "Review Notes (Optional)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: widget.notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Add review comments or notes...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(12),
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
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rate_review, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Submit Review",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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
// ✅ FINAL SUBMIT DIALOG CONTENT - FIXED for WEB + MOBILE
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
        withData: true,
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.send_and_archive,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    "Final Submission",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ],
            ),
            const Divider(height: 24),

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
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.orange,
                    size: 18,
                  ),
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

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "📄 Upload Final Document (PDF or Image) *",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "This document will be stored securely. (Required)",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap: _isPicking ? null : _pickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
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
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _clearFile,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Remove",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red,
                                        ),
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

                    const Text(
                      "Additional Notes (Optional)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: widget.notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Add any final remarks or notes...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(12),
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
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_and_archive, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Confirm Final Submit",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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