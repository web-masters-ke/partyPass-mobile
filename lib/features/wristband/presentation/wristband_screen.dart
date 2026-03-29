import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _wristbandProvider = FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, eventId) async {
    try {
      final data = await DioClient.instance
          .get<Map<String, dynamic>>('/wristbands/my/$eventId');
      return data;
    } catch (_) {
      return null;
    }
  },
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class WristbandScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String? eventTitle;

  const WristbandScreen({
    super.key,
    required this.eventId,
    this.eventTitle,
  });

  @override
  ConsumerState<WristbandScreen> createState() => _WristbandScreenState();
}

class _WristbandScreenState extends ConsumerState<WristbandScreen> {
  bool _topping = false;
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _topupFromWallet(String nfcId) async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < 50) {
      AppSnackbar.showError(context, 'Minimum top-up is KES 50');
      return;
    }
    setState(() => _topping = true);
    try {
      await DioClient.instance.post<Map<String, dynamic>>(
        '/wristbands/topup-wallet',
        data: {'nfcId': nfcId, 'amount': amount},
      );
      ref.invalidate(_wristbandProvider(widget.eventId));
      _amountCtrl.clear();
      if (mounted) {
        context.pop();
        AppSnackbar.showSuccess(
            context, 'KES ${amount.toStringAsFixed(0)} added to wristband');
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _topping = false);
    }
  }

  void _showTopupSheet(String nfcId) {
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
                  'Top Up Wristband',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Deducted from your PartyPass wallet',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: dark ? kDarkTextMuted : kTextMuted),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  children: [100, 250, 500, 1000, 2000].map((a) {
                    return ActionChip(
                      label: Text('KES $a',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: dark ? kDarkTextPrimary : kTextPrimary)),
                      onPressed: () => _amountCtrl.text = a.toString(),
                      backgroundColor: dark ? kDarkBackground : kSurface,
                      side: BorderSide(
                          color: dark ? kDarkBorder : kBorder, width: 0.8),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Amount (KES)',
                    prefixText: 'KES ',
                    labelStyle: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted),
                    prefixStyle: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: dark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _topping
                        ? null
                        : () => _topupFromWallet(nfcId),
                    icon: _topping
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.add_circle_rounded, size: 18),
                    label: Text(
                      _topping ? 'Processing…' : 'Add to Wristband',
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
    final wristbandAsync = ref.watch(_wristbandProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.eventTitle ?? 'My Wristband'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(_wristbandProvider(widget.eventId)),
          ),
        ],
      ),
      body: wristbandAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.credit_card_off_rounded,
                    size: 56,
                    color: dark ? kDarkTextMuted : kTextMuted),
                const SizedBox(height: 16),
                Text(
                  'Could not load wristband',
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
                    onPressed: () =>
                        ref.invalidate(_wristbandProvider(widget.eventId)),
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
        data: (wristband) {
          if (wristband == null) {
            return _buildNoWristband(dark);
          }
          return _buildWristband(wristband, dark);
        },
      ),
    );
  }

  Widget _buildNoWristband(bool dark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.credit_card_off_rounded,
                  size: 44, color: kPrimary),
            ),
            const SizedBox(height: 20),
            Text(
              'No Wristband Yet',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: dark ? kDarkTextPrimary : kTextPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Issue your digital wristband to pay cashlessly at bars and vendors.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: dark ? kDarkTextMuted : kTextMuted,
                  height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'You need a valid ticket for this event to get a wristband.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => context.push('/tickets'),
                icon: const Icon(Icons.confirmation_number_rounded, size: 18),
                label: Text(
                  'View My Tickets',
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

  Widget _buildWristband(Map<String, dynamic> wb, bool dark) {
    final nfcId = wb['nfcId']?.toString() ?? '';
    final balance = (wb['balance'] as num?)?.toDouble() ?? 0.0;
    final isActive = wb['isActive'] as bool? ?? true;
    final qrDataUrl = wb['qrDataUrl']?.toString();
    final transactions = (wb['transactions'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        const SizedBox(height: 8),

        // ── Balance card ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'WRISTBAND BALANCE',
                    style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? kSuccess.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'ACTIVE' : 'INACTIVE',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'KES ${balance.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1),
              ),
              const SizedBox(height: 4),
              Text(
                nfcId,
                style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
              ),
              if (isActive) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _showTopupSheet(nfcId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Top Up',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── QR code section ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dark ? kDarkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: dark ? kDarkBorder : kBorder, width: 0.8),
            boxShadow: const [
              BoxShadow(
                  color: kCardShadow,
                  blurRadius: 8,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Scan at Venue',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: dark ? kDarkTextPrimary : kTextPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Show this QR to bar staff to pay. Keep screen brightness high.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
              ),
              const SizedBox(height: 16),
              if (qrDataUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    qrDataUrl,
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        _QrPlaceholder(nfcId: nfcId),
                  ),
                )
              else
                _QrPlaceholder(nfcId: nfcId),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: nfcId));
                  AppSnackbar.showSuccess(context, 'ID copied');
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nfcId,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: dark ? kDarkTextMuted : kTextMuted),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded,
                        size: 14,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Transactions ──────────────────────────────────────────────────────
        if (transactions.isNotEmpty) ...[
          Text(
            'Recent Transactions',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: dark ? kDarkTextPrimary : kTextPrimary),
          ),
          const SizedBox(height: 12),
          ...transactions.map(
              (tx) => _TxRow(tx: tx as Map<String, dynamic>, dark: dark)),
        ],
      ],
    );
  }
}

// ─── QR placeholder ───────────────────────────────────────────────────────────

class _QrPlaceholder extends StatelessWidget {
  final String nfcId;
  const _QrPlaceholder({required this.nfcId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 100, color: Colors.black87),
          const SizedBox(height: 8),
          Text(nfcId,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black54)),
        ],
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
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final desc = tx['description']?.toString() ?? '';
    final isCredit = type == 'TOPUP' || type == 'REFUND';

    final iconBg = (isCredit ? kSuccess : kPrimary).withValues(alpha: 0.12);
    final iconColor = isCredit ? kSuccess : kPrimary;

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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc.isEmpty ? type : desc,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                ),
                Text(
                  type,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: dark ? kDarkTextMuted : kTextMuted),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}KES ${amount.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
