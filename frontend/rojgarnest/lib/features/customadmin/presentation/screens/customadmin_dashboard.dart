// lib/features/customadmin/presentation/screens/customadmin_dashboard.dart
// ✅ COMPLETE UPDATED VERSION
// ✅ NEW: Added Scheme Applications submenu under Application Management
// ✅ Shows job applications, service applications, AND scheme applications
// ✅ AI-BASED FAST DASHBOARD (matches Admin Dashboard)
// ✅ Cache-first loading for ultra-fast performance
// ✅ Parent menu click ONLY expands sidebar — never changes right-side content
// ✅ Right-side content changes ONLY when a submenu is tapped
// ✅ PRESERVED: Settings submenu (Change Password, Setup MPIN, Fingerprint)
// ✅ FIXED: _onDashboardSelected now accepts CustomAdminMenu (matches sidebar)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rojgarnest/features/customadmin/presentation/widgets/customadmin_sidebar.dart';
import 'package:rojgarnest/features/notification/widgets/notification_bell.dart';
import 'package:rojgarnest/features/customadmin/data/customadmin_service.dart';
import 'package:rojgarnest/features/common/widgets/location_display.dart';
import 'package:rojgarnest/features/jobs/presentation/screens/candidate_profile_screen.dart';

// ==================== UNIFIED SCREENS ====================
import 'package:rojgarnest/features/jobs/presentation/screens/add_job_screen.dart';
import 'package:rojgarnest/features/jobs/presentation/screens/show_jobs_screen.dart';
import 'package:rojgarnest/features/jobs/presentation/screens/applications_screen.dart';

// ✅ SERVICE SCREEN IMPORT
import 'package:rojgarnest/features/services/presentation/screens/service_application_screen.dart';

// ✅ NEW: SCHEME APPLICATION SCREEN IMPORT
import 'package:rojgarnest/features/schemes/presentation/screens/customadmin_scheme_applications_screen.dart';

// ✅ AUTH SCREENS IMPORT
import 'package:rojgarnest/features/auth/presentation/screens/change_password_screen.dart';
import 'package:rojgarnest/features/auth/presentation/screens/mpin_setup_page.dart';
import 'package:rojgarnest/features/auth/presentation/screens/fingerprint_setup_page.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';

// ===============================================================
// ENUMS
// ===============================================================

enum CustomAdminMenu {
  dashboard,
  jobManagement,
  applicationManagement,
  settings,
}

enum JobSubMenu { allJobs, addNewJob }

// ✅ UPDATED: Added schemeApplications
enum ApplicationSubMenu {
  jobApplications,
  serviceApplications,
  schemeApplications, // ✅ NEW
}

enum SettingsSubMenu {
  changePassword,
  setupMpin,
  fingerprint,
}

// ===============================================================
// DASHBOARD WIDGET
// ===============================================================

class CustomAdminDashboard extends StatefulWidget {
  const CustomAdminDashboard({super.key});

  @override
  State<CustomAdminDashboard> createState() => _CustomAdminDashboardState();
}

class _CustomAdminDashboardState extends State<CustomAdminDashboard> {
  // ==================== STATE ====================
  CustomAdminMenu selectedMenu = CustomAdminMenu.dashboard;

  // ✅ NULLABLE — no submenu auto-selected
  JobSubMenu? selectedJobSubMenu;
  ApplicationSubMenu? selectedAppSubMenu;
  SettingsSubMenu? selectedSettingsSubMenu;

  // ==================== DASHBOARD DATA ====================
  Map<String, dynamic>? _dashboardStats;
  bool _isLoading = true;
  bool _isDataReady = false;
  String _adminName = 'Custom Admin';

  // ==================== CACHED EMAIL FOR SETTINGS ====================
  String? _adminEmail;
  bool _emailLoaded = false;

  // ==================== CANDIDATE PROFILE ====================
  bool _showCandidateProfile = false;
  String? _candidateEmail;
  String? _candidateName;

  // ==================== DRAWER ====================
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ==================== CACHE KEY ====================
  static const String _cacheKey = 'customadmin_dashboard_cache';

  // ============================================================
  // LIFECYCLE
  // ============================================================
  @override
  void initState() {
    super.initState();
    _loadFromCacheSync();
    _refreshInBackground();
    _loadAdminEmail();
  }

  // ============================================================
  // ✅ SYNC CACHE LOAD
  // ============================================================
  void _loadFromCacheSync() {
    try {
      SharedPreferences.getInstance().then((pref) {
        final cached = pref.getString(_cacheKey);
        if (cached != null) {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _dashboardStats = data['stats'] != null
                  ? Map<String, dynamic>.from(data['stats'])
                  : null;
              _adminName = data['adminName'] ?? 'Custom Admin';
              _isDataReady = true;
              _isLoading = false;
            });
          }
          debugPrint("✅ CustomAdmin Dashboard loaded from CACHE in < 10ms!");
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
      debugPrint("⚠️ CustomAdmin cache read error: $e");
      if (mounted) {
        setState(() {
          _isDataReady = true;
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // ✅ LOAD ADMIN EMAIL ONCE
  // ============================================================
  Future<void> _loadAdminEmail() async {
    try {
      final email = await SecureStorage.getEmail();
      if (mounted) {
        setState(() {
          _adminEmail = email;
          _emailLoaded = true;
          if (email != null && email.isNotEmpty) {
            _adminName = email.split('@').first;
          }
        });
        debugPrint("📧 CustomAdmin Email loaded: $_adminEmail");
      }
    } catch (e) {
      debugPrint('⚠️ _loadAdminEmail error: $e');
      if (mounted) {
        setState(() {
          _adminEmail = null;
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
      final stats = await CustomAdminService.getStats();

      if (!mounted) return;

      setState(() {
        _dashboardStats = stats;
        _isDataReady = true;
        _isLoading = false;
      });

      await _cacheDashboardData();
      debugPrint("✅ CustomAdmin Dashboard background refresh complete!");
    } catch (e) {
      debugPrint("❌ CustomAdmin background refresh error: $e");
      if (mounted) {
        setState(() {
          _isDataReady = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cacheDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'stats': _dashboardStats,
          'adminName': _adminName,
        }),
      );
      await prefs.setInt(
          '${_cacheKey}_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("⚠️ CustomAdmin cache save error: $e");
    }
  }

  void _refreshDashboard() {
    setState(() => _isLoading = true);
    _refreshInBackground();
  }

  // ============================================================
  // ✅ CANDIDATE PROFILE
  // ============================================================
  void _showCandidateProfileFromApplication(Map<String, dynamic> application) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    setState(() {
      _candidateEmail = application['applicant_email'];
      _candidateName = application['applicant_name'] ?? 'Candidate';
      _showCandidateProfile = true;
    });
  }

  void _closeCandidateProfile() {
    setState(() {
      _showCandidateProfile = false;
      _candidateEmail = null;
      _candidateName = null;
    });
  }

  // ============================================================
  // ✅ NOTIFICATION NAVIGATION
  // ============================================================
  void _navigateToJobsFromNotification() {
    debugPrint("🔔 CUSTOM ADMIN: Navigating to Job Management > All Jobs");
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _closeCandidateProfile();
        setState(() {
          selectedMenu = CustomAdminMenu.jobManagement;
          selectedJobSubMenu = JobSubMenu.allJobs;
          _showCandidateProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📋 Navigating to Job Management > All Jobs..."),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _navigateToApplicationsFromNotification() {
    debugPrint(
        "🔔 CUSTOM ADMIN: Navigating to Application Management > Service Applications");
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _closeCandidateProfile();
        setState(() {
          selectedMenu = CustomAdminMenu.applicationManagement;
          selectedAppSubMenu = ApplicationSubMenu.serviceApplications;
          _showCandidateProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📋 Navigating to Service Applications..."),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  // ============================================================
  // ✅ SUBMENU HANDLERS — these are the ONLY ones that change content
  // ============================================================
  void _onJobSubMenuSelected(JobSubMenu subMenu) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = CustomAdminMenu.jobManagement;
          selectedJobSubMenu = subMenu;
          _showCandidateProfile = false;
        });
      }
    });
  }

  void _onApplicationSubMenuSelected(ApplicationSubMenu subMenu) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = CustomAdminMenu.applicationManagement;
          selectedAppSubMenu = subMenu;
          _showCandidateProfile = false;
        });
      }
    });
  }

  void _onSettingsSubMenuSelected(SettingsSubMenu subMenu) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = CustomAdminMenu.settings;
          selectedSettingsSubMenu = subMenu;
          _showCandidateProfile = false;
        });
      }
    });
  }

  // ============================================================
  // ✅ DASHBOARD MENU HANDLER
  // ============================================================
  void _onDashboardSelected(CustomAdminMenu menu) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = menu;
          _showCandidateProfile = false;
        });
      }
    });
  }

  // ============================================================
  // GET SETTINGS SCREEN
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
        if (_adminEmail == null || _adminEmail!.isEmpty) {
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
          key: const ValueKey('customadmin_mpin_setup_page'),
          email: _adminEmail!,
        );

      case SettingsSubMenu.fingerprint:
        if (!_emailLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_adminEmail == null || _adminEmail!.isEmpty) {
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
          key: const ValueKey('customadmin_fingerprint_setup_page'),
          email: _adminEmail!,
        );

      case null:
        return const ChangePasswordScreen(
          isForgotFlow: false,
          isEmbedded: true,
        );
    }
  }

  // ============================================================
  // ✅ GET CONTENT
  // ============================================================
  Widget _getContent() {
    if (_showCandidateProfile && _candidateEmail != null) {
      return CandidateProfileScreen(
        email: _candidateEmail!,
        candidateName: _candidateName ?? 'Candidate',
        onBack: _closeCandidateProfile,
      );
    }

    switch (selectedMenu) {
      case CustomAdminMenu.dashboard:
        return _buildDashboardContent();

      case CustomAdminMenu.jobManagement:
        if (selectedJobSubMenu == JobSubMenu.addNewJob) {
          return AddJobScreen(
            adminRole: 'customadmin',
            onJobAdded: _refreshDashboard,
          );
        }
        return ShowJobsScreen(
          adminRole: 'customadmin',
          onJobDeleted: _refreshDashboard,
          onJobUpdated: _refreshDashboard,
        );

      case CustomAdminMenu.applicationManagement:
        // ✅ Job Applications
        if (selectedAppSubMenu == ApplicationSubMenu.jobApplications) {
          return ApplicationsScreen(
            adminRole: 'customadmin',
            filterStatus: 'all',
            onViewCandidateProfile: _showCandidateProfileFromApplication,
          );
        }
        // ✅ Service Applications
        else if (selectedAppSubMenu ==
            ApplicationSubMenu.serviceApplications) {
          return const ServiceApplicationScreen();
        }
        // ✅ NEW: Scheme Applications
        else if (selectedAppSubMenu ==
            ApplicationSubMenu.schemeApplications) {
          return const CustomAdminSchemeApplicationsScreen();
        }
        // Default fallback
        return ApplicationsScreen(
          adminRole: 'customadmin',
          filterStatus: 'all',
          onViewCandidateProfile: _showCandidateProfileFromApplication,
        );

      case CustomAdminMenu.settings:
        return _getSettingsScreen();
    }
  }

  // ============================================================
  // ✅ AI-BASED DASHBOARD CONTENT
  // ============================================================
  Widget _buildDashboardContent() {
    final greeting = _getGreetingMessage();

    final stats = _dashboardStats;
    final totalJobs = stats?['total_jobs'] ?? 0;
    final totalApps = stats?['total_applications'] ?? 0;
    final pending = stats?['pending_applications'] ?? 0;
    final shortlisted = stats?['shortlisted_applications'] ?? 0;
    final interview = stats?['interview_applications'] ?? 0;
    final offered = stats?['offered_applications'] ?? 0;
    final rejected = stats?['rejected_applications'] ?? 0;
    final avgMatch = stats?['avg_match_score'] ?? 0;
    final recent7d = stats?['recent_applications_7d'] ?? 0;
    final topJobs = stats?['top_jobs'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIHeader(greeting),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Total Jobs",
                  totalJobs.toString(),
                  Icons.work_rounded,
                  const Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Applications",
                  totalApps.toString(),
                  Icons.assignment_rounded,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Pending",
                  pending.toString(),
                  Icons.hourglass_empty_rounded,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Shortlisted",
                  shortlisted.toString(),
                  Icons.star_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Interview",
                  interview.toString(),
                  Icons.people_rounded,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Offered",
                  offered.toString(),
                  Icons.celebration_rounded,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Rejected",
                  rejected.toString(),
                  Icons.cancel_rounded,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Avg AI Match",
                  "$avgMatch%",
                  Icons.auto_awesome_rounded,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Recent (7d)",
                  recent7d.toString(),
                  Icons.trending_up_rounded,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildQuickActionsGrid(),
          const SizedBox(height: 20),

          _buildTopJobsCard(topJobs),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAIHeader(String greeting) {
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$greeting, $_adminName!",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage jobs, applications, and track progress",
                  style: TextStyle(
                    fontSize: 13,
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final List<Map<String, dynamic>> actions = [
      {
        'title': 'Add Job',
        'icon': Icons.add_circle,
        'color': Colors.green,
        'onTap': () {
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            Navigator.of(context).pop();
          }
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                selectedMenu = CustomAdminMenu.jobManagement;
                selectedJobSubMenu = JobSubMenu.addNewJob;
                _showCandidateProfile = false;
              });
            }
          });
        },
      },
      {
        'title': 'All Jobs',
        'icon': Icons.list_rounded,
        'color': const Color(0xFF6C63FF),
        'onTap': () {
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            Navigator.of(context).pop();
          }
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                selectedMenu = CustomAdminMenu.jobManagement;
                selectedJobSubMenu = JobSubMenu.allJobs;
                _showCandidateProfile = false;
              });
            }
          });
        },
      },
      {
        'title': 'Job Apps',
        'icon': Icons.work_rounded,
        'color': Colors.blue,
        'onTap': () {
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            Navigator.of(context).pop();
          }
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                selectedMenu = CustomAdminMenu.applicationManagement;
                selectedAppSubMenu = ApplicationSubMenu.jobApplications;
                _showCandidateProfile = false;
              });
            }
          });
        },
      },
      {
        'title': 'Service Apps',
        'icon': Icons.workspace_premium_rounded,
        'color': Colors.purple,
        'onTap': () {
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            Navigator.of(context).pop();
          }
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                selectedMenu = CustomAdminMenu.applicationManagement;
                selectedAppSubMenu = ApplicationSubMenu.serviceApplications;
                _showCandidateProfile = false;
              });
            }
          });
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.dashboard_rounded, color: Color(0xFF6C63FF), size: 22),
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
            final color = action['color'] as Color;
            return GestureDetector(
              onTap: action['onTap'] as VoidCallback,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.08),
                      color.withOpacity(0.02)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        action['icon'] as IconData,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action['title'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildTopJobsCard(List<dynamic> topJobs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  color: Color(0xFF6C63FF), size: 22),
              SizedBox(width: 10),
              Text(
                "Top Jobs by Applications",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (topJobs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  "No applications yet",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...topJobs.take(5).map(
                  (job) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6C63FF).withOpacity(0.15),
                                const Color(0xFF6C63FF).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.work_rounded,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            job['title']?.toString() ??
                                job['category']?.toString() ??
                                'Job',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6C63FF).withOpacity(0.15),
                                const Color(0xFF6C63FF).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${job['applications'] ?? job['count'] ?? 0} apps",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C63FF),
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

  // ============================================================
  // ✅ MAIN BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final isShowingProfile = _showCandidateProfile;

    return Scaffold(
      key: _scaffoldKey,
      appBar: isMobile
          ? AppBar(
              title: Text(
                isShowingProfile
                    ? "Candidate Profile"
                    : _getAppBarTitle(),
              ),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              leading: isShowingProfile
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _closeCandidateProfile,
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
                  onJobAlertClicked: _navigateToJobsFromNotification,
                  onApplicationStatusClicked:
                      _navigateToApplicationsFromNotification,
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      drawer: isMobile
          ? Drawer(
              child: CustomAdminSidebar(
                selectedMenu: selectedMenu,
                selectedJobSubMenu: selectedJobSubMenu,
                selectedAppSubMenu: selectedAppSubMenu,
                selectedSettingsSubMenu: selectedSettingsSubMenu,
                onMenuSelected: _onDashboardSelected,
                onJobSubMenuSelected: _onJobSubMenuSelected,
                onApplicationSubMenuSelected: _onApplicationSubMenuSelected,
                onSettingsSubMenuSelected: _onSettingsSubMenuSelected,
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            CustomAdminSidebar(
              selectedMenu: selectedMenu,
              selectedJobSubMenu: selectedJobSubMenu,
              selectedAppSubMenu: selectedAppSubMenu,
              selectedSettingsSubMenu: selectedSettingsSubMenu,
              onMenuSelected: _onDashboardSelected,
              onJobSubMenuSelected: _onJobSubMenuSelected,
              onApplicationSubMenuSelected: _onApplicationSubMenuSelected,
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
                          Text(
                            isShowingProfile
                                ? "Candidate Profile: $_candidateName"
                                : _getAppBarTitle(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          Row(
                            children: [
                              const LocationDisplay(),
                              NotificationBell(
                                onJobAlertClicked:
                                    _navigateToJobsFromNotification,
                                onApplicationStatusClicked:
                                    _navigateToApplicationsFromNotification,
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
                          '${selectedAppSubMenu?.name ?? "none"}_'
                          '${selectedSettingsSubMenu?.name ?? "none"}_'
                          '$isShowingProfile',
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
    switch (selectedMenu) {
      case CustomAdminMenu.dashboard:
        return "Custom Admin Dashboard";
      case CustomAdminMenu.jobManagement:
        if (selectedJobSubMenu == JobSubMenu.allJobs) return "All Jobs";
        if (selectedJobSubMenu == JobSubMenu.addNewJob) return "Add New Job";
        return "Job Management";
      case CustomAdminMenu.applicationManagement:
        if (selectedAppSubMenu == ApplicationSubMenu.jobApplications) {
          return "Job Applications";
        }
        if (selectedAppSubMenu == ApplicationSubMenu.serviceApplications) {
          return "Service Applications";
        }
        if (selectedAppSubMenu == ApplicationSubMenu.schemeApplications) {
          return "Scheme Applications";
        }
        return "Application Management";
      case CustomAdminMenu.settings:
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