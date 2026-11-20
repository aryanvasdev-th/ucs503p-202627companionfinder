import 'package:flutter/material.dart';

enum ActivityStatus { open, full }

class ActivityListing {
  final int id;
  final String title;
  final String category;
  final double? rating;
  final String timeLabel;
  final int peopleJoined;
  final int peopleCapacity;
  final String hostName;
  final String hostInitials;
  final Color hostColor;
  final List<Color> imageGradient;
  final String? bannerUrl;
  final bool joinedByMe;
  final bool requestPending;
  final bool requestDeclined;
  final bool isEvent;
  final int eventActivityCount;

  /// Pinned to the top of Discover by an admin.
  final bool isFeatured;

  const ActivityListing({
    required this.id,
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
    this.bannerUrl,
    this.joinedByMe = false,
    this.requestPending = false,
    this.requestDeclined = false,
    this.isEvent = false,
    this.eventActivityCount = 0,
    this.isFeatured = false,
  });

  ActivityStatus get status => peopleJoined >= peopleCapacity
      ? ActivityStatus.full
      : ActivityStatus.open;

  String get capacityLabel => status == ActivityStatus.full
      ? 'Full'
      : '$peopleJoined/$peopleCapacity people';
}

enum EventRsvp { confirmed, going }

class UpcomingEvent {
  final int id;
  final String title;
  final String timeLabel;
  final EventRsvp rsvp;
  final String hostName;
  final String hostInitials;
  final Color hostColor;
  final double? rating;
  final int peopleJoined;
  final int peopleCapacity;
  final List<Color> imageGradient;
  final String? bannerUrl;

  /// A fest-style event: no people counter on its card.
  final bool isEvent;

  const UpcomingEvent({
    required this.id,
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
    this.bannerUrl,
    this.isEvent = false,
  });

  ActivityStatus get status => peopleJoined >= peopleCapacity
      ? ActivityStatus.full
      : ActivityStatus.open;

  String get capacityLabel => status == ActivityStatus.full
      ? 'Full'
      : '$peopleJoined/$peopleCapacity people';
}
