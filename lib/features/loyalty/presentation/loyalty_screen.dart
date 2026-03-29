import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/loyalty_event.dart';
import '../../../shared/widgets/red_button.dart';
import '../../../shared/providers/auth_provider.dart';
import 'rewards_sheet.dart';

final _loyaltyProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return {'points': 0, 'tier': 'BRONZE'};
  return DioClient.instance.get<Map<String, dynamic>>('/loyalty/me');
});

final _loyaltyHistoryProvider =
    FutureProvider<List<LoyaltyEvent>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  final data = await DioClient.instance
      .get<dynamic>('/loyalty/me/history');
  if (data is List) {
    return data.map((e) => LoyaltyEvent.fromJson(e as Map<String, dynamic>)).toList();
  }
  final items = (data as Map<String, dynamic>)['items'] as List? ?? [];
  return items.map((e) => LoyaltyEvent.fromJson(e as Map<String, dynamic>)).toList();
});

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final loyaltyAsync = ref.watch(_loyaltyProvider);
    final historyAsync = ref.watch(_loyaltyHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Loyalty'),
      ),
      body: loyaltyAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (loyalty) {
          final points = int.tryParse(
                  loyalty['points']?.toString() ?? '0') ?? 0;
          final tier = loyalty['tier']?.toString() ?? 'BRONZE';
          final nextTier = loyalty['nextTier']?.toString() ?? 'SILVER';
          final pointsToNext = int.tryParse(
                  loyalty['pointsToNextTier']?.toString() ?? '500') ?? 500;
          final benefits = (loyalty['benefits'] as List?)
                  ?.map((e) => e?.toString() ?? '')
                  .toList() ??
              _defaultBenefits(tier);

          final pct = pointsToNext > 0
              ? (points / (points + pointsToNext)).clamp(0.0, 1.0)
              : 1.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Tier header card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _tierGradient(tier),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_tierIcon(tier), color: Colors.white, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          tier,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$points pts',
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PartyPass Points',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.3),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$pointsToNext pts more to reach $nextTier',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Benefits
              Text('Your Benefits',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...benefits.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: kSuccess, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(b,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: dark ? kDarkTextPrimary : kTextPrimary)),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),

              RedButton(
                label: 'Redeem Points',
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const RewardsSheet(),
                ),
              ),
              const SizedBox(height: 28),

              // History
              Text('Points History',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              historyAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: kPrimary)),
                error: (_, __) => Text('Could not load history',
                    style: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted)),
                data: (history) {
                  if (history.isEmpty) {
                    return Center(
                      child: Text('No points history yet',
                          style: GoogleFonts.inter(
                              color: dark ? kDarkTextMuted : kTextMuted)),
                    );
                  }
                  return Column(
                    children: history
                        .map((e) => _HistoryRow(event: e))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _tierIcon(String tier) {
    switch (tier) {
      case 'PLATINUM':
        return Icons.workspace_premium_rounded;
      case 'DIAMOND':
        return Icons.diamond_rounded;
      case 'GOLD':
        return Icons.emoji_events_rounded;
      case 'SILVER':
        return Icons.star_half_rounded;
      default:
        return Icons.star_outline_rounded;
    }
  }

  List<Color> _tierGradient(String tier) {
    switch (tier) {
      case 'DIAMOND':
        return [const Color(0xFF7C3AED), const Color(0xFF4F46E5)];
      case 'PLATINUM':
        return [const Color(0xFF475569), const Color(0xFF1E293B)];
      case 'GOLD':
        return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      case 'SILVER':
        return [const Color(0xFF9CA3AF), const Color(0xFF6B7280)];
      default: // BRONZE
        return [const Color(0xFFCD7F32), const Color(0xFFA0522D)];
    }
  }

  List<String> _defaultBenefits(String tier) {
    switch (tier) {
      case 'GOLD':
        return [
          'Priority entry at all events',
          '10% discount on tickets',
          'Exclusive Gold member events',
          'Free drink at select venues',
        ];
      case 'SILVER':
        return [
          '5% discount on tickets',
          'Early access to presales',
          'Silver badge on profile',
        ];
      default:
        return [
          'Earn 1 point per KES 100 spent',
          'Access to exclusive offers',
          'Birthday bonus points',
        ];
    }
  }
}

class _HistoryRow extends StatelessWidget {
  final LoyaltyEvent event;
  const _HistoryRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: event.isEarning
                  ? kSuccess.withValues(alpha: 0.1)
                  : kDanger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              event.isEarning ? Icons.add_rounded : Icons.remove_rounded,
              size: 16,
              color: event.isEarning ? kSuccess : kDanger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description ?? event.action,
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (event.createdAt.isNotEmpty)
                  Text(
                    AppDateUtils.formatDate(
                        DateTime.parse(event.createdAt)),
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
              ],
            ),
          ),
          Text(
            '${event.isEarning ? "+" : ""}${event.points}',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: event.isEarning ? kSuccess : kDanger,
            ),
          ),
        ],
      ),
    );
  }
}
