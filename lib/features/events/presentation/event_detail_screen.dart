import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../home/domain/events_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/ticket_tier.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/red_button.dart';
import '../../../shared/widgets/tier_badge.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final tiersAsync = ref.watch(ticketTiersProvider(widget.eventId));

    return Scaffold(
      body: eventAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: GoogleFonts.inter(
                  color: dark ? kDarkTextMuted : kTextMuted)),
        ),
        data: (event) {
          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Hero image with back + heart
                  SliverToBoxAdapter(
                    child: _buildHeroImage(context, event, dark),
                  ),
                  // Event info
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title + price
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: dark
                                        ? kDarkTextPrimary
                                        : kTextPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  tiersAsync.when(
                                    data: (tiers) {
                                      if (tiers.isEmpty) {
                                        return Text(
                                          'Free',
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: kPrimary,
                                          ),
                                        );
                                      }
                                      final minTier = tiers.reduce(
                                          (a, b) =>
                                              a.price < b.price ? a : b);
                                      final maxTier = tiers.reduce(
                                          (a, b) =>
                                              a.price > b.price ? a : b);
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'KES ${minTier.price.toStringAsFixed(0)}',
                                            style: GoogleFonts.inter(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: kPrimary,
                                            ),
                                          ),
                                          if (maxTier.price > minTier.price)
                                            Text(
                                              'KES ${maxTier.price.toStringAsFixed(0)}',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: dark
                                                    ? kDarkTextMuted
                                                    : kTextMuted,
                                                decoration:
                                                    TextDecoration
                                                        .lineThrough,
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                    loading: () => const SizedBox(
                                        width: 60, height: 24),
                                    error: (_, __) =>
                                        const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Star rating
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 18, color: kPrimary),
                              const SizedBox(width: 4),
                              Text(
                                event.rating?.toStringAsFixed(1) ?? '4.8',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: dark
                                      ? kDarkTextPrimary
                                      : kTextPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${event.reviewCount ?? 194} reviews)',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: dark
                                        ? kDarkTextMuted
                                        : kTextMuted),
                              ),
                              if (event.venueName != null) ...[
                                const Spacer(),
                                Icon(Icons.location_on_rounded,
                                    size: 14,
                                    color: dark
                                        ? kDarkTextMuted
                                        : kTextMuted),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    event.venueName!,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: dark
                                            ? kDarkTextMuted
                                            : kTextMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Tab bar
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                    color: dark ? kDarkBorder : kBorder,
                                    width: 1),
                              ),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              labelColor: dark
                                  ? kDarkTextPrimary
                                  : kTextPrimary,
                              unselectedLabelColor: dark
                                  ? kDarkTextMuted
                                  : kTextMuted,
                              indicatorColor: dark
                                  ? kDarkTextPrimary
                                  : kTextPrimary,
                              indicatorWeight: 2,
                              labelStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              unselectedLabelStyle:
                                  GoogleFonts.inter(fontSize: 13),
                              tabs: const [
                                Tab(text: 'Online event'),
                                Tab(text: 'Refund policy'),
                                Tab(text: 'Date & Time'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Tab content
                          IndexedStack(
                            index: _selectedTab,
                            children: [
                              _buildOnlineEventTab(event, dark),
                              _buildRefundPolicyTab(event, dark),
                              _buildDateTimeTab(event, dark),
                            ],
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Persistent back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 18, color: Colors.black87),
                  ),
                ),
              ),

              // Sticky bottom bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      MediaQuery.of(context).padding.bottom + 12),
                  decoration: BoxDecoration(
                    color: dark ? kDarkBackground : kBackground,
                    border: Border(
                        top: BorderSide(
                            color: dark ? kDarkBorder : kBorder,
                            width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: RedButton(
                          label: 'Get tickets',
                          onTap: () => _showTicketTiers(
                              context, event, tiersAsync),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showGroupBookingSheet(
                              context, event, tiersAsync),
                          icon: const Icon(Icons.group_add_rounded,
                              size: 18),
                          label: const Text('Group'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimary,
                            side: const BorderSide(color: kPrimary),
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(50)),
                            textStyle: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
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

  Widget _buildHeroImage(BuildContext context, Event event, bool dark) {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenHeight * 0.42,
      child: Stack(
        fit: StackFit.expand,
        children: [
          event.coverImageUrl != null
              ? CachedNetworkImage(
                  imageUrl: event.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: dark ? kDarkSurface : kSurface),
                )
              : Container(color: dark ? kDarkSurface : kSurface),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.1),
                ],
              ),
            ),
          ),
          // Heart icon
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: GestureDetector(
              onTap: () =>
                  setState(() => _isFavorited = !_isFavorited),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isFavorited
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 20,
                  color: _isFavorited ? kPrimary : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineEventTab(Event event, bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.description,
          style: GoogleFonts.inter(
              fontSize: 14,
              color: dark ? kDarkTextPrimary : kTextPrimary,
              height: 1.6),
        ),
        const SizedBox(height: 20),
        if (event.isOnline)
          _infoRow(Icons.videocam_rounded, 'Online Event',
              'Join from anywhere',
              dark: dark),
        _infoRow(Icons.people_rounded, 'Max Capacity',
            '${event.maxCapacity} attendees',
            dark: dark),
        if (event.ageRestriction != null && event.ageRestriction! > 0)
          _infoRow(Icons.no_adult_content_rounded, 'Age Restriction',
              '${event.ageRestriction}+ only',
              dark: dark),
        if (event.dressCode != null)
          _infoRow(Icons.checkroom_rounded, 'Dress Code',
              event.dressCode!,
              dark: dark),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {required bool dark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: dark ? kDarkSurface : kSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: 18, color: dark ? kDarkTextMuted : kTextMuted),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: dark ? kDarkTextMuted : kTextMuted)),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: dark ? kDarkTextPrimary : kTextPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefundPolicyTab(Event event, bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Refund Policy',
          style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: dark ? kDarkTextPrimary : kTextPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          event.refundPolicy ??
              'No refunds are available for this event once purchased. '
                  'Tickets may be transferred to another person up to 24 hours before the event.',
          style: GoogleFonts.inter(
              fontSize: 14,
              color: dark ? kDarkTextPrimary : kTextPrimary,
              height: 1.6),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kWarning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kWarning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_rounded, color: kWarning, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Refund requests must be submitted at least 48 hours before the event.',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeTab(Event event, bool dark) {
    final diff = event.endDateTime.difference(event.startDateTime);
    final durationHours = diff.inHours;
    final durationMins = diff.inMinutes % 60;
    final durationStr = durationHours > 0
        ? (durationMins > 0
            ? '${durationHours}h ${durationMins}m'
            : '${durationHours}h')
        : '${durationMins}m';

    final multiDay = !AppDateUtils.isSameDay(
        event.startDateTime, event.endDateTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Start date — big highlight card
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: kPrimary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      AppDateUtils.formatMonth(event.startDateTime),
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    Text(
                      AppDateUtils.formatDayNumber(
                          event.startDateTime),
                      style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppDateUtils.formatDate(event.startDateTime),
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: dark
                              ? kDarkTextPrimary
                              : kTextPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppDateUtils.formatTime(event.startDateTime),
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: kPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                    if (multiDay) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ends ${AppDateUtils.formatDate(event.endDateTime)} · ${AppDateUtils.formatTime(event.endDateTime)}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: dark
                                ? kDarkTextMuted
                                : kTextMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (event.doorsOpenAt != null)
          _infoRow(Icons.door_front_door_rounded, 'Doors Open',
              AppDateUtils.formatTime(event.doorsOpenAt!),
              dark: dark),
        if (!multiDay)
          _infoRow(Icons.timer_off_rounded, 'End Time',
              AppDateUtils.formatTime(event.endDateTime),
              dark: dark),
        _infoRow(Icons.hourglass_top_rounded, 'Duration', durationStr,
            dark: dark),
        _infoRow(Icons.access_time_rounded, 'Timezone',
            event.timezone,
            dark: dark),

        if (event.venueName != null || event.venueCity != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dark ? kDarkSurface : kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: dark ? kDarkBorder : kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: kPrimary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (event.venueName != null)
                        Text(event.venueName!,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: dark
                                    ? kDarkTextPrimary
                                    : kTextPrimary)),
                      if (event.venueCity != null)
                        Text(event.venueCity!,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: dark
                                    ? kDarkTextMuted
                                    : kTextMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        if (event.isOnline) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF1E88E5)
                      .withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam_rounded,
                    color: Color(0xFF1E88E5), size: 18),
                const SizedBox(width: 8),
                Text('Online Event — join from anywhere',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF1E88E5),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showTicketTiers(BuildContext context, Event event,
      AsyncValue<List<TicketTier>> tiersAsync) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TicketTiersBottomSheet(
        event: event,
        tiersAsync: tiersAsync,
        onCheckout: (selections) {
          context.pop();
          context.push('/checkout/${widget.eventId}',
              extra: selections);
        },
      ),
    );
  }

  void _showGroupBookingSheet(BuildContext context, Event event,
      AsyncValue<List<TicketTier>> tiersAsync) {
    final tiers = tiersAsync.valueOrNull ?? [];
    if (tiers.isEmpty) {
      AppSnackbar.showError(
          context, 'No ticket tiers available for this event');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _GroupBookingSheet(event: event, tiers: tiers),
    );
  }
}

// ---- Ticket Tiers Bottom Sheet ----
class TicketTiersBottomSheet extends StatefulWidget {
  final Event event;
  final AsyncValue<List<TicketTier>> tiersAsync;
  final void Function(Map<String, int> selections) onCheckout;

  const TicketTiersBottomSheet({
    super.key,
    required this.event,
    required this.tiersAsync,
    required this.onCheckout,
  });

  @override
  State<TicketTiersBottomSheet> createState() =>
      _TicketTiersBottomSheetState();
}

class _TicketTiersBottomSheetState
    extends State<TicketTiersBottomSheet> {
  final Map<String, int> _quantities = {};

  int _total(List<TicketTier> tiers) {
    double total = 0;
    for (final tier in tiers) {
      total += tier.price * (_quantities[tier.id] ?? 0);
    }
    return total.toInt();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final screenH = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final event = widget.event;

    return Container(
      decoration: BoxDecoration(
        color: dark ? kDarkBackground : kBackground,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: screenH * 0.88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Event image banner ────────────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (event.coverImageUrl != null)
                    CachedNetworkImage(
                      imageUrl: event.coverImageUrl!,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: kPrimary.withValues(alpha: 0.15),
                      child: const Icon(Icons.event_rounded,
                          size: 48, color: kPrimary),
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.70),
                          ],
                          stops: const [0.35, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // drag handle
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  // event title + date
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${AppDateUtils.formatDate(event.startDateTime)}  •  ${event.venueCity ?? event.venueName ?? ''}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white
                                .withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Tier list (scrollable) ──────────────────────────────
          Flexible(
            child: widget.tiersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child:
                        CircularProgressIndicator(color: kPrimary)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Text(e.toString(),
                    style: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted)),
              ),
              data: (tiers) {
                final hasSelections =
                    _quantities.values.any((q) => q > 0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        padding:
                            const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Tickets',
                              style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: dark
                                      ? kDarkTextPrimary
                                      : kTextPrimary),
                            ),
                            const SizedBox(height: 14),
                            ...tiers.map((tier) {
                              final qty =
                                  _quantities[tier.id] ?? 0;
                              return Container(
                                margin: const EdgeInsets.only(
                                    bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: dark
                                      ? kDarkSurface
                                      : kSurface,
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: qty > 0
                                      ? Border.all(
                                          color: kPrimary,
                                          width: 1.5)
                                      : Border.all(
                                          color: dark
                                              ? kDarkBorder
                                              : kBorder,
                                          width: 0.8),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        TierBadge(
                                            tier: tier.tierType),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            tier.name,
                                            style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: dark
                                                    ? kDarkTextPrimary
                                                    : kTextPrimary),
                                          ),
                                        ),
                                        Text(
                                          tier.price == 0
                                              ? 'Free'
                                              : 'KES ${tier.price.toStringAsFixed(0)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight:
                                                FontWeight.w700,
                                            color: kPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (tier.perks.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: tier.perks
                                            .map((p) => Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration:
                                                      BoxDecoration(
                                                    color: dark
                                                        ? kDarkBackground
                                                        : Colors.white,
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(20),
                                                    border: Border.all(
                                                        color: dark
                                                            ? kDarkBorder
                                                            : kBorder),
                                                  ),
                                                  child: Text(p,
                                                      style: GoogleFonts
                                                          .inter(
                                                              fontSize:
                                                                  11,
                                                              color: dark
                                                                  ? kDarkTextMuted
                                                                  : kTextMuted)),
                                                ))
                                            .toList(),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        _qtyBtn(
                                          Icons.remove_rounded,
                                          qty > 0
                                              ? () => setState(() =>
                                                  _quantities[
                                                      tier.id] =
                                                  qty - 1)
                                              : null,
                                          dark: dark,
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16),
                                          child: Text(
                                            '$qty',
                                            style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: dark
                                                    ? kDarkTextPrimary
                                                    : kTextPrimary),
                                          ),
                                        ),
                                        _qtyBtn(
                                          Icons.add_rounded,
                                          qty < tier.maxPerOrder &&
                                                  !tier.isSoldOut
                                              ? () => setState(() =>
                                                  _quantities[
                                                      tier.id] =
                                                  qty + 1)
                                              : null,
                                          dark: dark,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    // ── Sticky total + checkout ──────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, 8, 20, bottomPad + 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasSelections)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 10),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total',
                                      style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: dark
                                              ? kDarkTextPrimary
                                              : kTextPrimary)),
                                  Text(
                                    'KES ${_total(tiers)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: kPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          RedButton(
                            label: hasSelections
                                ? 'Checkout — KES ${_total(tiers)}'
                                : 'Select tickets',
                            onTap: hasSelections
                                ? () =>
                                    widget.onCheckout(_quantities)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap,
      {required bool dark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null
              ? kPrimary
              : (dark ? kDarkSurface : kSurface),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null
              ? Colors.white
              : (dark ? kDarkTextMuted : kTextMuted),
        ),
      ),
    );
  }
}

// ─── Group Booking Sheet ──────────────────────────────────────────────────────

class _GroupBookingSheet extends StatefulWidget {
  final Event event;
  final List<TicketTier> tiers;
  const _GroupBookingSheet(
      {required this.event, required this.tiers});

  @override
  State<_GroupBookingSheet> createState() =>
      _GroupBookingSheetState();
}

class _GroupBookingSheetState extends State<_GroupBookingSheet> {
  late TicketTier _selectedTier;
  int _groupSize = 4;
  bool _creatorPaysAll = false;
  bool _loading = false;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTier = widget.tiers.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final body = <String, dynamic>{
        'eventId': widget.event.id,
        'tierId': _selectedTier.id,
        'maxSize': _groupSize,
        'creatorPaysAll': _creatorPaysAll,
        if (_nameCtrl.text.trim().isNotEmpty)
          'name': _nameCtrl.text.trim(),
      };
      final result = await DioClient.instance
          .post<Map<String, dynamic>>('/group-bookings', data: body);
      final token = result['shareToken']?.toString() ?? '';
      final link = 'https://partypass.app/group/$token';
      if (mounted) {
        context.pop();
        AppSnackbar.showSuccess(context, 'Group created!');
        Share.share(
          'Join my group booking on PartyPass! 🎉\n$link',
          subject: 'Group invite — ${widget.event.title}',
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, 'Failed to create group');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
    final totalCost = _creatorPaysAll
        ? _selectedTier.price * _groupSize
        : _selectedTier.price;

    return Container(
      decoration: BoxDecoration(
        color: dark ? kDarkBackground : kBackground,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: dark ? kDarkBorder : kBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          Text('Create Group Booking',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: dark ? kDarkTextPrimary : kTextPrimary)),
          const SizedBox(height: 4),
          Text('Invite friends — everyone pays their own seat',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: dark ? kDarkTextMuted : kTextMuted)),
          const SizedBox(height: 20),

          // Tier picker
          Text('Ticket tier',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: dark ? kDarkTextMuted : kTextMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.tiers.map((t) {
              final selected = t.id == _selectedTier.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedTier = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? kPrimary.withValues(alpha: 0.1)
                        : (dark ? kDarkSurface : kSurface),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                        color: selected
                            ? kPrimary
                            : (dark ? kDarkBorder : kBorder),
                        width: selected ? 1.5 : 1),
                  ),
                  child: Text(
                    '${t.name}  •  KES ${t.price.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? kPrimary
                          : (dark ? kDarkTextPrimary : kTextPrimary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Group size stepper
          Text('Group size',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: dark ? kDarkTextMuted : kTextMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              _stepBtn(
                Icons.remove_rounded,
                _groupSize > 2
                    ? () => setState(() => _groupSize--)
                    : null,
                dark: dark,
              ),
              const SizedBox(width: 16),
              Text('$_groupSize people',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: dark ? kDarkTextPrimary : kTextPrimary)),
              const SizedBox(width: 16),
              _stepBtn(
                Icons.add_rounded,
                _groupSize < 10
                    ? () => setState(() => _groupSize++)
                    : null,
                dark: dark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Optional group name
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              hintText: 'Group name (optional)',
              hintStyle: GoogleFonts.inter(
                  color: dark ? kDarkTextMuted : kTextMuted,
                  fontSize: 14),
              filled: true,
              fillColor: dark ? kDarkSurface : kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Creator pays all toggle
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _creatorPaysAll
                  ? (dark
                      ? const Color(0xFF92400E).withValues(alpha: 0.15)
                      : const Color(0xFFFFF7ED))
                  : (dark ? kDarkSurface : kSurface),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _creatorPaysAll
                      ? const Color(0xFFFED7AA)
                      : (dark ? kDarkBorder : kBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.volunteer_activism_rounded,
                    size: 18, color: Color(0xFFEA580C)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("I'm paying for everyone",
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: dark
                                  ? kDarkTextPrimary
                                  : kTextPrimary)),
                      Text('You cover all seats upfront',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: dark
                                  ? kDarkTextMuted
                                  : kTextMuted)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _creatorPaysAll,
                  activeThumbColor: kPrimary,
                  onChanged: (v) =>
                      setState(() => _creatorPaysAll = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Total cost indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _creatorPaysAll
                    ? 'Your total ($_groupSize seats)'
                    : 'Your seat cost',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: dark ? kDarkTextMuted : kTextMuted),
              ),
              Text(
                'KES ${totalCost.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Create button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _loading ? null : _create,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.group_add_rounded),
              label: Text(
                _loading ? 'Creating…' : 'Create Group & Share Link',
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
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap,
      {required bool dark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null
              ? kPrimary
              : (dark ? kDarkSurface : kSurface),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 18,
            color: onTap != null
                ? Colors.white
                : (dark ? kDarkTextMuted : kTextMuted)),
      ),
    );
  }
}
