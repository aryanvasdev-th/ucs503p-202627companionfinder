import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../api_config.dart';
import 'auth_session.dart';
import 'notifications_state.dart';

/// One app-wide socket for pushed notifications (join requests, accepted /
/// declined, new teammates, reviews). Chat keeps its own per-conversation
/// socket in ChatPage; this one only listens for `notification:new`.
class RealtimeService {
  RealtimeService._();

  static socket_io.Socket? _socket;
  static final _controller = StreamController<Map<String, dynamic>>.broadcast();

  /// Every notification pushed by the server while logged in. The popup
  /// overlay listens to this, and so can any page that wants to refresh
  /// itself (e.g. an activity page reloading when a request is answered).
  static Stream<Map<String, dynamic>> get notifications => _controller.stream;

  static void connect() {
    if (_socket != null || AuthSession.token == null) return;
    _socket = socket_io.io(
      ApiConfig.apiRoot,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          // Its own connection, never shared with a chat screen's socket.
          .enableForceNew()
          .setAuth({'token': AuthSession.token})
          .enableReconnection()
          .build(),
    );
    _socket!.on('notification:new', (data) {
      if (data is! Map) return;
      _deliver(Map<String, dynamic>.from(data));
    });
  }

  static void _deliver(Map<String, dynamic> notification) {
    NotificationsState.unreadCount.value += 1;
    _controller.add(notification);
  }

  /// Feeds a notification through the same path a socket push takes.
  @visibleForTesting
  static void debugDeliver(Map<String, dynamic> notification) =>
      _deliver(notification);

  static void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
