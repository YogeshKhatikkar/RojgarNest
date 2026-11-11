// lib/features/admin/presentation/models/admin_menu.dart
// ✅ UPDATED: Removed Reports and Users
// ✅ ADDED: Settings submenu

enum AdminMenuType {
  dashboard,
  jobManagement,
  applicationManagement,
  settings,
  // ❌ REMOVED: manageUsers
  // ❌ REMOVED: reports
}

enum JobSubMenu { allJobs, addNewJob }

enum ApplicationSubMenu {
  allApplications, // ✅ ONLY this remains
  // ❌ REMOVED: pendingApplications
  // ❌ REMOVED: shortlistedApplications
  // ❌ REMOVED: interviewApplications
  // ❌ REMOVED: offeredApplications
  // ❌ REMOVED: rejectedApplications
}

// ✅ NEW: Settings SubMenu
enum SettingsSubMenu {
  changePassword,
  setupMpin,
  fingerprint,
}