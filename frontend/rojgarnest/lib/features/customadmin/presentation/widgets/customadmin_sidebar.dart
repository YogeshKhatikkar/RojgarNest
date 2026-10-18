// lib/features/customadmin/presentation/widgets/customadmin_sidebar.dart
// ✅ COMPLETE UPDATED VERSION
// ✅ NEW: Added Scheme Applications submenu under Application Management
// ✅ AI-BASED MODERN DESIGN
// ✅ Parent menu tap ONLY expands — never navigates.
// ✅ Right side changes ONLY when a submenu is tapped.
// ✅ ListTile warnings avoided (Material + InkWell everywhere)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnest/core/routes/app_routes.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import '../screens/customadmin_dashboard.dart';

class CustomAdminSidebar extends StatefulWidget {
  final CustomAdminMenu selectedMenu;
  final JobSubMenu? selectedJobSubMenu;
  final ApplicationSubMenu? selectedAppSubMenu;
  final SettingsSubMenu? selectedSettingsSubMenu;

  // ✅ Only Dashboard leaf calls this
  final Function(CustomAdminMenu) onMenuSelected;
  final Function(JobSubMenu) onJobSubMenuSelected;
  final Function(ApplicationSubMenu) onApplicationSubMenuSelected;
  final Function(SettingsSubMenu) onSettingsSubMenuSelected;

  const CustomAdminSidebar({
    super.key,
    required this.selectedMenu,
    required this.selectedJobSubMenu,
    required this.selectedAppSubMenu,
    required this.selectedSettingsSubMenu,
    required this.onMenuSelected,
    required this.onJobSubMenuSelected,
    required this.onApplicationSubMenuSelected,
    required this.onSettingsSubMenuSelected,
  });

  @override
  State<CustomAdminSidebar> createState() => _CustomAdminSidebarState();
}

class _CustomAdminSidebarState extends State<CustomAdminSidebar> {
  static const Color _primaryGradientStart = Color(0xFF6C63FF);
  static const Color _primaryGradientEnd = Color(0xFFFF6588);
  static const Color _selectedAccent = Color(0xFF6C63FF);

  bool _jobExpanded = false;
  bool _appExpanded = false;
  bool _settingsExpanded = false;

  @override
  void initState() {
    super.initState();
    _syncExpansionFromSelection();
  }

  @override
  void didUpdateWidget(covariant CustomAdminSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMenu != oldWidget.selectedMenu) {
      if (widget.selectedMenu == CustomAdminMenu.jobManagement) {
        _jobExpanded = true;
      }
      if (widget.selectedMenu == CustomAdminMenu.applicationManagement) {
        _appExpanded = true;
      }
      if (widget.selectedMenu == CustomAdminMenu.settings) {
        _settingsExpanded = true;
      }
    }
  }

  void _syncExpansionFromSelection() {
    _jobExpanded = widget.selectedMenu == CustomAdminMenu.jobManagement;
    _appExpanded = widget.selectedMenu == CustomAdminMenu.applicationManagement;
    _settingsExpanded = widget.selectedMenu == CustomAdminMenu.settings;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            const SizedBox(height: 30),

            // HEADER ICON
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryGradientStart, _primaryGradientEnd],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryGradientStart.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                size: 42,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              "Custom Admin",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryGradientStart.withOpacity(0.25),
                    _primaryGradientEnd.withOpacity(0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _primaryGradientStart.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified,
                    size: 12,
                    color: Color(0xFF6C63FF),
                  ),
                  SizedBox(width: 4),
                  Text(
                    "Full Access Admin",
                    style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  // Dashboard — the only leaf that calls onMenuSelected
                  _buildMenuItem(
                    "Dashboard",
                    Icons.dashboard_rounded,
                    CustomAdminMenu.dashboard,
                  ),

                  // Job Management
                  _buildExpandableMenu(
                    title: "Job Management",
                    icon: Icons.work_rounded,
                    isSelected:
                        widget.selectedMenu == CustomAdminMenu.jobManagement,
                    isExpanded: _jobExpanded,
                    onToggle: () {
                      setState(() => _jobExpanded = !_jobExpanded);
                    },
                    children: [
                      _buildSubMenuItem(
                        "All Jobs",
                        Icons.list_rounded,
                        () =>
                            widget.onJobSubMenuSelected(JobSubMenu.allJobs),
                        isActive: widget.selectedMenu ==
                                CustomAdminMenu.jobManagement &&
                            widget.selectedJobSubMenu == JobSubMenu.allJobs,
                      ),
                      _buildSubMenuItem(
                        "Add New Job",
                        Icons.add_circle_outline_rounded,
                        () => widget
                            .onJobSubMenuSelected(JobSubMenu.addNewJob),
                        isActive: widget.selectedMenu ==
                                CustomAdminMenu.jobManagement &&
                            widget.selectedJobSubMenu ==
                                JobSubMenu.addNewJob,
                      ),
                    ],
                  ),

                  // Applications
                  _buildExpandableMenu(
                    title: "Applications",
                    icon: Icons.assignment_rounded,
                    isSelected: widget.selectedMenu ==
                        CustomAdminMenu.applicationManagement,
                    isExpanded: _appExpanded,
                    onToggle: () {
                      setState(() => _appExpanded = !_appExpanded);
                    },
                    children: [
                      _buildSubMenuItem(
                        "Job Applications",
                        Icons.work_rounded,
                        () => widget.onApplicationSubMenuSelected(
                            ApplicationSubMenu.jobApplications),
                        isActive: widget.selectedMenu ==
                                CustomAdminMenu.applicationManagement &&
                            widget.selectedAppSubMenu ==
                                ApplicationSubMenu.jobApplications,
                      ),
                      _buildSubMenuItem(
                        "Service Applications",
                        Icons.workspace_premium_rounded,
                        () => widget.onApplicationSubMenuSelected(
                            ApplicationSubMenu.serviceApplications),
                        isActive: widget.selectedMenu ==
                                CustomAdminMenu.applicationManagement &&
                            widget.selectedAppSubMenu ==
                                ApplicationSubMenu.serviceApplications,
                      ),
                      // ✅ NEW: Scheme Applications
                      _buildSubMenuItem(
                        "Scheme Applications",
                        Icons.account_balance_rounded,
                        () => widget.onApplicationSubMenuSelected(
                            ApplicationSubMenu.schemeApplications),
                        isActive: widget.selectedMenu ==
                                CustomAdminMenu.applicationManagement &&
                            widget.selectedAppSubMenu ==
                                ApplicationSubMenu.schemeApplications,
                      ),
                    ],
                  ),

                  // Settings
                  _buildExpandableMenu(
                    title: "Settings",
                    icon: Icons.settings_rounded,
                    isSelected:
                        widget.selectedMenu == CustomAdminMenu.settings,
                    isExpanded: _settingsExpanded,
                    onToggle: () {
                      setState(() => _settingsExpanded = !_settingsExpanded);
                    },
                    children: [
                      _buildSettingsSubMenuItem(
                        "Change Password",
                        Icons.lock_rounded,
                        SettingsSubMenu.changePassword,
                      ),
                      _buildSettingsSubMenuItem(
                        "Setup MPIN",
                        Icons.pin_rounded,
                        SettingsSubMenu.setupMpin,
                      ),
                      _buildSettingsSubMenuItem(
                        "Fingerprint",
                        Icons.fingerprint_rounded,
                        SettingsSubMenu.fingerprint,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Logout
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await SecureStorage.logout();
                  if (context.mounted) {
                    context.go(AppRoutes.home);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SIMPLE MENU ITEM (Dashboard)
  // ============================================================
  Widget _buildMenuItem(String title, IconData icon, CustomAdminMenu menu) {
    final isSelected = widget.selectedMenu == menu;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onMenuSelected(menu),
          splashColor: Colors.white.withOpacity(0.08),
          highlightColor: Colors.white.withOpacity(0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [_primaryGradientStart, _primaryGradientEnd],
                    )
                  : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _primaryGradientStart.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EXPANDABLE MENU — parent tap ONLY toggles expansion
  // ============================================================
  Widget _buildExpandableMenu({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? _primaryGradientStart.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onToggle, // ✅ no navigation, just expand/collapse
                splashColor: Colors.white.withOpacity(0.08),
                highlightColor: Colors.white.withOpacity(0.04),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color:
                            isSelected ? _selectedAccent : Colors.white70,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected
                                ? _selectedAccent
                                : Colors.white70,
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isSelected
                              ? _selectedAccent
                              : Colors.white70,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUB MENU ITEM — the ONLY thing that navigates
  // ============================================================
  Widget _buildSubMenuItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.08),
        highlightColor: Colors.white.withOpacity(0.04),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? _primaryGradientStart.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(
                    color: _primaryGradientStart.withOpacity(0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? _selectedAccent : Colors.white54,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive ? _selectedAccent : Colors.white54,
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
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
  // SETTINGS SUB MENU ITEM
  // ============================================================
  Widget _buildSettingsSubMenuItem(
    String title,
    IconData icon,
    SettingsSubMenu subMenu,
  ) {
    final isActive = widget.selectedMenu == CustomAdminMenu.settings &&
        widget.selectedSettingsSubMenu == subMenu;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onSettingsSubMenuSelected(subMenu),
        splashColor: Colors.white.withOpacity(0.08),
        highlightColor: Colors.white.withOpacity(0.04),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? _primaryGradientStart.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(
                    color: _primaryGradientStart.withOpacity(0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? _selectedAccent : Colors.white54,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive ? _selectedAccent : Colors.white54,
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}