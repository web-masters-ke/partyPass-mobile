import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/ticket_tier.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/red_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/tier_badge.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../home/domain/events_provider.dart';

// ─── Attendee model ───────────────────────────────────────────────────────────

class _Attendee {
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;

  _Attendee({String? initName, String? initEmail, String? initPhone})
      : name = TextEditingController(text: initName ?? ''),
        email = TextEditingController(text: initEmail ?? ''),
        phone = TextEditingController(text: initPhone ?? '');

  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
  }

  Map<String, String?> toJson() => {
        'name': name.text.trim().isEmpty ? null : name.text.trim(),
        'email': email.text.trim().isEmpty ? null : email.text.trim(),
        'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
      };
}

// ─── Checkout screen ─────────────────────────────────────────────────────────

class CheckoutScreen extends ConsumerStatefulWidget {
  final String eventId;
  final Map<String, int> selections; // tierId -> quantity

  const CheckoutScreen({
    super.key,
    required this.eventId,
    required this.selections,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  // Steps: 0 = Attendees, 1 = Payment
  int _step = 0;

  String _paymentMethod = 'MPESA_STK';
  bool _isLoading = false;
  final _promoCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '07');
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _cardNameCtrl = TextEditingController();

  // Loyalty points
  int _userLoyaltyPoints = 0;
  bool _useLoyalty = false;
  int _loyaltyPointsToRedeem = 0;

  List<_Attendee> _attendees = [];
  bool _attendeesInitialized = false;

  @override
  void initState() {
    super.initState();
    _fetchLoyaltyPoints();
  }

  Future<void> _fetchLoyaltyPoints() async {
    try {
      final data = await DioClient.instance
          .get<Map<String, dynamic>>('/loyalty/balance');
      if (mounted) {
        setState(() {
          _userLoyaltyPoints =
              int.tryParse(data['points']?.toString() ?? '0') ?? 0;
        });
      }
    } catch (_) {}
  }

  void _toggleLoyalty(bool value, double subtotal) {
    setState(() {
      _useLoyalty = value;
      if (value && _userLoyaltyPoints >= 100) {
        final maxByBalance = (_userLoyaltyPoints ~/ 100) * 100;
        final maxBySubtotal = (subtotal * 0.5 * 10).floor();
        final roundedMax = (maxBySubtotal ~/ 100) * 100;
        _loyaltyPointsToRedeem =
            maxByBalance < roundedMax ? maxByBalance : roundedMax;
      } else {
        _loyaltyPointsToRedeem = 0;
      }
    });
  }

  double _loyaltyDiscount(double subtotal) {
    if (!_useLoyalty || _loyaltyPointsToRedeem < 100) return 0;
    final raw = _loyaltyPointsToRedeem / 10.0;
    return raw > subtotal * 0.5 ? subtotal * 0.5 : raw;
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    _phoneCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _cardNameCtrl.dispose();
    for (final a in _attendees) {
      a.dispose();
    }
    super.dispose();
  }

  void _initAttendees(List<TicketTier> tiers) {
    if (_attendeesInitialized) return;
    _attendeesInitialized = true;

    final user = ref.read(currentUserProvider).valueOrNull;
    final totalTickets =
        widget.selections.values.fold(0, (a, b) => a + b);

    _attendees = List.generate(totalTickets, (i) {
      if (i == 0) {
        return _Attendee(
          initName: user != null
              ? '${user.firstName} ${user.lastName}'.trim()
              : null,
          initEmail: user?.email,
          initPhone: user?.phone,
        );
      }
      return _Attendee();
    });
  }

  int _totalTickets(List<TicketTier> tiers) =>
      widget.selections.values.fold(0, (a, b) => a + b);

  double _computeTotal(List<TicketTier> tiers) {
    double total = 0;
    for (final tier in tiers) {
      final qty = widget.selections[tier.id] ?? 0;
      total += tier.price * qty;
    }
    return total;
  }

  bool _validateAttendees() {
    for (int i = 0; i < _attendees.length; i++) {
      final name = _attendees[i].name.text.trim();
      if (name.isEmpty) {
        AppSnackbar.showError(
            context, 'Enter a name for Attendee ${i + 1}');
        return false;
      }
      final email = _attendees[i].email.text.trim();
      if (email.isNotEmpty &&
          !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
        AppSnackbar.showError(
            context, 'Invalid email for Attendee ${i + 1}');
        return false;
      }
    }
    return true;
  }

  Future<void> _placeOrder(List<TicketTier> tiers) async {
    if (_paymentMethod == 'MPESA_STK') {
      final phone = _phoneCtrl.text.trim();
      if (phone.length < 10) {
        AppSnackbar.showError(context, 'Enter a valid M-Pesa number');
        return;
      }
    }
    if (_paymentMethod == 'CARD') {
      if (_cardNumberCtrl.text.replaceAll(' ', '').length < 13) {
        AppSnackbar.showError(context, 'Enter a valid card number');
        return;
      }
      if (_expiryCtrl.text.length < 5) {
        AppSnackbar.showError(context, 'Enter card expiry (MM/YY)');
        return;
      }
      if (_cvvCtrl.text.length < 3) {
        AppSnackbar.showError(context, 'Enter CVV');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final items = widget.selections.entries
          .where((e) => e.value > 0)
          .map((e) => {'tierId': e.key, 'quantity': e.value})
          .toList();

      final attendeeData = _attendees
          .map((a) => a.toJson())
          .where((m) => m['name'] != null)
          .toList();

      final data = await DioClient.instance.post<Map<String, dynamic>>(
        '/orders',
        data: {
          'eventId': widget.eventId,
          'items': items,
          'paymentMethod': _paymentMethod,
          if (attendeeData.isNotEmpty) 'attendees': attendeeData,
          if (_promoCtrl.text.isNotEmpty)
            'promoCode': _promoCtrl.text.trim(),
          if (_useLoyalty && _loyaltyPointsToRedeem >= 100)
            'loyaltyPointsToRedeem': _loyaltyPointsToRedeem,
          if (_paymentMethod == 'MPESA_STK')
            'phoneNumber': _phoneCtrl.text.trim(),
          if (_paymentMethod == 'CARD')
            'card': {
              'number': _cardNumberCtrl.text.replaceAll(' ', ''),
              'expiry': _expiryCtrl.text.trim(),
              'cvv': _cvvCtrl.text.trim(),
              'name': _cardNameCtrl.text.trim(),
            },
        },
      );
      final order = Order.fromJson(data);
      if (mounted) context.push('/payment/${order.id}', extra: order);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final tiersAsync = ref.watch(ticketTiersProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(_step == 0 ? 'Attendee Details' : 'Checkout'),
      ),
      body: tiersAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (tiers) {
          _initAttendees(tiers);
          final selectedTiers = tiers
              .where((t) => (widget.selections[t.id] ?? 0) > 0)
              .toList();
          final subtotal = _computeTotal(tiers);
          final loyaltyDisc = _loyaltyDiscount(subtotal);
          final discountedSub = subtotal - loyaltyDisc;
          final fee = discountedSub * 0.05;
          final total = discountedSub + fee;
          final ticketCount = _totalTickets(tiers);

          if (_step == 0) {
            return _buildAttendeesStep(
                dark, selectedTiers, ticketCount, subtotal,
                subtotal * 0.05, subtotal * 1.05);
          }
          return _buildPaymentStep(
              dark, eventAsync, selectedTiers, subtotal,
              loyaltyDisc, fee, total);
        },
      ),
    );
  }

  // ─── Step 0: Attendee details ──────────────────────────────────────────────

  Widget _buildAttendeesStep(
    bool dark,
    List<TicketTier> selectedTiers,
    int ticketCount,
    double subtotal,
    double fee,
    double total,
  ) {
    int ticketIndex = 0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _StepIndicator(current: 0, dark: dark),
              const SizedBox(height: 20),

              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: kPrimary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: kPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Each ticket is assigned to an attendee. '
                        'Their name appears on the ticket QR.',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: dark ? kDarkTextPrimary : kTextPrimary,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Per-tier attendee cards
              for (final tier in selectedTiers) ...[
                for (int q = 0;
                    q < (widget.selections[tier.id] ?? 0);
                    q++) ...[
                  _AttendeeCard(
                    index: ticketIndex,
                    tierName: tier.name,
                    tierType: tier.tierType,
                    attendee: _attendees[ticketIndex],
                    dark: dark,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  () {
                    ticketIndex++;
                    return const SizedBox.shrink();
                  }(),
                ],
              ],

              const Divider(height: 28),
              _summaryRow(
                  dark,
                  '$ticketCount ticket${ticketCount > 1 ? 's' : ''}',
                  'KES ${subtotal.toStringAsFixed(0)}'),
              const SizedBox(height: 6),
              _summaryRow(dark, 'Platform fee (5%)',
                  'KES ${fee.toStringAsFixed(0)}'),
              const SizedBox(height: 8),
              _summaryRow(dark, 'Total', 'KES ${total.toStringAsFixed(0)}',
                  bold: true),
              const SizedBox(height: 8),
            ],
          ),
        ),
        _BottomBar(
          dark: dark,
          child: RedButton(
            label: 'Continue to Payment',
            onTap: () {
              if (_validateAttendees()) setState(() => _step = 1);
            },
            isLoading: false,
          ),
        ),
      ],
    );
  }

  // ─── Step 1: Payment ──────────────────────────────────────────────────────

  Widget _buildPaymentStep(
    bool dark,
    AsyncValue eventAsync,
    List<TicketTier> selectedTiers,
    double subtotal,
    double loyaltyDisc,
    double fee,
    double total,
  ) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _StepIndicator(current: 1, dark: dark),
              const SizedBox(height: 20),

              // Event title
              eventAsync.when(
                data: (event) => Text(
                  event.title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                  ),
                ),
                loading: () => const SizedBox(height: 24),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              // Order summary
              Text(
                'Order Summary',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: dark ? kDarkTextPrimary : kTextPrimary),
              ),
              const SizedBox(height: 12),
              ...selectedTiers.map((tier) {
                final qty = widget.selections[tier.id]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      TierBadge(tier: tier.tierType, small: true),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tier.name,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: dark
                                        ? kDarkTextPrimary
                                        : kTextPrimary)),
                            Text('x$qty',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: dark
                                        ? kDarkTextMuted
                                        : kTextMuted)),
                          ],
                        ),
                      ),
                      Text(
                        'KES ${(tier.price * qty).toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: dark ? kDarkTextPrimary : kTextPrimary),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),
              _summaryRow(
                  dark, 'Subtotal', 'KES ${subtotal.toStringAsFixed(0)}'),
              const SizedBox(height: 6),
              if (loyaltyDisc > 0) ...[
                _summaryRow(
                  dark,
                  'Loyalty discount',
                  '-KES ${loyaltyDisc.toStringAsFixed(0)}',
                  accent: true,
                ),
                const SizedBox(height: 6),
              ],
              _summaryRow(
                  dark, 'Platform fee (5%)', 'KES ${fee.toStringAsFixed(0)}'),
              const SizedBox(height: 8),
              _summaryRow(dark, 'Total', 'KES ${total.toStringAsFixed(0)}',
                  bold: true),
              const SizedBox(height: 24),

              // Attendees summary (read-only)
              Text(
                'Attendees',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: dark ? kDarkTextPrimary : kTextPrimary),
              ),
              const SizedBox(height: 10),
              ...List.generate(_attendees.length, (i) {
                final a = _attendees[i];
                final name = a.name.text.trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name.isEmpty ? 'No name set' : name,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: name.isEmpty
                                  ? (dark ? kDarkTextMuted : kTextMuted)
                                  : (dark ? kDarkTextPrimary : kTextPrimary)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _step = 0),
                        child: Text('Edit',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: kPrimary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),

              // Promo code
              Text(
                'Promo Code',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: dark ? kDarkTextPrimary : kTextPrimary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _promoCtrl,
                      style: GoogleFonts.inter(
                          color: dark ? kDarkTextPrimary : kTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter promo code',
                        hintStyle: GoogleFonts.inter(
                            color: dark ? kDarkTextMuted : kTextMuted),
                        prefixIcon: Icon(Icons.local_offer_rounded,
                            size: 16,
                            color: dark ? kDarkTextMuted : kTextMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(80, 52),
                      foregroundColor: kPrimary,
                      side: const BorderSide(color: kPrimary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Apply',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Loyalty points
              if (_userLoyaltyPoints >= 100) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kWarning.withValues(
                        alpha: dark ? 0.08 : 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: kWarning.withValues(alpha: 0.35),
                        width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 22, color: kWarning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use loyalty points',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: dark
                                      ? kDarkTextPrimary
                                      : kTextPrimary),
                            ),
                            Text(
                              '$_userLoyaltyPoints pts = KES ${(_userLoyaltyPoints ~/ 10).toStringAsFixed(0)} off  •  max 50% discount',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: dark
                                      ? kDarkTextMuted
                                      : kTextMuted),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useLoyalty,
                        activeThumbColor: kWarning,
                        onChanged: (v) => _toggleLoyalty(v, subtotal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Payment method
              Text(
                'Payment Method',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: dark ? kDarkTextPrimary : kTextPrimary),
              ),
              const SizedBox(height: 12),
              ..._paymentOptions.map((opt) => _PaymentOption(
                    label: opt['label'] as String,
                    subtitle: opt['subtitle'] as String,
                    icon: opt['icon'] as IconData,
                    value: opt['value'] as String,
                    selected: _paymentMethod,
                    dark: dark,
                    onSelect: (v) => setState(() => _paymentMethod = v),
                  )),
              const SizedBox(height: 4),
              if (_paymentMethod == 'MPESA_STK')
                _buildStkForm(dark)
              else if (_paymentMethod == 'MPESA_PAYBILL')
                _buildPaybillInfo(dark)
              else if (_paymentMethod == 'CARD')
                _buildCardForm(dark),
              const SizedBox(height: 8),
            ],
          ),
        ),
        _BottomBar(
          dark: dark,
          child: RedButton(
            label: 'Pay KES ${total.toStringAsFixed(0)}',
            onTap: () => _placeOrder(
                ref.read(ticketTiersProvider(widget.eventId)).valueOrNull ??
                    []),
            isLoading: _isLoading,
          ),
        ),
      ],
    );
  }

  Widget _buildStkForm(bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android_rounded,
                  size: 16, color: kPrimary),
              const SizedBox(width: 6),
              Text('M-Pesa Number',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dark ? kDarkTextPrimary : kTextPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: dark ? kDarkTextPrimary : kTextPrimary),
            decoration: InputDecoration(
              hintText: '07XX XXX XXX',
              hintStyle: GoogleFonts.inter(
                  color: dark ? kDarkTextMuted : kTextMuted, fontSize: 14),
              prefixText: '+254 ',
              prefixStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: dark ? kDarkTextPrimary : kTextPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'An STK push prompt will be sent to this number. Keep your phone unlocked.',
            style: GoogleFonts.inter(
                fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPaybillInfo(bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSuccess.withValues(alpha: dark ? 0.06 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: kSuccess.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 16, color: kSuccess),
              const SizedBox(width: 6),
              Text('Paybill Payment Instructions',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dark ? kDarkTextPrimary : kTextPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          _paybillRow(dark, 'Business No.', '400200'),
          const SizedBox(height: 6),
          _paybillRow(dark, 'Account No.', 'Your Order ID'),
          const SizedBox(height: 6),
          _paybillRow(dark, 'Amount', 'As shown above'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: dark ? kDarkSurface : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Go to M-Pesa → Lipa na M-Pesa → Pay Bill → Enter the details above. '
              'Your order ID will appear as the account reference after placing the order.',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: dark ? kDarkTextPrimary : kTextPrimary,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paybillRow(bool dark, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: dark ? kDarkTextMuted : kTextMuted)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: dark ? kDarkTextPrimary : kTextPrimary)),
      ],
    );
  }

  Widget _buildCardForm(bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card_rounded,
                  size: 16, color: kPrimary),
              const SizedBox(width: 6),
              Text('Card Details',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dark ? kDarkTextPrimary : kTextPrimary)),
              const Spacer(),
              Row(
                children: [
                  _cardBrandIcon('VISA'),
                  const SizedBox(width: 4),
                  _cardBrandIcon('MC'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cardNumberCtrl,
            keyboardType: TextInputType.number,
            maxLength: 19,
            style: GoogleFonts.inter(
                fontSize: 14,
                letterSpacing: 1.5,
                color: dark ? kDarkTextPrimary : kTextPrimary),
            decoration: InputDecoration(
              hintText: '0000 0000 0000 0000',
              hintStyle: GoogleFonts.inter(
                  color: dark ? kDarkTextMuted : kTextMuted, fontSize: 14),
              labelText: 'Card Number',
              counterText: '',
            ),
            onChanged: (v) {
              final digits = v.replaceAll(' ', '');
              final formatted = digits
                  .replaceAllMapped(
                      RegExp(r'.{1,4}'), (m) => '${m.group(0)} ')
                  .trim();
              if (formatted != v) {
                _cardNumberCtrl.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(
                      offset: formatted.length),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'MM/YY',
                    hintStyle: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted,
                        fontSize: 14),
                    labelText: 'Expiry',
                    counterText: '',
                  ),
                  onChanged: (v) {
                    if (v.length == 2 && !v.contains('/')) {
                      _expiryCtrl.text = '$v/';
                      _expiryCtrl.selection = TextSelection.collapsed(
                          offset: _expiryCtrl.text.length);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _cvvCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                  decoration: InputDecoration(
                    hintText: '•••',
                    hintStyle: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted,
                        fontSize: 14),
                    labelText: 'CVV',
                    counterText: '',
                    suffixIcon: Icon(Icons.lock_rounded,
                        size: 16,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _cardNameCtrl,
            textCapitalization: TextCapitalization.characters,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: dark ? kDarkTextPrimary : kTextPrimary),
            decoration: InputDecoration(
              hintText: 'JOHN KAMAU',
              hintStyle: GoogleFonts.inter(
                  color: dark ? kDarkTextMuted : kTextMuted, fontSize: 14),
              labelText: 'Cardholder Name',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kSuccess.withValues(alpha: dark ? 0.06 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: kSuccess.withValues(alpha: 0.3), width: 0.8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: kSuccess),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'M-Pesa Global (virtual Visa/Mastercard) is accepted. '
                    'Use your M-Pesa Global card number, expiry and CVV.',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: dark ? kDarkTextPrimary : kTextPrimary,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardBrandIcon(String brand) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        brand,
        style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: brand == 'VISA'
                ? const Color(0xFF1A1F71)
                : const Color(0xFFEB001B)),
      ),
    );
  }

  Widget _summaryRow(bool dark, String label, String value,
      {bool bold = false, bool accent = false}) {
    final valueColor = accent
        ? kSuccess
        : bold
            ? kPrimary
            : (dark ? kDarkTextPrimary : kTextPrimary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: accent
                  ? kSuccess
                  : bold
                      ? (dark ? kDarkTextPrimary : kTextPrimary)
                      : (dark ? kDarkTextMuted : kTextMuted),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            )),
        Text(value,
            style: GoogleFonts.inter(
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: valueColor,
            )),
      ],
    );
  }

  static const _paymentOptions = [
    {
      'label': 'M-Pesa STK Push',
      'subtitle': 'Pay via M-Pesa prompt',
      'icon': Icons.phone_android_rounded,
      'value': 'MPESA_STK',
    },
    {
      'label': 'M-Pesa Paybill',
      'subtitle': 'Pay via Paybill number',
      'icon': Icons.receipt_long_rounded,
      'value': 'MPESA_PAYBILL',
    },
    {
      'label': 'Card',
      'subtitle': 'Visa / Mastercard',
      'icon': Icons.credit_card_rounded,
      'value': 'CARD',
    },
  ];
}

// ─── Bottom bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool dark;
  final Widget child;
  const _BottomBar({required this.dark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: dark ? kDarkBackground : kBackground,
        border: Border(
            top: BorderSide(
                color: dark ? kDarkBorder : kBorder, width: 0.5)),
      ),
      child: child,
    );
  }
}

// ─── Step indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final bool dark;
  const _StepIndicator({required this.current, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(0, 'Attendees'),
        Expanded(
          child: Container(
            height: 2,
            color: current >= 1
                ? kPrimary
                : (dark ? kDarkBorder : kBorder),
          ),
        ),
        _dot(1, 'Payment'),
      ],
    );
  }

  Widget _dot(int step, String label) {
    final done = current > step;
    final active = current == step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done || active ? kPrimary : (dark ? kDarkSurface : kSurface),
            shape: BoxShape.circle,
            border: Border.all(
                color: done || active ? kPrimary : (dark ? kDarkBorder : kBorder),
                width: 1.5),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? Colors.white
                          : (dark ? kDarkTextMuted : kTextMuted),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: active ? kPrimary : (dark ? kDarkTextMuted : kTextMuted),
          ),
        ),
      ],
    );
  }
}

// ─── Attendee card ────────────────────────────────────────────────────────────

class _AttendeeCard extends StatelessWidget {
  final int index;
  final String tierName;
  final String tierType;
  final _Attendee attendee;
  final bool dark;
  final VoidCallback onChanged;

  const _AttendeeCard({
    required this.index,
    required this.tierName,
    required this.tierType,
    required this.attendee,
    required this.dark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: dark ? kDarkBackground : kBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(
                      color: dark ? kDarkBorder : kBorder, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        index == 0
                            ? 'Primary Attendee (You)'
                            : 'Attendee ${index + 1}',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: dark ? kDarkTextPrimary : kTextPrimary),
                      ),
                      Text(
                        tierName,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: dark ? kDarkTextMuted : kTextMuted),
                      ),
                    ],
                  ),
                ),
                TierBadge(tier: tierType, small: true),
              ],
            ),
          ),

          // Fields
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  controller: attendee.name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => onChanged(),
                  style: GoogleFonts.inter(
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. Jane Muthoni',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: dark ? kDarkTextMuted : kTextMuted),
                    prefixIcon: Icon(Icons.person_rounded,
                        size: 18,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: attendee.email,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => onChanged(),
                  style: GoogleFonts.inter(
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Email (optional)',
                    hintText: 'jane@example.com',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: dark ? kDarkTextMuted : kTextMuted),
                    prefixIcon: Icon(Icons.email_rounded,
                        size: 18,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: attendee.phone,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => onChanged(),
                  style: GoogleFonts.inter(
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Phone (optional)',
                    hintText: '07XX XXX XXX',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: dark ? kDarkTextMuted : kTextMuted),
                    prefixIcon: Icon(Icons.phone_android_rounded,
                        size: 18,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payment option ───────────────────────────────────────────────────────────

class _PaymentOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final String value;
  final String selected;
  final bool dark;
  final ValueChanged<String> onSelect;

  const _PaymentOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.selected,
    required this.dark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? kPrimary.withValues(alpha: 0.06)
              : (dark ? kDarkSurface : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? kPrimary
                : (dark ? kDarkBorder : kBorder),
            width: isSelected ? 1.5 : 0.8,
          ),
          boxShadow: [
            if (!isSelected)
              const BoxShadow(
                  color: kCardShadow,
                  blurRadius: 4,
                  offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: isSelected
                    ? kPrimary
                    : (dark ? kDarkTextMuted : kTextMuted)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: dark ? kDarkTextPrimary : kTextPrimary,
                      )),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: dark ? kDarkTextMuted : kTextMuted)),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? kPrimary
                      : (dark ? kDarkBorder : kBorder),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
