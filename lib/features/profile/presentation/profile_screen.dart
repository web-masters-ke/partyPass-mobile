import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../features/auth/domain/auth_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/tier_badge.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: userAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: kPrimary)),
          error: (e, _) => Center(
            child: Text(e.toString(),
                style: GoogleFonts.inter(
                    color: dark ? kDarkTextMuted : kTextMuted)),
          ),
          data: (user) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: dark ? kDarkSurface : kSurface,
                      backgroundImage: user?.avatarUrl != null
                          ? CachedNetworkImageProvider(user!.avatarUrl!)
                          : null,
                      child: user?.avatarUrl == null
                          ? Icon(Icons.person_rounded,
                              size: 40,
                              color: dark ? kDarkTextMuted : kTextMuted)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.fullName ?? 'Guest',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: dark ? kDarkTextPrimary : kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: dark ? kDarkTextMuted : kTextMuted),
                    ),
                    const SizedBox(height: 10),
                    if (user != null) TierBadge(tier: user.loyaltyTier),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Divider(height: 1, color: dark ? kDarkBorder : kBorder),
              const SizedBox(height: 8),

              // Menu items
              _MenuItem(
                icon: Icons.confirmation_number_rounded,
                label: 'My Tickets',
                onTap: () => context.push('/tickets'),
              ),
              _MenuItem(
                icon: Icons.workspace_premium_rounded,
                label: 'Loyalty Wallet',
                onTap: () => context.push('/loyalty'),
              ),
              _MenuItem(
                icon: Icons.workspace_premium_rounded,
                label: 'Membership',
                badge: 'FREE',
                onTap: () => context.push('/membership'),
              ),
              if (user?.role == 'ORGANIZER') ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                  child: Text(
                    'Organizer Tools',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dark ? kDarkTextMuted : kTextMuted,
                    ),
                  ),
                ),
                _MenuItem(
                  icon: Icons.dashboard_rounded,
                  label: 'My Dashboard',
                  onTap: () => context.push('/organizer'),
                ),
                _MenuItem(
                  icon: Icons.event_rounded,
                  label: 'My Events',
                  onTap: () => context.push('/organizer/events'),
                ),
                _MenuItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'My Wallet',
                  onTap: () => context.push('/organizer/wallet'),
                ),
                _MenuItem(
                  icon: Icons.group_rounded,
                  label: 'My Team',
                  onTap: () => context.push('/organizer/team'),
                ),
              ],
              _MenuItem(
                icon: Icons.notifications_rounded,
                label: 'Notifications',
                onTap: () => context.push('/notifications'),
              ),
              _MenuItem(
                icon: Icons.edit_rounded,
                label: 'Edit Profile',
                onTap: () => context.push('/edit-profile'),
              ),
              if (user?.isStaff ?? false)
                _MenuItem(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Gate Scanner',
                  badge: 'STAFF',
                  onTap: () => context.push('/scanner'),
                ),
              _MenuItem(
                icon: Icons.help_rounded,
                label: 'Help & Support',
                onTap: () {},
              ),
              // Dark mode toggle
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (dark ? kDarkTextMuted : kTextMuted)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.dark_mode_rounded,
                          size: 20,
                          color: dark ? kDarkTextMuted : kTextMuted),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Dark Mode',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: dark ? kDarkTextPrimary : kTextPrimary,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value:
                          ref.watch(themeProvider) == ThemeMode.dark,
                      activeThumbColor: kPrimary,
                      activeTrackColor:
                          kPrimary.withValues(alpha: 0.4),
                      onChanged: (_) =>
                          ref.read(themeProvider.notifier).toggle(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: dark ? kDarkBorder : kBorder),
              const SizedBox(height: 8),
              _MenuItem(
                icon: Icons.logout_rounded,
                label: 'Logout',
                iconColor: kDanger,
                labelColor: kDanger,
                showChevron: false,
                onTap: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'PartyPass v1.0.0',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: dark ? kDarkTextMuted : kTextMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final Color? iconColor;
  final Color? labelColor;
  final bool showChevron;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.iconColor,
    this.labelColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor =
        iconColor ?? (dark ? kDarkTextMuted : kTextMuted);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    effectiveIconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(icon, size: 20, color: effectiveIconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: labelColor ??
                      (dark ? kDarkTextPrimary : kTextPrimary),
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (showChevron)
              Icon(Icons.chevron_right_rounded,
                  color: dark ? kDarkTextMuted : kTextMuted,
                  size: 20),
          ],
        ),
      ),
    );
  }
}
