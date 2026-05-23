import 'package:flutter/material.dart';

class AppColors {
  // Pure visual color palette from Figma
  static const Color background = Color(
    0xFF09090B,
  ); // Darkest ambient background
  static const Color sidebar = Color(0xFF09090B); // Navigation rail background
  static const Color sidebarList = Color(
    0xFF0E0E11,
  ); // Chat list sidebar background
  static const Color chatBackground = Color(
    0xFF050507,
  ); // Right-pane chat view background

  static const Color cardBg = Color(0xFF121214); // Input card background
  static const Color inputBg = Color(0xFF09090B); // Text input fill
  static const Color border = Color(0xFF27272A); // Muted border outline
  static const Color borderFocused = Color(0xFF3B82F6); // Focused blue border

  static const Color textPrimary = Color(0xFFFFFFFF); // Bold white text
  static const Color textSecondary = Color(0xFFD4D4D8); // Muted white text
  static const Color textMuted = Color(0xFF71717A); // Muted gray subtext

  static const Color accentBlue = Color(0xFF3B82F6); // Accent Blue
  static const Color accentIndigo = Color(0xFF6366F1); // Accent Indigo/Purple
  static const Color onlineGreen = Color(
    0xFF22C55E,
  ); // Standard online green dot
  static const Color badgeBg = Color(
    0xFF3B82F6,
  ); // Notification badge background

  // Chat Bubbles
  static const Color bubbleIncoming = Color(
    0xFF1C1C1F,
  ); // Charcoal incoming bubble
  static const List<Color> bubbleOutgoingGradient = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF3B82F6), // Blue
  ];

  // Dynamic color palette for avatars matching Figma
  static const List<Color> avatarColors = [
    Color(0xFF8B5CF6), // Purple
    Color(0xFF3B82F6), // Blue
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Orange
    Color(0xFF14B8A6), // Teal
    Color(0xFFD946EF), // Magenta
    Color(0xFF2563EB), // Deep Blue
    Color(0xFF84CC16), // Lime
  ];

  /// Deterministically gets a background color for a name so that
  /// a user's avatar color is always consistent across screens.
  static Color getAvatarColor(String name) {
    if (name.isEmpty) return avatarColors[0];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return avatarColors[hash.abs() % avatarColors.length];
  }
}
