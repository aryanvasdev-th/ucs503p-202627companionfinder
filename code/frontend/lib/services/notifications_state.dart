import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'auth_session.dart';

/// Lightweight cross-page unread count, mirroring how ThemeController shares
/// state without a full state-management dependency. Refreshed on login and
/// whenever the notifications page changes read status.
class NotificationsState {
  NotificationsState._();

  static final ValueNotifier<int> unreadCount = ValueNotifier(0);

  static Future<void> refresh() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiRoot}/api/notifications'),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final list = (data['notifications'] as List).cast<Map<String, dynamic>>();
        unreadCount.value = list.where((n) => n['read'] != true).length;
      }
    } catch (e) {
      // Best-effort — a badge that fails to update isn't worth surfacing an error for.
    }
  }
}
