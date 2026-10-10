// lib/features/user/presentation/utils/menu_types.dart
// ✅ COMPLETE UPDATED VERSION
// ✅ Parent menu tap ONLY expands — never navigates
// ✅ Right-side content changes ONLY when a submenu is tapped
// ✅ Submenus are NULLABLE — nothing auto-selected
// ✅ NEW: Schemes menu added with browse + applications submenus

enum UserMenuType {
  dashboard,
  jobs,          // ✅ Parent — expands to Browse Jobs + Job Applications
  services,      // ✅ Parent — expands to Browse Services + My Applications
  resume,        // ✅ Parent — expands to Build Resume + View Resume + ATS + AI
  schemes,       // ✅ Parent — expands to Browse Schemes + Scheme Applications
  ai,            // ✅ Parent — expands to AI Dashboard + Career Roadmap (HIDDEN)
  profile,       // ✅ Parent — expands to Basic / Education / Experience / Advanced / Documents
  support,       // ✅ Leaf — direct
  settings,      // ✅ Parent — expands to Change Password / MPIN / Fingerprint
}

// ============================================================
// JOB SUBMENU
// ============================================================
enum JobSubMenu {
  browseJobs,
  jobApplications,
}

// ============================================================
// SERVICE SUBMENU
// ============================================================
enum ServiceSubMenu {
  browseServices,
  myApplications,
}

// ============================================================
// RESUME SUBMENU
// ============================================================
enum ResumeSubMenu {
  buildResume,
  viewResume,
  atsScore,
  aiGenerator,
}

// ============================================================
// ✅ NEW: SCHEMES SUBMENU
// ============================================================
enum SchemesSubMenu {
  browseSchemes,
  schemeApplications,
}

// ============================================================
// AI SUBMENU
// ============================================================
enum AISubMenu {
  dashboard,
  careerRoadmap,
}

// ============================================================
// PROFILE SUBMENU
// ============================================================
enum ProfileSubMenu {
  basicDetails,
  education,
  experience,
  advancedDetails,
  documents,
}

// ============================================================
// SETTINGS SUBMENU
// ============================================================
enum SettingsSubMenu {
  changePassword,
  setupMpin,
  fingerprint,
}