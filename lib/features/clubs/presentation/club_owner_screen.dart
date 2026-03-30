import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final _myVenuesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await DioClient.instance.get<dynamic>('/organizer/venues');
  if (data is List) return data.cast<Map<String, dynamic>>();
  final items = (data as Map<String, dynamic>)['items'] as List? ?? (data['data'] as List? ?? []);
  return items.cast<Map<String, dynamic>>();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class ClubOwnerScreen extends ConsumerWidget {
  const ClubOwnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final venuesAsync = ref.watch(_myVenuesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/organizer'),
        ),
        title: Text('Clubs & Venues', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Register Venue',
            onPressed: () async {
              await context.push('/organizer/clubs/new');
              ref.invalidate(_myVenuesProvider);
            },
          ),
        ],
      ),
      body: venuesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (e, _) => _ErrorBody(onRetry: () => ref.invalidate(_myVenuesProvider)),
        data: (venues) {
          if (venues.isEmpty) {
            return _EmptyState(
              onAdd: () async {
                await context.push('/organizer/clubs/new');
                ref.invalidate(_myVenuesProvider);
              },
            );
          }
          return RefreshIndicator(
            color: kPrimary,
            onRefresh: () async => ref.invalidate(_myVenuesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: venues.length,
              itemBuilder: (ctx, i) => _VenueCard(
                venue: venues[i],
                dark: dark,
                onTap: () => context.push('/organizer/clubs/${venues[i]['id']}'),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/organizer/clubs/new');
          ref.invalidate(_myVenuesProvider);
        },
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Register Venue', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─── Venue card ───────────────────────────────────────────────────────────────

class _VenueCard extends StatelessWidget {
  final Map<String, dynamic> venue;
  final bool dark;
  final VoidCallback onTap;

  const _VenueCard({required this.venue, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = venue['_count'] as Map<String, dynamic>?;
    final nights = count?['clubNights'] ?? 0;
    final members = count?['clubMemberships'] ?? 0;
    final capacity = venue['capacity'];
    final logo = venue['logoUrl']?.toString();
    final initials = (venue['name']?.toString() ?? 'V').substring(0, 1).toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? kDarkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? kDarkBorder : kBorder),
          boxShadow: const [BoxShadow(color: kCardShadow, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Logo
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: logo != null
                      ? Image.network(logo, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kPrimary)),
                          ))
                      : Center(
                          child: Text(initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kPrimary)),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue['name']?.toString() ?? '',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15,
                            color: dark ? kDarkTextPrimary : kTextPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 12, color: dark ? kDarkTextMuted : kTextMuted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${venue['address'] ?? ''}, ${venue['city'] ?? ''}',
                              style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: dark ? kDarkTextMuted : kTextMuted),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(label: 'Capacity', value: capacity?.toString() ?? '—', dark: dark),
                const SizedBox(width: 12),
                _Stat(label: 'Nights', value: nights.toString(), dark: dark),
                const SizedBox(width: 12),
                _Stat(label: 'Members', value: members.toString(), dark: dark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final bool dark;
  const _Stat({required this.label, required this.value, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: dark ? kDarkBackground : kSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18,
                color: dark ? kDarkTextPrimary : kTextPrimary)),
            const SizedBox(height: 1),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.location_city_rounded, size: 40, color: kPrimary),
            ),
            const SizedBox(height: 20),
            Text('No venues yet', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              'Register your venue to start managing club nights, table bookings and memberships.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: kTextMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Register Venue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBody({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: kDanger),
          const SizedBox(height: 12),
          const Text('Failed to load venues'),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
