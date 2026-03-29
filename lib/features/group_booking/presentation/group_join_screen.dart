import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/app_snackbar.dart';

final _groupProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, shareToken) async {
  return DioClient.instance
      .get<Map<String, dynamic>>('/group-bookings/join/$shareToken');
});

class GroupJoinScreen extends ConsumerStatefulWidget {
  final String shareToken;
  const GroupJoinScreen({super.key, required this.shareToken});

  @override
  ConsumerState<GroupJoinScreen> createState() => _GroupJoinScreenState();
}

class _GroupJoinScreenState extends ConsumerState<GroupJoinScreen> {
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      final result = await DioClient.instance.post<Map<String, dynamic>>(
        '/group-bookings/join/${widget.shareToken}',
      );
      if (mounted) {
        final orderId = result['orderId']?.toString();
        final groupId = result['groupId']?.toString();
        if (orderId != null) {
          context.push('/payment/$orderId');
        } else if (groupId != null) {
          AppSnackbar.showSuccess(
              context, 'Joined! Waiting for creator to pay.');
          context.pop();
        } else {
          AppSnackbar.showSuccess(context, 'Successfully joined the group!');
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final groupAsync = ref.watch(_groupProvider(widget.shareToken));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Group Booking'),
      ),
      body: groupAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off_rounded, size: 56, color: dark ? kDarkTextMuted : kTextMuted),
                const SizedBox(height: 16),
                Text('Invalid or expired link',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: dark ? kDarkTextPrimary : kTextPrimary)),
                const SizedBox(height: 8),
                Text('This group booking link may have expired.',
                    style:
                        GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextMuted : kTextMuted),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/events'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  child: const Text('Browse Events'),
                ),
              ],
            ),
          ),
        ),
        data: (group) {
          final event = group['event'] as Map<String, dynamic>?;
          final tier = group['tier'] as Map<String, dynamic>?;
          final members = (group['members'] as List?) ?? [];
          final maxSize = group['maxSize'] as int? ?? 10;
          final name = group['name']?.toString();
          final creatorPaysAll = group['creatorPaysAll'] == true;
          final status = group['status']?.toString() ?? 'OPEN';
          final tierPrice =
              (tier?['price'] as num?)?.toDouble() ?? 0.0;
          final currency = tier?['currency']?.toString() ?? 'KES';
          final isFull = members.length >= maxSize;
          final isOpen = status == 'OPEN' || status == 'PARTIAL';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Event info ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: dark ? kDarkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: dark ? kDarkBorder : kBorder, width: 0.8),
                    boxShadow: const [BoxShadow(color: kCardShadow, blurRadius: 16, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: kPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Group Booking',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: kPrimary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name ?? event?['title']?.toString() ?? 'Group Booking',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: dark ? kDarkTextPrimary : kTextPrimary),
                      ),
                      if (event != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          event['title']?.toString() ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: dark ? kDarkTextMuted : kTextMuted),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Divider(height: 1, color: dark ? kDarkBorder : kBorder),
                      const SizedBox(height: 16),
                      // Tier + price
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ticket Tier',
                                    style: GoogleFonts.inter(
                                        fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
                                const SizedBox(height: 2),
                                Text(
                                    tier?['name']?.toString() ??
                                        'General Admission',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: dark ? kDarkTextPrimary : kTextPrimary)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Your Cost',
                                  style: GoogleFonts.inter(
                                      fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
                              const SizedBox(height: 2),
                              Text(
                                creatorPaysAll
                                    ? 'FREE (host pays)'
                                    : '$currency ${tierPrice.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: creatorPaysAll ? kSuccess : kPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Members ────────────────────────────────────────────
                Row(
                  children: [
                    Text('Group Members',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: dark ? kDarkTextPrimary : kTextPrimary)),
                    const Spacer(),
                    Text('${members.length}/$maxSize',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted)),
                  ],
                ),
                const SizedBox(height: 12),
                // Slot indicators
                Row(
                  children: List.generate(maxSize, (i) {
                    final filled = i < members.length;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 6,
                        decoration: BoxDecoration(
                          color: filled ? kPrimary : kBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                if (members.isNotEmpty)
                  ...members.map((m) {
                    final member = m as Map<String, dynamic>;
                    final mStatus =
                        member['status']?.toString() ?? 'JOINED';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                kPrimary.withValues(alpha: 0.15),
                            child: Text(
                              (member['user'] as Map?)?['firstName']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true
                                  ? (member['user']
                                          as Map)['firstName']
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : '?',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              [
                                (member['user'] as Map?)?['firstName']
                                    ?.toString(),
                                (member['user'] as Map?)?['lastName']
                                    ?.toString(),
                              ]
                                  .where((s) =>
                                      s != null && s.isNotEmpty)
                                  .join(' ')
                                  .ifEmpty('Member'),
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: dark ? kDarkTextPrimary : kTextPrimary),
                            ),
                          ),
                          _memberBadge(mStatus),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 24),

                // ── Share link ─────────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                        text:
                            'Join my group booking! Token: ${widget.shareToken}'));
                    AppSnackbar.showSuccess(context, 'Link copied!');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: dark ? kDarkSurface : kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: dark ? kDarkBorder : kBorder, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded,
                            size: 18, color: dark ? kDarkTextMuted : kTextMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.shareToken,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: dark ? kDarkTextMuted : kTextMuted,
                                letterSpacing: 0.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.copy_rounded,
                            size: 16, color: dark ? kDarkTextMuted : kTextMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── CTA ────────────────────────────────────────────────
                if (!isOpen)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dark ? kDarkSurface : kSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 16, color: dark ? kDarkTextMuted : kTextMuted),
                        const SizedBox(width: 8),
                        Text('This group is $status',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: dark ? kDarkTextMuted : kTextMuted)),
                      ],
                    ),
                  )
                else if (isFull)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dark ? kDarkSurface : kSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off_rounded,
                            size: 16, color: dark ? kDarkTextMuted : kTextMuted),
                        const SizedBox(width: 8),
                        Text('Group is full ($maxSize/$maxSize)',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: dark ? kDarkTextMuted : kTextMuted)),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _joining ? null : _join,
                      icon: _joining
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.group_add_rounded),
                      label: Text(
                        _joining
                            ? 'Joining...'
                            : creatorPaysAll
                                ? 'Join Group (Free)'
                                : 'Join & Pay My Seat',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: kPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _memberBadge(String status) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Color bg, fg;
    String label;
    switch (status) {
      case 'PAID':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        label = 'Paid';
      case 'JOINED':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'Joined';
      case 'DECLINED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Declined';
      default:
        bg = dark ? kDarkSurface : kSurface;
        fg = dark ? kDarkTextMuted : kTextMuted;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
