import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/constants.dart';
import '../../shared/models/gate_entry.dart';
import '../../shared/models/order.dart';
import '../../shared/providers/auth_provider.dart';

// Auth screens
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';

// Home / Shell
import '../../features/home/presentation/home_screen.dart';

// Events
import '../../features/events/presentation/event_detail_screen.dart';

// Tickets
import '../../features/tickets/presentation/ticket_wallet_screen.dart';
import '../../features/tickets/presentation/ticket_qr_screen.dart';
import '../../features/tickets/presentation/checkout_screen.dart';
import '../../features/tickets/presentation/payment_screen.dart';

// Gate Staff
import '../../features/gate_staff/presentation/scanner_screen.dart';
import '../../features/gate_staff/presentation/scan_result_screen.dart';
import '../../features/gate_staff/presentation/gate_dashboard_screen.dart';
import '../../features/gate_staff/presentation/staff_home_screen.dart';
import '../../features/gate_staff/presentation/manage_staff_screen.dart';

// Loyalty
import '../../features/loyalty/presentation/loyalty_screen.dart';

// Profile
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';

// Organizer
import '../../features/organizer/presentation/organizer_dashboard_screen.dart';
import '../../features/organizer/presentation/organizer_events_screen.dart';
import '../../features/organizer/presentation/organizer_event_detail_screen.dart';
import '../../features/organizer/presentation/create_event_screen.dart';
import '../../features/organizer/presentation/organizer_wallet_screen.dart';

// Membership
import '../../features/membership/presentation/membership_screen.dart';

// Notifications
import '../../features/notifications/presentation/notifications_screen.dart';

// Search / Events browse
import '../../features/home/presentation/search_screen.dart';

// Venues
import '../../features/venues/presentation/venues_screen.dart';

// Reviews
import '../../features/reviews/presentation/write_review_screen.dart';

// Wallet
import '../../features/wallet/presentation/wallet_screen.dart';

// Wristband
import '../../features/wristband/presentation/wristband_screen.dart';
import '../../features/wristband/presentation/wristband_charge_screen.dart';

// Waitlist
import '../../features/waitlist/presentation/waitlist_screen.dart';

// Waiting Room
import '../../features/waiting_room/presentation/waiting_room_screen.dart';

// Group Booking
import '../../features/group_booking/presentation/group_join_screen.dart';
import '../../features/group_booking/presentation/my_groups_screen.dart';

const _storage = FlutterSecureStorage();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final token = await _storage.read(key: AppConstants.tokenKey);
      final hasToken = token != null && token.isNotEmpty;
      final loc = state.matchedLocation;

      final publicRoutes = ['/splash', '/login', '/register', '/otp'];
      final isPublic = publicRoutes.any((r) => loc.startsWith(r));

      if (!hasToken && !isPublic) return '/login';
      if (hasToken && (loc == '/login' || loc == '/register')) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpScreen(phone: phone);
        },
      ),

      // Shell route: bottom nav tabs
      ShellRoute(
        builder: (context, state, child) {
          return _ShellScaffold(location: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/events',
            builder: (_, __) => const SearchScreen(autoLoad: true),
          ),
          GoRoute(
            path: '/tickets',
            builder: (_, __) => const TicketWalletScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // Event detail (full screen, outside shell)
      GoRoute(
        path: '/event/:id',
        builder: (_, state) =>
            EventDetailScreen(eventId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: '/ticket/:id',
        builder: (_, state) =>
            TicketQRScreen(ticketId: state.pathParameters['id']!),
      ),

      // Checkout + Payment
      GoRoute(
        path: '/checkout/:eventId',
        builder: (_, state) {
          final selections =
              (state.extra as Map<String, int>?) ?? const {};
          return CheckoutScreen(
            eventId: state.pathParameters['eventId']!,
            selections: selections,
          );
        },
      ),
      GoRoute(
        path: '/payment/:orderId',
        builder: (_, state) {
          final order = state.extra as Order?;
          return PaymentScreen(
            orderId: state.pathParameters['orderId']!,
            order: order,
          );
        },
      ),

      // Gate staff
      GoRoute(
        path: '/scanner',
        builder: (_, state) {
          final eventId = state.uri.queryParameters['eventId'];
          final gateId = state.uri.queryParameters['gateId'];
          return ScannerScreen(eventId: eventId, gateId: gateId);
        },
      ),
      GoRoute(
        path: '/scan-result',
        builder: (_, state) {
          final entry = state.extra as GateEntry;
          return ScanResultScreen(entry: entry);
        },
      ),
      GoRoute(
        path: '/gate-dashboard/:eventId',
        builder: (_, state) => GateDashboardScreen(
          eventId: state.pathParameters['eventId']!,
        ),
      ),

      // Loyalty
      GoRoute(
        path: '/loyalty',
        builder: (_, __) => const LoyaltyScreen(),
      ),

      // Notifications
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),

      // Edit profile
      GoRoute(
        path: '/edit-profile',
        builder: (_, __) => const EditProfileScreen(),
      ),

      // Venues
      GoRoute(
        path: '/venues',
        builder: (_, __) => const VenuesScreen(),
      ),
      // Reviews
      GoRoute(
        path: '/review/:eventId',
        builder: (_, state) {
          final title = state.uri.queryParameters['title'] ?? '';
          return WriteReviewScreen(
            eventId: state.pathParameters['eventId']!,
            eventTitle: title,
          );
        },
      ),

      // Search
      GoRoute(
        path: '/search',
        builder: (_, state) {
          final q = state.uri.queryParameters['q'];
          return SearchScreen(initialQuery: q?.isNotEmpty == true ? q : null);
        },
      ),

      // Staff-only routes
      GoRoute(
        path: '/staff-home',
        builder: (_, __) => const StaffHomeScreen(),
      ),
      GoRoute(
        path: '/manage-staff',
        builder: (_, __) => const ManageStaffScreen(),
      ),

      // Organizer routes
      GoRoute(
        path: '/organizer',
        builder: (_, __) => const OrganizerDashboardScreen(),
      ),
      GoRoute(
        path: '/organizer/events',
        builder: (_, __) => const OrganizerEventsScreen(),
      ),
      GoRoute(
        path: '/organizer/events/new',
        builder: (_, __) => const CreateEventScreen(),
      ),
      GoRoute(
        path: '/organizer/events/:id',
        builder: (_, state) => OrganizerEventDetailScreen(
          eventId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/organizer/wallet',
        builder: (_, __) => const OrganizerWalletScreen(),
      ),
      GoRoute(
        path: '/organizer/team',
        builder: (_, __) => const ManageStaffScreen(),
      ),

      // Membership
      GoRoute(
        path: '/membership',
        builder: (_, __) => const MembershipScreen(),
      ),

      // Wallet
      GoRoute(
        path: '/wallet',
        builder: (_, __) => const WalletScreen(),
      ),

      // Wristband
      GoRoute(
        path: '/wristband/:eventId',
        builder: (_, state) => WristbandScreen(
          eventId: state.pathParameters['eventId']!,
          eventTitle: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/wristband-charge',
        builder: (_, __) => const WristbandChargeScreen(),
      ),

      // Waitlist
      GoRoute(
        path: '/waitlist',
        builder: (_, __) => const WaitlistScreen(),
      ),

      // Waiting Room
      GoRoute(
        path: '/queue/:eventId',
        builder: (_, state) =>
            WaitingRoomScreen(eventId: state.pathParameters['eventId']!),
      ),

      // Group Booking
      GoRoute(
        path: '/my-groups',
        builder: (_, __) => const MyGroupsScreen(),
      ),
      GoRoute(
        path: '/group-pay/:memberId',
        builder: (_, state) => GroupJoinScreen(
          shareToken: state.pathParameters['memberId']!,
        ),
      ),
      GoRoute(
        path: '/group/:shareToken',
        builder: (_, state) =>
            GroupJoinScreen(shareToken: state.pathParameters['shareToken']!),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/home'),
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

class _ShellScaffold extends ConsumerWidget {
  final Widget child;
  final String location;

  const _ShellScaffold({required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final role = userAsync.valueOrNull?.role ?? 'ATTENDEE';
    final isOrganizer = role == 'ORGANIZER' || role == 'CLUB_OWNER';

    int currentIndex;
    if (isOrganizer) {
      if (location.startsWith('/events')) {
        currentIndex = 1;
      } else if (location.startsWith('/organizer')) {
        currentIndex = 2;
      } else if (location.startsWith('/profile')) {
        currentIndex = 3;
      } else {
        currentIndex = 0;
      }
    } else {
      if (location.startsWith('/events')) {
        currentIndex = 1;
      } else if (location.startsWith('/tickets')) {
        currentIndex = 2;
      } else if (location.startsWith('/profile')) {
        currentIndex = 3;
      } else {
        currentIndex = 0;
      }
    }

    void onNavTap(int index) {
      if (isOrganizer) {
        switch (index) {
          case 0:
            context.go('/home');
          case 1:
            context.go('/events');
          case 2:
            context.go('/organizer');
          case 3:
            context.go('/profile');
        }
      } else {
        switch (index) {
          case 0:
            context.go('/home');
          case 1:
            context.go('/events');
          case 2:
            context.go('/tickets');
          case 3:
            context.go('/profile');
        }
      }
    }

    final navItems = isOrganizer
        ? const [
            (icon: Icons.home_rounded, label: 'Home'),
            (icon: Icons.event_rounded, label: 'Events'),
            (icon: Icons.dashboard_rounded, label: 'Dashboard'),
            (icon: Icons.person_rounded, label: 'Profile'),
          ]
        : const [
            (icon: Icons.home_rounded, label: 'Home'),
            (icon: Icons.event_rounded, label: 'Events'),
            (icon: Icons.confirmation_number_rounded, label: 'Tickets'),
            (icon: Icons.person_rounded, label: 'Profile'),
          ];

    return Scaffold(
      body: Stack(
        children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _RoleAwarePillNav(
              currentIndex: currentIndex,
              onTap: onNavTap,
              items: navItems,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role-aware pill nav — mirrors PillBottomNav but accepts dynamic items
// ---------------------------------------------------------------------------

class _RoleAwarePillNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<({IconData icon, String label})> items;

  const _RoleAwarePillNav({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 32, right: 32, bottom: bottomInset + 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: kBackground,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: kBorder, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (int i = 0; i < items.length; i++)
              _NavItem(
                icon: items[i].icon,
                label: items[i].label,
                index: i,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  bool get isSelected => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFD93B2F);
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 6,
        ),
        decoration: isSelected
            ? BoxDecoration(
                color: primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(24),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? primary : kTextPrimary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primary : kTextPrimary,
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
