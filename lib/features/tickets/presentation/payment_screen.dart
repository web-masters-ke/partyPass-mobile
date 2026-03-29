import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/red_button.dart';
import '../../../shared/widgets/app_snackbar.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  final Order? order;

  const PaymentScreen({super.key, required this.orderId, this.order});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  Order? _order;
  bool _loading = true;
  bool _paying = false;
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPolls = 20;

  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    if (_order != null) {
      _loading = false;
    } else {
      _fetchOrder();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchOrder() async {
    try {
      final data = await DioClient.instance
          .get<Map<String, dynamic>>('/orders/${widget.orderId}');
      if (mounted) setState(() { _order = Order.fromJson(data); _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); AppSnackbar.showError(context, e.toString()); }
    }
  }

  Future<void> _initiateStkPush() async {
    if (_phoneCtrl.text.trim().isEmpty) {
      AppSnackbar.showError(context, 'Enter your M-Pesa phone number');
      return;
    }
    setState(() => _paying = true);
    try {
      await DioClient.instance.post<dynamic>(
        '/orders/${widget.orderId}/pay/mpesa-stk',
        data: {'phone': _phoneCtrl.text.trim()},
      );
      if (mounted) AppSnackbar.showSuccess(context, 'Check your phone for M-Pesa prompt');
      _startPolling();
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
      setState(() => _paying = false);
    }
  }

  void _startPolling() {
    _pollCount = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      _pollCount++;
      if (_pollCount > _maxPolls) {
        t.cancel();
        if (mounted) {
          setState(() => _paying = false);
          AppSnackbar.showError(context, 'Payment timeout. Try again.');
        }
        return;
      }
      try {
        final data = await DioClient.instance
            .get<Map<String, dynamic>>('/orders/${widget.orderId}');
        final order = Order.fromJson(data);
        if (order.isPaid) {
          t.cancel();
          if (mounted) context.go('/tickets');
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_rounded,
                            size: 56,
                            color: dark ? kDarkTextMuted : kTextMuted),
                        const SizedBox(height: 16),
                        Text(
                          'Order not found',
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
                            onPressed: () {
                              setState(() => _loading = true);
                              _fetchOrder();
                            },
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
                )
              : _buildBody(dark),
    );
  }

  Widget _buildBody(bool dark) {
    final order = _order!;

    if (order.isPaid) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    color: kSuccess, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'Payment Confirmed!',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: dark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your tickets are ready',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: dark ? kDarkTextMuted : kTextMuted),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => context.go('/tickets'),
                  icon: const Icon(Icons.confirmation_number_rounded,
                      size: 18),
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

    // M-Pesa Paybill instructions
    if (order.paymentMethod == 'MPESA_PAYBILL' &&
        order.mpesaAccountRef != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00A651).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF00A651).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.phone_android_rounded,
                        color: Color(0xFF00A651)),
                    const SizedBox(width: 8),
                    Text('M-Pesa Paybill',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: dark ? kDarkTextPrimary : kTextPrimary)),
                  ]),
                  const SizedBox(height: 16),
                  _paybillRow('Paybill Number',
                      order.paybill ?? '522522', dark),
                  _paybillRow(
                      'Account Number', order.mpesaAccountRef!, dark),
                  _paybillRow(
                      'Amount',
                      'KES ${order.total.toStringAsFixed(0)}',
                      dark),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Steps:',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: dark ? kDarkTextPrimary : kTextPrimary)),
            const SizedBox(height: 8),
            ...[
              'Go to M-Pesa on your phone',
              'Select Lipa na M-Pesa → Paybill',
              'Enter Business No: ${order.paybill ?? "522522"}',
              'Enter Account No: ${order.mpesaAccountRef}',
              'Enter Amount: KES ${order.total.toStringAsFixed(0)}',
              'Enter your M-Pesa PIN and confirm',
            ].asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                            color: kPrimary, shape: BoxShape.circle),
                        child: Center(
                          child: Text('${e.key + 1}',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.value,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: dark
                                    ? kDarkTextPrimary
                                    : kTextPrimary)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
            if (_paying)
              Center(
                child: Column(children: [
                  const CircularProgressIndicator(color: kPrimary),
                  const SizedBox(height: 12),
                  Text('Waiting for payment...',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: dark ? kDarkTextMuted : kTextMuted)),
                ]),
              )
            else
              RedButton(
                label: "I've paid — Check Status",
                onTap: () {
                  setState(() => _paying = true);
                  _startPolling();
                },
              ),
          ],
        ),
      );
    }

    // STK Push
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dark ? kDarkSurface : kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: dark ? kDarkBorder : kBorder, width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total to pay',
                    style: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted,
                        fontSize: 13)),
                Text('KES ${order.total.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('M-Pesa Phone Number',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: dark ? kDarkTextPrimary : kTextPrimary)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '07XXXXXXXX',
              prefixIcon: Icon(Icons.phone_android_rounded,
                  color: dark ? kDarkTextMuted : kTextMuted),
            ),
          ),
          const SizedBox(height: 28),
          if (_paying)
            Center(
              child: Column(children: [
                const CircularProgressIndicator(color: kPrimary),
                const SizedBox(height: 12),
                Text('Waiting for M-Pesa prompt...',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: dark ? kDarkTextMuted : kTextMuted)),
              ]),
            )
          else
            Column(
              children: [
                RedButton(label: 'Pay with M-Pesa', onTap: _initiateStkPush),
                const SizedBox(height: 12),
                _TestPayButton(
                  orderId: widget.orderId,
                  onSuccess: () {
                    if (mounted) context.go('/tickets');
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _paybillRow(String label, String value, bool dark) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: dark ? kDarkTextMuted : kTextMuted)),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: dark ? kDarkTextPrimary : kTextPrimary)),
          ],
        ),
      );
}

class _TestPayButton extends StatefulWidget {
  final String orderId;
  final VoidCallback onSuccess;

  const _TestPayButton({required this.orderId, required this.onSuccess});

  @override
  State<_TestPayButton> createState() => _TestPayButtonState();
}

class _TestPayButtonState extends State<_TestPayButton> {
  bool _loading = false;

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      await DioClient.instance
          .post<dynamic>('/orders/${widget.orderId}/pay/test');
      if (mounted) {
        AppSnackbar.showSuccess(
            context, 'Test payment confirmed! Tickets issued 🎉');
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _loading ? null : _pay,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: dark ? kDarkSurface : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: dark ? kDarkBorder : const Color(0xFFD1D5DB)),
        ),
        child: Center(
          child: _loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: dark ? kDarkTextMuted : Colors.grey),
                )
              : Text(
                  '🧪  Test Pay (Sandbox)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dark ? kDarkTextMuted : const Color(0xFF6B7280),
                  ),
                ),
        ),
      ),
    );
  }
}
