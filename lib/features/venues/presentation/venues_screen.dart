import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/venue.dart';

class VenuesScreen extends ConsumerStatefulWidget {
  const VenuesScreen({super.key});

  @override
  ConsumerState<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends ConsumerState<VenuesScreen> {
  List<Venue> _venues = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final raw = await DioClient.instance.get<dynamic>('/venues', queryParameters: params);
      final list = (raw is Map ? raw['items'] ?? raw : raw) as List;
      setState(() => _venues = list.map((e) => Venue.fromJson(e as Map<String, dynamic>)).toList());
    } catch (_) {
      setState(() => _venues = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Venues', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search venues…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      )
                    : null,
                filled: true,
                fillColor: dark ? kDarkSurface : kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (v) => _load(search: v),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _venues.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_city_rounded,
                                size: 60,
                                color: (dark ? kDarkTextMuted : kTextMuted)
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('No venues found',
                                style: TextStyle(
                                    color: dark ? kDarkTextMuted : kTextMuted,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: kPrimary,
                        onRefresh: () => _load(search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null),
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.78,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _venues.length,
                          itemBuilder: (ctx, i) => _VenueCard(
                            venue: _venues[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => VenueDetailScreen(venueId: _venues[i].id)),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final Venue venue;
  final VoidCallback onTap;

  const _VenueCard({required this.venue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: dark ? kDarkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? kDarkBorder : kBorder),
          boxShadow: const [BoxShadow(color: kCardShadow, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 100,
                width: double.infinity,
                color: kPrimary.withValues(alpha: 0.15),
                child: venue.imageUrl != null
                    ? Image.network(venue.imageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(child: Text('🏟️', style: TextStyle(fontSize: 32))))
                    : const Center(child: Text('🏟️', style: TextStyle(fontSize: 32))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 12, color: dark ? kDarkTextMuted : kTextMuted),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(venue.city,
                            style: TextStyle(
                                fontSize: 11,
                                color: dark ? kDarkTextMuted : kTextMuted),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if (venue.capacity != null) ...[
                    const SizedBox(height: 2),
                    Text('👥 ${venue.capacity!.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: dark ? kDarkTextMuted : kTextMuted)),
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

// ─── Venue Detail Screen ────────────────────────────────────────────────────

class VenueDetailScreen extends ConsumerStatefulWidget {
  final String venueId;
  const VenueDetailScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  Map<String, dynamic>? _venue;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await DioClient.instance.get<dynamic>('/venues/${widget.venueId}');
      setState(() => _venue = data as Map<String, dynamic>);
    } catch (_) {}
    finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimary)));
    }
    if (_venue == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Venue not found')),
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final v = _venue!;
    final amenities = (v['amenities'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: v['bannerUrl'] != null
                  ? Image.network(v['bannerUrl'] as String, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: kPrimary))
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [kPrimary, kPrimary.withValues(alpha: 0.7)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: const Center(child: Text('🏟️', style: TextStyle(fontSize: 60))),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v['name']?.toString() ?? '',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: dark ? kDarkTextPrimary : kTextPrimary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 16, color: dark ? kDarkTextMuted : kTextMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('${v['address']}, ${v['city']}',
                            style: TextStyle(
                                color: dark ? kDarkTextMuted : kTextMuted,
                                fontSize: 14)),
                      ),
                    ],
                  ),
                  if (v['capacity'] != null) ...[
                    const SizedBox(height: 4),
                    Text('👥 Capacity: ${v['capacity']}',
                        style: TextStyle(
                            color: dark ? kDarkTextMuted : kTextMuted,
                            fontSize: 13)),
                  ],
                  if (amenities.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Amenities',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: dark ? kDarkTextPrimary : kTextPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: amenities.map((a) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('✓ $a',
                            style: const TextStyle(
                                fontSize: 12,
                                color: kPrimary,
                                fontWeight: FontWeight.w500)),
                      )).toList(),
                    ),
                  ],
                  if (v['latitude'] != null && v['longitude'] != null) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final lat = v['latitude'];
                        final lng = v['longitude'];
                        final name = Uri.encodeComponent(
                            v['name']?.toString() ?? 'Venue');
                        final googleNav = Uri.parse(
                            'google.navigation:q=$lat,$lng&mode=d');
                        final googleMaps = Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name&travelmode=driving');
                        if (await canLaunchUrl(googleNav)) {
                          await launchUrl(googleNav);
                        } else {
                          await launchUrl(googleMaps,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: dark ? kDarkSurface : kSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: dark ? kDarkBorder : kBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.directions_rounded,
                                color: kPrimary, size: 18),
                            SizedBox(width: 8),
                            Text('Get Directions',
                                style: TextStyle(
                                    color: kPrimary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
