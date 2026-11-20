import 'package:flutter/widgets.dart';

/// Lets widgets that sit above the Navigator (the notification popup, which
/// is mounted in MaterialApp.builder so it shows over every screen) push
/// routes.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
