import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Paleta principal ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color.fromARGB(255, 165, 133, 200);
  static const Color primaryLight = Color(0xFF818CF8);

  static const Color secondary = Color(0xFF06B6D4); // cyan
  static const Color secondaryDark = Color(0xFF0891B2);
  static const Color secondaryLight = Color(0xFF67E8F9);

  // ── Fondos ────────────────────────────────────────────────────────────────
  static const Color background = Color.fromARGB(255, 242, 230, 255);
  static const Color surface = Color(0xFF12122A);
  static const Color card = Color(0xFF1C1C3A);
  static const Color cardLight = Color(0xFF252550);

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color.fromARGB(255, 87, 86, 86);
  static const Color textSecondary = Color(0xFFB4B4D0);
  static const Color textHint = Color.fromARGB(255, 109, 107, 107);

  // ── Estado ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Roles ─────────────────────────────────────────────────────────────────
  static const Color rolePsicologo = Color(0xFF8B5CF6); // violeta
  static const Color roleUsuario = Color(0xFF06B6D4); // cyan
  static const Color roleAdmin = Color(0xFFF59E0B); // ámbar

  // ── Bordes ────────────────────────────────────────────────────────────────
  static const Color border = Color(0xFF2E2E5C);
  static const Color borderFocus = Color(0xFF6366F1);

  // ── Overlay ───────────────────────────────────────────────────────────────
  static const Color overlay = Color(0x806366F1);
}
