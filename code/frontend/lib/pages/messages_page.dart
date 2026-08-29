import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../widgets/app_top_bar.dart';
import 'chat_page.dart';
import 'notifications_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

enum _MessagesFilter { all, dms, groups }

class _MessagesPageState extends State<MessagesPage> {
  List<Map<String, dynamic>>? _conversations;
  String? _error;
  _MessagesFilter _filter = _MessagesFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiRoot}/api/conversations'),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(
          () => _conversations = (data['conversations'] as List)
              .cast<Map<String, dynamic>>(),
        );
      } else {
        setState(
          () => _error = data['message'] ?? 'Could not load conversations',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = 'Network error. Check your connection and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: AppTopBar(
        onBellTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _FilterSelector(
                value: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _buildBody(theme, extras),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, AppExtras extras) {
    if (_error != null) {
      return _emptyState(
        theme,
        extras,
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: _error!,
      );
    }
    if (_conversations == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _conversations!.where((c) {
      switch (_filter) {
        case _MessagesFilter.all:
          return true;
        case _MessagesFilter.dms:
          return c['activity_id'] == null;
        case _MessagesFilter.groups:
          return c['activity_id'] != null;
      }
    }).toList();

    if (filtered.isEmpty) {
      final noneAtAll = _conversations!.isEmpty;
      return _emptyState(
        theme,
        extras,
        icon: Icons.chat_bubble_outline_rounded,
        title: switch (_filter) {
          _MessagesFilter.all => 'No messages yet',
          _MessagesFilter.dms => 'No DMs yet',
          _MessagesFilter.groups => 'No group chats yet',
        },
        subtitle: noneAtAll
            ? 'Message someone from an activity\'s details page to start a conversation.'
            : switch (_filter) {
                _MessagesFilter.dms =>
                  'Message someone from an activity\'s details page to start one.',
                _MessagesFilter.groups =>
                  'Join or host an activity to get a group chat.',
                _MessagesFilter.all => '',
              },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final conversation = filtered[i];
        final title =
            conversation['other_user_name'] ??
            conversation['activity_title'] ??
            'Conversation';
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ChatPage(conversationId: conversation['id'], title: title),
              ),
            );
            _load();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    (conversation['activity_banner_url'] as String?)
                                ?.isNotEmpty ==
                            true
                        ? CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                              '${ApiConfig.apiRoot}${conversation['activity_banner_url']}',
                            ),
                          )
                        : CircleAvatar(
                            radius: 20,
                            backgroundColor: colorForSeed(conversation['id']),
                            child: Text(
                              initialsFor(title),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                    if (conversation['activity_id'] != null)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.groups_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        conversation['last_message'] ?? 'No messages yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: extras.text2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(
    ThemeData theme,
    AppExtras extras, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: extras.text3),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 13.5,
                      color: extras.text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSelector extends StatelessWidget {
  final _MessagesFilter value;
  final ValueChanged<_MessagesFilter> onChanged;

  const _FilterSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    Widget segment(_MessagesFilter filter, String label) {
      final active = filter == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(filter),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? theme.colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : extras.text2,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: extras.field,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          segment(_MessagesFilter.all, 'All'),
          segment(_MessagesFilter.dms, 'DMs'),
          segment(_MessagesFilter.groups, 'Groups'),
        ],
      ),
    );
  }
}
