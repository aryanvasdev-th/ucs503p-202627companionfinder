import 'package:flutter/material.dart';

/// Red tick shown next to the name of anyone whose selfie matched their
/// Thapar ID card. Red rather than the usual blue to match the app's brand.
class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'ID verified',
      child: Icon(
        Icons.verified_rounded,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Name text followed by the badge when [verified] is true.
class NameWithBadge extends StatelessWidget {
  final String name;
  final bool verified;
  final TextStyle? style;
  final double badgeSize;

  const NameWithBadge({
    super.key,
    required this.name,
    required this.verified,
    this.style,
    this.badgeSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(name, style: style, overflow: TextOverflow.ellipsis),
        ),
        if (verified) ...[
          const SizedBox(width: 4),
          VerifiedBadge(size: badgeSize),
        ],
      ],
    );
  }
}
