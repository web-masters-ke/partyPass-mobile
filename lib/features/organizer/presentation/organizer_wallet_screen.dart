import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_snackbar.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _orgWalletProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return DioClient.instance.get<Map<String, dynamic>>('/organizer/wallet');
});

final _orgPayoutsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data =
      await DioClient.instance.get<dynamic>('/organizer/payouts');
  if (data is List) return data.cast<Map<String, dynamic>>();
  final items =
      (data as Map<String, dynamic>)['items'] as List? ?? [];
  return items.cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OrganizerWalletScreen extends ConsumerWidget {
  const OrganizerWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final walletAsync = ref.watch(_orgWalletProvider);
    final payoutsAsync = ref.watch(_orgPayoutsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(_orgWalletProvider);
              ref.invalidate(_orgPayoutsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: () async {
          ref.invalidate(_orgWalletProvider);
          ref.invalidate(_orgPayoutsProvider);
        },
        child: walletAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: kPrimary)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_rounded,
                      size: 48,
                      color: dark ? kDarkTextMuted : kTextMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load wallet',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: dark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () => ref.invalidate(_orgWalletProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text('Retry',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
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
          data: (wallet) {
            final gross = double.tryParse(
                    wallet['grossRevenue']?.toString() ?? '0') ??
                0;
            final fee = gross * 0.05;
            final net = gross - fee;
            final paidOut = double.tryParse(
                    wallet['paidOut']?.toString() ?? '0') ??
                0;
            final inProgress = double.tryParse(
                    wallet['inProgress']?.toString() ?? '0') ??
                0;
            final available = net - paidOut - inProgress;
            final canWithdraw = available >= 100;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                // ── Hero card ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPrimary, Color(0xFFA82B22)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available to Withdraw',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fmt(available),
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: canWithdraw
                              ? () => _showWithdrawSheet(
                                  context, ref, available)
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: canWithdraw
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            disabledBackgroundColor:
                                Colors.white.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50)),
                          ),
                          child: Text(
                            canWithdraw
                                ? 'Request Withdrawal'
                                : 'Minimum KES 100 to withdraw',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: canWithdraw
                                  ? kPrimary
                                  : Colors.white60,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Breakdown grid ───────────────────────────────────────
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _BreakdownCard(
                      label: 'Gross Revenue',
                      value: _fmt(gross),
                      color: kSuccess,
                      icon: Icons.trending_up_rounded,
                      dark: dark,
                    ),
                    _BreakdownCard(
                      label: 'Platform Fee (5%)',
                      value: '-${_fmt(fee)}',
                      color: kDanger,
                      icon: Icons.percent_rounded,
                      dark: dark,
                    ),
                    _BreakdownCard(
                      label: 'Already Paid Out',
                      value: _fmt(paidOut),
                      color: const Color(0xFF3B82F6),
                      icon: Icons.check_circle_rounded,
                      dark: dark,
                    ),
                    _BreakdownCard(
                      label: 'In Progress',
                      value: _fmt(inProgress),
                      color: kWarning,
                      icon: Icons.hourglass_top_rounded,
                      dark: dark,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Payout history ───────────────────────────────────────
                Text(
                  'Payout History',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                payoutsAsync.when(
                  loading: () => Column(
                    children: List.generate(
                      3,
                      (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PayoutShimmer(dark: dark),
                      ),
                    ),
                  ),
                  error: (_, __) => Text(
                    'Could not load payouts',
                    style: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                  data: (payouts) {
                    if (payouts.isEmpty) {
                      return Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No payouts yet',
                            style: GoogleFonts.inter(
                                color: dark ? kDarkTextMuted : kTextMuted),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: payouts
                          .map((p) => _PayoutRow(payout: p, dark: dark))
                          .toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _fmt(double v) =>
      'KES ${NumberFormat('#,##0').format(v.round())}';

  void _showWithdrawSheet(
      BuildContext context, WidgetRef ref, double available) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WithdrawSheet(
        available: available,
        onSuccess: () {
          ref.invalidate(_orgWalletProvider);
          ref.invalidate(_orgPayoutsProvider);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Breakdown Card
// ---------------------------------------------------------------------------

class _BreakdownCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool dark;

  const _BreakdownCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? kDarkBorder : kBorder, width: 0.8),
        boxShadow: const [
          BoxShadow(
              color: kCardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: dark ? kDarkTextMuted : kTextMuted),
                maxLines: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payout Row
// ---------------------------------------------------------------------------

class _PayoutRow extends StatelessWidget {
  final Map<String, dynamic> payout;
  final bool dark;

  const _PayoutRow({required this.payout, required this.dark});

  @override
  Widget build(BuildContext context) {
    final amount =
        double.tryParse(payout['amount']?.toString() ?? '0') ?? 0;
    final status = payout['status']?.toString() ?? 'PENDING';
    final phone = payout['phone']?.toString() ?? '';
    DateTime? createdAt;
    try {
      if (payout['createdAt'] != null) {
        createdAt =
            DateTime.parse(payout['createdAt'].toString());
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: dark ? kDarkBorder : kBorder, width: 0.8),
        boxShadow: const [
          BoxShadow(
              color: kCardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kSuccess.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 20,
                color: kSuccess),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KES ${NumberFormat('#,##0').format(amount.round())}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                Text(
                  phone.isNotEmpty
                      ? '$phone${createdAt != null ? ' · ${AppDateUtils.formatDate(createdAt)}' : ''}'
                      : (createdAt != null
                          ? AppDateUtils.formatDate(createdAt)
                          : ''),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: dark ? kDarkTextMuted : kTextMuted),
                ),
              ],
            ),
          ),
          _StatusBadge(status: status, dark: dark),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool dark;

  const _StatusBadge({required this.status, required this.dark});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        bg = kSuccess.withValues(alpha: 0.12);
        fg = kSuccess;
      case 'PROCESSING':
      case 'APPROVED':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
      case 'PENDING':
        bg = kWarning.withValues(alpha: 0.12);
        fg = kWarning;
      case 'FAILED':
      case 'REJECTED':
      case 'CANCELLED':
        bg = kDanger.withValues(alpha: 0.12);
        fg = kDanger;
      default:
        bg = dark ? kDarkBorder : kBorder;
        fg = dark ? kDarkTextMuted : kTextMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer
// ---------------------------------------------------------------------------

class _PayoutShimmer extends StatelessWidget {
  final bool dark;
  const _PayoutShimmer({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Withdrawal Bottom Sheet
// ---------------------------------------------------------------------------

class _WithdrawSheet extends ConsumerStatefulWidget {
  final double available;
  final VoidCallback onSuccess;

  const _WithdrawSheet({
    required this.available,
    required this.onSuccess,
  });

  @override
  ConsumerState<_WithdrawSheet> createState() =>
      _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (amountText.isEmpty) {
      AppSnackbar.showError(context, 'Enter withdrawal amount');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount < 100) {
      AppSnackbar.showError(context, 'Minimum withdrawal is KES 100');
      return;
    }
    if (amount > widget.available) {
      AppSnackbar.showError(context, 'Amount exceeds available balance');
      return;
    }
    if (phone.isEmpty) {
      AppSnackbar.showError(context, 'Enter M-Pesa phone number');
      return;
    }

    setState(() => _submitting = true);
    try {
      await DioClient.instance.post<dynamic>(
        '/organizer/payouts/request',
        data: {
          'amount': amount,
          'phone': phone,
          if (_notesCtrl.text.trim().isNotEmpty)
            'notes': _notesCtrl.text.trim(),
        },
      );
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitted = true;
        });
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.toString());
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = dark ? kDarkSurface : Colors.white;
    final txtPrimary = dark ? kDarkTextPrimary : kTextPrimary;
    final txtMuted = dark ? kDarkTextMuted : kTextMuted;
    final borderCol = dark ? kDarkBorder : kBorder;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: borderCol,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          if (_submitted) ...[
            const Icon(Icons.check_circle_rounded,
                color: kSuccess, size: 64),
            const SizedBox(height: 16),
            Text(
              'Withdrawal Requested!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: txtPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payout will be sent to your M-Pesa within 24 hours.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: txtMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => context.pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: kSuccess,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ] else ...[
            Text(
              'Request Withdrawal',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: txtPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Available: KES ${NumberFormat('#,##0').format(widget.available.round())}',
              style: GoogleFonts.inter(fontSize: 13, color: txtMuted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(color: txtPrimary),
              decoration: InputDecoration(
                labelText: 'Amount (KES)',
                hintText: '1000',
                prefixText: 'KES ',
                labelStyle: GoogleFonts.inter(color: txtMuted),
                prefixIcon:
                    Icon(Icons.attach_money_rounded, color: txtMuted),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.inter(color: txtPrimary),
              decoration: InputDecoration(
                labelText: 'M-Pesa Phone',
                hintText: '07XXXXXXXX',
                labelStyle: GoogleFonts.inter(color: txtMuted),
                prefixIcon:
                    Icon(Icons.phone_android_rounded, color: txtMuted),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtrl,
              style: GoogleFonts.inter(color: txtPrimary),
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. For Club Night event',
                labelStyle: GoogleFonts.inter(color: txtMuted),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.phone_android_rounded, size: 18),
                label: Text(
                  _submitting ? 'Processing…' : 'Request Payout',
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
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: txtMuted, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
