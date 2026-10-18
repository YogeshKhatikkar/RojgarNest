// lib/features/superadmin/presentation/widgets/superadmin_sidebar.dart
// ✅ SuperAdmin Sidebar - FIXED ListTile Warning

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnest/core/routes/app_routes.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';

enum SuperAdminMenu {
  dashboard,
  users,
  jobs,
  applications,
  reports,
  settings,
}

class SuperAdminSidebar extends StatelessWidget {
  final SuperAdminMenu selectedMenu;
  final Function(SuperAdminMenu) onMenuSelected;

  const SuperAdminSidebar({
    super.key,
    required this.selectedMenu,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF1E293B),
      child: Material( // ✅ FIX: Wrapped with Material to fix ListTile warning
        color: Colors.transparent,
        child: Column(
          children: [
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                size: 45,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Super Admin Panel",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "Full Platform Admin",
              style: TextStyle(color: Colors.amber, fontSize: 12),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildMenuItem("Dashboard", Icons.dashboard,
                      SuperAdminMenu.dashboard),
                  _buildMenuItem("Users", Icons.people, SuperAdminMenu.users),
                  _buildMenuItem("Jobs", Icons.work, SuperAdminMenu.jobs),
                  _buildMenuItem("Applications", Icons.assignment,
                      SuperAdminMenu.applications),
                  _buildMenuItem("Reports", Icons.bar_chart,
                      SuperAdminMenu.reports),
                  _buildMenuItem("Settings", Icons.settings,
                      SuperAdminMenu.settings),
                ],
              ),
            ),
            const Divider(color: Colors.grey, height: 1),
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Logout", style: TextStyle(color: Colors.white)),
                onTap: () async {
                  await SecureStorage.logout();
                  if (context.mounted) {
                    context.go(AppRoutes.home);
                  }
                },
                tileColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, SuperAdminMenu menu) {
    final isSelected = selectedMenu == menu;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.amber : Colors.white70,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.amber : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.amber.withAlpha(51),
        onTap: () => onMenuSelected(menu),
        tileColor: Colors.transparent,
      ),
    );
  }
}