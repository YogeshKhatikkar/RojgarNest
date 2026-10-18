// lib/features/superadmin/presentation/screens/superadmin_dashboard.dart
// ✅ COMPLETE FIXED VERSION - With proper logout that preserves email
// ✅ Mobile Sidebar Auto-Hide Fix

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/routes/app_routes.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/notification/widgets/notification_bell.dart';
import 'package:rojgarnest/features/superadmin/presentation/widgets/superadmin_sidebar.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  Map<String, dynamic>? dashboardData;
  bool isLoading = true;
  String? errorMessage;

  // ==================== DRAWER STATE ====================
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ==================== SIDEBAR MENU STATE ====================
  SuperAdminMenu selectedMenu = SuperAdminMenu.dashboard;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final res = await DioClient.dio.get('/superadmin/ai-dashboard');
      if (mounted) {
        setState(() {
          dashboardData = res.data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
        showMessage(
          context,
          "Failed to load dashboard: ${e.toString()}",
          isError: true,
        );
      }
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadDashboard();
  }

  // ==================== MENU SELECTION WITH DRAWER CLOSE ====================

  void _onMenuSelected(SuperAdminMenu menu) {
    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          selectedMenu = menu;
        });
      }
    });
  }

  // ✅ FIXED: Use logout() instead of clear() to preserve email
  Future<void> logout(BuildContext context) async {
    await SecureStorage.logout();
    if (context.mounted) {
      context.go(AppRoutes.home);
    }
  }

  // ==================== NOTIFICATION NAVIGATION METHODS ====================

  void _navigateToJobsFromNotification() {
    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📋 Opening All Jobs..."),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _navigateToApplicationsFromNotification() {
    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📋 Opening All Applications..."),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Widget _getContent() {
    switch (selectedMenu) {
      case SuperAdminMenu.dashboard:
        return _buildDashboardContent();
      case SuperAdminMenu.users:
        return _buildUsersContent();
      case SuperAdminMenu.jobs:
        return _buildJobsContent();
      case SuperAdminMenu.applications:
        return _buildApplicationsContent();
      case SuperAdminMenu.reports:
        return _buildReportsContent();
      case SuperAdminMenu.settings:
        return _buildSettingsContent();
    }
  }

  Widget _buildDashboardContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Loading dashboard data...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "Failed to load dashboard",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Total Users",
                  _getValue('overview', 'total_users'),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Total Jobs",
                  _getValue('overview', 'total_jobs'),
                  Icons.work,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Total Applications",
                  _getValue('overview', 'total_applications'),
                  Icons.assignment,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Successful Placements",
                  _getValue('overview', 'successful_placements'),
                  Icons.celebration,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildHealthScoreCard(),
          const SizedBox(height: 24),
          _buildAiSummaryCard(),
          const SizedBox(height: 24),
          if (_hasRecommendations()) _buildRecommendationsCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.admin_panel_settings,
              size: 35,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome, Super Admin",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Platform Overview & Analytics",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScoreCard() {
    final dynamic healthScoreDynamic = dashboardData?['platform_health_score'];
    final int healthScore = healthScoreDynamic != null
        ? (healthScoreDynamic is int
            ? healthScoreDynamic
            : int.tryParse(healthScoreDynamic.toString()) ?? 0)
        : 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.health_and_safety,
                  size: 24,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Platform Health Score",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getHealthColor(healthScore).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getHealthStatus(healthScore),
                    style: TextStyle(
                      color: _getHealthColor(healthScore),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 12,
              child: LinearProgressIndicator(
                value: healthScore / 100,
                backgroundColor: Colors.grey.shade200,
                color: _getHealthColor(healthScore),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Poor",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  "$healthScore%",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _getHealthColor(healthScore),
                  ),
                ),
                const Text(
                  "Excellent",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSummaryCard() {
    final summary =
        dashboardData?['ai_executive_summary'] ?? 'No summary available';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Text(
                  "AI Executive Summary",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(summary, style: const TextStyle(height: 1.6, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    final recommendations = dashboardData!['recommendations'] as List;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lightbulb, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                const Text(
                  "AI Recommendations",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recommendations.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              "${entry.key + 1}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value.toString(),
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ==================== PLACEHOLDER CONTENT METHODS ====================

  Widget _buildUsersContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 80, color: Colors.blue),
          SizedBox(height: 16),
          Text(
            "User Management",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Manage all users on the platform",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work, size: 80, color: Colors.green),
          SizedBox(height: 16),
          Text(
            "Job Management",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "View and manage all jobs",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 80, color: Colors.orange),
          SizedBox(height: 16),
          Text(
            "Applications Management",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "View and manage all applications",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 80, color: Colors.purple),
          SizedBox(height: 16),
          Text(
            "Reports & Analytics",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "View platform reports and analytics",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "Settings",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Platform settings and configuration",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER METHODS ====================

  String _getValue(String section, String key) {
    final value = dashboardData?[section]?[key];
    if (value == null) return '0';
    return value.toString();
  }

  bool _hasRecommendations() {
    final recommendations = dashboardData?['recommendations'];
    return recommendations != null &&
        recommendations is List &&
        recommendations.isNotEmpty;
  }

  Color _getHealthColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getHealthStatus(int score) {
    if (score >= 80) return "Excellent";
    if (score >= 60) return "Good";
    if (score >= 40) return "Fair";
    return "Critical";
  }

  // ==================== MAIN BUILD ====================

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      key: _scaffoldKey, // ✅ Add key for drawer control
      appBar: isMobile
          ? AppBar(
              title: const Text("Super Admin Dashboard"),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              actions: [
                NotificationBell(
                  onJobAlertClicked: _navigateToJobsFromNotification,
                  onApplicationStatusClicked:
                      _navigateToApplicationsFromNotification,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshDashboard,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => logout(context),
                  tooltip: 'Logout',
                ),
              ],
            )
          : null,
      drawer: isMobile
          ? Drawer(
              child: SuperAdminSidebar(
                selectedMenu: selectedMenu,
                onMenuSelected: _onMenuSelected,
              ),
            )
          : null,
      body: Row(
        children: [
          // Desktop sidebar only
          if (!isMobile)
            SuperAdminSidebar(
              selectedMenu: selectedMenu,
              onMenuSelected: _onMenuSelected,
            ),
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  // Desktop top bar
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
                          const Text(
                            "Super Admin Panel",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          Row(
                            children: [
                              NotificationBell(
                                onJobAlertClicked:
                                    _navigateToJobsFromNotification,
                                onApplicationStatusClicked:
                                    _navigateToApplicationsFromNotification,
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _refreshDashboard,
                                tooltip: 'Refresh',
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout),
                                onPressed: () => logout(context),
                                tooltip: 'Logout',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshDashboard,
                      child: _getContent(),
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
}