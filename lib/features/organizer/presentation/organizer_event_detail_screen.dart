import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_snackbar.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _eventDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return DioClient.instance.get<Map<String, dynamic>>('/events/$id');
});

final _eventAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return DioClient.instance
      .get<Map<String, dynamic>>('/events/$id/analytics');
});

final _eventAttendeesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, id) async {
  final data = await DioClient.instance
      .get<dynamic>('/events/$id/attendees', queryParameters: {'limit': 5});
  if (data is List) return data.cast<Map<String, dynamic>>();
  final items =
      (data as Map<String, dynamic>)['items'] as List? ?? [];
  return items.cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OrganizerEventDetailScreen extends ConsumerWidget {
  final String eventId;

  const OrganizerEventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final eventAsync = ref.watch(_eventDetailProvider(eventId));
    final analyticsAsync = ref.watch(_eventAnalyticsProvider(eventId));
    final attendeesAsync = ref.watch(_eventAttendeesProvider(eventId));

    return Scaffold(
      body: eventAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (e, _) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => context.pop(),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_rounded,
                    size: 48,
                    color: dark ? kDarkTextMuted : kTextMuted),
                const SizedBox(height: 12),
                Text(e.toString(),
                    style: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(_eventDetailProvider(eventId)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (event) {
          final coverUrl = event['coverImageUrl']?.toString();
          final title = event['title']?.toString() ?? 'Untitled';
          final status = event['status']?.toString() ?? 'DRAFT';
          final tiers = (event['ticketTiers'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              [];

          return CustomScrollView(
            slivers: [
              // ── Sliver App Bar with cover ──────────────────────────────
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                leading: IconButton(
                  icon: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 16, color: Colors.white),
                  ),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: kPrimary.withValues(alpha: 0.2)),
                      // Gradient overlay
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            _StatusBadge(status: status),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Content ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Analytics stats
                      analyticsAsync.when(
                        loading: () => _StatsShimmer(dark: dark),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (analytics) => _AnalyticsGrid(
                            analytics: analytics, dark: dark),
                      ),
                      const SizedBox(height: 28),

                      // Ticket tiers
                      Text(
                        'Ticket Tiers',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: dark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (tiers.isEmpty)
                        Text(
                          'No ticket tiers defined',
                          style: GoogleFonts.inter(
                              color: dark ? kDarkTextMuted : kTextMuted,
                              fontSize: 13),
                        )
                      else
                        ...tiers.map((t) => _TierRow(tier: t, dark: dark)),
                      const SizedBox(height: 28),

                      // Action buttons
                      if (status == 'DRAFT')
                        _ActionButton(
                          label: 'Publish Event',
                          color: kSuccess,
                          icon: Icons.publish_rounded,
                          onTap: () =>
                              _handleAction(context, ref, 'publish'),
                        ),
                      if (status == 'PUBLISHED')
                        _ActionButton(
                          label: 'Cancel Event',
                          color: kDanger,
                          icon: Icons.cancel_rounded,
                          onTap: () =>
                              _handleAction(context, ref, 'cancel'),
                        ),
                      const SizedBox(height: 28),

                      // Recent attendees
                      Text(
                        'Recent Attendees',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: dark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      attendeesAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                              color: kPrimary),
                        ),
                        error: (_, __) => Text(
                          'Could not load attendees',
                          style: GoogleFonts.inter(
                              color: dark ? kDarkTextMuted : kTextMuted),
                        ),
                        data: (attendees) {
                          if (attendees.isEmpty) {
                            return Text(
                              'No orders yet',
                              style: GoogleFonts.inter(
                                  color: dark ? kDarkTextMuted : kTextMuted,
                                  fontSize: 13),
                            );
                          }
                          return Column(
                            children: attendees
                                .map((a) =>
                                    _AttendeeRow(attendee: a, dark: dark))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String action) async {
    final label = action == 'publish' ? 'Publish' : 'Cancel';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label Event'),
        content: Text(
            'Are you sure you want to $action this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: action == 'cancel' ? kDanger : kPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await DioClient.instance
            .patch<dynamic>('/events/$eventId/$action');
        ref.invalidate(_eventDetailProvider(eventId));
        if (context.mounted) {
          AppSnackbar.showSuccess(
              context, 'Event ${action}ed successfully');
        }
      } catch (e) {
        if (context.mounted) AppSnackbar.showError(context, e.toString());
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Analytics Grid
// ---------------------------------------------------------------------------

class _AnalyticsGrid extends StatelessWidget {
  final Map<String, dynamic> analytics;
  final bool dark;

  const _AnalyticsGrid({required this.analytics, required this.dark});

  @override
  Widget build(BuildContext context) {
    final revenue =
        double.tryParse(analytics['revenue']?.toString() ?? '0') ?? 0;
    final ticketsSold =
        int.tryParse(analytics['ticketsSold']?.toString() ?? '0') ?? 0;
    final orders =
        int.tryParse(analytics['orders']?.toString() ?? '0') ?? 0;
    final checkIns =
        int.tryParse(analytics['checkIns']?.toString() ?? '0') ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatTile(
          label: 'Revenue',
          value: 'KES ${NumberFormat('#,##0').format(revenue.round())}',
          color: kSuccess,
          dark: dark,
        ),
        _StatTile(
          label: 'Tickets Sold',
          value: ticketsSold.toString(),
          color: kPrimary,
          dark: dark,
        ),
        _StatTile(
          label: 'Orders',
          value: orders.toString(),
          color: const Color(0xFF3B82F6),
          dark: dark,
        ),
        _StatTile(
          label: 'Check-ins',
          value: checkIns.toString(),
          color: kWarning,
          dark: dark,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool dark;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: dark ? kDarkTextMuted : kTextMuted),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tier Row
// ---------------------------------------------------------------------------

class _TierRow extends StatelessWidget {
  final Map<String, dynamic> tier;
  final bool dark;

  const _TierRow({required this.tier, required this.dark});

  @override
  Widget build(BuildContext context) {
    final name = tier['name']?.toString() ?? 'Tier';
    final type = tier['type']?.toString() ?? 'GA';
    final sold =
        int.tryParse(tier['soldCount']?.toString() ?? '0') ?? 0;
    final total =
        int.tryParse(tier['quantity']?.toString() ?? '1') ?? 1;
    final revenue =
        double.tryParse(tier['revenue']?.toString() ?? '0') ?? 0;
    final progress = total > 0 ? (sold / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark ? kDarkBorder : kBorder, width: 0.8),
        boxShadow: const [
          BoxShadow(
              color: kCardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: dark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const SizedBox(width: 8),
              _TypeBadge(type: type),
              const Spacer(),
              Text(
                'KES ${NumberFormat('#,##0').format(revenue.round())}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kSuccess,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: dark ? kDarkBorder : kBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(kPrimary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$sold / $total sold',
            style: GoogleFonts.inter(
                fontSize: 11,
                color: dark ? kDarkTextMuted : kTextMuted),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: kPrimary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action Button
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attendee Row
// ---------------------------------------------------------------------------

class _AttendeeRow extends StatelessWidget {
  final Map<String, dynamic> attendee;
  final bool dark;

  const _AttendeeRow({required this.attendee, required this.dark});

  @override
  Widget build(BuildContext context) {
    final name = attendee['customerName']?.toString() ??
        attendee['name']?.toString() ??
        'Guest';
    final tierName = attendee['tierName']?.toString() ?? 'GA';
    final amount =
        double.tryParse(attendee['amount']?.toString() ?? '0') ?? 0;
    DateTime? createdAt;
    try {
      if (attendee['createdAt'] != null) {
        createdAt =
            DateTime.parse(attendee['createdAt'].toString());
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
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
          CircleAvatar(
            radius: 18,
            backgroundColor: kPrimary.withValues(alpha: 0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                Text(
                  tierName +
                      (createdAt != null
                          ? ' · ${AppDateUtils.formatShortDate(createdAt)}'
                          : ''),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: dark ? kDarkTextMuted : kTextMuted),
                ),
              ],
            ),
          ),
          Text(
            'KES ${NumberFormat('#,##0').format(amount.round())}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: dark ? kDarkTextPrimary : kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Badge (overlaid on cover image — stays white)
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status.toUpperCase()) {
      case 'PUBLISHED':
        bg = kSuccess.withValues(alpha: 0.18);
        fg = kSuccess;
      case 'CANCELLED':
      case 'REJECTED':
        bg = kDanger.withValues(alpha: 0.18);
        fg = kDanger;
      case 'DRAFT':
      default:
        bg = Colors.white.withValues(alpha: 0.2);
        fg = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer
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
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: dark ? kDarkSurface : kSurface,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
