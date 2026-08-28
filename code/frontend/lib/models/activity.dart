import 'package:flutter/material.dart';

enum ActivityStatus { open, full }

class ActivityListing {
  final String title;
  final String category;
  final double rating;
  final String timeLabel;
  final int peopleJoined;
  final int peopleCapacity;
  final String hostName;
  final String hostInitials;
  final Color hostColor;
  final List<Color> imageGradient;

  const ActivityListing({
    required this.title,
    required this.category,
    required this.rating,
    required this.timeLabel,
    required this.peopleJoined,
    required this.peopleCapacity,
    required this.hostName,
    required this.hostInitials,
    required this.hostColor,
    required this.imageGradient,
  });

  ActivityStatus get status =>
      peopleJoined >= peopleCapacity ? ActivityStatus.full : ActivityStatus.open;

  String get capacityLabel =>
      status == ActivityStatus.full ? 'Full' : '$peopleJoined/$peopleCapacity people';
}

enum EventRsvp { confirmed, going }

class UpcomingEvent {
  final String title;
  final String timeLabel;
  final EventRsvp rsvp;
  final String hostName;
  final String hostInitials;
  final Color hostColor;
  final double rating;
  final int peopleJoined;
  final int peopleCapacity;
  final List<Color> imageGradient;

  const UpcomingEvent({
    required this.title,
    required this.timeLabel,
    required this.rsvp,
    required this.hostName,
    required this.hostInitials,
    required this.hostColor,
    required this.rating,
    required this.peopleJoined,
    required this.peopleCapacity,
    required this.imageGradient,
  });

  ActivityStatus get status =>
      peopleJoined >= peopleCapacity ? ActivityStatus.full : ActivityStatus.open;

  String get capacityLabel =>
      status == ActivityStatus.full ? 'Full' : '$peopleJoined/$peopleCapacity people';
}
