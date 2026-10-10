// lib/features/user/presentation/widgets/user_sidebar.dart
// ✅ COMPLETE UPDATED VERSION
// ✅ Parent menu tap ONLY expands — never navigates
// ✅ Right-side content changes ONLY when a submenu is tapped
// ✅ ListTile warnings avoided (Material + InkWell everywhere)
// ✅ NULLABLE submenus — no auto-select
// ✅ AI MENU HIDDEN
// ✅ PROFILE MENU MOVED TO BELOW DASHBOARD
// ✅ ADVANCED DETAILS SUBMENU HIDDEN
// ✅ ATS SCORE & AI RESUME SUBMENUS HIDDEN
// ✅ NEW: SCHEMES MENU ADDED (below Resume, above Support)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnext/core/routes/app_routes.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import '../utils/menu_types.dart';

class UserSidebar extends StatefulWidget {
  final UserMenuType selectedMenu;
  final JobSubMenu? selectedJobSubMenu;
  final ServiceSubMenu? selectedServiceSubMenu;
  final ResumeSubMenu? selectedResumeSubMenu;
  final SchemesSubMenu? selectedSchemesSubMenu;
  final AISubMenu? selectedAISubMenu;
  final ProfileSubMenu? selectedProfileSubMenu;
  final SettingsSubMenu? selectedSettingsSubMenu;

  // ✅ Only leaf menus call this
  final Function(UserMenuType) onMenuSelected;
  final Function(JobSubMenu) onJobSubMenuSelected;
  final Function(ServiceSubMenu) onServiceSubMenuSelected;
  final Function(ResumeSubMenu) onResumeSubMenuSelected;
  final Function(SchemesSubMenu) onSchemesSubMenuSelected;
  final Function(AISubMenu) onAISubMenuSelected;
  final Function(ProfileSubMenu) onProfileSubMenuSelected;
  final Function(SettingsSubMenu) onSettingsSubMenuSelected;

  const UserSidebar({
    super.key,
    required this.selectedMenu,
    required this.selectedJobSubMenu,
    required this.selectedServiceSubMenu,
    required this.selectedResumeSubMenu,
    required this.selectedSchemesSubMenu,
    required this.selectedAISubMenu,
    required this.selectedProfileSubMenu,
    required this.selectedSettingsSubMenu,
    required this.onMenuSelected,
    required this.onJobSubMenuSelected,
    required this.onServiceSubMenuSelected,
    required this.onResumeSubMenuSelected,
    required this.onSchemesSubMenuSelected,
    required this.onAISubMenuSelected,
    required this.onProfileSubMenuSelected,
    required this.onSettingsSubMenuSelected,
  });

  @override
  State<UserSidebar> createState() => _UserSidebarState();
}

class _UserSidebarState extends State<UserSidebar> {
  static const Color _primaryGradientStart = Color(0xFF6C63FF);
  static const Color _primaryGradientEnd = Color(0xFFFF6588);
  static const Color _selectedAccent = Color(0xFF6C63FF);

  bool _jobExpanded = false;
  bool _serviceExpanded = false;
  bool _resumeExpanded = false;
  bool _schemesExpanded = false;
  bool _profileExpanded = false;
  bool _settingsExpanded = false;

  @override
  void initState() {
    super.initState();
    _syncExpansionFromSelection();
  }

  @override
  void didUpdateWidget(covariant UserSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMenu != oldWidget.selectedMenu) {
      if (widget.selectedMenu == UserMenuType.jobs) {
        _jobExpanded = true;
      }
      if (widget.selectedMenu == UserMenuType.services) {
        _serviceExpanded = true;
      }
      if (widget.selectedMenu == UserMenuType.resume) {
        _resumeExpanded = true;
      }
      if (widget.selectedMenu == UserMenuType.schemes) {
        _schemesExpanded = true;
      }
      if (widget.selectedMenu == UserMenuType.profile) {
        _profileExpanded = true;
      }
      if (widget.selectedMenu == UserMenuType.settings) {
        _settingsExpanded = true;
      }
    }
  }

  void _syncExpansionFromSelection() {
    _jobExpanded = widget.selectedMenu == UserMenuType.jobs;
    _serviceExpanded = widget.selectedMenu == UserMenuType.services;
    _resumeExpanded = widget.selectedMenu == UserMenuType.resume;
    _schemesExpanded = widget.selectedMenu == UserMenuType.schemes;
    _profileExpanded = widget.selectedMenu == UserMenuType.profile;
    _settingsExpanded = widget.selectedMenu == UserMenuType.settings;
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
                Icons.person,
                size: 42,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              "User Dashboard",
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
                    "Job Seeker",
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
                  // ============================================================
                  // ✅ Dashboard — LEAF
                  // ============================================================
                  _buildMenuItem(
                    "Dashboard",
                    Icons.dashboard_rounded,
                    UserMenuType.dashboard,
                  ),

                  // ============================================================
                  // ✅ Profile — PARENT (below Dashboard)
                  // ✅ "Advanced Details" submenu HIDDEN
                  // ============================================================
                  _buildExpandableMenu(
                    title: "Profile",
                    icon: Icons.person_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.profile,
                    isExpanded: _profileExpanded,
                    onToggle: () {
                      setState(() => _profileExpanded = !_profileExpanded);
                    },
                    children: [
                      _buildSubMenuItem(
                        "Basic Details",
                        Icons.info_rounded,
                        () => widget.onProfileSubMenuSelected(
                            ProfileSubMenu.basicDetails),
                        isActive: widget.selectedMenu ==
                                UserMenuType.profile &&
                            widget.selectedProfileSubMenu ==
                                ProfileSubMenu.basicDetails,
                      ),
                      _buildSubMenuItem(
                        "Education",
                        Icons.school_rounded,
                        () => widget.onProfileSubMenuSelected(
                            ProfileSubMenu.education),
                        isActive: widget.selectedMenu ==
                                UserMenuType.profile &&
                            widget.selectedProfileSubMenu ==
                                ProfileSubMenu.education,
                      ),
                      _buildSubMenuItem(
                        "Experience",
                        Icons.work_history_rounded,
                        () => widget.onProfileSubMenuSelected(
                            ProfileSubMenu.experience),
                        isActive: widget.selectedMenu ==
                                UserMenuType.profile &&
                            widget.selectedProfileSubMenu ==
                                ProfileSubMenu.experience,
                      ),
                      // ✅ ADVANCED DETAILS — HIDDEN
                      // _buildSubMenuItem(
                      //   "Advanced Details",
                      //   Icons.tune_rounded,
                      //   () => widget.onProfileSubMenuSelected(
                      //       ProfileSubMenu.advancedDetails),
                      //   isActive: widget.selectedMenu ==
                      //           UserMenuType.profile &&
                      //       widget.selectedProfileSubMenu ==
                      //           ProfileSubMenu.advancedDetails,
                      // ),
                      _buildSubMenuItem(
                        "Documents",
                        Icons.folder_rounded,
                        () => widget.onProfileSubMenuSelected(
                            ProfileSubMenu.documents),
                        isActive: widget.selectedMenu ==
                                UserMenuType.profile &&
                            widget.selectedProfileSubMenu ==
                                ProfileSubMenu.documents,
                      ),
                    ],
                  ),

                  // ============================================================
                  // ✅ Jobs — PARENT
                  // ============================================================
                  _buildExpandableMenu(
                    title: "Jobs",
                    icon: Icons.work_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.jobs,
                    isExpanded: _jobExpanded,
                    onToggle: () {
                      setState(() => _jobExpanded = !_jobExpanded);
                    },
                    children: [
                      _buildSubMenuItem(
                        "Browse Jobs",
                        Icons.search_rounded,
                        () => widget
                            .onJobSubMenuSelected(JobSubMenu.browseJobs),
                        isActive: widget.selectedMenu == UserMenuType.jobs &&
                            widget.selectedJobSubMenu ==
                                JobSubMenu.browseJobs,
                      ),
                      _buildSubMenuItem(
                        "Job Applications",
                        Icons.assignment_rounded,
                        () => widget.onJobSubMenuSelected(
                            JobSubMenu.jobApplications),
                        isActive: widget.selectedMenu == UserMenuType.jobs &&
                            widget.selectedJobSubMenu ==
                                JobSubMenu.jobApplications,
                      ),
                    ],
                  ),

                  // ============================================================
                  // ✅ Services — PARENT
                  // ============================================================
                  _buildExpandableMenu(
                    title: "Services",
                    icon: Icons.miscellaneous_services_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.services,
                    isExpanded: _serviceExpanded,
                    onToggle: () {
                      setState(() => _serviceExpanded = !_serviceExpanded);
                    },
                    children: [
                      _buildSubMenuItem(
                        "Browse Services",
                        Icons.explore_rounded,
                        () => widget.onServiceSubMenuSelected(
                            ServiceSubMenu.browseServices),
                        isActive: widget.selectedMenu ==
                                UserMenuType.services &&
                            widget.selectedServiceSubMenu ==
                                ServiceSubMenu.browseServices,
                      ),
                      _buildSubMenuItem(
                        "Service Application",
                        Icons.workspace_premium_rounded,
                        () => widget.onServiceSubMenuSelected(
                            ServiceSubMenu.myApplications),
                        isActive: widget.selectedMenu ==
                                UserMenuType.services &&
                            widget.selectedServiceSubMenu ==
                                ServiceSubMenu.myApplications,
                      ),
                    ],
                  ),

                  // ============================================================
                  // ✅ Resume — PARENT
                  // ✅ "ATS Score" & "AI Resume" submenus HIDDEN
                  // ============================================================
                  _buildExpandableMenu(
                    title: "Resume",
                    icon: Icons.description_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.resume,
                    isExpanded: _resumeExpanded,
                    onToggle: () {
                      setState(() => _resumeExpanded = !_resumeExpanded);
                    },
                    children: [
                      _buildSubMenuItem(
                        "Build Resume",
                        Icons.build_rounded,
                        () => widget.onResumeSubMenuSelected(
                            ResumeSubMenu.buildResume),
                        isActive: widget.selectedMenu ==
                                UserMenuType.resume &&
                            widget.selectedResumeSubMenu ==
                                ResumeSubMenu.buildResume,
                      ),
                      _buildSubMenuItem(
                        "View Resume",
                        Icons.visibility_rounded,
                        () => widget.onResumeSubMenuSelected(
                            ResumeSubMenu.viewResume),
                        isActive: widget.selectedMenu ==
                                UserMenuType.resume &&
                            widget.selectedResumeSubMenu ==
                                ResumeSubMenu.viewResume,
                      ),
                      // ============================================================
                      // ✅ ATS SCORE — HIDDEN
                      // ============================================================
                      // _buildSubMenuItem(
                      //   "ATS Score",
                      //   Icons.analytics_rounded,
                      //   () => widget.onResumeSubMenuSelected(
                      //       ResumeSubMenu.atsScore),
                      //   isActive: widget.selectedMenu ==
                      //           UserMenuType.resume &&
                      //       widget.selectedResumeSubMenu ==
                      //           ResumeSubMenu.atsScore,
                      // ),
                      // ============================================================
                      // ✅ AI RESUME — HIDDEN
                      // ============================================================
                      // _buildSubMenuItem(
                      //   "AI Resume",
                      //   Icons.auto_awesome_rounded,
                      //   () => widget.onResumeSubMenuSelected(
                      //       ResumeSubMenu.aiGenerator),
                      //   isActive: widget.selectedMenu ==
                      //           UserMenuType.resume &&
                      //       widget.selectedResumeSubMenu ==
                      //           ResumeSubMenu.aiGenerator,
                      // ),
                    ],
                  ),

                  // ============================================================
                  // ✅ NEW: Government Schemes — PARENT
                  // ✅ Added BELOW Resume menu
                  // ✅ Submenus: Browse Schemes + Scheme Applications
                  // ============================================================
                  _buildExpandableMenu(
                    title: "सरकारी योजनाएं",
                    icon: Icons.account_balance_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.schemes,
                    isExpanded: _schemesExpanded,
                    onToggle: () {
                      setState(() => _schemesExpanded = !_schemesExpanded);
                    },
                    children: [
                      _buildSubMenuItem(
                        "योजनाएं ब्राउज़ करें",
                        Icons.travel_explore_rounded,
                        () => widget.onSchemesSubMenuSelected(
                            SchemesSubMenu.browseSchemes),
                        isActive: widget.selectedMenu ==
                                UserMenuType.schemes &&
                            widget.selectedSchemesSubMenu ==
                                SchemesSubMenu.browseSchemes,
                      ),
                      _buildSubMenuItem(
                        "योजना आवेदन",
                        Icons.assignment_turned_in_rounded,
                        () => widget.onSchemesSubMenuSelected(
                            SchemesSubMenu.schemeApplications),
                        isActive: widget.selectedMenu ==
                                UserMenuType.schemes &&
                            widget.selectedSchemesSubMenu ==
                                SchemesSubMenu.schemeApplications,
                      ),
                    ],
                  ),

                  // ============================================================
                  // ✅ AI — MENU HIDDEN (commented out)
                  // ============================================================
                  // _buildExpandableMenu(...)

                  // ============================================================
                  // ✅ Support — LEAF
                  // ============================================================
                  _buildMenuItem(
                    "Support",
                    Icons.support_agent_rounded,
                    UserMenuType.support,
                  ),

                  // ============================================================
                  // ✅ Settings — PARENT
                  // ============================================================
                  _buildExpandableMenu(
                    title: "Settings",
                    icon: Icons.settings_rounded,
                    isSelected: widget.selectedMenu == UserMenuType.settings,
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
  // SIMPLE MENU ITEM (Dashboard / Support — LEAF)
  // ============================================================
  Widget _buildMenuItem(String title, IconData icon, UserMenuType menu) {
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
                onTap: onToggle,
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
    final isActive = widget.selectedMenu == UserMenuType.settings &&
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