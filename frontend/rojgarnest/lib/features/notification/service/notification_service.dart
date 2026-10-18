// lib/features/notification/service/notification_service.dart
// COMPLETE WORKING VERSION

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';

class NotificationService {
  static final List<Function(Map<String, dynamic>)> _listeners = [];
  static Timer? _pollingTimer;

  static void addListener(Function(Map<String, dynamic>) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      if (kDebugMode) {
        debugPrint(
            "✅ Added notification listener, total: ${_listeners.length}");
      }
    }
  }

  static void removeListener(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
    if (kDebugMode) {
      debugPrint(
          "❌ Removed notification listener, total: ${_listeners.length}");
    }
  }

  static void _notifyListeners(Map<String, dynamic> data) {
    if (kDebugMode) {
      debugPrint("🔔 Notifying ${_listeners.length} listeners");
    }
    for (var listener in _listeners) {
      try {
        listener(data);
      } catch (e) {
        if (kDebugMode) {
          debugPrint("Error in notification listener: $e");
        }
      }
    }
  }

  static Future<int> getUnreadCount() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        return 0;
      }

      final response = await DioClient.dio.get('/notification/unread-count');

      if (kDebugMode) {
        debugPrint("📊 Unread count response: ${response.data}");
      }

      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;

        if (data.containsKey('unread_count')) {
          return data['unread_count'] as int? ?? 0;
        } else if (data.containsKey('data') && data['data'] is Map) {
          final innerData = data['data'] as Map<String, dynamic>;
          return innerData['unread_count'] as int? ?? 0;
        }
      }
      return 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching unread count: $e");
      }
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        return [];
      }

      final response = await DioClient.dio.get(
        '/notification/my-notifications',
        queryParameters: {'limit': limit, 'skip': skip},
      );

      List<Map<String, dynamic>> notifications = [];
      final data = response.data;

      if (data is Map<String, dynamic>) {
        if (data.containsKey('notifications')) {
          notifications =
              List<Map<String, dynamic>>.from(data['notifications']);
        } else if (data.containsKey('data') && data['data'] is Map) {
          final innerData = data['data'] as Map<String, dynamic>;
          if (innerData.containsKey('notifications')) {
            notifications =
                List<Map<String, dynamic>>.from(innerData['notifications']);
          }
        } else if (data.containsKey('data') && data['data'] is List) {
          notifications = List<Map<String, dynamic>>.from(data['data']);
        }
      } else if (data is List) {
        notifications = List<Map<String, dynamic>>.from(data);
      }

      if (kDebugMode) {
        debugPrint("📋 Found ${notifications.length} notifications");
      }
      return notifications;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching notifications: $e");
      }
      return [];
    }
  }

  static Future<void> markAsRead(String notificationId) async {
    try {
      await DioClient.dio.post('/notification/mark-read/$notificationId');
      if (kDebugMode) {
        debugPrint("✅ Marked notification as read: $notificationId");
      }
      refreshUnreadCount();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error marking notification as read: $e");
      }
    }
  }

  static Future<void> markAllAsRead() async {
    try {
      await DioClient.dio.post('/notification/mark-all-read');
      if (kDebugMode) {
        debugPrint("✅ Marked all notifications as read");
      }
      refreshUnreadCount();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error marking all notifications as read: $e");
      }
    }
  }

  static Future<void> refreshUnreadCount() async {
    final count = await getUnreadCount();
    _notifyListeners({
      'type': 'refresh_count',
      'unread_count': count,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    });
  }

  static void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      refreshUnreadCount();
    });
    if (kDebugMode) {
      debugPrint("✅ Started notification polling every 15 seconds");
    }
  }

  static void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (kDebugMode) {
      debugPrint("🛑 Stopped notification polling");
    }
  }

  // WebSocket methods - kept for compatibility (not actively used)
  static void connectWebSocket() {
    if (kDebugMode) {
      debugPrint("🔌 WebSocket connection skipped - using polling instead");
    }
    startPolling();
  }

  static void disconnectWebSocket() {
    stopPolling();
  }
}
