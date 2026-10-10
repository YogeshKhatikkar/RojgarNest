// lib/features/user/presentation/screens/user_dashboard.dart
// ✅ COMPLETE UPDATED VERSION
// ✅ Parent menu tap ONLY expands sidebar — never changes right-side content
// ✅ Right-side content changes ONLY when a submenu is tapped
// ✅ NULLABLE submenus — no auto-select
// ✅ Placeholder shown when parent expanded but no submenu chosen
// ✅ FIXED: ApplicationDetailScreen now shows in right panel when "View Application" clicked
// ✅ NEW: Schemes menu added — Browse Schemes + Scheme Applications
// ✅ NEW: SchemeDetailScreen now shows in right panel (embedded)
// ✅ NEW: SchemeListScreen now shows in right panel (embedded)
// ✅ NEW: UserSchemeApplicationsScreen now shows in right panel (embedded)
// ✅ All original functionality preserved — NO lines skipped

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/services/profile_state_service.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/user/presentation/widgets/user_sidebar.dart';
import 'package:rojgarnext/features/user/presentation/utils/menu_types.dart';
import 'package:rojgarnext/features/notification/widgets/notification_bell.dart';
import 'package:rojgarnext/features/common/widgets/location_display.dart';
import 'package:rojgarnext/features/user/data/user_service.dart';

// ==================== SCREENS ====================
import 'package:rojgarnext/features/user/presentation/screens/basic_details_screen.dart';
import 'package:rojgarnext/features/user/presentation/screens/education_screen.dart';
import 'package:rojgarnext/features/user/presentation/screens/experience_screen.dart';
import 'package:rojgarnext/features/user/presentation/screens/advanced_details_screen.dart';
import 'package:rojgarnext/features/user/presentation/screens/user_documents_screen.dart';
import 'package:rojgarnext/features/user/presentation/screens/user_applications_screen.dart';
import 'package:rojgarnext/features/user/presentation/screens/user_support_screen.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/job_list_screen.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/job_detail_screen.dart';
import 'package:rojgarnext/features/jobs/presentation/screens/saved_jobs_screen.dart';

// ✅ Service screens
import 'package:rojgarnext/features/services/presentation/screens/apply_service_screen.dart';
import 'package:rojgarnext/features/services/presentation/screens/user_service_applications_screen.dart';

// ✅ Resume screens
import 'package:rojgarnext/features/resume/presentation/screens/build_resume_screen.dart';
import 'package:rojgarnext/features/resume/presentation/screens/resume_screen.dart';
import 'package:rojgarnext/features/resume/AI/presentation/screens/ats_score_screen.dart';
import 'package:rojgarnext/features/resume/AI/presentation/screens/ai_resume_generator_screen.dart';

// ✅ AI screens
import 'package:rojgarnext/features/user/AI/user_ai_screen.dart';
import 'package:rojgarnext/features/user/AI/user_career_roadmap_screen.dart';

// ✅ AUTH SCREENS IMPORT
import 'package:rojgarnext/features/auth/presentation/screens/change_password_screen.dart';
import 'package:rojgarnext/features/auth/presentation/screens/mpin_setup_page.dart';
import 'package:rojgarnext/features/auth/presentation/screens/fingerprint_setup_page.dart';

// ✅ Schemes screens
import 'package:rojgarnext/features/schemes/presentation/screens/scheme_list_screen.dart';
import 'package:rojgarnext/features/schemes/presentation/screens/scheme_detail_screen.dart';
import 'package:rojgarnext/features/schemes/presentation/screens/user_scheme_applications_screen.dart';

// ============================================================
// DASHBOARD STATS MODEL
// ============================================================
class DashboardStats {
  final int profileCompletion;
  final int careerScore;
  final int jobApplicationsTotal;
  final int jobApplicationsSaved;
  final int jobApplicationsApplied;
  final int serviceApplicationsTotal;
  final Map<String, dynamic> profileSections;
  final Map<String, dynamic> careerBreakdown;

  DashboardStats({
    required this.profileCompletion,
    required this.careerScore,
    required this.jobApplicationsTotal,
    required this.jobApplicationsSaved,
    required this.jobApplicationsApplied,
    required this.serviceApplicationsTotal,
    required this.profileSections,
    required this.careerBreakdown,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final jobApps = json['job_applications'] as Map? ?? {};
    final serviceApps = json['service_applications'] as Map? ?? {};

    return DashboardStats(
      profileCompletion: (json['profile_completion'] as num?)?.toInt() ?? 0,
      careerScore: (json['career_score'] as num?)?.toInt() ?? 0,
      jobApplicationsTotal: (jobApps['total'] as num?)?.toInt() ?? 0,
      jobApplicationsSaved: (jobApps['saved'] as num?)?.toInt() ?? 0,
      jobApplicationsApplied: (jobApps['applied'] as num?)?.toInt() ?? 0,
      serviceApplicationsTotal: (serviceApps['total'] as num?)?.toInt() ?? 0,
      profileSections:
          Map<String, dynamic>.from(json['profile_sections'] as Map? ?? {}),
      careerBreakdown:
          Map<String, dynamic>.from(json['career_breakdown'] as Map? ?? {}),
    );
  }

  static DashboardStats empty() => DashboardStats(
        profileCompletion: 0,
        careerScore: 0,
        jobApplicationsTotal: 0,
        jobApplicationsSaved: 0,
        jobApplicationsApplied: 0,
        serviceApplicationsTotal: 0,
        profileSections: {},
        careerBreakdown: {},
      );
}

// ============================================================
// USER DASHBOARD
// ✅ NULLABLE submenus — no auto-select
// ✅ FIXED: ApplicationDetailScreen shows in right panel
// ✅ NEW: Schemes submenu state + handlers
// ✅ NEW: Scheme detail view in right panel
// ============================================================
class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  // ==================== STATE ====================
  UserMenuType selectedMenu = UserMenuType.dashboard;

  // ✅ NULLABLE — nothing auto-selected
  JobSubMenu? selectedJobSubMenu;
  ServiceSubMenu? selectedServiceSubMenu;
  ResumeSubMenu? selectedResumeSubMenu;
  SchemesSubMenu? selectedSchemesSubMenu;
  AISubMenu? selectedAISubMenu;
  ProfileSubMenu? selectedProfileSubMenu;
  SettingsSubMenu? selectedSettingsSubMenu;

  // ✅ Embedded detail views
  Map<String, dynamic>? _selectedJob;
  Map<String, dynamic>? _selectedApplication;

  // ==================== SCHEME VIEW STATE (NEW) ====================
  String? _selectedSchemeId;
  String? _selectedSchemeName;
  Map<String, dynamic>? _selectedSchemeData;
  bool _showSchemeDetailView = false;

  // ==================== DASHBOARD DATA ====================
  DashboardStats _stats = DashboardStats.empty();
  bool _isLoading = true;
  bool _isDataReady = false;
  String _userName = 'User';

  // ==================== CACHED EMAIL ====================
  String? _cachedEmail;
  bool _emailLoaded = false;

  // ==================== DRAWER ====================
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ==================== CACHE KEY ====================
  static const String _cacheKey = 'user_dashboard_stats_cache';

  // ============================================================
  // LIFECYCLE
  // ============================================================
  @override
  void initState() {
    super.initState();
    _loadFromCacheSync();
    _refreshInBackground();
    _loadEmail();
  }

  // ============================================================
  // ✅ SYNC CACHE LOAD - ZERO DELAY
  // ============================================================
  void _loadFromCacheSync() {
    try {
      SharedPreferences.getInstance().then((pref) {
        final cached = pref.getString(_cacheKey);
        if (cached != null) {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _stats = DashboardStats.fromJson(data);
              _isDataReady = true;
              _isLoading = false;
            });
          }
          debugPrint("✅ User Dashboard loaded from CACHE");
          return;
        }

        if (mounted) {
          setState(() {
            _isDataReady = true;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint("⚠️ User cache read error: $e");
      if (mounted) {
        setState(() {
          _isDataReady = true;
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // ✅ LOAD EMAIL ONCE
  // ============================================================
  Future<void> _loadEmail() async {
    try {
      final email = await SecureStorage.getEmail();
      if (mounted) {
        setState(() {
          _cachedEmail = email;
          _emailLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('⚠️ _loadEmail error: $e');
      if (mounted) {
        setState(() {
          _cachedEmail = null;
          _emailLoaded = true;
        });
      }
    }
  }

  // ============================================================
  // ✅ BACKGROUND REFRESH
  // ============================================================
  Future<void> _refreshInBackground() async {
    try {
      try {
        await ProfileStateService().loadPhotoFromBackend();
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint("⚠️ Photo load failed: $e");
      }

      final statsResponse = await UserService.getDashboardStats();
      final stats = DashboardStats.fromJson(statsResponse);

      String userName = 'User';
      try {
        final profileRes = await UserService.getFullProfile();
        final profileData = profileRes['data'] is Map
            ? profileRes['data'] as Map
            : profileRes;
        final fullName = profileData['full_name']?.toString() ?? '';
        if (fullName.isNotEmpty) {
          userName = fullName;
        }
      } catch (e) {
        debugPrint("⚠️ Profile load failed: $e");
      }

      if (!mounted) return;

      setState(() {
        _stats = stats;
        _userName = userName;
        _isDataReady = true;
        _isLoading = false;
      });

      await _cacheDashboardData(stats, userName);
      debugPrint("✅ User Dashboard refresh complete");
    } catch (e) {
      debugPrint("❌ User dashboard refresh error: $e");
      if (mounted) {
        setState(() {
          _isDataReady = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cacheDashboardData(
      DashboardStats stats, String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'profile_completion': stats.profileCompletion,
          'career_score': stats.careerScore,
          'job_applications': {
            'total': stats.jobApplicationsTotal,
            'saved': stats.jobApplicationsSaved,
            'applied': stats.jobApplicationsApplied,
          },
          'service_applications': {
            'total': stats.serviceApplicationsTotal,
          },
          'profile_sections': stats.profileSections,
          'career_breakdown': stats.careerBreakdown,
        }),
      );
      await prefs.setInt(
        '${_cacheKey}_time',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint("⚠️ Cache save error: $e");
    }
  }

  // ============================================================
  // ✅ Refresh dashboard stats
  // ============================================================
  Future<void> _refreshDashboardStats() async {
    try {
      final statsResponse = await UserService.getDashboardStats();
      final stats = DashboardStats.fromJson(statsResponse);

      if (!mounted) return;

      setState(() {
        _stats = stats;
        _isLoading = false;
        _isDataReady = true;
      });

      await _cacheDashboardData(stats, _userName);

      debugPrint(
        "✅ Dashboard stats refreshed: "
        "profile=${stats.profileCompletion}% "
        "career=${stats.careerScore}",
      );
    } catch (e) {
      debugPrint("⚠️ Refresh dashboard stats failed: $e");
    }
  }

  // ============================================================
  // ✅ Called AFTER resume is generated/rebuilt
  // ============================================================
  Future<void> _onResumeGenerated() async {
    try {
      await UserService.rebuildResume();
    } catch (e) {
      debugPrint("⚠️ Resume rebuild call failed (non-fatal): $e");
    }

    await _refreshDashboardStats();

    if (mounted) {
      showMessage(
        context,
        "✅ Resume generated! Profile completion updated.",
        isError: false,
      );
    }
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isLoading = true);
    await _refreshInBackground();
  }

  // ============================================================
  // MENU HANDLERS
  // ============================================================
  void _closeDrawerIfOpen() {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // ✅ CLEAR ALL DETAIL VIEWS HELPER
  // ============================================================
  void _clearAllDetailViews() {
    _selectedJob = null;
    _selectedApplication = null;
    _selectedSchemeId = null;
    _selectedSchemeName = null;
    _selectedSchemeData = null;
    _showSchemeDetailView = false;
  }

  // ✅ Dashboard / Support — LEAF menu handlers
  void _onMenuSelected(UserMenuType menu) {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = menu;
          _clearAllDetailViews();
        });
      }
    });
  }

  // ✅ Jobs — SUBMENU handlers (ONLY these change content)
  void _onJobSubMenuSelected(JobSubMenu subMenu) {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.jobs;
          selectedJobSubMenu = subMenu;
          _clearAllDetailViews();
        });
      }
    });
  }

  // ✅ Services — SUBMENU handlers
  void _onServiceSubMenuSelected(ServiceSubMenu subMenu) {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.services;
          selectedServiceSubMenu = subMenu;
          _clearAllDetailViews();
        });
      }
    });
  }

  // ✅ Resume — SUBMENU handlers
  void _onResumeSubMenuSelected(ResumeSubMenu subMenu) {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.resume;
          selectedResumeSubMenu = subMenu;
          _clearAllDetailViews();
        });
      }
    });
  }

  // ✅ Schemes — SUBMENU handlers
  void _onSchemesSubMenuSelected(SchemesSubMenu subMenu) {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.schemes;
          selectedSchemesSubMenu = subMenu;
          _clearAllDetailViews();
        });
      }
    });
  }

  // ✅ AI — SUBMENU handlers
  void _onAISubMenuSelected(AISubMenu subMenu) {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.ai;
          selectedAISubMenu = subMenu;
          _clearAllDetailViews();
        });
      }
    });
  }

  // ✅ Profile — SUBMENU handlers
  void _onProfileSubMenuSelected(ProfileSubMenu subMenu) {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.profile;
          selectedProfileSubMenu = subMenu;
          _clearAllDetailViews();
        });
      }
    });
  }

  // ✅ Settings — SUBMENU handlers
  void _onSettingsSubMenuSelected(SettingsSubMenu subMenu) {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.settings;
          selectedSettingsSubMenu = subMenu;
          _clearAllDetailViews();
        });
      }
    });
  }

  // ============================================================
  // ✅ JOB / APPLICATION selection (embedded)
  // ============================================================
  void _onJobSelected(Map<String, dynamic> job) {
    debugPrint("📋 Job selected: ${job['post_name']}");
    setState(() {
      _selectedJob = job;
      _selectedApplication = null;
      _selectedSchemeId = null;
      _selectedSchemeName = null;
      _selectedSchemeData = null;
      _showSchemeDetailView = false;
    });
  }

  void _closeJobDetail() {
    setState(() {
      _selectedJob = null;
    });
  }

  // ✅ Handle application selection from UserApplicationsScreen
  void _onApplicationSelected(Map<String, dynamic> application) {
    debugPrint("📋 Application selected: ${application['_id']}");
    debugPrint("   Job Title: ${application['job_title']}");
    debugPrint("   Status: ${application['status']}");
    setState(() {
      _selectedApplication = application;
      _selectedJob = null;
      _selectedSchemeId = null;
      _selectedSchemeName = null;
      _selectedSchemeData = null;
      _showSchemeDetailView = false;
    });
  }

  void _closeApplicationDetail() {
    setState(() {
      _selectedApplication = null;
    });
  }

  // ============================================================
  // ✅ SCHEME SELECTION HANDLERS (NEW)
  // ============================================================
  void _onSchemeSelectedFromList(Map<String, dynamic> schemeData) {
    debugPrint("📋 Scheme selected from list: ${schemeData['scheme_id']}");
    setState(() {
      _selectedSchemeId = schemeData['scheme_id']?.toString();
      _selectedSchemeName = schemeData['scheme_name']?.toString();
      _selectedSchemeData = schemeData;
      _showSchemeDetailView = true;
      _selectedJob = null;
      _selectedApplication = null;
    });
  }

  void _onSchemeSelectedFromApplications(Map<String, dynamic> schemeData) {
    debugPrint("📋 Scheme selected from applications: ${schemeData['scheme_id']}");
    setState(() {
      _selectedSchemeId = schemeData['scheme_id']?.toString();
      _selectedSchemeName = schemeData['scheme_name']?.toString();
      _selectedSchemeData = schemeData;
      _showSchemeDetailView = true;
      _selectedJob = null;
      _selectedApplication = null;
    });
  }

  void _closeSchemeDetailView() {
    setState(() {
      _showSchemeDetailView = false;
      _selectedSchemeId = null;
      _selectedSchemeName = null;
      _selectedSchemeData = null;
    });
  }

  // ============================================================
  // ✅ NAVIGATION HELPERS
  // ============================================================
  void _goToJobApplications() {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.jobs;
          selectedJobSubMenu = JobSubMenu.jobApplications;
          _clearAllDetailViews();
        });
      }
    });
  }

  void _goToBrowseJobs() {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.jobs;
          selectedJobSubMenu = JobSubMenu.browseJobs;
          _clearAllDetailViews();
        });
      }
    });
  }

  void _goToServiceApplications() {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.services;
          selectedServiceSubMenu = ServiceSubMenu.myApplications;
          _clearAllDetailViews();
        });
      }
    });
  }

  void _goToSavedJobs() {
    _closeDrawerIfOpen();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SavedJobsScreen()),
    );
  }

  // ✅ NEW: Go to Browse Schemes
  void _goToBrowseSchemes() {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.schemes;
          selectedSchemesSubMenu = SchemesSubMenu.browseSchemes;
          _clearAllDetailViews();
        });
      }
    });
  }

  // ✅ NEW: Go to Scheme Applications
  void _goToSchemeApplications() {
    _closeDrawerIfOpen();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = UserMenuType.schemes;
          selectedSchemesSubMenu = SchemesSubMenu.schemeApplications;
          _clearAllDetailViews();
        });
      }
    });
  }

  // ============================================================
  // ✅ GET SETTINGS SCREEN
  // ============================================================
  Widget _getSettingsScreen() {
    switch (selectedSettingsSubMenu) {
      case SettingsSubMenu.changePassword:
        return const ChangePasswordScreen(
          isForgotFlow: false,
          isEmbedded: true,
        );

      case SettingsSubMenu.setupMpin:
        if (!_emailLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_cachedEmail == null || _cachedEmail!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text("Please login with email & password first"),
              ],
            ),
          );
        }
        return MpinSetupPage(
          key: const ValueKey('user_mpin_setup_page'),
          email: _cachedEmail!,
        );

      case SettingsSubMenu.fingerprint:
        if (!_emailLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_cachedEmail == null || _cachedEmail!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text("Please login with email & password first"),
              ],
            ),
          );
        }
        return FingerprintSetupPage(
          key: const ValueKey('user_fingerprint_setup_page'),
          email: _cachedEmail!,
        );

      case null:
        // ✅ Defensive fallback — settings screen only renders after submenu tap
        return _buildSelectSubmenuPlaceholder(
          title: "Settings",
          icon: Icons.settings_rounded,
          message: "Select a submenu from the sidebar",
        );
    }
  }

  // ============================================================
  // ✅ GET SCHEMES SCREEN (UPDATED — Embedded mode)
  // ============================================================
  Widget _getSchemesScreen() {
    // ✅ If scheme detail view is active, show detail screen
    if (_showSchemeDetailView && _selectedSchemeId != null) {
      return SchemeDetailScreen(
        schemeId: _selectedSchemeId!,
        schemeName: _selectedSchemeName ?? 'योजना',
        isEmbedded: true,
        onBack: _closeSchemeDetailView,
      );
    }

    // ✅ Otherwise, show list or applications based on submenu
    switch (selectedSchemesSubMenu) {
      case SchemesSubMenu.browseSchemes:
        return SchemeListScreen(
          isEmbedded: true,
          onSchemeSelected: _onSchemeSelectedFromList,
        );
      case SchemesSubMenu.schemeApplications:
        return UserSchemeApplicationsScreen(
          isEmbedded: true,
          onSchemeSelected: _onSchemeSelectedFromApplications,
        );
      case null:
        return _buildSelectSubmenuPlaceholder(
          title: "सरकारी योजनाएं",
          icon: Icons.account_balance_rounded,
          message: "Select a submenu from the sidebar",
        );
    }
  }

  // ============================================================
  // ✅ PLACEHOLDER — shown when parent expanded but no submenu selected
  // ============================================================
  Widget _buildSelectSubmenuPlaceholder({
    required String title,
    required IconData icon,
    required String message,
  }) {
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
              child: Icon(
                icon,
                size: 60,
                color: const Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back,
                    size: 16,
                    color: Color(0xFF6C63FF),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Tap a submenu in the sidebar",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ✅ GET CONTENT
  // ✅ Uses NULLABLE checks — placeholder if submenu not selected
  // ✅ FIXED: ApplicationDetailScreen shows when application selected
  // ✅ NEW: Schemes case with embedded detail view
  // ============================================================
  Widget _getContent() {
    switch (selectedMenu) {
      case UserMenuType.dashboard:
        return _buildDashboardContent();

      // ============================================================
      // JOBS
      // ============================================================
      case UserMenuType.jobs:
        // ✅ CRITICAL FIX: If application selected → show ApplicationDetailScreen
        if (_selectedApplication != null &&
            selectedJobSubMenu == JobSubMenu.jobApplications) {
          debugPrint(
              "📋 Showing ApplicationDetailScreen for: ${_selectedApplication!['job_title']}");
          return ApplicationDetailScreen(
            application: _selectedApplication!,
            onBack: _closeApplicationDetail,
            onViewJob: (job) {
              // Navigate to job detail when "View Full Job Details" clicked
              setState(() {
                _selectedJob = job;
                _selectedApplication = null;
              });
            },
          );
        }

        // ✅ Job Applications list
        if (selectedJobSubMenu == JobSubMenu.jobApplications) {
          return UserApplicationsScreen(
            onApplicationSelected: _onApplicationSelected,
            showAppBar: false,
          );
        }

        // ✅ Browse Jobs
        if (selectedJobSubMenu == JobSubMenu.browseJobs) {
          if (_selectedJob != null) {
            return JobDetailScreen(
              job: _selectedJob!,
              isEmbedded: true,
              onBack: _closeJobDetail,
              onApplicationSubmitted: () {
                _refreshDashboard();
              },
            );
          }
          return JobListScreen(
            isEmbedded: true,
            onJobSelected: _onJobSelected,
          );
        }

        // ✅ Placeholder — no submenu selected
        return _buildSelectSubmenuPlaceholder(
          title: "Jobs",
          icon: Icons.work_rounded,
          message: "Select a submenu from the sidebar",
        );

      // ============================================================
      // SERVICES
      // ============================================================
      case UserMenuType.services:
        if (selectedServiceSubMenu == ServiceSubMenu.browseServices) {
          return const ApplyServiceScreen();
        }
        if (selectedServiceSubMenu == ServiceSubMenu.myApplications) {
          return const UserServiceApplicationScreen();
        }
        return _buildSelectSubmenuPlaceholder(
          title: "Services",
          icon: Icons.miscellaneous_services_rounded,
          message: "Select a submenu from the sidebar",
        );

      // ============================================================
      // RESUME
      // ============================================================
      case UserMenuType.resume:
        switch (selectedResumeSubMenu) {
          case ResumeSubMenu.buildResume:
            return _ResumeLauncher(
              child: const BuildResumeScreen(),
              onGenerated: _onResumeGenerated,
            );
          case ResumeSubMenu.viewResume:
            return const ResumeScreen();
          case ResumeSubMenu.atsScore:
            return const ATSScoreScreen();
          case ResumeSubMenu.aiGenerator:
            return _ResumeLauncher(
              child: const AIResumeGeneratorScreen(),
              onGenerated: _onResumeGenerated,
            );
          case null:
            return _buildSelectSubmenuPlaceholder(
              title: "Resume",
              icon: Icons.description_rounded,
              message: "Select a submenu from the sidebar",
            );
        }

      // ============================================================
      // SCHEMES ✅ UPDATED — Now shows detail view embedded
      // ============================================================
      case UserMenuType.schemes:
        return _getSchemesScreen();

      // ============================================================
      // AI
      // ============================================================
      case UserMenuType.ai:
        switch (selectedAISubMenu) {
          case AISubMenu.dashboard:
            return const UserAIScreen();
          case AISubMenu.careerRoadmap:
            return const UserCareerRoadmapScreen();
          case null:
            return _buildSelectSubmenuPlaceholder(
              title: "AI",
              icon: Icons.auto_awesome_rounded,
              message: "Select a submenu from the sidebar",
            );
        }

      // ============================================================
      // PROFILE
      // ============================================================
      case UserMenuType.profile:
        switch (selectedProfileSubMenu) {
          case ProfileSubMenu.basicDetails:
            return const BasicDetailsScreen();
          case ProfileSubMenu.education:
            return const EducationScreen();
          case ProfileSubMenu.experience:
            return const ExperienceScreen();
          case ProfileSubMenu.advancedDetails:
            return const AdvancedDetailsScreen();
          case ProfileSubMenu.documents:
            return const UserDocumentsScreen();
          case null:
            return _buildSelectSubmenuPlaceholder(
              title: "Profile",
              icon: Icons.person_rounded,
              message: "Select a submenu from the sidebar",
            );
        }

      // ============================================================
      // SUPPORT (LEAF)
      // ============================================================
      case UserMenuType.support:
        return const SupportScreen();

      // ============================================================
      // SETTINGS
      // ============================================================
      case UserMenuType.settings:
        return _getSettingsScreen();
    }
  }

  // ============================================================
  // ✅ DASHBOARD CONTENT
  // ============================================================
  Widget _buildDashboardContent() {
    final greeting = _getGreetingMessage();

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      color: const Color(0xFF6C63FF),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAIHeader(greeting),
            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildCareerScoreCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildProfileCompletionCard()),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildApplicationCountCard(
                    title: "Job Applications",
                    count: _stats.jobApplicationsTotal,
                    savedCount: _stats.jobApplicationsSaved,
                    icon: Icons.work_rounded,
                    color: const Color(0xFF6C63FF),
                    onTap: _goToJobApplications,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildApplicationCountCard(
                    title: "Service Applications",
                    count: _stats.serviceApplicationsTotal,
                    savedCount: 0,
                    icon: Icons.workspace_premium_rounded,
                    color: const Color(0xFFFF6588),
                    onTap: _goToServiceApplications,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildCareerBreakdownCard(),
            const SizedBox(height: 20),

            _buildProfileSectionsCard(),
            const SizedBox(height: 20),

            _buildQuickActionsGrid(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ✅ AI HEADER
  // ============================================================
  Widget _buildAIHeader(String greeting) {
    final photoUrl = ProfileStateService().profilePhotoUrl.value;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              image: hasPhoto
                  ? DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: !hasPhoto
                ? Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$greeting, ${_userName.split(' ').first}!",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Track your career progress with AI",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
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

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "🌅 Good Morning";
    if (hour < 17) return "☀️ Good Afternoon";
    return "🌙 Good Evening";
  }

  // ============================================================
  // ✅ CAREER SCORE CARD
  // ============================================================
  Widget _buildCareerScoreCard() {
    final score = _stats.careerScore;
    final color = _getScoreColor(score);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 3,
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
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Career Score",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$score",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Text(
                  "/100",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getCareerScoreLabel(score),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ PROFILE COMPLETION CARD
  // ============================================================
  Widget _buildProfileCompletionCard() {
    final percent = _stats.profileCompletion;
    final color = _getCompletionColor(percent);

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMenu = UserMenuType.profile;
          selectedProfileSubMenu = ProfileSubMenu.basicDetails;
          _clearAllDetailViews();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              spreadRadius: 3,
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
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Profile",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$percent",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 2),
                  child: Text(
                    "%",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getCompletionLabel(percent),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ✅ APPLICATION COUNT CARD
  // ============================================================
  Widget _buildApplicationCountCard({
    required String title,
    required int count,
    required int savedCount,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 15,
              spreadRadius: 3,
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
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              "$count",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (savedCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                "$savedCount saved",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ✅ CAREER BREAKDOWN CARD
  // ============================================================
  Widget _buildCareerBreakdownCard() {
    final breakdown = _stats.careerBreakdown;

    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = [
      _BreakdownItem(
        label: "Skills",
        value: (breakdown['skill_score'] as num?)?.toInt() ?? 0,
        color: const Color(0xFF6C63FF),
        icon: Icons.build,
      ),
      _BreakdownItem(
        label: "Experience",
        value: (breakdown['experience_score'] as num?)?.toInt() ?? 0,
        color: const Color(0xFFF97316),
        icon: Icons.work,
      ),
      _BreakdownItem(
        label: "Education",
        value: (breakdown['education_score'] as num?)?.toInt() ?? 0,
        color: const Color(0xFF8B5CF6),
        icon: Icons.school,
      ),
      _BreakdownItem(
        label: "Completeness",
        value: (breakdown['completeness_score'] as num?)?.toInt() ?? 0,
        color: const Color(0xFF10B981),
        icon: Icons.checklist,
      ),
      _BreakdownItem(
        label: "Market Fit",
        value: (breakdown['market_alignment_score'] as num?)?.toInt() ?? 0,
        color: const Color(0xFFFF6588),
        icon: Icons.trending_up,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Color(0xFF6C63FF), size: 22),
              SizedBox(width: 10),
              Text(
                "Career Score Breakdown",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _buildBreakdownRow(item)),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(_BreakdownItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                "${item.value}%",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: item.value / 100,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(item.color),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ PROFILE SECTIONS CARD
  // ============================================================
  Widget _buildProfileSectionsCard() {
    final sections = _stats.profileSections;

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<_SectionItem> items = [
      _SectionItem(
        label: "Basic Info",
        done: sections['basic_info'] == true,
        icon: Icons.person,
      ),
      _SectionItem(
        label: "Address",
        done: sections['address'] == true,
        icon: Icons.location_on,
      ),
      _SectionItem(
        label: "Education",
        done: sections['education'] == true,
        icon: Icons.school,
      ),
      _SectionItem(
        label: "Experience",
        done: sections['experience'] == true,
        icon: Icons.work,
      ),
      _SectionItem(
        label: "Skills",
        done: sections['skills'] == true,
        icon: Icons.build,
      ),
      _SectionItem(
        label: "Resume",
        done: sections['resume'] == true,
        icon: Icons.picture_as_pdf,
      ),
      _SectionItem(
        label: "Photo",
        done: sections['profile_photo'] == true,
        icon: Icons.camera_alt,
      ),
      _SectionItem(
        label: "Summary",
        done: sections['summary'] == true,
        icon: Icons.description,
      ),
    ];

    final completedCount = items.where((i) => i.done).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, color: Color(0xFF10B981), size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Profile Sections",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$completedCount/${items.length}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) => _buildSectionChip(item)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionChip(_SectionItem item) {
    final color = item.done ? const Color(0xFF10B981) : Colors.grey.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: item.done
            ? const Color(0xFF10B981).withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.done
              ? const Color(0xFF10B981).withOpacity(0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.done ? Icons.check_circle : item.icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: item.done
                  ? const Color(0xFF047857)
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ QUICK ACTIONS GRID (UPDATED — Added Schemes)
  // ============================================================
  Widget _buildQuickActionsGrid() {
    final actions = [
      _QuickAction(
        title: 'Browse Jobs',
        icon: Icons.search,
        color: const Color(0xFF6C63FF),
        onTap: _goToBrowseJobs,
      ),
      _QuickAction(
        title: 'My Resume',
        icon: Icons.description,
        color: const Color(0xFFF97316),
        onTap: () {
          setState(() {
            selectedMenu = UserMenuType.resume;
            selectedResumeSubMenu = ResumeSubMenu.buildResume;
            _clearAllDetailViews();
          });
        },
      ),
      _QuickAction(
        title: 'AI Insights',
        icon: Icons.auto_awesome,
        color: const Color(0xFFFF6588),
        onTap: () {
          setState(() {
            selectedMenu = UserMenuType.ai;
            selectedAISubMenu = AISubMenu.dashboard;
            _clearAllDetailViews();
          });
        },
      ),
      _QuickAction(
        title: 'Edit Profile',
        icon: Icons.person,
        color: const Color(0xFF10B981),
        onTap: () {
          setState(() {
            selectedMenu = UserMenuType.profile;
            selectedProfileSubMenu = ProfileSubMenu.basicDetails;
            _clearAllDetailViews();
          });
        },
      ),
      _QuickAction(
        title: 'Services',
        icon: Icons.workspace_premium,
        color: const Color(0xFF8B5CF6),
        onTap: () {
          setState(() {
            selectedMenu = UserMenuType.services;
            selectedServiceSubMenu = ServiceSubMenu.browseServices;
            _clearAllDetailViews();
          });
        },
      ),
      // ✅ NEW: Schemes Quick Action
      _QuickAction(
        title: 'Schemes',
        icon: Icons.account_balance,
        color: const Color(0xFF059669),
        onTap: _goToBrowseSchemes,
      ),
      _QuickAction(
        title: 'Saved Jobs',
        icon: Icons.bookmark,
        color: const Color(0xFF0891B2),
        onTap: _goToSavedJobs,
      ),
      _QuickAction(
        title: 'Support',
        icon: Icons.support_agent,
        color: const Color(0xFFDC2626),
        onTap: () {
          setState(() {
            selectedMenu = UserMenuType.support;
            _clearAllDetailViews();
          });
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flash_on, color: Color(0xFF6C63FF), size: 22),
            SizedBox(width: 10),
            Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.9,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return GestureDetector(
              onTap: action.onTap,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      action.color.withOpacity(0.08),
                      action.color.withOpacity(0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: action.color.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: action.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        action.icon,
                        color: action.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        action.title,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // SCORE HELPERS
  // ============================================================
  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 60) return const Color(0xFF6C63FF);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getCareerScoreLabel(int score) {
    if (score >= 80) return "🚀 Excellent Career Readiness";
    if (score >= 60) return "⭐ Good Career Foundation";
    if (score >= 40) return "📈 Developing Your Profile";
    return "🌱 Start Building Your Profile";
  }

  Color _getCompletionColor(int percent) {
    if (percent >= 80) return const Color(0xFF10B981);
    if (percent >= 60) return const Color(0xFF6C63FF);
    if (percent >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getCompletionLabel(int percent) {
    if (percent >= 80) return "✅ Profile Complete";
    if (percent >= 60) return "🔵 Almost There";
    if (percent >= 40) return "🟠 Keep Going";
    return "🔴 Complete Your Profile";
  }

  // ============================================================
  // ✅ CHECK IF BACK BUTTON NEEDED (UPDATED — Includes schemes)
  // ============================================================
  bool _shouldShowBackButton() {
    // Job detail view
    if (_selectedJob != null) return true;
    // Application detail view
    if (_selectedApplication != null) return true;
    // Scheme detail view
    if (_showSchemeDetailView && _selectedSchemeId != null) return true;
    return false;
  }

  // ✅ Handle back button action
  void _handleBackButton() {
    setState(() {
      if (_selectedApplication != null) {
        _selectedApplication = null;
      } else if (_selectedJob != null) {
        _selectedJob = null;
      } else if (_showSchemeDetailView) {
        _closeSchemeDetailView();
      }
    });
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final showBackButton = _shouldShowBackButton();

    return Scaffold(
      key: _scaffoldKey,
      appBar: isMobile
          ? AppBar(
              title: Text(_getAppBarTitle()),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              leading: showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _handleBackButton,
                    )
                  : Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
              actions: [
                const LocationDisplay(),
                NotificationBell(
                  onJobAlertClicked: _goToBrowseJobs,
                  onApplicationStatusClicked: _goToJobApplications,
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      drawer: isMobile
          ? Drawer(
              child: UserSidebar(
                selectedMenu: selectedMenu,
                selectedJobSubMenu: selectedJobSubMenu,
                selectedServiceSubMenu: selectedServiceSubMenu,
                selectedResumeSubMenu: selectedResumeSubMenu,
                selectedSchemesSubMenu: selectedSchemesSubMenu,
                selectedAISubMenu: selectedAISubMenu,
                selectedProfileSubMenu: selectedProfileSubMenu,
                selectedSettingsSubMenu: selectedSettingsSubMenu,
                onMenuSelected: _onMenuSelected,
                onJobSubMenuSelected: _onJobSubMenuSelected,
                onServiceSubMenuSelected: _onServiceSubMenuSelected,
                onResumeSubMenuSelected: _onResumeSubMenuSelected,
                onSchemesSubMenuSelected: _onSchemesSubMenuSelected,
                onAISubMenuSelected: _onAISubMenuSelected,
                onProfileSubMenuSelected: _onProfileSubMenuSelected,
                onSettingsSubMenuSelected: _onSettingsSubMenuSelected,
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            UserSidebar(
              selectedMenu: selectedMenu,
              selectedJobSubMenu: selectedJobSubMenu,
              selectedServiceSubMenu: selectedServiceSubMenu,
              selectedResumeSubMenu: selectedResumeSubMenu,
              selectedSchemesSubMenu: selectedSchemesSubMenu,
              selectedAISubMenu: selectedAISubMenu,
              selectedProfileSubMenu: selectedProfileSubMenu,
              selectedSettingsSubMenu: selectedSettingsSubMenu,
              onMenuSelected: _onMenuSelected,
              onJobSubMenuSelected: _onJobSubMenuSelected,
              onServiceSubMenuSelected: _onServiceSubMenuSelected,
              onResumeSubMenuSelected: _onResumeSubMenuSelected,
              onSchemesSubMenuSelected: _onSchemesSubMenuSelected,
              onAISubMenuSelected: _onAISubMenuSelected,
              onProfileSubMenuSelected: _onProfileSubMenuSelected,
              onSettingsSubMenuSelected: _onSettingsSubMenuSelected,
            ),
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  if (!isMobile)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (showBackButton) ...[
                                IconButton(
                                  icon: const Icon(Icons.arrow_back,
                                      color: Colors.blueAccent),
                                  onPressed: _handleBackButton,
                                  tooltip: "Back",
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                _getAppBarTitle(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const LocationDisplay(),
                              NotificationBell(
                                onJobAlertClicked: _goToBrowseJobs,
                                onApplicationStatusClicked: _goToJobApplications,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: KeyedSubtree(
                        key: ValueKey(
                          'menu_${selectedMenu.name}_'
                          '${selectedJobSubMenu?.name ?? "none"}_'
                          '${selectedServiceSubMenu?.name ?? "none"}_'
                          '${selectedResumeSubMenu?.name ?? "none"}_'
                          '${selectedSchemesSubMenu?.name ?? "none"}_'
                          '${selectedAISubMenu?.name ?? "none"}_'
                          '${selectedProfileSubMenu?.name ?? "none"}_'
                          '${selectedSettingsSubMenu?.name ?? "none"}_'
                          '${_selectedJob != null ? _selectedJob!['_id'] : 'none'}_'
                          '${_selectedApplication != null ? _selectedApplication!['_id'] : 'none'}_'
                          '${_selectedSchemeId ?? "none"}_'
                          '$_showSchemeDetailView',
                        ),
                        child: _getContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    // ✅ If scheme detail is open
    if (_showSchemeDetailView && _selectedSchemeId != null) {
      return _selectedSchemeName ?? "योजना विवरण";
    }

    // ✅ If application detail is open
    if (_selectedApplication != null &&
        selectedMenu == UserMenuType.jobs &&
        selectedJobSubMenu == JobSubMenu.jobApplications) {
      return _selectedApplication!['job_title']?.toString() ??
          "Application Details";
    }

    // ✅ If job is selected
    if (_selectedJob != null && selectedMenu == UserMenuType.jobs) {
      return _selectedJob!['post_name']?.toString() ?? "Job Details";
    }

    switch (selectedMenu) {
      case UserMenuType.dashboard:
        return "Dashboard";

      case UserMenuType.jobs:
        if (selectedJobSubMenu == JobSubMenu.jobApplications) {
          return "My Applications";
        }
        if (selectedJobSubMenu == JobSubMenu.browseJobs) {
          return "Browse Jobs";
        }
        return "Jobs";

      case UserMenuType.services:
        if (selectedServiceSubMenu == ServiceSubMenu.myApplications) {
          return "My Service Applications";
        }
        if (selectedServiceSubMenu == ServiceSubMenu.browseServices) {
          return "Online Services";
        }
        return "Services";

      case UserMenuType.resume:
        switch (selectedResumeSubMenu) {
          case ResumeSubMenu.buildResume:
            return "Build Resume";
          case ResumeSubMenu.viewResume:
            return "My Resume";
          case ResumeSubMenu.atsScore:
            return "ATS Score";
          case ResumeSubMenu.aiGenerator:
            return "AI Resume Generator";
          case null:
            return "Resume";
        }

      case UserMenuType.schemes:
        switch (selectedSchemesSubMenu) {
          case SchemesSubMenu.browseSchemes:
            return "सरकारी योजनाएं";
          case SchemesSubMenu.schemeApplications:
            return "मेरे योजना आवेदन";
          case null:
            return "सरकारी योजनाएं";
        }

      case UserMenuType.ai:
        switch (selectedAISubMenu) {
          case AISubMenu.dashboard:
            return "AI Insights";
          case AISubMenu.careerRoadmap:
            return "Career Roadmap";
          case null:
            return "AI";
        }

      case UserMenuType.profile:
        switch (selectedProfileSubMenu) {
          case ProfileSubMenu.basicDetails:
            return "Basic Details";
          case ProfileSubMenu.education:
            return "Education";
          case ProfileSubMenu.experience:
            return "Experience";
          case ProfileSubMenu.advancedDetails:
            return "Advanced Details";
          case ProfileSubMenu.documents:
            return "Documents";
          case null:
            return "Profile";
        }

      case UserMenuType.support:
        return "Support";

      case UserMenuType.settings:
        switch (selectedSettingsSubMenu) {
          case SettingsSubMenu.changePassword:
            return "Change Password";
          case SettingsSubMenu.setupMpin:
            return "Setup MPIN";
          case SettingsSubMenu.fingerprint:
            return "Fingerprint Setup";
          case null:
            return "Settings";
        }
    }
  }
}

// ============================================================
// ✅ Resume launcher widget — wraps resume screens and
//    triggers dashboard refresh after generation.
// ============================================================
class _ResumeLauncher extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onGenerated;

  const _ResumeLauncher({
    required this.child,
    required this.onGenerated,
  });

  @override
  State<_ResumeLauncher> createState() => _ResumeLauncherState();
}

class _ResumeLauncherState extends State<_ResumeLauncher> {
  @override
  void initState() {
    super.initState();
    // Silently refresh on open (in case user already had a resume)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.onGenerated();
      } catch (e) {
        debugPrint("⚠️ ResumeLauncher post-frame refresh failed: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ============================================================
// HELPER MODELS
// ============================================================
class _BreakdownItem {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  _BreakdownItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _SectionItem {
  final String label;
  final bool done;
  final IconData icon;

  _SectionItem({
    required this.label,
    required this.done,
    required this.icon,
  });
}

class _QuickAction {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}