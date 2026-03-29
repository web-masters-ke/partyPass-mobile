import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../domain/events_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../shared/widgets/event_card_large.dart';
import '../../../shared/widgets/event_card_small.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/models/event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();

  static const _categories = [
    'All',
    'Free Events',
    'FAMILY',
    'Online',
    'CLUB_NIGHT',
    'FESTIVAL',
  ];

  static const _categoryLabels = {
    'All': 'All',
    'Free Events': 'Free Events',
    'FAMILY': 'Family & Education',
    'Online': 'Online',
    'CLUB_NIGHT': 'Club Nights',
    'FESTIVAL': 'Festivals',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Consumer(
              builder: (context, ref, _) {
                final userAsync = ref.watch(currentUserProvider);
                final selectedCategory = ref.watch(selectedCategoryProvider);
                final eventsAsync = ref.watch(homeEventsProvider);
                final featuredAsync = ref.watch(featuredEventsProvider);

                return CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Greeting row
                            Row(
                              children: [
                                userAsync.when(
                                  data: (user) => CircleAvatar(
                                    radius: 22,
                                    backgroundColor: dark
                                        ? kDarkSurface
                                        : kSurface,
                                    backgroundImage: user?.avatarUrl != null
                                        ? CachedNetworkImageProvider(
                                            user!.avatarUrl!)
                                        : null,
                                    child: user?.avatarUrl == null
                                        ? Icon(Icons.person_rounded,
                                            color: dark
                                                ? kDarkTextMuted
                                                : kTextMuted)
                                        : null,
                                  ),
                                  loading: () => CircleAvatar(
                                    radius: 22,
                                    backgroundColor: dark
                                        ? kDarkSurface
                                        : kSurface,
                                  ),
                                  error: (_, __) => CircleAvatar(
                                    radius: 22,
                                    backgroundColor: dark
                                        ? kDarkSurface
                                        : kSurface,
                                    child: Icon(Icons.person_rounded,
                                        color: dark
                                            ? kDarkTextMuted
                                            : kTextMuted),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      () {
                                        final h = DateTime.now().hour;
                                        if (h >= 5 && h < 12) return 'Good Morning';
                                        if (h >= 12 && h < 17) return 'Good Afternoon';
                                        if (h >= 17 && h < 21) return 'Good Evening';
                                        return 'Good Night';
                                      }(),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: dark
                                            ? kDarkTextMuted
                                            : kTextMuted,
                                      ),
                                    ),
                                    userAsync.when(
                                      data: (user) => Text(
                                        user?.firstName ?? 'Guest',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: dark
                                              ? kDarkTextPrimary
                                              : kTextPrimary,
                                        ),
                                      ),
                                      loading: () => const SizedBox(
                                          width: 80, height: 16),
                                      error: (_, __) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Notification bell
                                GestureDetector(
                                  onTap: () =>
                                      context.push('/notifications'),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: dark
                                              ? kDarkSurface
                                              : kSurface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.notifications_rounded,
                                          color: dark
                                              ? kDarkTextPrimary
                                              : kTextPrimary,
                                          size: 22,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: kPrimary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Search bar
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: dark ? kDarkSurface : kSurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                onSubmitted: (v) =>
                                    context.push('/search?q=$v'),
                                decoration: InputDecoration(
                                  hintText: 'Search events...',
                                  hintStyle: GoogleFonts.inter(
                                      color: dark
                                          ? kDarkTextMuted
                                          : kTextMuted,
                                      fontSize: 14),
                                  prefixIcon: Icon(Icons.search_rounded,
                                      color: dark
                                          ? kDarkTextMuted
                                          : kTextMuted,
                                      size: 20),
                                  suffixIcon: GestureDetector(
                                    onTap: () => context.push('/search'),
                                    child: Icon(Icons.tune_rounded,
                                        color: dark
                                            ? kDarkTextMuted
                                            : kTextMuted,
                                        size: 20),
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          vertical: 14),
                                  filled: false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Quick-access tiles — row 1 (4 tiles)
                            Row(
                              children: [
                                _QuickTile(
                                  imagePath: 'assets/icons/tickets.svg',
                                  label: 'My Tickets',
                                  onTap: () => context.go('/tickets'),
                                ),
                                const SizedBox(width: 12),
                                _QuickTile(
                                  imagePath: 'assets/icons/wallet.svg',
                                  label: 'Wallet',
                                  onTap: () =>
                                      context.push('/wallet'),
                                ),
                                const SizedBox(width: 12),
                                _QuickTile(
                                  imagePath: 'assets/icons/loyalty.svg',
                                  label: 'Loyalty',
                                  onTap: () =>
                                      context.push('/loyalty'),
                                ),
                                const SizedBox(width: 12),
                                _QuickTile(
                                  imagePath: 'assets/icons/waitlist.svg',
                                  label: 'Waitlist',
                                  onTap: () =>
                                      context.push('/waitlist'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Quick-access tiles — row 2 (4 tiles)
                            Row(
                              children: [
                                if (userAsync.valueOrNull?.role !=
                                    'ATTENDEE') ...[
                                  _QuickTile(
                                    imagePath: 'assets/icons/scan.svg',
                                    label: 'Scan',
                                    onTap: () =>
                                        context.push('/scanner'),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                _QuickTile(
                                  imagePath:
                                      'assets/icons/group_buy.svg',
                                  label: 'Group Buy',
                                  onTap: () =>
                                      context.push('/my-groups'),
                                ),
                                const SizedBox(width: 12),
                                _QuickTile(
                                  imagePath: 'assets/icons/venues.svg',
                                  label: 'Venues',
                                  onTap: () =>
                                      context.push('/venues'),
                                ),
                                const SizedBox(width: 12),
                                _QuickTile(
                                  imagePath:
                                      'assets/icons/membership.svg',
                                  label: 'Membership',
                                  onTap: () =>
                                      context.push('/membership'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // Category chips
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final cat = _categories[i];
                            return CategoryChip(
                              label: _categoryLabels[cat] ?? cat,
                              isSelected: selectedCategory == cat,
                              onTap: () => ref
                                  .read(selectedCategoryProvider
                                      .notifier)
                                  .state = cat,
                            );
                          },
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                        child: SizedBox(height: 20)),

                    // Featured event card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        child: featuredAsync.when(
                          data: (events) {
                            if (events.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return EventCardLarge(
                              event: events.first,
                              onTap: () => context
                                  .push('/event/${events.first.id}'),
                              onJoin: () => context
                                  .push('/event/${events.first.id}'),
                            );
                          },
                          loading: () => const ShimmerEventCard(),
                          error: (e, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                        child: SizedBox(height: 24)),

                    // "Upcoming Events" header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Upcoming Events',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: dark
                                    ? kDarkTextPrimary
                                    : kTextPrimary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/search'),
                              child: Text(
                                'See all',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: kPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                        child: SizedBox(height: 16)),

                    // 2-column event grid
                    eventsAsync.when(
                      data: (events) =>
                          _buildEventGrid(context, events, dark),
                      loading: () => SliverToBoxAdapter(
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.76,
                          ),
                          itemCount: 4,
                          itemBuilder: (_, __) =>
                              const ShimmerEventCard(),
                        ),
                      ),
                      error: (_, __) => SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'Could not load events',
                              style: GoogleFonts.inter(
                                  color: dark
                                      ? kDarkTextMuted
                                      : kTextMuted),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom padding for nav bar
                    const SliverToBoxAdapter(
                        child: SizedBox(height: 120)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventGrid(
      BuildContext context, List<Event> events, bool dark) {
    if (events.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.event_busy_rounded,
                    size: 48,
                    color: dark ? kDarkTextMuted : kTextMuted),
                const SizedBox(height: 12),
                Text(
                  'No events found',
                  style: GoogleFonts.inter(
                      color: dark ? kDarkTextMuted : kTextMuted,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.76,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => EventCardSmall(
            event: events[i],
            onTap: () => context.push('/event/${events[i].id}'),
          ),
          childCount: events.length,
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final String imagePath;
  final String label;
  final VoidCallback onTap;

  const _QuickTile({
    required this.imagePath,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: dark ? kDarkBorder : kBorder, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 3D illustration — shadow copy offset + main SVG on top
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 3,
                      left: 3,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0, 0, 0, 0, 0,
                          0, 0, 0, 0, 0,
                          0, 0, 0, 0, 0,
                          0, 0, 0, 0.22, 0,
                        ]),
                        child: SvgPicture.asset(imagePath,
                            width: 34, height: 34),
                      ),
                    ),
                    SvgPicture.asset(imagePath, width: 34, height: 34),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dark ? kDarkTextPrimary : kTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
