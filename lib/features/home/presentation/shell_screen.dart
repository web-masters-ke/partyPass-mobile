import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/pill_bottom_nav.dart';
import 'home_screen.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../home/presentation/search_screen.dart';
import '../../organizer/presentation/organizer_dashboard_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _currentIndex = 0;

  static const _baseItems = [
    PillNavItem(icon: Icons.home_rounded, label: 'Home'),
    PillNavItem(icon: Icons.event_rounded, label: 'Events'),
    PillNavItem(icon: Icons.confirmation_number_rounded, label: 'Tickets'),
    PillNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  static const _organizerItems = [
    PillNavItem(icon: Icons.home_rounded, label: 'Home'),
    PillNavItem(icon: Icons.event_rounded, label: 'Events'),
    PillNavItem(icon: Icons.dashboard_rounded, label: 'Organizer'),
    PillNavItem(icon: Icons.confirmation_number_rounded, label: 'Tickets'),
    PillNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final isOrganizer = userAsync.maybeWhen(
      data: (u) => u?.role == 'ORGANIZER' || u?.role == 'CLUB_OWNER',
      orElse: () => false,
    );

    final List<Widget> screens = isOrganizer
        ? const [
            HomeScreen(),
            SearchScreen(),
            OrganizerDashboardScreen(),
            FavoritesScreen(),
            ProfileScreen(),
          ]
        : const [
            HomeScreen(),
            SearchScreen(),
            FavoritesScreen(),
            ProfileScreen(),
          ];

    final items = isOrganizer ? _organizerItems : _baseItems;
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: safeIndex,
            children: screens,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PillBottomNav(
              items: items,
              currentIndex: safeIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
          ),
        ],
      ),
    );
  }
}
