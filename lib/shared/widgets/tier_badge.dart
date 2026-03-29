import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TierBadge extends StatelessWidget {
  final String tier;
  final bool small;

  const TierBadge({super.key, required this.tier, this.small = false});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _tierColors(tier);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        _tierLabel(tier),
        style: GoogleFonts.inter(
          fontSize: small ? 11 : 13,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _tierLabel(String tier) {
    const labels = {
      'GA': 'General Admission',
      'EARLY_BIRD': 'Early Bird',
      'VIP': 'VIP',
      'VVIP': 'VVIP',
      'TABLE': 'Table',
      'GROUP': 'Group',
      'BACKSTAGE': 'Backstage',
      'PRESS': 'Press',
      'COMP': 'Complimentary',
    };
    return labels[tier.toUpperCase()] ?? tier;
  }

  (Color, Color) _tierColors(String tier) {
    switch (tier.toUpperCase()) {
      case 'VVIP':
        return (const Color(0xFF1A1A1A), Colors.white);
      case 'VIP':
        return (const Color(0xFFF59E0B), const Color(0xFF1A1A1A));
      case 'EARLY_BIRD':
        return (const Color(0xFF3B82F6), Colors.white);
      case 'TABLE':
        return (const Color(0xFF8B5CF6), Colors.white);
      case 'BACKSTAGE':
        return (const Color(0xFF10B981), Colors.white);
      case 'PRESS':
        return (const Color(0xFF6B7280), Colors.white);
      default: // GA
        return (const Color(0xFFE5E5E5), const Color(0xFF1A1A1A));
    }
  }
}
