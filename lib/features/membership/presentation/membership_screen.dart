import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _membershipMeProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return {'plan': 'FREE', 'status': null};
  return DioClient.instance.get<Map<String, dynamic>>('/membership/me');
});

// ---------------------------------------------------------------------------
// Plan data
// ---------------------------------------------------------------------------

const _kPlans = [
  {
    'key': 'FREE',
    'name': 'Free',
    'monthlyPrice': 0,
    'annualPrice': 0,
    'features': [
      'Access to public events',
      'Basic ticket wallet',
      'Earn loyalty points',
      'Standard support',
    ],
    'color': 0xFF94A3B8,
  },
  {
    'key': 'PREMIUM',
    'name': 'Premium',
    'monthlyPrice': 500,
    'annualPrice': 4800,
    'features': [
      'Everything in Free',
      'Early access to presale tickets',
      'Priority customer support',
      '10% discount on all tickets',
      'Exclusive Premium events',
      'No booking fees',
    ],
    'color': 0xFFD93B2F,
  },
  {
    'key': 'VIP',
    'name': 'VIP',
    'monthlyPrice': 1500,
    'annualPrice': 14400,
    'features': [
      'Everything in Premium',
      'VIP entry at all events',
      'Free drink at select venues',
      'Dedicated VIP concierge',
      'Backstage access (select events)',
      '25% discount on all tickets',
      'Guest list priority',
    ],
    'color': 0xFFD93B2F,
  },
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> {
  bool _isAnnual = false;

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(_membershipMeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Membership',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: meAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kPrimary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_rounded, size: 48, color: kDanger),
                const SizedBox(height: 12),
                Text(e.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? kDarkTextMuted
                            : kTextMuted,
                        fontSize: 14)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(_membershipMeProvider),
                  style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50))),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (me) {
          final currentPlan = me['plan']?.toString() ?? 'FREE';
          final billingCycle = me['billingCycle']?.toString() ?? 'MONTHLY';
          final loyaltyTier = me['loyaltyTier']?.toString() ?? 'BRONZE';
          final isPaid = currentPlan != 'FREE';

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            children: [
              // ── Hero card ───────────────────────────────────────────
              _HeroCard(
                  plan: currentPlan,
                  billingCycle: billingCycle,
                  loyaltyTier: loyaltyTier),
              const SizedBox(height: 24),

              // ── Billing toggle ──────────────────────────────────────
              _BillingToggle(
                isAnnual: _isAnnual,
                onToggle: (v) => setState(() => _isAnnual = v),
              ),
              const SizedBox(height: 16),

              // ── Plan cards ──────────────────────────────────────────
              ..._kPlans.map((plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlanCard(
                      plan: plan,
                      isAnnual: _isAnnual,
                      currentPlan: currentPlan,
                      onUpgrade: () => _showUpgradeSheet(
                        plan['key'] as String,
                        plan['name'] as String,
                        _isAnnual
                            ? plan['annualPrice'] as int
                            : plan['monthlyPrice'] as int,
                      ),
                    ),
                  )),

              // ── Cancel link ─────────────────────────────────────────
              if (isPaid) ...[
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: _confirmCancel,
                    child: Text('Cancel subscription',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: kDanger,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showUpgradeSheet(String plan, String planName, int price) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpgradeSheet(
        plan: plan,
        planName: planName,
        price: price,
        isAnnual: _isAnnual,
        onSuccess: () => ref.invalidate(_membershipMeProvider),
      ),
    );
  }

  void _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Subscription',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Your benefits will end at the next billing cycle. Are you sure?',
          style: GoogleFonts.inter(fontSize: 14, color: kTextMuted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Plan')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: kDanger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await DioClient.instance.post<dynamic>('/membership/cancel');
        ref.invalidate(_membershipMeProvider);
        if (mounted) {
          AppSnackbar.showSuccess(context,
              'Cancelled. Benefits continue until end of billing period.');
        }
      } catch (e) {
        if (mounted) AppSnackbar.showError(context, e.toString());
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Hero card — clean gradient, no blobs
// ---------------------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  final String plan;
  final String billingCycle;
  final String loyaltyTier;

  const _HeroCard({
    required this.plan,
    required this.billingCycle,
    required this.loyaltyTier,
  });

  List<Color> get _gradient {
    switch (plan) {
      case 'VIP':
        return [const Color(0xFFD93B2F), const Color(0xFF7F1D1D)];
      case 'PREMIUM':
        return [const Color(0xFFD93B2F), const Color(0xFF7F1D1D)];
      default:
        return [const Color(0xFF1E293B), const Color(0xFF0F172A)];
    }
  }

  IconData get _icon {
    switch (plan) {
      case 'VIP':
        return Icons.diamond_rounded;
      case 'PREMIUM':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.confirmation_number_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpgrade = plan == 'FREE';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan == 'FREE' ? 'PartyPass Free' : 'PartyPass $plan',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isUpgrade
                      ? 'Upgrade to unlock exclusive perks'
                      : '${billingCycle == 'ANNUAL' ? 'Annual' : 'Monthly'} · $loyaltyTier tier',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Text(
              plan == 'FREE' ? 'FREE' : 'ACTIVE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Billing toggle — same style as home quick tiles
// ---------------------------------------------------------------------------

class _BillingToggle extends StatelessWidget {
  final bool isAnnual;
  final ValueChanged<bool> onToggle;

  const _BillingToggle({required this.isAnnual, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? kDarkBorder : kBorder),
      ),
      child: Row(
        children: [
          _Tab(label: 'Monthly', isSelected: !isAnnual,
              onTap: () => onToggle(false)),
          _Tab(label: 'Annual', subLabel: 'Save 20%', isSelected: isAnnual,
              onTap: () => onToggle(true)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String? subLabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    this.subLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (dark ? kDarkTextMuted : kTextMuted),
                  )),
              if (subLabel != null)
                Text(subLabel!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white70 : kSuccess,
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan card — identical structure for every tier, home-screen card style
// ---------------------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isAnnual;
  final String currentPlan;
  final VoidCallback onUpgrade;

  const _PlanCard({
    required this.plan,
    required this.isAnnual,
    required this.currentPlan,
    required this.onUpgrade,
  });

  bool get _isCurrent =>
      (plan['key'] as String).toUpperCase() == currentPlan.toUpperCase();
  bool get _isFree => (plan['key'] as String).toUpperCase() == 'FREE';
  Color get _accent => Color(plan['color'] as int);
  int get _price =>
      isAnnual ? plan['annualPrice'] as int : plan['monthlyPrice'] as int;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = dark ? kDarkSurface : Colors.white;
    final borderCol = _isCurrent ? _accent : (dark ? kDarkBorder : kBorder);
    final txtPrimary = dark ? kDarkTextPrimary : kTextPrimary;
    final features = (plan['features'] as List).cast<String>();
    final planName = plan['name'] as String;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: _isCurrent ? 1.5 : 0.8),
        boxShadow: const [
          BoxShadow(color: kCardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name + price row ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent stripe
                Container(
                  width: 3,
                  height: 42,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(planName,
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: txtPrimary)),
                      const SizedBox(height: 2),
                      _isFree
                          ? Text('Free forever',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _accent))
                          : Text(
                              'KES $_price / ${isAnnual ? 'year' : 'month'}',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _accent)),
                    ],
                  ),
                ),
                if (_isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _accent.withValues(alpha: 0.3)),
                    ),
                    child: Text('Active',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _accent)),
                  ),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────
          Divider(
              height: 1,
              color: dark ? kDarkBorder : kBorder),

          // ── Features ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: features
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: _accent, size: 15),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(f,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: txtPrimary)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),

          // ── Divider ──────────────────────────────────────────────
          Divider(height: 1, color: dark ? kDarkBorder : kBorder),

          // ── Action button ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: _isCurrent
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: _accent.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                        foregroundColor: _accent,
                        disabledForegroundColor: _accent,
                      ),
                      child: Text('✓  Current Plan',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    )
                  : _isFree
                      ? const SizedBox.shrink()
                      : FilledButton(
                          onPressed: onUpgrade,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(50)),
                          ),
                          child: Text('Upgrade to $planName',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upgrade sheet
// ---------------------------------------------------------------------------

class _UpgradeSheet extends ConsumerStatefulWidget {
  final String plan;
  final String planName;
  final int price;
  final bool isAnnual;
  final VoidCallback onSuccess;

  const _UpgradeSheet({
    required this.plan,
    required this.planName,
    required this.price,
    required this.isAnnual,
    required this.onSuccess,
  });

  @override
  ConsumerState<_UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends ConsumerState<_UpgradeSheet> {
  final _phoneCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      AppSnackbar.showError(context, 'Enter your M-Pesa phone number');
      return;
    }
    setState(() => _submitting = true);
    try {
      await DioClient.instance.post<dynamic>(
        '/membership/subscribe',
        data: {
          'plan': widget.plan,
          'billingCycle': widget.isAnnual ? 'ANNUAL' : 'MONTHLY',
          'phone': phone,
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
    final fieldBg = dark ? kDarkBackground : kSurface;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
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
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: borderCol,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          if (_submitted) ...[
            const Icon(Icons.check_circle_rounded,
                color: kSuccess, size: 56),
            const SizedBox(height: 14),
            Text('Payment Initiated!',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: txtPrimary)),
            const SizedBox(height: 8),
            Text(
              'Check your M-Pesa for the STK prompt.\n${widget.planName} membership activates once confirmed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: txtMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                onPressed: () => context.pop(),
                style: FilledButton.styleFrom(
                    backgroundColor: kSuccess,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50))),
                child: Text('Done',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ] else ...[
            Text('Upgrade to ${widget.planName}',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: txtPrimary)),
            const SizedBox(height: 4),
            Text(
              'KES ${widget.price} / ${widget.isAnnual ? 'year' : 'month'}',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kPrimary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.inter(color: txtPrimary),
              decoration: InputDecoration(
                hintText: '07XXXXXXXX',
                labelText: 'M-Pesa Phone Number',
                labelStyle: GoogleFonts.inter(color: txtMuted),
                prefixIcon:
                    Icon(Icons.phone_android_rounded, color: txtMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: kPrimary, width: 2),
                ),
                filled: true,
                fillColor: fieldBg,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.phone_android_rounded),
                label: Text(
                    _submitting ? 'Processing…' : 'Pay with M-Pesa',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      color: txtMuted, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}
