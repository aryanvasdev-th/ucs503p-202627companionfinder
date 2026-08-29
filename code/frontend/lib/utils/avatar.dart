import 'package:flutter/material.dart';

/// Deterministic cosmetic look for a person/activity from their id — the
/// backend has no color/image data, so this keeps the same visual variety
/// the original mock data had without storing anything server-side.
const _gradients = [
  [Color(0xFF4C7C5A), Color(0xFF2C4A38)],
  [Color(0xFF8A6A4E), Color(0xFF4A3527)],
  [Color(0xFF5A4A8A), Color(0xFF2E2450)],
  [Color(0xFF6E85B0), Color(0xFF33456B)],
  [Color(0xFF9B7B4C), Color(0xFF5A4526)],
];

const _colors = [
  Color(0xFFC77B7B),
  Color(0xFF6E85B0),
  Color(0xFF8A7A5A),
  Color(0xFF6E9B7C),
  Color(0xFF9B7B4C),
];

List<Color> gradientForSeed(int seed) => _gradients[seed % _gradients.length];

Color colorForSeed(int seed) => _colors[seed % _colors.length];

String initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
