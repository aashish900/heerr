import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Gradient ring around the profile avatar — the brand accent shared by the
/// Home AppBar entry point, the Profile display screen's header, and the
/// Settings-tab profile card (Phase Z redesign). Outer gradient circle →
/// thin black gap → the photo itself (or a person glyph placeholder).
class ProfileAvatarRing extends StatelessWidget {
  const ProfileAvatarRing({
    required this.avatar,
    this.radius = 20,
    this.ringPadding = 2,
    this.gapPadding = 2,
    super.key,
  });

  final File? avatar;
  final double radius;
  final double ringPadding;
  final double gapPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ringPadding),
      decoration: const BoxDecoration(
        gradient: heerrGradient,
        shape: BoxShape.circle,
      ),
      child: Container(
        padding: EdgeInsets.all(gapPadding),
        decoration: const BoxDecoration(
          color: heerrBlack,
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          radius: radius,
          foregroundImage: avatar != null ? FileImage(avatar!) : null,
          child: avatar == null
              ? Icon(Icons.person_outline, size: radius)
              : null,
        ),
      ),
    );
  }
}
