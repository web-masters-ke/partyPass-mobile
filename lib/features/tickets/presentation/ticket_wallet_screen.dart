import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/ticket.dart';
import '../../../shared/providers/auth_provider.dart';

final _ticketsProvider = FutureProvider<List<Ticket>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  final data = await DioClient.instance.get<dynamic>('/users/me/tickets');
  if (data is List) {
    return data
        .map((e) => Ticket.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  final items = (data as Map<String, dynamic>)['items'] as List? ?? [];
  return items
      .map((e) => Ticket.fromJson(e as Map<String, dynamic>))
      .toList();
});

class TicketWalletScreen extends ConsumerWidget {
  const TicketWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ticketsAsync = ref.watch(_ticketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tickets'),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => context.pop(),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_ticketsProvider),
          ),
        ],
      ),
      body: ticketsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_rounded,
                    size: 56,
                    color: dark ? kDarkTextMuted : kTextMuted),
                const SizedBox(height: 16),
                Text(
                  'Could not load tickets',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () => ref.invalidate(_ticketsProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('Retry',
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
        ),
        data: (tickets) {
          if (tickets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.confirmation_number_rounded,
                          size: 44, color: kPrimary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No tickets yet',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: dark ? kDarkTextPrimary : kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your purchased tickets will appear here',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: dark ? kDarkTextMuted : kTextMuted),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => context.go('/events'),
                        icon: const Icon(Icons.explore_rounded, size: 18),
                        label: Text(
                          'Browse Events',
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
              ),
            );
          }

          // Group by event
          final grouped = <String, List<Ticket>>{};
          final eventOrder = <String>[];
          for (final t in tickets) {
            final key = t.event?.id ?? t.eventId;
            if (!grouped.containsKey(key)) {
              grouped[key] = [];
              eventOrder.add(key);
            }
            grouped[key]!.add(t);
          }

          final now = DateTime.now();
          final upcomingKeys = eventOrder
              .where((k) =>
                  grouped[k]!.first.event == null ||
                  grouped[k]!.first.event!.startDateTime.isAfter(now))
              .toList();
          final pastKeys =
              eventOrder.where((k) => !upcomingKeys.contains(k)).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              if (upcomingKeys.isNotEmpty) ...[
                _sectionLabel('Upcoming', dark),
                const SizedBox(height: 10),
                ...upcomingKeys.map((k) => _EventTicketGroup(
                      tickets: grouped[k]!,
                      isPast: false,
                      dark: dark,
                    )),
              ],
              if (pastKeys.isNotEmpty) ...[
                if (upcomingKeys.isNotEmpty) const SizedBox(height: 4),
                _sectionLabel('Past', dark),
                const SizedBox(height: 10),
                ...pastKeys.map((k) => _EventTicketGroup(
                      tickets: grouped[k]!,
                      isPast: true,
                      dark: dark,
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label, bool dark) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: dark ? kDarkTextPrimary : kTextPrimary,
          ),
        ),
      );
}

// ─── Event group card ─────────────────────────────────────────────────────────

class _EventTicketGroup extends StatelessWidget {
  final List<Ticket> tickets;
  final bool isPast;
  final bool dark;

  const _EventTicketGroup({
    required this.tickets,
    required this.isPast,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final event = tickets.first.event;
    final coverUrl = event?.coverImageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: dark ? kDarkBorder : kBorder, width: 0.8),
        boxShadow: isPast
            ? null
            : [
                BoxShadow(
                  color: dark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // ── Event banner ──────────────────────────────────────────────
            SizedBox(
              height: 164,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null)
                    CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      color: isPast
                          ? Colors.black.withValues(alpha: 0.45)
                          : null,
                      colorBlendMode:
                          isPast ? BlendMode.darken : null,
                    )
                  else
                    Container(
                      color: isPast
                          ? (dark ? kDarkBackground : kSurface)
                          : kPrimary.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.event_rounded,
                        size: 52,
                        color: isPast
                            ? (dark ? kDarkTextMuted : kTextMuted)
                            : kPrimary.withValues(alpha: 0.4),
                      ),
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.68),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event?.title ?? 'Event',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (event != null)
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 11, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                AppDateUtils.formatDate(
                                    event.startDateTime),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color:
                                      Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              if ((event.venueCity ?? event.venueName) !=
                                  null) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.location_on_rounded,
                                    size: 11, color: Colors.white70),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    event.venueCity ??
                                        event.venueName ??
                                        '',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white
                                          .withValues(alpha: 0.85),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${tickets.length} ticket${tickets.length > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tear line ────────────────────────────────────────────────
            _TearLine(dark: dark),

            // ── Individual tickets ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  for (int i = 0; i < tickets.length; i++) ...[
                    _TicketRow(
                        ticket: tickets[i], isPast: isPast, dark: dark),
                    if (i < tickets.length - 1)
                      Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: dark ? kDarkBorder : kBorder),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tear / perforation line ──────────────────────────────────────────────────

class _TearLine extends StatelessWidget {
  final bool dark;
  const _TearLine({required this.dark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          _notch(left: true),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) {
                const dashW = 7.0;
                const gapW = 5.0;
                final count = (c.maxWidth / (dashW + gapW)).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    count,
                    (_) => Container(
                      width: dashW,
                      height: 1.5,
                      color: dark ? kDarkBorder : kBorder,
                    ),
                  ),
                );
              },
            ),
          ),
          _notch(left: false),
        ],
      ),
    );
  }

  Widget _notch({required bool left}) {
    return Transform.translate(
      offset: Offset(left ? -12 : 12, 0),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: dark ? kDarkBackground : kBackground,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Individual ticket row ────────────────────────────────────────────────────

class _TicketRow extends StatelessWidget {
  final Ticket ticket;
  final bool isPast;
  final bool dark;

  const _TicketRow(
      {required this.ticket, required this.isPast, required this.dark});

  @override
  Widget build(BuildContext context) {
    final tier = ticket.tier;
    final tierColor = _parseColor(tier?.color);

    return GestureDetector(
      onTap: () => context.push('/ticket/${ticket.id}'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Tier colour dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isPast
                    ? (dark ? kDarkTextMuted : kTextMuted)
                    : (tierColor ?? kPrimary),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier?.name ?? 'General Admission',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isPast
                          ? (dark ? kDarkTextMuted : kTextMuted)
                          : (dark ? kDarkTextPrimary : kTextPrimary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticket.shortId,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: dark ? kDarkTextMuted : kTextMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            _statusBadge(ticket.status),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isPast
                    ? (dark ? kDarkBackground : kSurface)
                    : kPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 20,
                color: isPast ? (dark ? kDarkTextMuted : kTextMuted) : kPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'VALID':
        bg = dark
            ? kSuccess.withValues(alpha: 0.15)
            : const Color(0xFFDCFCE7);
        fg = dark ? kSuccess : const Color(0xFF166534);
        label = 'Valid';
      case 'USED':
        bg = dark ? kDarkSurface : const Color(0xFFF3F4F6);
        fg = dark ? kDarkTextMuted : const Color(0xFF6B7280);
        label = 'Used';
      case 'TRANSFERRED':
        bg = dark
            ? const Color(0xFF1D4ED8).withValues(alpha: 0.15)
            : const Color(0xFFDBEAFE);
        fg = dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        label = 'Transferred';
      default:
        bg = dark
            ? kDanger.withValues(alpha: 0.15)
            : const Color(0xFFFEE2E2);
        fg = dark ? kDanger : const Color(0xFFDC2626);
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceFirst('#', '');
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return null;
    return Color(clean.length == 6 ? 0xFF000000 | value : value);
  }
}
