import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api_config.dart';
import '../models/activity.dart';
import '../theme/app_theme.dart';

/// Home-tab card: image with time + RSVP badge, title, host row, View Details.
/// The image block only appears when the host uploaded a banner.
class EventCard extends StatelessWidget {
  final UpcomingEvent event;
  final VoidCallback? onViewDetails;

  const EventCard({super.key, required this.event, this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final isConfirmed = event.rsvp == EventRsvp.confirmed;

    // No banner from the host: skip the image block so the card stays
    // compact, and show the time and RSVP pills in a slim row instead.
    final hasBanner = event.bannerUrl != null && event.bannerUrl!.isNotEmpty;

    Widget timePill(Color background, Color foreground) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 13, color: foreground),
          const SizedBox(width: 5),
          Text(
            event.timeLabel,
            style: TextStyle(
              color: foreground,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    Widget rsvpPill() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConfirmed ? extras.greenTint : extras.brandTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isConfirmed ? 'Confirmed' : 'Going',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isConfirmed ? extras.green : extras.brandInk,
        ),
      ),
    );

    Widget gradientFallback() => Container(
      height: 148,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: event.imageGradient,
        ),
      ),
    );

    return Container(
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
          if (hasBanner)
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: '${ApiConfig.apiRoot}${event.bannerUrl}',
                  height: 148,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => gradientFallback(),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: timePill(
                    Colors.black.withValues(alpha: 0.5),
                    Colors.white,
                  ),
                ),
                Positioned(top: 12, right: 12, child: rsvpPill()),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  timePill(extras.field, extras.text2),
                  const Spacer(),
                  rsvpPill(),
                ],
              ),
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
                        event.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 19,
                        ),
                      ),
                    ),
                    if (!event.isEvent) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: event.status == ActivityStatus.full
                              ? extras.field
                              : extras.indigoTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          event.capacityLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: event.status == ActivityStatus.full
                                ? extras.text3
                                : extras.indigo,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: event.hostColor,
                      child: Text(
                        event.hostInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hosted by ${event.hostName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (event.rating != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: Color(0xFFF0A93B),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      event.rating?.toStringAsFixed(1) ?? 'New',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: onViewDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: extras.indigo,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
