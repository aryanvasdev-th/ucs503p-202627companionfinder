import 'package:flutter/material.dart';

import '../api_config.dart';
import '../models/activity.dart';
import '../theme/app_theme.dart';

/// Discover-tab card: image, rating badge, title, capacity badge, time, host row.
class ActivityCard extends StatelessWidget {
  final ActivityListing listing;
  final VoidCallback? onJoin;
  final VoidCallback? onTap;

  const ActivityCard({
    super.key,
    required this.listing,
    this.onJoin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final isFull = listing.status == ActivityStatus.full;
    final requestDisabled =
        isFull ||
        listing.joinedByMe ||
        listing.requestPending ||
        listing.requestDeclined;
    final requestLabel = listing.joinedByMe
        ? 'Joined'
        : listing.requestPending
        ? 'Requested'
        : listing.requestDeclined
        ? 'Declined'
        : (isFull ? 'Full' : 'Request');

    Widget gradientFallback() => Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: listing.imageGradient,
        ),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.35 : 0.06,
              ),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                listing.bannerUrl != null && listing.bannerUrl!.isNotEmpty
                    ? Image.network(
                        '${ApiConfig.apiRoot}${listing.bannerUrl}',
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            gradientFallback(),
                      )
                    : gradientFallback(),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _Pill(
                    color: theme.brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.92),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (listing.rating != null) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: Color(0xFFF0A93B),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          listing.rating?.toStringAsFixed(1) ?? 'New',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 19,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Pill(
                        color: isFull ? extras.field : extras.indigoTint,
                        child: Text(
                          listing.capacityLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isFull ? extras.text3 : extras.indigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: extras.text2,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        listing.timeLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: extras.text2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: theme.dividerColor),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: listing.hostColor,
                        child: Text(
                          listing.hostInitials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.hostName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              'Host',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: extras.text3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: requestDisabled ? null : onJoin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: requestDisabled
                              ? extras.field
                              : theme.colorScheme.primary,
                          foregroundColor: requestDisabled
                              ? extras.text3
                              : Colors.white,
                          disabledBackgroundColor: extras.field,
                          disabledForegroundColor: extras.text3,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 10,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(requestLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Pill({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}
