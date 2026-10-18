// lib/features/notification/screens/notifications_list_screen.dart
// COMPLETE FIX - Handle all notification types including payment alerts

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/notification/service/notification_service.dart';

class NotificationsListScreen extends StatefulWidget {
  final VoidCallback? onJobAlertClicked;
  final VoidCallback? onApplicationStatusClicked;

  const NotificationsListScreen({
    super.key,
    this.onJobAlertClicked,
    this.onApplicationStatusClicked,
  });

  @override
  State<NotificationsListScreen> createState() =>
      _NotificationsListScreenState();
}

class _NotificationsListScreenState extends State<NotificationsListScreen> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  bool hasMore = true;
  int skip = 0;
  final int limit = 20;
  String? userRole;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _fetchNotifications();
    _setupNotificationListener();
  }

  Future<void> _getUserInfo() async {
    final role = await SecureStorage.getRole();
    final email = await SecureStorage.getEmail();
    if (mounted) {
      setState(() {
        userRole = role;
        userEmail = email;
      });
    }
    if (kDebugMode) {
      debugPrint("👤 User info - Role: $userRole, Email: $userEmail");
    }
  }

  void _setupNotificationListener() {
    NotificationService.addListener(_onNewNotification);
  }

  void _onNewNotification(Map<String, dynamic> notification) {
    if (mounted) {
      _refreshNotifications();
    }
  }

  Future<void> _fetchNotifications({bool refresh = false}) async {
    if (refresh) {
      skip = 0;
      notifications.clear();
      hasMore = true;
      if (mounted) {
        setState(() => isLoading = true);
      }
    }
    if (!hasMore && !refresh) return;

    try {
      final newNotifs = await NotificationService.getNotifications(
        limit: limit,
        skip: skip,
      );

      if (mounted) {
        setState(() {
          notifications.addAll(newNotifs);
          skip += newNotifs.length;
          hasMore = newNotifs.length == limit;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to load notifications: $e", isError: true);
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    await NotificationService.markAsRead(id);
    if (mounted) {
      setState(() {
        final index = notifications.indexWhere((n) => n['_id'] == id);
        if (index != -1) {
          notifications[index]['read'] = true;
        }
      });
    }
  }

  Future<void> _refreshNotifications() async {
    await _fetchNotifications(refresh: true);
    await NotificationService.refreshUnreadCount();
  }

  // ✅ FIXED: Handle ALL notification types
  Future<void> _onNotificationTap(Map<String, dynamic> notification) async {
    final type = notification['type'];
    final metadata = notification['metadata'] as Map<String, dynamic>?;

    if (kDebugMode) {
      debugPrint("🔔 Notification tapped: type=$type");
      debugPrint("📦 Metadata: $metadata");
    }

    // Mark as read if not already
    if (notification['read'] != true && notification['_id'] != null) {
      await _markAsRead(notification['_id']);
    }

    if (!mounted) return;

    // Close the notifications list screen
    Navigator.pop(context);

    // Small delay to ensure navigation after pop
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    // ✅ CRITICAL FIX: Handle ALL notification types that should navigate to Applications
    // This includes:
    // - application_update
    // - application_status
    // - admin_alert (payment verification, application updates)
    // - customadmin_alert (payment verification, application updates)

    final bool isApplicationRelated = type == 'application_update' ||
        type == 'application_status' ||
        type == 'admin_alert' ||
        type == 'customadmin_alert';

    final bool isJobRelated = type == 'new_job';

    if (kDebugMode) {
      debugPrint("🔔 isApplicationRelated: $isApplicationRelated");
      debugPrint("🔔 isJobRelated: $isJobRelated");
      debugPrint(
          "🔔 onApplicationStatusClicked exists: ${widget.onApplicationStatusClicked != null}");
      debugPrint(
          "🔔 onJobAlertClicked exists: ${widget.onJobAlertClicked != null}");
    }

    // Navigate based on notification type
    if (isJobRelated) {
      if (widget.onJobAlertClicked != null) {
        debugPrint("🔔 CALLING onJobAlertClicked");
        widget.onJobAlertClicked!();
      } else {
        debugPrint("⚠️ onJobAlertClicked is NULL");
      }
    } else if (isApplicationRelated) {
      if (widget.onApplicationStatusClicked != null) {
        debugPrint("🔔 CALLING onApplicationStatusClicked");
        widget.onApplicationStatusClicked!();
      } else {
        debugPrint("⚠️ onApplicationStatusClicked is NULL");
      }
    } else {
      debugPrint("⚠️ Unknown notification type: $type - no navigation");
      // Optional: Show snackbar for unknown notification types
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Notification received. Check your dashboard for details."),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'Recently';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          if (diff.inMinutes == 0) return 'Just now';
          return '${diff.inMinutes} min ago';
        }
        return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _markAllAsRead() async {
    await NotificationService.markAllAsRead();
    await _refreshNotifications();
    if (mounted) {
      showMessage(context, "All notifications marked as read");
    }
  }

  @override
  void dispose() {
    NotificationService.removeListener(_onNewNotification);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                "Mark All Read",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading && notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Loading notifications...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No notifications yet",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "You'll see notifications here when you receive updates",
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notifications.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == notifications.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final notification = notifications[index];
        final isRead = notification['read'] == true;
        final type = notification['type'] ?? 'system';
        final title = notification['title'] ?? '';
        final message = notification['message'] ?? '';
        final createdAt = notification['created_at'];
        final metadata = notification['metadata'] as Map<String, dynamic>?;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: isRead ? 1 : 3,
          color: isRead ? Colors.grey.shade50 : Colors.white,
          child: InkWell(
            onTap: () => _onNotificationTap(notification),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: _getIconColor(type).withAlpha(25),
                    radius: 24,
                    child: Icon(
                      _getIcon(type),
                      color: _getIconColor(type),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _formatDateTime(createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            if (metadata != null && metadata['status'] != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(metadata['status']),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    metadata['status'].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'new_job':
        return Icons.work;
      case 'application_update':
      case 'application_status':
        return Icons.assignment_turned_in;
      case 'job_application':
        return Icons.person_add;
      case 'admin_alert':
        return Icons.admin_panel_settings;
      case 'customadmin_alert':
        return Icons.admin_panel_settings;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String? type) {
    switch (type) {
      case 'new_job':
        return Colors.green;
      case 'application_update':
      case 'application_status':
        return Colors.orange;
      case 'job_application':
        return Colors.blue;
      case 'admin_alert':
        return Colors.purple;
      case 'customadmin_alert':
        return Colors.deepPurple;
      case 'system':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'shortlisted':
        return Colors.blue;
      case 'interview':
        return Colors.orange;
      case 'offered':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
