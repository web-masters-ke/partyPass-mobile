import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../home/domain/events_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/event_card_small.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final favAsync = ref.watch(favoritesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                'Favorites',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: dark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
            ),
            // Pill tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _TabPill(
                    label: 'All',
                    isSelected: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                  const SizedBox(width: 10),
                  _TabPill(
                    label: 'Organizers',
                    isSelected: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: favAsync.when(
                loading: () => const LoadingShimmer(),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 48,
                          color: dark ? kDarkTextMuted : kTextMuted),
                      const SizedBox(height: 12),
                      Text('Could not load favorites',
                          style: GoogleFonts.inter(
                              color: dark ? kDarkTextMuted : kTextMuted)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(favoritesProvider),
                        style: FilledButton.styleFrom(
                            backgroundColor: kPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50))),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (events) {
                  if (events.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border_rounded,
                              size: 56,
                              color: dark ? kDarkTextMuted : kTextMuted),
                          const SizedBox(height: 16),
                          Text(
                            'No favorites yet',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: dark ? kDarkTextPrimary : kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the heart on any event to save it here',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: dark ? kDarkTextMuted : kTextMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => context.go('/search'),
                            style: FilledButton.styleFrom(
                                backgroundColor: kPrimary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50))),
                            icon: const Icon(Icons.search_rounded, size: 18),
                            label: const Text('Explore Events'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: [
                      // Featured favorite card (first event, large)
                      if (events.isNotEmpty) ...[
                        _FeaturedFavoriteCard(
                          event: events.first,
                          onTap: () =>
                              context.push('/event/${events.first.id}'),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Find Events',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: dark ? kDarkTextPrimary : kTextPrimary,
                              ),
                            ),
                            Text(
                              '${events.length} saved',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: dark ? kDarkTextMuted : kTextMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      // 2-col grid of remaining
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount:
                            events.length > 1 ? events.length - 1 : 0,
                        itemBuilder: (context, i) => EventCardSmall(
                          event: events[i + 1],
                          onTap: () =>
                              context.push('/event/${events[i + 1].id}'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabPill(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isSelected
                ? kPrimary
                : Theme.of(context).brightness == Brightness.dark
                    ? kDarkBorder
                    : kBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : Theme.of(context).brightness == Brightness.dark
                    ? kDarkTextPrimary
                    : kTextPrimary,
          ),
        ),
      ),
    );
  }
}

class _FeaturedFavoriteCard extends StatelessWidget {
  final dynamic event;
  final VoidCallback onTap;

  const _FeaturedFavoriteCard(
      {required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kPrimary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date top-left
                Column(
                  children: [
                    Text(
                      AppDateUtils.formatDayNumber(event.startDateTime),
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Text(
                      AppDateUtils.formatMonth(event.startDateTime),
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Spacer(),
                // Heart icon
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      size: 18, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Category
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                event.category.toString().replaceAll('_', ' '),
                style: GoogleFonts.inter(
                    fontSize: 10, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.title.toString(),
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 13, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  AppDateUtils.formatDate(event.startDateTime),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white70),
                ),
                const Spacer(),
                // Participant avatars placeholder
                Row(
                  children: [
                    for (int i = 0; i < 3; i++)
                      Container(
                        width: 26,
                        height: 26,
                        margin: EdgeInsets.only(left: i > 0 ? -8 : 0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: kPrimary, width: 1.5),
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 14, color: Colors.white),
                      ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white70, size: 18),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
