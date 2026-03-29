import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';

class RewardsSheet extends StatefulWidget {
  const RewardsSheet({super.key});

  @override
  State<RewardsSheet> createState() => _RewardsSheetState();
}

class _RewardsSheetState extends State<RewardsSheet> {
  List<Map<String, dynamic>> _rewards = [];
  bool _loading = true;
  String? _redeemingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await DioClient.instance.get<dynamic>('/loyalty/rewards');
      final list = raw is List ? raw : (raw as Map<String, dynamic>)['items'] ?? [];
      setState(() => _rewards = List<Map<String, dynamic>>.from(list as List));
    } catch (_) {
      setState(() => _rewards = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _redeem(String rewardId, String name) async {
    setState(() => _redeemingId = rewardId);
    try {
      final res = await DioClient.instance
          .post<Map<String, dynamic>>('/loyalty/redeem/$rewardId');
      final code = res['code']?.toString() ?? '';
      if (mounted) {
        context.pop(true);
        AppSnackbar.showSuccess(
            context, '🎉 Redeemed! Your code: $code');
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _redeemingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: dark ? kDarkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: dark ? kDarkBorder : kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Redeem Points',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: dark ? kDarkTextPrimary : kTextPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: dark ? kDarkTextMuted : kTextMuted),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: dark ? kDarkBorder : kBorder),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: kPrimary))
                  : _rewards.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.card_giftcard_rounded,
                                  size: 56,
                                  color: dark ? kDarkTextMuted : kTextMuted),
                              const SizedBox(height: 12),
                              Text('No rewards available yet',
                                  style: GoogleFonts.inter(
                                      color: dark ? kDarkTextMuted : kTextMuted,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          itemCount: _rewards.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _RewardCard(
                                reward: _rewards[i],
                                isRedeeming:
                                    _redeemingId == _rewards[i]['id'],
                                onRedeem: () => _redeem(
                                  _rewards[i]['id'].toString(),
                                  _rewards[i]['name']?.toString() ?? '',
                                ),
                              ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final Map<String, dynamic> reward;
  final bool isRedeeming;
  final VoidCallback onRedeem;

  const _RewardCard({
    required this.reward,
    required this.isRedeeming,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cost = reward['pointsCost']?.toString() ?? '0';
    final stock = reward['stock'];
    final redeemed = reward['redeemedCount'] ?? 0;
    final remaining =
        stock != null ? (stock as int) - (redeemed as int) : null;
    final category = (reward['category']?.toString() ?? '')
        .replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? kDarkBorder : kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_categoryIcon(reward['category']?.toString() ?? ''),
                color: kPrimary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward['name']?.toString() ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: dark ? kDarkTextMuted : kTextMuted),
                ),
                if (remaining != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$remaining left',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: remaining < 10
                            ? kDanger
                            : (dark ? kDarkTextMuted : kTextMuted)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$cost pts',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kPrimary,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 34,
                child: FilledButton(
                  onPressed: isRedeeming ? null : onRedeem,
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: isRedeeming
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Redeem',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'FREE_TICKET':
        return Icons.confirmation_number_rounded;
      case 'DRINK_VOUCHER':
        return Icons.local_bar_rounded;
      case 'FOOD_VOUCHER':
        return Icons.fastfood_rounded;
      case 'VIP_UPGRADE':
        return Icons.workspace_premium_rounded;
      case 'DISCOUNT':
        return Icons.percent_rounded;
      case 'MERCH':
        return Icons.checkroom_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }
}
