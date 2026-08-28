import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';

/// Placeholder — no reference design or backend for messaging yet.
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: const AppTopBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 48, color: extras.text3),
                const SizedBox(height: 16),
                Text('No messages yet', style: theme.textTheme.titleMedium?.copyWith(fontSize: 17)),
                const SizedBox(height: 8),
                Text(
                  'Conversations with hosts and activity groups will show up here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5, color: extras.text2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
