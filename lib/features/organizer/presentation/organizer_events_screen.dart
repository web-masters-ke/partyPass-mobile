import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';

// ---------------------------------------------------------------------------
// Provider (family keyed by status filter)
// ---------------------------------------------------------------------------

final _orgEventsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, status) async {
  final params = <String, dynamic>{'page': 1, 'limit': 20};
  if (status != 'ALL') params['status'] = status;
  final data = await DioClient.instance
      .get<dynamic>('/organizer/events', queryParameters: params);
  if (data is List) return data.cast<Map<String, dynamic>>();
  final items =
      (data as Map<String, dynamic>)['items'] as List? ?? [];
  return items.cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OrganizerEventsScreen extends ConsumerStatefulWidget {
  const OrganizerEventsScreen({super.key});

  @override
  ConsumerState<OrganizerEventsScreen> createState() =>
      _OrganizerEventsScreenState();
}

class _OrganizerEventsScreenState
    extends ConsumerState<OrganizerEventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['ALL', 'DRAFT', 'PUBLISHED', 'PAST'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/organizer');
            }
          },
        ),
        title: const Text('My Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary,
          unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
              ? kDarkTextMuted
              : kTextMuted,
          indicatorColor: kPrimary,
          indicatorWeight: 2,
          labelStyle: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
          tabs: _tabs
              .map((t) => Tab(text: t == 'ALL' ? 'All' : _capitalize(t)))
              .toList(),
        ),
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
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((status) => _EventsList(status: status))
            .toList(),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();
}

// ---------------------------------------------------------------------------
// Events list for a given tab
// ---------------------------------------------------------------------------

class _EventsList extends ConsumerWidget {
  final String status;

  const _EventsList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final eventsAsync = ref.watch(_orgEventsProvider(status));

    return eventsAsync.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => _EventRowShimmer(dark: dark),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded,
                size: 48, color: dark ? kDarkTextMuted : kTextMuted),
            const SizedBox(height: 12),
            Text(
              'Could not load events',
              style: GoogleFonts.inter(
                  color: dark ? kDarkTextMuted : kTextMuted),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => ref.invalidate(_orgEventsProvider(status)),
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
      data: (events) {
        if (events.isEmpty) {
          return _EmptyTab(status: status, dark: dark);
        }
        return RefreshIndicator(
          color: kPrimary,
          onRefresh: () async =>
              ref.invalidate(_orgEventsProvider(status)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _EventRow(event: events[i], dark: dark),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Event Row
// ---------------------------------------------------------------------------

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool dark;

  const _EventRow({required this.event, required this.dark});

  @override
  Widget build(BuildContext context) {
    final coverUrl = event['coverImageUrl']?.toString();
    final title = event['title']?.toString() ?? 'Untitled';
    final status = event['status']?.toString() ?? 'DRAFT';
    final ticketsSold =
        int.tryParse(event['ticketsSold']?.toString() ?? '0') ?? 0;
    final revenue =
        double.tryParse(event['revenue']?.toString() ?? '0') ?? 0;
    final eventId = event['id']?.toString() ?? '';

    DateTime? startDate;
    try {
      if (event['startDateTime'] != null) {
        startDate = DateTime.parse(event['startDateTime'].toString());
      }
    } catch (_) {}

    return GestureDetector(
      onTap: () => context.push('/organizer/events/$eventId'),
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Row(
          children: [
            // Cover thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 60,
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: kPrimary.withValues(alpha: 0.12),
                        child: const Icon(Icons.event_rounded,
                            color: kPrimary, size: 24),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
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
                      if (startDate != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          AppDateUtils.formatShortDate(startDate),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: dark ? kDarkTextMuted : kTextMuted),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$ticketsSold tickets sold · KES ${NumberFormat('#,##0').format(revenue.round())}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: dark ? kDarkTextMuted : kTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: dark ? kDarkTextMuted : kTextMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool dark;

  const _StatusBadge({required this.status, required this.dark});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status.toUpperCase()) {
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
      case 'PAST':
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
// Empty state per tab
// ---------------------------------------------------------------------------

class _EmptyTab extends StatelessWidget {
  final String status;
  final bool dark;

  const _EmptyTab({required this.status, required this.dark});

  @override
  Widget build(BuildContext context) {
    String message;
    switch (status) {
      case 'DRAFT':
        message = 'No draft events';
      case 'PUBLISHED':
        message = 'No published events yet';
      case 'PAST':
        message = 'No past events';
      default:
        message = 'No events yet';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_rounded,
              size: 56, color: dark ? kDarkTextMuted : kTextMuted),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: dark ? kDarkTextPrimary : kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (status == 'ALL' || status == 'DRAFT')
            GestureDetector(
              onTap: () => context.push('/organizer/events/new'),
              child: Text(
                'Create your first event',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: kPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer row
// ---------------------------------------------------------------------------

class _EventRowShimmer extends StatelessWidget {
  final bool dark;
  const _EventRowShimmer({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
