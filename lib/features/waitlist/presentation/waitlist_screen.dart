import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/providers/auth_provider.dart';

final _waitlistProvider = FutureProvider<List<dynamic>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  final data =
      await DioClient.instance.get<dynamic>('/users/me/waitlist');
  if (data is List) return data;
  return (data as Map<String, dynamic>)['items'] as List? ?? [];
});

class WaitlistScreen extends ConsumerStatefulWidget {
  const WaitlistScreen({super.key});

  @override
  ConsumerState<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends ConsumerState<WaitlistScreen> {
  final Map<String, bool> _claiming = {};

  Future<void> _claimTicket(String waitlistId) async {
    setState(() => _claiming[waitlistId] = true);
    try {
      await DioClient.instance
          .post<Map<String, dynamic>>('/waitlist/$waitlistId/claim');
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Ticket claimed! Check your tickets.');
        ref.invalidate(_waitlistProvider);
        context.push('/tickets');
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _claiming[waitlistId] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final waitlistAsync = ref.watch(_waitlistProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Waitlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_waitlistProvider),
          ),
        ],
      ),
      body: waitlistAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_rounded,
                    size: 56, color: dark ? kDarkTextMuted : kTextMuted),
                const SizedBox(height: 16),
                Text(
                  'Could not load waitlist',
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
                    onPressed: () => ref.invalidate(_waitlistProvider),
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
        data: (entries) {
          if (entries.isEmpty) {
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
                      child: const Icon(Icons.hourglass_empty_rounded,
                          size: 44, color: kPrimary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No waitlist entries',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: dark ? kDarkTextPrimary : kTextPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When sold-out events have cancellations, you\'ll be notified here.',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: dark ? kDarkTextMuted : kTextMuted,
                          height: 1.5),
                      textAlign: TextAlign.center,
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

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i] as Map<String, dynamic>;
              return _WaitlistCard(
                entry: e,
                isClaiming: _claiming[e['id']?.toString()] ?? false,
                onClaim: () => _claimTicket(e['id']?.toString() ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Waitlist card ────────────────────────────────────────────────────────────

class _WaitlistCard extends StatefulWidget {
  final Map<String, dynamic> entry;
  final bool isClaiming;
  final VoidCallback onClaim;

  const _WaitlistCard({
    required this.entry,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  State<_WaitlistCard> createState() => _WaitlistCardState();
}

class _WaitlistCardState extends State<_WaitlistCard> {
  Timer? _timer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final claimExpiresAt = widget.entry['claimExpiresAt']?.toString();
    if (claimExpiresAt == null) {
      if (mounted) setState(() => _remaining = null);
      return;
    }
    try {
      final exp = DateTime.parse(claimExpiresAt);
      final r = exp.difference(DateTime.now());
      if (mounted) {
        setState(() => _remaining = r.isNegative ? Duration.zero : r);
      }
    } catch (_) {
      if (mounted) setState(() => _remaining = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final e = widget.entry;
    final status = e['status']?.toString() ?? 'WAITING';
    final position = e['position'] as int?;
    final eventTitle = (e['event'] as Map?)?['title']?.toString() ??
        e['eventTitle']?.toString() ??
        'Event';
    final tierName = (e['tier'] as Map?)?['name']?.toString() ??
        e['tierName']?.toString() ??
        'General Admission';

    final isAvailable = status == 'NOTIFIED' || status == 'AVAILABLE';
    final hasCountdown = _remaining != null && _remaining!.inSeconds > 0;

    String countdownStr = '';
    if (hasCountdown) {
      final m = _remaining!.inMinutes
          .remainder(60)
          .toString()
          .padLeft(2, '0');
      final s = _remaining!.inSeconds
          .remainder(60)
          .toString()
          .padLeft(2, '0');
      countdownStr =
          '${_remaining!.inHours > 0 ? '${_remaining!.inHours}h ' : ''}${m}m ${s}s';
    }

    // Status badge colors — dark-aware
    Color statusColor;
    Color statusBg;
    String statusLabel;
    switch (status) {
      case 'NOTIFIED':
      case 'AVAILABLE':
        statusColor = dark ? kSuccess : const Color(0xFF166534);
        statusBg = dark
            ? kSuccess.withValues(alpha: 0.15)
            : const Color(0xFFDCFCE7);
        statusLabel = 'Claim Available!';
      case 'WAITING':
        statusColor = dark ? kWarning : const Color(0xFF92400E);
        statusBg = dark
            ? kWarning.withValues(alpha: 0.12)
            : const Color(0xFFFEF3C7);
        statusLabel = 'Waiting';
      case 'CLAIMED':
        statusColor = dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        statusBg = dark
            ? const Color(0xFF1D4ED8).withValues(alpha: 0.15)
            : const Color(0xFFDBEAFE);
        statusLabel = 'Claimed';
      case 'EXPIRED':
        statusColor = dark ? kDarkTextMuted : const Color(0xFF6B7280);
        statusBg = dark ? kDarkSurface : const Color(0xFFF3F4F6);
        statusLabel = 'Expired';
      default:
        statusColor = dark ? kDarkTextMuted : kTextMuted;
        statusBg = dark ? kDarkSurface : kSurface;
        statusLabel = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAvailable
              ? (dark
                  ? kSuccess.withValues(alpha: 0.5)
                  : const Color(0xFF86EFAC))
              : (dark ? kDarkBorder : kBorder),
          width: isAvailable ? 1.5 : 0.8,
        ),
        boxShadow: [
          if (isAvailable)
            BoxShadow(
              color: kSuccess.withValues(alpha: dark ? 0.1 : 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          else
            const BoxShadow(
                color: kCardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  eventTitle,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tier + position
          Row(
            children: [
              Icon(Icons.local_activity_rounded,
                  size: 13,
                  color: dark ? kDarkTextMuted : kTextMuted),
              const SizedBox(width: 4),
              Text(
                tierName,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: dark ? kDarkTextMuted : kTextMuted),
              ),
              if (position != null && status == 'WAITING') ...[
                const SizedBox(width: 16),
                Icon(Icons.people_rounded,
                    size: 13,
                    color: dark ? kDarkTextMuted : kTextMuted),
                const SizedBox(width: 4),
                Text(
                  'Position #$position',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: dark ? kDarkTextMuted : kTextMuted),
                ),
              ],
            ],
          ),

          // Countdown + claim button
          if (isAvailable) ...[
            const SizedBox(height: 14),
            if (hasCountdown) ...[
              Row(
                children: [
                  const Icon(Icons.timer_rounded,
                      size: 15, color: kWarning),
                  const SizedBox(width: 4),
                  Text(
                    'Expires in $countdownStr',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kWarning),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: widget.isClaiming ? null : widget.onClaim,
                icon: widget.isClaiming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  widget.isClaiming ? 'Claiming...' : 'Claim Ticket',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: kSuccess,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
