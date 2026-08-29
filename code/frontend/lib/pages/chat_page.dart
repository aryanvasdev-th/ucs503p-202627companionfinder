import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../api_config.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  final int id;
  final int senderUserId;
  final String senderName;
  final String body;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    senderUserId: json['sender_user_id'],
    senderName: json['sender_name'] ?? '',
    body: json['body'],
    createdAt: DateTime.parse(json['created_at']).toLocal(),
  );
}

class ChatPage extends StatefulWidget {
  final int conversationId;
  final String title;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.title,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  socket_io.Socket? _socket;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistoryAndConnect();
  }

  Future<void> _loadHistoryAndConnect() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.apiRoot}/api/conversations/${widget.conversationId}/messages',
        ),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;

      if (data['success'] == true) {
        setState(() {
          _messages.addAll(
            (data['messages'] as List).map((m) => ChatMessage.fromJson(m)),
          );
          _isLoading = false;
        });
        _connectSocket();
      } else {
        setState(() {
          _isLoading = false;
          _error = data['message'] ?? 'Could not load messages';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Network error. Check your connection and try again.';
      });
    }
  }

  void _connectSocket() {
    _socket = socket_io.io(
      ApiConfig.apiRoot,
      socket_io.OptionBuilder().setTransports(['websocket']).setAuth({
        'token': AuthSession.token,
      }).build(),
    );

    _socket!.onConnect((_) {
      _socket!.emitWithAck(
        'conversation:join',
        widget.conversationId,
        ack: (response) {
          if (response is Map && response['success'] != true && mounted) {
            setState(
              () =>
                  _error = response['message'] ?? 'Could not join conversation',
            );
          }
        },
      );
    });

    _socket!.on('message:new', (data) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          ChatMessage.fromJson(Map<String, dynamic>.from(data)),
        ),
      );
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _socket == null) return;

    _socket!.emitWithAck(
      'message:send',
      {'conversationId': widget.conversationId, 'body': text},
      ack: (response) {
        if (response is Map && response['success'] != true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Could not send message'),
            ),
          );
        }
      },
    );
    _messageController.clear();
  }

  @override
  void dispose() {
    _socket?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: TextStyle(color: extras.text2),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final message = _messages[i];
                        final isMine =
                            message.senderUserId.toString() ==
                            AuthSession.userId;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.72,
                            ),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? theme.colorScheme.primary
                                  : extras.field,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              message.body,
                              style: TextStyle(
                                color: isMine
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded),
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
}
