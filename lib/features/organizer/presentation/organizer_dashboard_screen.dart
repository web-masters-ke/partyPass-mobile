import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _walletProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return DioClient.instance.get<Map<String, dynamic>>('/organizer/wallet');
});

final _recentEventsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await DioClient.instance
      .get<dynamic>('/organizer/events', queryParameters: {'limit': 3});
  if (data is List) return data.cast<Map<String, dynamic>>();
  final items =
      (data as Map<String, dynamic>)['items'] as List? ?? [];
  return items.cast<Map<String, dynamic>>();
});

final _recentPayoutsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await DioClient.instance
      .get<dynamic>('/organizer/payouts', queryParameters: {'limit': 3});
  if (data is List) return data.cast<Map<String, dynamic>>();
  final items =
      (data as Map<String, dynamic>)['items'] as List? ?? [];
  return items.cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OrganizerDashboardScreen extends ConsumerWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final walletAsync = ref.watch(_walletProvider);
    final eventsAsync = ref.watch(_recentEventsProvider);
    final payoutsAsync = ref.watch(_recentPayoutsProvider);
    final userAsync = ref.watch(currentUserProvider);
    final isClubOwner = userAsync.valueOrNull?.role == 'ORGANIZER';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/organizer/events/new'),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Create Event',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: () async {
          ref.invalidate(_walletProvider);
          ref.invalidate(_recentEventsProvider);
          ref.invalidate(_recentPayoutsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            // ── Stat Cards ────────────────────────────────────────────────
            walletAsync.when(
              loading: () => _StatsShimmer(dark: dark),
              error: (e, _) => _ErrorCard(
                message: e.toString(),
                onRetry: () => ref.invalidate(_walletProvider),
              ),
              data: (wallet) {
                final gross = double.tryParse(
                        wallet['grossRevenue']?.toString() ?? '0') ??
                    0;
                final net = gross * 0.95;
                final activeEvents = int.tryParse(
                        wallet['activeEvents']?.toString() ?? '0') ??
                    0;
                final ticketsSold = int.tryParse(
                        wallet['ticketsSold']?.toString() ?? '0') ??
                    0;
                return GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StatCard(
                      label: 'Gross Revenue',
                      value: _formatCurrency(gross),
                      icon: Icons.trending_up_rounded,
                      color: kSuccess,
                      dark: dark,
                    ),
                    _StatCard(
                      label: 'Net Earnings',
                      value: _formatCurrency(net),
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFF3B82F6),
                      dark: dark,
                    ),
                    _StatCard(
                      label: 'Active Events',
                      value: activeEvents.toString(),
                      icon: Icons.event_rounded,
                      color: kPrimary,
                      dark: dark,
                    ),
                    _StatCard(
                      label: 'Tickets Sold',
                      value: ticketsSold.toString(),
                      icon: Icons.confirmation_number_rounded,
                      color: kWarning,
                      dark: dark,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Quick links ───────────────────────────────────────────────
            Row(
              children: [
                _QuickLink(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Wallet',
                  onTap: () => context.push('/organizer/wallet'),
                  dark: dark,
                ),
                const SizedBox(width: 10),
                _QuickLink(
                  icon: Icons.group_rounded,
                  label: 'My Team',
                  onTap: () => context.push('/organizer/team'),
                  dark: dark,
                ),
                if (isClubOwner) ...[
                  const SizedBox(width: 10),
                  _QuickLink(
                    icon: Icons.location_city_rounded,
                    label: 'My Clubs',
                    onTap: () => context.push('/organizer/clubs'),
                    dark: dark,
                    accent: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 28),

            // ── My Events ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Events',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/organizer/events'),
                  child: Text(
                    'See All',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            eventsAsync.when(
              loading: () => SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, __) => _HorizontalCardShimmer(dark: dark),
                ),
              ),
              error: (e, _) => _ErrorCard(
                message: 'Could not load events',
                onRetry: () => ref.invalidate(_recentEventsProvider),
              ),
              data: (events) {
                if (events.isEmpty) {
                  return _EmptyState(
                    icon: Icons.event_rounded,
                    message: 'No events yet',
                    action: 'Create your first event',
                    onAction: () => context.push('/organizer/events/new'),
                    dark: dark,
                  );
                }
                return SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: events.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 12),
                    itemBuilder: (_, i) =>
                        _EventCard(event: events[i], dark: dark),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // ── Recent Payouts ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Payouts',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/organizer/wallet'),
                  child: Text(
                    'View Wallet',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            payoutsAsync.when(
              loading: () => Column(
                children: List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ListItemShimmer(dark: dark),
                  ),
                ),
              ),
              error: (e, _) => _ErrorCard(
                message: 'Could not load payouts',
                onRetry: () => ref.invalidate(_recentPayoutsProvider),
              ),
              data: (payouts) {
                if (payouts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No payouts yet',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: dark ? kDarkTextMuted : kTextMuted),
                      ),
                    ),
                  );
                }
                return Column(
                  children: payouts
                      .map((p) => _PayoutRow(payout: p, dark: dark))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    final fmt = NumberFormat('#,##0', 'en_US');
    return 'KES ${fmt.format(value.round())}';
  }
}

// ---------------------------------------------------------------------------
// Stat Card
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool dark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? kDarkBorder : kBorder, width: 0.8),
        boxShadow: const [
          BoxShadow(
              color: kCardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: dark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: dark ? kDarkTextMuted : kTextMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event Card (horizontal)
// ---------------------------------------------------------------------------

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool dark;

  const _EventCard({required this.event, required this.dark});

  @override
  Widget build(BuildContext context) {
    final coverUrl = event['coverImageUrl']?.toString();
    final title = event['title']?.toString() ?? 'Untitled';
    final status = event['status']?.toString() ?? 'DRAFT';
    final revenue = double.tryParse(
            event['revenue']?.toString() ?? '0') ??
        0;
    DateTime? startDate;
    try {
      if (event['startDateTime'] != null) {
        startDate = DateTime.parse(event['startDateTime'].toString());
      }
    } catch (_) {}

    return GestureDetector(
      onTap: () => context.push(
          '/organizer/events/${event['id']?.toString() ?? ''}'),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: dark ? kDarkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: dark ? kDarkBorder : kBorder, width: 0.8),
          boxShadow: const [
            BoxShadow(
                color: kCardShadow, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            SizedBox(
              height: 100,
              width: double.infinity,
              child: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: kPrimary.withValues(alpha: 0.12),
                      child: const Icon(Icons.event_rounded,
                          color: kPrimary, size: 32),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: dark ? kDarkTextPrimary : kTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusBadge(status: status, dark: dark),
                      const Spacer(),
                      if (startDate != null)
                        Text(
                          AppDateUtils.formatShortDate(startDate),
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: dark ? kDarkTextMuted : kTextMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'KES ${NumberFormat('#,##0').format(revenue.round())}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kSuccess,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payout Row
// ---------------------------------------------------------------------------

class _PayoutRow extends StatelessWidget {
  final Map<String, dynamic> payout;
  final bool dark;

  const _PayoutRow({required this.payout, required this.dark});

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(
            payout['amount']?.toString() ?? '0') ??
        0;
    final status = payout['status']?.toString() ?? 'PENDING';
    DateTime? createdAt;
    try {
      if (payout['createdAt'] != null) {
        createdAt = DateTime.parse(payout['createdAt'].toString());
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: dark ? kDarkBorder : kBorder, width: 0.8),
        boxShadow: const [
          BoxShadow(
              color: kCardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kSuccess.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                size: 20, color: kSuccess),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KES ${NumberFormat('#,##0').format(amount.round())}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                if (createdAt != null)
                  Text(
                    AppDateUtils.formatDate(createdAt),
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
              ],
            ),
          ),
          _StatusBadge(status: status, dark: dark),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool dark;

  const _StatusBadge({required this.status, required this.dark});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'PUBLISHED':
        bg = kSuccess.withValues(alpha: 0.12);
        fg = kSuccess;
      case 'PROCESSING':
      case 'APPROVED':
        bg = dark
            ? const Color(0xFF1D4ED8).withValues(alpha: 0.15)
            : const Color(0xFFDBEAFE);
        fg = dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
      case 'PENDING':
        bg = kWarning.withValues(alpha: 0.12);
        fg = kWarning;
      case 'FAILED':
      case 'REJECTED':
      case 'CANCELLED':
        bg = kDanger.withValues(alpha: 0.12);
        fg = kDanger;
      case 'DRAFT':
      default:
        bg = dark ? kDarkBorder : kBorder;
        fg = dark ? kDarkTextMuted : kTextMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty State
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final bool dark;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(icon,
                size: 48, color: dark ? kDarkTextMuted : kTextMuted),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: dark ? kDarkTextMuted : kTextMuted),
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onAction,
                child: Text(
                  action!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error Card
// ---------------------------------------------------------------------------

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDanger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDanger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: kDanger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 13, color: kDanger),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.inter(
                  color: kPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer helpers
// ---------------------------------------------------------------------------

class _StatsShimmer extends StatelessWidget {
  final bool dark;
  const _StatsShimmer({required this.dark});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: dark ? kDarkSurface : kSurface,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _HorizontalCardShimmer extends StatelessWidget {
  final bool dark;
  const _HorizontalCardShimmer({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _ListItemShimmer extends StatelessWidget {
  final bool dark;
  const _ListItemShimmer({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;
  final bool accent;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.dark,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: accent ? kPrimary.withValues(alpha: 0.08) : (dark ? kDarkSurface : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent ? kPrimary : (dark ? kDarkBorder : kBorder)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: accent ? kPrimary : (dark ? kDarkTextPrimary : kTextPrimary)),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent ? kPrimary : (dark ? kDarkTextPrimary : kTextPrimary),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
