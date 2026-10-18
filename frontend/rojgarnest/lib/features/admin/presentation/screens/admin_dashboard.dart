// lib/features/admin/presentation/screens/admin_dashboard.dart
// ✅ COMPLETE UPDATED VERSION
// ✅ REMOVED: Reports menu handling
// ✅ REMOVED: Users menu handling
// ✅ PRESERVED: Settings submenu (Change Password, Setup MPIN, Fingerprint)
// ✅ Application Management: Only "All Applications"
// ✅ AI-BASED FAST DASHBOARD (like User Dashboard)
// ✅ All original functionality preserved

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rojgarnest/features/admin/presentation/widgets/admin_sidebar.dart';
import 'package:rojgarnest/features/admin/presentation/models/admin_menu.dart';
import 'package:rojgarnest/features/notification/widgets/notification_bell.dart';
import 'package:rojgarnest/features/common/widgets/location_display.dart';
import 'package:rojgarnest/features/admin/data/admin_service.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';

// ==================== UNIFIED SCREENS ====================
import 'package:rojgarnest/features/jobs/presentation/screens/add_job_screen.dart';
import 'package:rojgarnest/features/jobs/presentation/screens/show_jobs_screen.dart';
import 'package:rojgarnest/features/jobs/presentation/screens/applications_screen.dart';
import 'package:rojgarnest/features/jobs/presentation/screens/candidate_profile_screen.dart';

// ✅ AUTH SCREENS IMPORT - Same as User Dashboard
import 'package:rojgarnest/features/auth/presentation/screens/change_password_screen.dart';
import 'package:rojgarnest/features/auth/presentation/screens/mpin_setup_page.dart';
import 'package:rojgarnest/features/auth/presentation/screens/fingerprint_setup_page.dart';

// ❌ REMOVED IMPORTS:
// - admin_reports_screen.dart (Reports removed)
// - admin_users_screen.dart (Users removed)

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // ==================== STATE ====================
  AdminMenuType selectedMenu = AdminMenuType.dashboard;
  JobSubMenu selectedJobSubMenu = JobSubMenu.allJobs;
  ApplicationSubMenu selectedAppSubMenu = ApplicationSubMenu.allApplications;
  SettingsSubMenu selectedSettingsSubMenu = SettingsSubMenu.changePassword;

  // ==================== DASHBOARD DATA ====================
  Map<String, dynamic> _dashboardStats = {};
  bool _isLoading = true;
  bool _isDataReady = false;
  String _adminName = 'Admin';

  // ==================== CACHED EMAIL FOR SETTINGS ====================
  String? _cachedEmail;
  bool _emailLoaded = false;

  // ==================== CANDIDATE PROFILE ====================
  bool _showCandidateProfileView = false;
  String? _candidateEmail;
  String? _candidateName;

  // ==================== DRAWER ====================
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ==================== CACHE KEY ====================
  static const String _cacheKey = 'admin_dashboard_cache';

  // ============================================================
  // LIFECYCLE
  // ============================================================
  @override
  void initState() {
    super.initState();
    // ✅ Load from cache IMMEDIATELY
    _loadFromCacheSync();
    // ✅ Refresh in background
    _refreshInBackground();
    // ✅ Load email ONCE for settings pages
    _loadEmail();
  }

  // ============================================================
  // ✅ SYNC CACHE LOAD - ZERO DELAY (< 10ms)
  // ============================================================
  void _loadFromCacheSync() {
    try {
      SharedPreferences.getInstance().then((pref) {
        final cached = pref.getString(_cacheKey);
        if (cached != null) {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _dashboardStats = data['stats'] ?? {};
              _adminName = data['adminName'] ?? 'Admin';
              _isDataReady = true;
              _isLoading = false;
            });
          }
          debugPrint("✅ Admin Dashboard loaded from CACHE in < 10ms!");
          return;
        }

        // No cache - show defaults
        if (mounted) {
          setState(() {
            _isDataReady = true;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint("⚠️ Admin cache read error: $e");
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
          if (email != null && email.isNotEmpty) {
            _adminName = email.split('@').first;
          }
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
  // ✅ BACKGROUND REFRESH - Silently updates data
  // ============================================================
  Future<void> _refreshInBackground() async {
    try {
      final response = await AdminService.getAIDashboard();

      if (!mounted) return;

      setState(() {
        _dashboardStats = response;
        _isDataReady = true;
        _isLoading = false;
      });

      // ✅ Cache the data
      await _cacheDashboardData();
      debugPrint("✅ Admin Dashboard background refresh complete!");
    } catch (e) {
      debugPrint("❌ Admin background refresh error: $e");
      if (mounted) {
        setState(() {
          _isDataReady = true;
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // ✅ CACHE HELPER
  // ============================================================
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
      debugPrint("⚠️ Admin cache save error: $e");
    }
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isLoading = true);
    await _refreshInBackground();
  }

  // ============================================================
  // ✅ CANDIDATE PROFILE
  // ============================================================
  void _openCandidateProfileFromApplication(Map<String, dynamic> application) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    setState(() {
      _candidateEmail = application['applicant_email'];
      _candidateName = application['applicant_name'] ?? 'Candidate';
      _showCandidateProfileView = true;
    });
  }

  void _closeCandidateProfile() {
    setState(() {
      _showCandidateProfileView = false;
      _candidateEmail = null;
      _candidateName = null;
    });
  }

  // ============================================================
  // ✅ NOTIFICATION NAVIGATION
  // ============================================================
  void _navigateToJobsFromNotification() {
    debugPrint("🔔 ADMIN: Navigating to Job Management > All Jobs");
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _closeCandidateProfile();
        setState(() {
          selectedMenu = AdminMenuType.jobManagement;
          selectedJobSubMenu = JobSubMenu.allJobs;
          _showCandidateProfileView = false;
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
        "🔔 ADMIN: Navigating to Application Management > All Applications");
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _closeCandidateProfile();
        setState(() {
          selectedMenu = AdminMenuType.applicationManagement;
          selectedAppSubMenu = ApplicationSubMenu.allApplications;
          _showCandidateProfileView = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📋 Navigating to Application Management..."),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  // ============================================================
  // ✅ MENU SELECTION WITH DRAWER CLOSE
  // ============================================================
  void _onMenuSelected(AdminMenuType menu) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = menu;
          _showCandidateProfileView = false;
          if (menu == AdminMenuType.settings) {
            selectedSettingsSubMenu = SettingsSubMenu.changePassword;
          }
        });
      }
    });
  }

  void _onJobSubMenuSelected(JobSubMenu subMenu) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = AdminMenuType.jobManagement;
          selectedJobSubMenu = subMenu;
          _showCandidateProfileView = false;
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
          selectedMenu = AdminMenuType.applicationManagement;
          selectedAppSubMenu = subMenu;
          _showCandidateProfileView = false;
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
          selectedMenu = AdminMenuType.settings;
          selectedSettingsSubMenu = subMenu;
          _showCandidateProfileView = false;
        });
      }
    });
  }

  // ============================================================
  // ✅ SETTINGS SCREEN (Same as User Dashboard - Auth folder)
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
          key: const ValueKey('admin_mpin_setup_page'),
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
          key: const ValueKey('admin_fingerprint_setup_page'),
          email: _cachedEmail!,
        );
    }
  }

  // ============================================================
  // ✅ GET CONTENT
  // ============================================================
  Widget _getContent() {
    if (_showCandidateProfileView && _candidateEmail != null) {
      return CandidateProfileScreen(
        email: _candidateEmail!,
        candidateName: _candidateName ?? 'Candidate',
        onBack: _closeCandidateProfile,
      );
    }

    switch (selectedMenu) {
      case AdminMenuType.dashboard:
        return _buildDashboardContent();

      case AdminMenuType.jobManagement:
        if (selectedJobSubMenu == JobSubMenu.addNewJob) {
          return AddJobScreen(
            adminRole: 'admin',
            onJobAdded: _refreshDashboard,
          );
        }
        return ShowJobsScreen(
          adminRole: 'admin',
          onJobDeleted: _refreshDashboard,
          onJobUpdated: _refreshDashboard,
        );

      case AdminMenuType.applicationManagement:
        // ✅ ONLY All Applications
        return ApplicationsScreen(
          adminRole: 'admin',
          filterStatus: 'all',
          onViewCandidateProfile: _openCandidateProfileFromApplication,
        );

      // ❌ REMOVED: manageUsers case
      // ❌ REMOVED: reports case

      case AdminMenuType.settings:
        return _getSettingsScreen();
    }
  }

  // ============================================================
  // ✅ AI-BASED DASHBOARD CONTENT (FAST + BEAUTIFUL)
  // ============================================================
  Widget _buildDashboardContent() {
    final greeting = _getGreetingMessage();

    // Extract stats
    final totalJobs = _dashboardStats['admin_jobs_count'] ?? 0;
    final totalApps = _dashboardStats['total_applications'] ?? 0;
    final pending = _dashboardStats['pending_applications'] ?? 0;
    final shortlisted = _dashboardStats['shortlisted_applications'] ?? 0;
    final interview = _dashboardStats['interview_applications'] ?? 0;
    final offered = _dashboardStats['offered_applications'] ?? 0;
    final rejected = _dashboardStats['rejected_applications'] ?? 0;
    final avgMatch = _dashboardStats['average_ai_match'] ?? 0;
    final recent7d = _dashboardStats['recent_applications_7d'] ?? 0;
    final topJobs = _dashboardStats['top_job_categories'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================== AI HEADER ====================
          _buildAIHeader(greeting, totalJobs, totalApps),
          const SizedBox(height: 20),

          // ==================== STATS ROW 1 ====================
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Total Jobs",
                  totalJobs.toString(),
                  Icons.work,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Applications",
                  totalApps.toString(),
                  Icons.assignment,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Pending",
                  pending.toString(),
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ==================== STATS ROW 2 ====================
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Shortlisted",
                  shortlisted.toString(),
                  Icons.star,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Interview",
                  interview.toString(),
                  Icons.people,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Offered",
                  offered.toString(),
                  Icons.celebration,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ==================== STATS ROW 3 ====================
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Rejected",
                  rejected.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Avg AI Match",
                  "$avgMatch%",
                  Icons.auto_awesome,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  "Recent (7d)",
                  recent7d.toString(),
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ==================== QUICK ACTIONS ====================
          _buildQuickActionsGrid(),
          const SizedBox(height: 20),

          // ==================== TOP JOBS ====================
          _buildTopJobsCard(topJobs),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ AI HEADER
  // ============================================================
  Widget _buildAIHeader(String greeting, int totalJobs, int totalApps) {
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

  // ============================================================
  // ✅ STAT CARD
  // ============================================================
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

  // ============================================================
  // ✅ QUICK ACTIONS GRID
  // ============================================================
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
                selectedMenu = AdminMenuType.jobManagement;
                selectedJobSubMenu = JobSubMenu.addNewJob;
                _showCandidateProfileView = false;
              });
            }
          });
        },
      },
      {
        'title': 'All Jobs',
        'icon': Icons.list,
        'color': Colors.blue,
        'onTap': () {
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            Navigator.of(context).pop();
          }
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                selectedMenu = AdminMenuType.jobManagement;
                selectedJobSubMenu = JobSubMenu.allJobs;
                _showCandidateProfileView = false;
              });
            }
          });
        },
      },
      {
        'title': 'Applications',
        'icon': Icons.assignment,
        'color': Colors.orange,
        'onTap': () {
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            Navigator.of(context).pop();
          }
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                selectedMenu = AdminMenuType.applicationManagement;
                selectedAppSubMenu = ApplicationSubMenu.allApplications;
                _showCandidateProfileView = false;
              });
            }
          });
        },
      },
      {
        'title': 'Settings',
        'icon': Icons.settings,
        'color': Colors.purple,
        'onTap': () {
          if (_scaffoldKey.currentState?.isDrawerOpen == true) {
            Navigator.of(context).pop();
          }
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                selectedMenu = AdminMenuType.settings;
                selectedSettingsSubMenu = SettingsSubMenu.changePassword;
                _showCandidateProfileView = false;
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
            Icon(Icons.dashboard, color: Color(0xFF6C63FF), size: 22),
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

  // ============================================================
  // ✅ TOP JOBS CARD
  // ============================================================
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
              Icon(Icons.trending_up, color: Color(0xFF6C63FF), size: 22),
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
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.work, color: Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            job['category']?.toString() ?? 'Job',
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
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${job['count'] ?? 0} apps",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
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
    final isShowingProfile = _showCandidateProfileView;

    return Scaffold(
      key: _scaffoldKey,
      appBar: isMobile
          ? AppBar(
              title: Text(
                  isShowingProfile ? "Candidate Profile" : _getAppBarTitle()),
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
              child: AdminSidebar(
                selectedMenu: selectedMenu,
                selectedJobSubMenu: selectedJobSubMenu,
                selectedAppSubMenu: selectedAppSubMenu,
                selectedSettingsSubMenu: selectedSettingsSubMenu,
                onMenuSelected: _onMenuSelected,
                onJobSubMenuSelected: _onJobSubMenuSelected,
                onApplicationSubMenuSelected: _onApplicationSubMenuSelected,
                onSettingsSubMenuSelected: _onSettingsSubMenuSelected,
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            AdminSidebar(
              selectedMenu: selectedMenu,
              selectedJobSubMenu: selectedJobSubMenu,
              selectedAppSubMenu: selectedAppSubMenu,
              selectedSettingsSubMenu: selectedSettingsSubMenu,
              onMenuSelected: _onMenuSelected,
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
                          'menu_${selectedMenu.name}_${selectedJobSubMenu.name}_${selectedAppSubMenu.name}_${selectedSettingsSubMenu.name}_$isShowingProfile',
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
    if (selectedMenu == AdminMenuType.settings) {
      switch (selectedSettingsSubMenu) {
        case SettingsSubMenu.changePassword:
          return "Change Password";
        case SettingsSubMenu.setupMpin:
          return "Setup MPIN";
        case SettingsSubMenu.fingerprint:
          return "Fingerprint Setup";
      }
    }
    return "Admin Dashboard";
  }
}