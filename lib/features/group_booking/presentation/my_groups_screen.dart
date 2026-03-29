import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/app_snackbar.dart';

final _myGroupsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return DioClient.instance.get<Map<String, dynamic>>('/group-bookings/my');
});

class MyGroupsScreen extends ConsumerWidget {
  const MyGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_myGroupsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_rounded,
                    size: 48, color: dark ? kDarkTextMuted : kTextMuted),
                const SizedBox(height: 12),
                Text('Could not load groups',
                    style: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(_myGroupsProvider),
                  style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50))),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        },
        data: (data) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          final created = (data['created'] as List?) ?? [];
          final joined = (data['joined'] as List?) ?? [];

          if (created.isEmpty && joined.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.group_rounded,
                          size: 40, color: kPrimary),
                    ),
                    const SizedBox(height: 20),
                    Text('No group bookings yet',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: dark ? kDarkTextPrimary : kTextPrimary)),
                    const SizedBox(height: 8),
                    Text(
                      'Open any event and tap "Group" to create a group booking — your crew each pays their own seat.',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: dark ? kDarkTextMuted : kTextMuted,
                          height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => context.go('/events'),
                        icon: const Icon(Icons.search_rounded),
                        label: Text('Browse Events',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: kPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              // ── Groups I created ─────────────────────────────────────
              if (created.isNotEmpty) ...[
                _sectionHeader('Groups I Created', created.length, dark),
                const SizedBox(height: 12),
                ...created.map((g) {
                  final group = g as Map<String, dynamic>;
                  return _CreatedGroupCard(
                    group: group,
                    onRefresh: () => ref.invalidate(_myGroupsProvider),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // ── Groups I joined ──────────────────────────────────────
              if (joined.isNotEmpty) ...[
                _sectionHeader('Groups I Joined', joined.length, dark),
                const SizedBox(height: 12),
                ...joined.map((g) {
                  final group = g as Map<String, dynamic>;
                  return _JoinedGroupCard(group: group);
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label, int count, bool dark) {
    return Row(
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: dark ? kDarkTextPrimary : kTextPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: dark ? kDarkSurface : kSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dark ? kDarkTextMuted : kTextMuted)),
        ),
      ],
    );
  }
}

// ─── Created group card ────────────────────────────────────────────────────────

class _CreatedGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onRefresh;

  const _CreatedGroupCard({required this.group, required this.onRefresh});

  void _share(BuildContext context) {
    final token = group['shareToken']?.toString() ?? '';
    Share.share(
      'Join my group booking on PartyPass! 🎉\n\nhttps://partypass.app/group/$token',
      subject: 'Group booking invite',
    );
  }

  void _copyLink(BuildContext context) {
    final token = group['shareToken']?.toString() ?? '';
    Clipboard.setData(
        ClipboardData(text: 'https://partypass.app/group/$token'));
    AppSnackbar.showSuccess(context, 'Link copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final event = group['event'] as Map<String, dynamic>?;
    final tier = group['tier'] as Map<String, dynamic>?;
    final members = (group['members'] as List?) ?? [];
    final maxSize = group['maxSize'] as int? ?? 4;
    final status = group['status']?.toString() ?? 'OPEN';
    final creatorPaysAll = group['creatorPaysAll'] == true;
    final filled = members.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dark ? kDarkBorder : kBorder, width: 0.5),
        boxShadow: const [
          BoxShadow(color: kCardShadow, blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event?['title']?.toString() ?? 'Event',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: dark ? kDarkTextPrimary : kTextPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tier?['name']?.toString() ?? 'General Admission',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: dark ? kDarkTextMuted : kTextMuted),
                      ),
                    ],
                  ),
                ),
                _statusChip(status),
              ],
            ),
          ),

          // ── Member slots progress ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Members joined',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: dark ? kDarkTextMuted : kTextMuted)),
                    Text('$filled / $maxSize',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: dark ? kDarkTextPrimary : kTextPrimary)),
                  ],
                ),
                const SizedBox(height: 6),
                // Slot dots
                Row(
                  children: List.generate(maxSize, (i) {
                    final isFilled = i < filled;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 6,
                        decoration: BoxDecoration(
                          color: isFilled ? kPrimary : (dark ? kDarkBorder : kBorder),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
                if (creatorPaysAll) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.volunteer_activism_rounded,
                            size: 12, color: Color(0xFFEA580C)),
                        const SizedBox(width: 4),
                        Text('You are paying for everyone',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF9A3412),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Actions ────────────────────────────────────────────────
          const SizedBox(height: 12),
          Divider(height: 1, color: dark ? kDarkBorder : kBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _copyLink(context),
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: Text('Copy link',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(foregroundColor: kTextMuted),
                ),
                TextButton.icon(
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.share_rounded, size: 15),
                  label: Text('Share',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(foregroundColor: kPrimary),
                ),
                const Spacer(),
                if (status == 'OPEN' || status == 'PARTIAL')
                  TextButton(
                    onPressed: () {
                      final token = group['shareToken']?.toString() ?? '';
                      context.push('/group/$token');
                    },
                    style: TextButton.styleFrom(
                        foregroundColor: kPrimary),
                    child: Text('View',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'OPEN':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        label = 'Open';
      case 'PARTIAL':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'Filling';
      case 'COMPLETE':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = 'Full';
      case 'EXPIRED':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        label = 'Expired';
      default:
        bg = kSurface;
        fg = kTextMuted;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ─── Joined group card ────────────────────────────────────────────────────────

class _JoinedGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  const _JoinedGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final event = group['event'] as Map<String, dynamic>?;
    final tier = group['tier'] as Map<String, dynamic>?;
    final members = (group['members'] as List?) ?? [];
    final maxSize = group['maxSize'] as int? ?? 4;
    final myStatus = group['myStatus']?.toString() ?? 'JOINED';
    final creatorPaysAll = group['creatorPaysAll'] == true;
    final price = (tier?['price'] as num?)?.toDouble() ?? 0.0;
    final currency = tier?['currency']?.toString() ?? 'KES';

    Color statusBg, statusFg;
    String statusLabel;
    switch (myStatus) {
      case 'PAID':
        statusBg = const Color(0xFFDCFCE7);
        statusFg = const Color(0xFF166534);
        statusLabel = 'Paid ✓';
      case 'JOINED':
        statusBg = const Color(0xFFFEF3C7);
        statusFg = const Color(0xFF92400E);
        statusLabel = 'Awaiting payment';
      default:
        statusBg = kSurface;
        statusFg = kTextMuted;
        statusLabel = myStatus;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dark ? kDarkBorder : kBorder, width: 0.5),
        boxShadow: const [
          BoxShadow(color: kCardShadow, blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event?['title']?.toString() ?? 'Event',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: dark ? kDarkTextPrimary : kTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tier?['name']?.toString() ?? 'General Admission',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: dark ? kDarkTextMuted : kTextMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusFg)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.people_rounded,
                  size: 14, color: dark ? kDarkTextMuted : kTextMuted),
              const SizedBox(width: 4),
              Text('${members.length}/$maxSize members',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: dark ? kDarkTextMuted : kTextMuted)),
              const Spacer(),
              if (creatorPaysAll)
                Text('Free (host pays)',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kSuccess))
              else
                Text('$currency ${price.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kPrimary)),
            ],
          ),
          if (myStatus == 'JOINED' && !creatorPaysAll) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () {
                  final memberId = group['myMemberId']?.toString() ?? '';
                  context.push('/group-pay/$memberId');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                ),
                child: Text('Pay My Seat — $currency ${price.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
