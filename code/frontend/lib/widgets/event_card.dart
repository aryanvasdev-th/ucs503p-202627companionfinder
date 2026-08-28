import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../theme/app_theme.dart';

/// Home-tab card: image with time + RSVP badge, title, host row, View Details.
class EventCard extends StatelessWidget {
  final UpcomingEvent event;
  final VoidCallback? onViewDetails;

  const EventCard({super.key, required this.event, this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final isConfirmed = event.rsvp == EventRsvp.confirmed;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.35 : 0.06),
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
              Container(
                height: 148,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: event.imageGradient,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(event.timeLabel, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
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
                      child: Text(event.title, style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: event.status == ActivityStatus.full ? extras.field : extras.indigoTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        event.capacityLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: event.status == ActivityStatus.full ? extras.text3 : extras.indigo,
                        ),
                      ),
                    ),
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
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Hosted by ${event.hostName}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ),
                    Icon(Icons.star_rounded, size: 15, color: const Color(0xFFF0A93B)),
                    const SizedBox(width: 3),
                    Text(event.rating.toStringAsFixed(1), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
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
                      textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
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
