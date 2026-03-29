import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/app_snackbar.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String paymentMethod;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.paymentMethod,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  Order? _order;
  bool _loading = true;
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPolls = 60; // 5 min at 5s intervals

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final data = await DioClient.instance
          .get<Map<String, dynamic>>('/orders/${widget.orderId}');
      final order = Order.fromJson(data);
      if (mounted) {
        setState(() {
          _order = order;
          _loading = false;
        });
        if (!order.isPaid) _startPolling();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.showError(context, e.toString());
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      _pollCount++;
      if (_pollCount >= _maxPolls) {
        _pollTimer?.cancel();
        if (mounted) {
          AppSnackbar.showError(
              context, 'Payment timeout. Please try again.');
        }
        return;
      }
      try {
        final data = await DioClient.instance
            .get<Map<String, dynamic>>('/orders/${widget.orderId}');
        final order = Order.fromJson(data);
        if (mounted) setState(() => _order = order);
        if (order.isPaid) {
          _pollTimer?.cancel();
          if (mounted) _onPaymentSuccess(order);
        }
      } catch (_) {}
    });
  }

  void _onPaymentSuccess(Order order) {
    // Navigate to first ticket in this order
    context.go('/tickets');
  }

  bool get _isStk =>
      widget.paymentMethod == 'MPESA_STK' ||
      widget.paymentMethod.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Payment'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _order == null
              ? const Center(child: Text('Order not found'))
              : _isStk
                  ? _StkView(order: _order!)
                  : _PaybillView(order: _order!, onConfirm: () {
                      if (mounted) {
                        AppSnackbar.showSuccess(
                            context, 'Checking payment...');
                        _startPolling();
                      }
                    }),
    );
  }
}

class _StkView extends StatelessWidget {
  final Order order;
  const _StkView({required this.order});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF00B300).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_android_rounded,
                size: 40, color: Color(0xFF00B300)),
          ),
          const SizedBox(height: 24),
          Text(
            'Check your phone',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: dark ? kDarkTextPrimary : kTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'An M-Pesa STK push has been sent to your phone. Enter your PIN to complete payment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: dark ? kDarkTextMuted : kTextMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: kPrimary, strokeWidth: 3),
          const SizedBox(height: 16),
          Text(
            'Waiting for payment confirmation...',
            style: GoogleFonts.inter(fontSize: 13, color: dark ? kDarkTextMuted : kTextMuted),
          ),
          const SizedBox(height: 40),
          OutlinedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _PaybillView extends StatelessWidget {
  final Order order;
  final VoidCallback onConfirm;

  const _PaybillView({required this.order, required this.onConfirm});

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.showSuccess(context, '$label copied');
  }

  @override
  Widget build(BuildContext context) {
    final paybill = order.paybill ?? '400200';
    final accountRef = order.mpesaAccountRef ?? 'PP-${order.id.substring(0, 8).toUpperCase()}';
    final amount = order.total.toStringAsFixed(0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF00B300).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded,
                size: 40, color: Color(0xFF00B300)),
          ),
          const SizedBox(height: 20),
          Text(
            'Pay via M-Pesa Paybill',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).brightness == Brightness.dark ? kDarkTextPrimary : kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Go to M-Pesa → Lipa na M-Pesa → Pay Bill',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? kDarkTextMuted : kTextMuted),
          ),
          const SizedBox(height: 32),
          _PaybillRow(
            label: 'Business Number',
            value: paybill,
            onCopy: () => _copy(context, paybill, 'Business number'),
          ),
          const SizedBox(height: 16),
          _PaybillRow(
            label: 'Account Number',
            value: accountRef,
            onCopy: () => _copy(context, accountRef, 'Account number'),
          ),
          const SizedBox(height: 16),
          _PaybillRow(
            label: 'Amount',
            value: 'KES $amount',
            valueColor: kPrimary,
            onCopy: () => _copy(context, amount, 'Amount'),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              child: const Text("I've sent the payment"),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaybillRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback onCopy;

  const _PaybillRow({
    required this.label,
    required this.value,
    required this.onCopy,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? kDarkBorder : kBorder, width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? (dark ? kDarkTextPrimary : kTextPrimary),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.copy_rounded, size: 18, color: kPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
