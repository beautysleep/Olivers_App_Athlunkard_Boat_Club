/// Faces rather than a headcount, so "who's going" reads like the WhatsApp
/// poll the flows describe.
library;

import 'package:flutter/material.dart';

import '../models/user_profile.dart';

const _palette = [
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFF00838F),
  Color(0xFFAD1457),
  Color(0xFF2E7D32),
  Color(0xFF4E342E),
  Color(0xFFEF6C00),
];

Color avatarColor(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _palette[hash % _palette.length];
}

class ProfileCircle extends StatelessWidget {
  const ProfileCircle({super.key, required this.user, this.radius = 18});

  final UserProfile user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColor(user.id),
      child: Text(
        user.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ProfileCircleRow extends StatelessWidget {
  const ProfileCircleRow({
    super.key,
    required this.users,
    this.max = 6,
    this.radius = 18,
  });

  final List<UserProfile> users;
  final int max;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Text('Nobody yet', style: Theme.of(context).textTheme.bodyMedium);
    }
    final shown = users.take(max).toList();
    final overflow = users.length - shown.length;
    final step = radius * 1.5;

    return SizedBox(
      height: radius * 2,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(1.5),
                child: ProfileCircle(user: shown[i], radius: radius),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: shown.length * step,
              child: CircleAvatar(
                radius: radius,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: radius * 0.7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
