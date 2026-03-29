import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/providers/auth_provider.dart';

// ─── Safe numeric parser ──────────────────────────────────────────────────────
double _toDouble(dynamic v) =>
    v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

// ─── Providers ────────────────────────────────────────────────────────────────

final _walletProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return {'balance': 0.0, 'currency': 'KES', 'recentTransactions': []};
  return DioClient.instance.get<Map<String, dynamic>>('/wallet/me');
});

final _walletTxProvider = FutureProvider<List<dynamic>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  final data = await DioClient.instance
      .get<Map<String, dynamic>>('/wallet/me/transactions?limit=30');
  return (data['items'] as List?) ?? [];
});

// ─── WalletScreen ─────────────────────────────────────────────────────────────

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  bool _topupLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initiateTopup() async {
    final phone = _phoneController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (phone.isEmpty || amount == null || amount < 10) {
      AppSnackbar.showError(
          context, 'Enter a valid phone and amount (min KES 10)');
      return;
    }
    setState(() => _topupLoading = true);
    try {
      await DioClient.instance
          .post<Map<String, dynamic>>('/wallet/topup', data: {
        'phone': phone,
        'amount': amount,
      });
      if (mounted) {
        _phoneController.clear();
        _amountController.clear();
        context.pop();
        AppSnackbar.showSuccess(
            context, 'STK push sent to $phone. Enter PIN to complete.');
        ref.invalidate(_walletProvider);
        ref.invalidate(_walletTxProvider);
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _topupLoading = false);
    }
  }

  void _showTopupSheet() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
            decoration: BoxDecoration(
              color: dark ? kDarkSurface : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: dark ? kDarkBorder : kBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Top Up Wallet',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Funds arrive instantly after M-Pesa payment',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: dark ? kDarkTextMuted : kTextMuted),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'M-Pesa Phone Number',
                    hintText: '07XXXXXXXX',
                    labelStyle: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted),
                    prefixIcon: Icon(Icons.phone_android_rounded,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Amount (KES)',
                    hintText: '100',
                    prefixText: 'KES ',
                    labelStyle: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                ),
                const SizedBox(height: 10),
                // Quick amount chips
                Wrap(
                  spacing: 8,
                  children: [100, 250, 500, 1000, 2000].map((amt) {
                    return ActionChip(
                      label: Text('KES $amt',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: dark ? kDarkTextPrimary : kTextPrimary)),
                      onPressed: () =>
                          _amountController.text = amt.toString(),
                      backgroundColor:
                          dark ? kDarkBackground : kSurface,
                      side: BorderSide(
                          color: dark ? kDarkBorder : kBorder, width: 0.8),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _topupLoading ? null : _initiateTopup,
                    icon: _topupLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.phone_android_rounded, size: 18),
                    label: Text(
                      _topupLoading ? 'Processing…' : 'Pay with M-Pesa',
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
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            color: dark ? kDarkTextMuted : kTextMuted,
                            fontSize: 13)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final walletAsync = ref.watch(_walletProvider);
    final txAsync = ref.watch(_walletTxProvider);

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
              ref.invalidate(_walletProvider);
              ref.invalidate(_walletTxProvider);
            },
          ),
        ],
      ),
      body: walletAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    size: 56,
                    color: dark ? kDarkTextMuted : kTextMuted),
                const SizedBox(height: 16),
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
                    onPressed: () => ref.invalidate(_walletProvider),
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
        data: (wallet) {
          final balance = _toDouble(wallet['balance']);
          final currency = wallet['currency']?.toString() ?? 'KES';

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              const SizedBox(height: 8),

              // ── Balance card ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD93B2F), Color(0xFFB02B20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$currency ${balance.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _WalletAction(
                          icon: Icons.add_rounded,
                          label: 'Top Up',
                          onTap: _showTopupSheet,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Info banner ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: dark
                      ? kWarning.withValues(alpha: 0.08)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dark
                        ? kWarning.withValues(alpha: 0.25)
                        : const Color(0xFFFED7AA),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18,
                        color: dark
                            ? kWarning
                            : const Color(0xFFEA580C)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Use your wallet balance at checkout instead of M-Pesa for faster payments.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: dark
                              ? kWarning
                              : const Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Transactions ─────────────────────────────────────────
              Text(
                'Transactions',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: dark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              txAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child:
                        CircularProgressIndicator(color: kPrimary),
                  ),
                ),
                error: (_, __) => Center(
                  child: Text(
                    'Could not load transactions',
                    style: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                ),
                data: (txList) {
                  if (txList.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 48,
                                color: dark
                                    ? kDarkTextMuted
                                    : kTextMuted),
                            const SizedBox(height: 12),
                            Text(
                              'No transactions yet',
                              style: GoogleFonts.inter(
                                  color: dark
                                      ? kDarkTextMuted
                                      : kTextMuted),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _showTopupSheet,
                              icon: const Icon(Icons.add_rounded,
                                  size: 16),
                              label: const Text('Top up now'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kPrimary,
                                side: const BorderSide(color: kPrimary),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(50)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: txList.map((tx) {
                      final m = tx as Map<String, dynamic>;
                      return _TxRow(tx: m, dark: dark);
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Wallet action button ─────────────────────────────────────────────────────

class _WalletAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WalletAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transaction row ──────────────────────────────────────────────────────────

class _TxRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final bool dark;

  const _TxRow({required this.tx, required this.dark});

  @override
  Widget build(BuildContext context) {
    final type = tx['type']?.toString() ?? '';
    final status = tx['status']?.toString() ?? '';
    final amount = _toDouble(tx['amount']);
    final desc = tx['description']?.toString() ?? type;
    final createdAt = tx['createdAt']?.toString() ?? '';

    final isCredit =
        type == 'TOPUP' || type == 'REFUND' || type == 'CASHBACK';
    final amountColor = status == 'FAILED'
        ? (dark ? kDarkTextMuted : kTextMuted)
        : isCredit
            ? kSuccess
            : (dark ? kDarkTextPrimary : kTextPrimary);
    final amountPrefix = isCredit ? '+' : '-';

    IconData typeIcon;
    Color iconBg;
    Color iconColor;
    switch (type) {
      case 'TOPUP':
        typeIcon = Icons.add_circle_rounded;
        iconBg = kSuccess.withValues(alpha: 0.12);
        iconColor = kSuccess;
      case 'PAYMENT':
        typeIcon = Icons.confirmation_number_rounded;
        iconBg = kWarning.withValues(alpha: 0.12);
        iconColor = kWarning;
      case 'REFUND':
        typeIcon = Icons.undo_rounded;
        iconBg = const Color(0xFFDBEAFE);
        iconColor = const Color(0xFF1D4ED8);
      case 'CASHBACK':
        typeIcon = Icons.card_giftcard_rounded;
        iconBg = kPrimary.withValues(alpha: 0.1);
        iconColor = kPrimary;
      default:
        typeIcon = Icons.swap_horiz_rounded;
        iconBg = dark ? kDarkBorder : kSurface;
        iconColor = dark ? kDarkTextMuted : kTextMuted;
    }

    String dateStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateStr =
            '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        dateStr = createdAt;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                color: iconBg,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(typeIcon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: dark ? kDarkTextMuted : kTextMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix KES ${amount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: amountColor),
              ),
              const SizedBox(height: 2),
              if (status == 'PENDING')
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kWarning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pending',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: kWarning),
                  ),
                )
              else if (status == 'FAILED')
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kDanger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Failed',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: kDanger),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
