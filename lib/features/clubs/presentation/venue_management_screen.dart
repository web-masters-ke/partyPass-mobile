import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _venueDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  return DioClient.instance.get<Map<String, dynamic>>('/organizer/venues/$id');
});

final _venueNightsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final data = await DioClient.instance.get<dynamic>('/organizer/venues/$id/nights');
  if (data is List) return data.cast<Map<String, dynamic>>();
  return ((data as Map<String, dynamic>)['items'] as List? ?? []).cast<Map<String, dynamic>>();
});

final _venueBookingsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final data = await DioClient.instance.get<dynamic>('/organizer/venues/$id/bookings');
  if (data is List) return data.cast<Map<String, dynamic>>();
  return ((data as Map<String, dynamic>)['items'] as List? ?? []).cast<Map<String, dynamic>>();
});

final _venueMembersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final data = await DioClient.instance.get<dynamic>('/organizer/venues/$id/members');
  if (data is List) return data.cast<Map<String, dynamic>>();
  return ((data as Map<String, dynamic>)['items'] as List? ?? []).cast<Map<String, dynamic>>();
});

const _kDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const _kBookingColors = {
  'PENDING': Color(0xFFFEF3C7),
  'CONFIRMED': Color(0xFFDCFCE7),
  'CANCELLED': Color(0xFFFEE2E2),
  'NO_SHOW': Color(0xFFF3F4F6),
};
const _kBookingTextColors = {
  'PENDING': Color(0xFFD97706),
  'CONFIRMED': Color(0xFF16A34A),
  'CANCELLED': Color(0xFFDC2626),
  'NO_SHOW': Color(0xFF6B7280),
};
const _kMemberColors = {
  'ACTIVE': Color(0xFFDCFCE7),
  'EXPIRED': Color(0xFFF3F4F6),
  'CANCELLED': Color(0xFFFEE2E2),
};
const _kMemberTextColors = {
  'ACTIVE': Color(0xFF16A34A),
  'EXPIRED': Color(0xFF6B7280),
  'CANCELLED': Color(0xFFDC2626),
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class VenueManagementScreen extends ConsumerStatefulWidget {
  final String venueId;
  const VenueManagementScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueManagementScreen> createState() => _VenueManagementScreenState();
}

class _VenueManagementScreenState extends ConsumerState<VenueManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final venueAsync = ref.watch(_venueDetailProvider(widget.venueId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/organizer/clubs'),
        ),
        title: venueAsync.when(
          data: (v) => Text(v['name']?.toString() ?? 'Venue',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          loading: () => const Text('Loading…'),
          error: (_, __) => const Text('Venue'),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.nightlife_rounded),
            tooltip: 'Add Club Night',
            onPressed: () async {
              final added = await context.push<bool>('/organizer/clubs/${widget.venueId}/nights/new');
              if (added == true) ref.invalidate(_venueNightsProvider(widget.venueId));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: kPrimary,
          labelColor: kPrimary,
          unselectedLabelColor: dark ? kDarkTextMuted : kTextMuted,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Nights'),
            Tab(text: 'Bookings'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Venue header stats
          venueAsync.when(
            data: (v) => _VenueHeader(venue: v, dark: dark),
            loading: () => const SizedBox(height: 70, child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _NightsTab(venueId: widget.venueId),
                _BookingsTab(venueId: widget.venueId),
                _MembersTab(venueId: widget.venueId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _VenueHeader extends StatelessWidget {
  final Map<String, dynamic> venue;
  final bool dark;
  const _VenueHeader({required this.venue, required this.dark});

  @override
  Widget build(BuildContext context) {
    final count = venue['_count'] as Map<String, dynamic>?;
    return Container(
      color: dark ? kDarkSurface : kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, size: 14, color: dark ? kDarkTextMuted : kTextMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${venue['address'] ?? ''}, ${venue['city'] ?? ''}',
              style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          if (venue['capacity'] != null) ...[
            const SizedBox(width: 12),
            Icon(Icons.people_rounded, size: 14, color: dark ? kDarkTextMuted : kTextMuted),
            const SizedBox(width: 4),
            Text('${venue['capacity']}',
                style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted)),
          ],
          if (count != null) ...[
            const SizedBox(width: 12),
            const Icon(Icons.nightlife_rounded, size: 14, color: kPrimary),
            const SizedBox(width: 3),
            Text('${count['clubNights'] ?? 0}',
                style: GoogleFonts.inter(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

// ─── Nights tab ───────────────────────────────────────────────────────────────

class _NightsTab extends ConsumerWidget {
  final String venueId;
  const _NightsTab({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ref.watch(_venueNightsProvider(venueId)).when(
      loading: () => const Center(child: CircularProgressIndicator(color: kPrimary)),
      error: (e, _) => _Retry(onRetry: () => ref.invalidate(_venueNightsProvider(venueId))),
      data: (nights) {
        if (nights.isEmpty) {
          return const _Empty(
            icon: Icons.nightlife_rounded,
            message: 'No club nights yet',
            sub: 'Tap + in the top bar to add your first night',
          );
        }
        return RefreshIndicator(
          color: kPrimary,
          onRefresh: () async => ref.invalidate(_venueNightsProvider(venueId)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: nights.length,
            itemBuilder: (_, i) => _NightCard(night: nights[i], dark: dark),
          ),
        );
      },
    );
  }
}

class _NightCard extends StatelessWidget {
  final Map<String, dynamic> night;
  final bool dark;
  const _NightCard({required this.night, required this.dark});

  @override
  Widget build(BuildContext context) {
    final day = int.tryParse(night['dayOfWeek']?.toString() ?? '0') ?? 0;
    final isActive = night['isActive'] as bool? ?? true;
    final cover = night['coverImageUrl']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? kDarkBorder : kBorder),
      ),
      child: Row(
        children: [
          if (cover != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(cover, width: 52, height: 52, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _NightIcon()),
            )
          else
            _NightIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(night['name']?.toString() ?? '',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14,
                        color: dark ? kDarkTextPrimary : kTextPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${_kDays[day]} · ${night['startTime'] ?? ''}${night['endTime'] != null ? ' – ${night['endTime']}' : ''}',
                  style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
                ),
                if (night['description'] != null) ...[
                  const SizedBox(height: 2),
                  Text(night['description'].toString(),
                      style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Off',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                  color: isActive ? const Color(0xFF16A34A) : const Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NightIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.nightlife_rounded, color: kPrimary, size: 26),
    );
  }
}

// ─── Bookings tab ─────────────────────────────────────────────────────────────

class _BookingsTab extends ConsumerWidget {
  final String venueId;
  const _BookingsTab({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ref.watch(_venueBookingsProvider(venueId)).when(
      loading: () => const Center(child: CircularProgressIndicator(color: kPrimary)),
      error: (_, __) => _Retry(onRetry: () => ref.invalidate(_venueBookingsProvider(venueId))),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const _Empty(icon: Icons.chair_rounded, message: 'No table bookings yet');
        }
        return RefreshIndicator(
          color: kPrimary,
          onRefresh: () async => ref.invalidate(_venueBookingsProvider(venueId)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: bookings.length,
            itemBuilder: (_, i) => _BookingCard(booking: bookings[i], dark: dark),
          ),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool dark;
  const _BookingCard({required this.booking, required this.dark});

  @override
  Widget build(BuildContext context) {
    final status = booking['status']?.toString() ?? 'PENDING';
    final bg = _kBookingColors[status] ?? const Color(0xFFF3F4F6);
    final fg = _kBookingTextColors[status] ?? const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? kDarkBorder : kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.chair_rounded, color: kPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${booking['tableName'] ?? 'Table'} (${booking['tableType'] ?? ''})',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13,
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                ),
                Text(
                  'Party of ${booking['partySize']} · Min KES ${booking['minSpend']}',
                  style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
                ),
                if (booking['notes'] != null)
                  Text(booking['notes'].toString(),
                      style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
          ),
        ],
      ),
    );
  }
}

// ─── Members tab ──────────────────────────────────────────────────────────────

class _MembersTab extends ConsumerWidget {
  final String venueId;
  const _MembersTab({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ref.watch(_venueMembersProvider(venueId)).when(
      loading: () => const Center(child: CircularProgressIndicator(color: kPrimary)),
      error: (_, __) => _Retry(onRetry: () => ref.invalidate(_venueMembersProvider(venueId))),
      data: (members) {
        if (members.isEmpty) {
          return const _Empty(icon: Icons.people_rounded, message: 'No members yet');
        }
        return RefreshIndicator(
          color: kPrimary,
          onRefresh: () async => ref.invalidate(_venueMembersProvider(venueId)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: members.length,
            itemBuilder: (_, i) => _MemberCard(member: members[i], dark: dark),
          ),
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool dark;
  const _MemberCard({required this.member, required this.dark});

  @override
  Widget build(BuildContext context) {
    final user = member['user'] as Map<String, dynamic>?;
    final firstName = user?['firstName']?.toString() ?? '';
    final lastName = user?['lastName']?.toString() ?? '';
    final name = '$firstName $lastName'.trim();
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
    final status = member['status']?.toString() ?? 'ACTIVE';
    final plan = member['plan']?.toString() ?? '';
    final bg = _kMemberColors[status] ?? const Color(0xFFF3F4F6);
    final fg = _kMemberTextColors[status] ?? const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? kDarkBorder : kBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: kPrimary.withValues(alpha: 0.15),
            child: Text(initials.isEmpty ? '?' : initials,
                style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Unknown' : name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13,
                        color: dark ? kDarkTextPrimary : kTextPrimary)),
                if (user?['email'] != null)
                  Text(user!['email'].toString(),
                      style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
              ),
              const SizedBox(height: 3),
              Text(plan, style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? sub;
  const _Empty({required this.icon, required this.message, this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: kPrimary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub!, style: GoogleFonts.inter(fontSize: 13, color: kTextMuted), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  final VoidCallback onRetry;
  const _Retry({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 40, color: kDanger),
        const SizedBox(height: 12),
        const Text('Failed to load'),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
