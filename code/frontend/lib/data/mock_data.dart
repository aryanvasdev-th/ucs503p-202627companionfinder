import 'package:flutter/material.dart';
import '../models/activity.dart';

/// Sample data standing in until the backend exposes activity/event endpoints.
const kCategories = ['All Activities', 'Hiking', 'Tech Meetups', 'Gaming', 'Sports'];

const kDiscoverListings = [
  ActivityListing(
    title: 'Weekend Ridge Hike',
    category: 'Hiking',
    rating: 4.9,
    timeLabel: 'Sat, 9:00 AM • 3 hrs',
    peopleJoined: 3,
    peopleCapacity: 5,
    hostName: 'Sarah J.',
    hostInitials: 'SJ',
    hostColor: Color(0xFFC77B7B),
    imageGradient: [Color(0xFF4C7C5A), Color(0xFF2C4A38)],
  ),
  ActivityListing(
    title: 'Frontend Dev Coffee',
    category: 'Tech Meetups',
    rating: 4.7,
    timeLabel: 'Today, 2:00 PM • 1.5 hrs',
    peopleJoined: 1,
    peopleCapacity: 4,
    hostName: 'Alex M.',
    hostInitials: 'AM',
    hostColor: Color(0xFF6E85B0),
    imageGradient: [Color(0xFF8A6A4E), Color(0xFF4A3527)],
  ),
  ActivityListing(
    title: 'Smash Bros Tournament',
    category: 'Gaming',
    rating: 5.0,
    timeLabel: 'Tomorrow, 7:00 PM • 4 hrs',
    peopleJoined: 8,
    peopleCapacity: 8,
    hostName: 'Jordan K.',
    hostInitials: 'JK',
    hostColor: Color(0xFF8A7A5A),
    imageGradient: [Color(0xFF5A4A8A), Color(0xFF2E2450)],
  ),
];

const kUpcomingEvents = [
  UpcomingEvent(
    title: 'Morning Hike',
    timeLabel: 'Tomorrow, 8:00 AM',
    rsvp: EventRsvp.confirmed,
    hostName: 'Elena R.',
    hostInitials: 'ER',
    hostColor: Color(0xFF6E9B7C),
    rating: 5.0,
    peopleJoined: 3,
    peopleCapacity: 5,
    imageGradient: [Color(0xFF4C7C5A), Color(0xFF2C4A38)],
  ),
  UpcomingEvent(
    title: 'Coffee & Code',
    timeLabel: 'In 2 hours',
    rsvp: EventRsvp.going,
    hostName: 'David L.',
    hostInitials: 'DL',
    hostColor: Color(0xFF9B7B4C),
    rating: 4.8,
    peopleJoined: 1,
    peopleCapacity: 3,
    imageGradient: [Color(0xFF8A6A4E), Color(0xFF4A3527)],
  ),
];
