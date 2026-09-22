import 'package:flutter/material.dart';

/// The temple palette, shared with the backend's `config/brand.php`.
///
/// Saffron is the devotional anchor, kumkum red the accent and temple gold the
/// highlight. Sandal is the warm paper tone of the light scheme; deep is the
/// aged-teak brown of the dark scheme.
class Palette {
  Palette._();

  static const Color saffron = Color(0xFFE07A1F);
  static const Color kumkum = Color(0xFF9B1B30);
  static const Color gold = Color(0xFFC9A227);
  static const Color sandal = Color(0xFFF5EBDC);
  static const Color deep = Color(0xFF3E2723);

  // Supporting tones.
  static const Color turmeric = Color(0xFFF2B632);
  static const Color vermilion = Color(0xFFC1440E);
  static const Color teak = Color(0xFF5D3A2E);
  static const Color ebony = Color(0xFF1E120F);
  static const Color ash = Color(0xFF6B7FA8);
  static const Color tulsi = Color(0xFF2E7D55);
  static const Color ivory = Color(0xFFFFF8EC);
  static const Color stone = Color(0xFFB8A48B);
  static const Color darkStone = Color(0xFF2B1B16);

  /// Brass gradient used for studs, rims and stamps.
  static const LinearGradient brass = LinearGradient(
    colors: [Color(0xFFF7E29C), Color(0xFFC9A227), Color(0xFF8C6A10), Color(0xFFE6C75A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Teak wood gradient for temple doors.
  static const LinearGradient teakWood = LinearGradient(
    colors: [Color(0xFF6B4230), Color(0xFF4E2C20), Color(0xFF6B4230), Color(0xFF3E2723)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
