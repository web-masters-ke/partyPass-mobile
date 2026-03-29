// Gate/bar staff screen: scan a wristband QR → show owner + balance → charge.
// Accessed by staff on the gate app; route: /wristband-charge

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';

class WristbandChargeScreen extends ConsumerStatefulWidget {
  const WristbandChargeScreen({super.key});

  @override
  ConsumerState<WristbandChargeScreen> createState() =>
      _WristbandChargeScreenState();
}

class _WristbandChargeScreenState
    extends ConsumerState<WristbandChargeScreen> {
  // ── scanner state ──────────────────────────────────────────────────────────
  MobileScannerController? _controller;
  bool _hasPermission = false;
  bool _scanning = true;

  // ── resolved wristband ─────────────────────────────────────────────────────
  Map<String, dynamic>? _wristband;
  bool _resolving = false;

  // ── charge form ────────────────────────────────────────────────────────────
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _charging = false;
  Map<String, dynamic>? _chargeResult;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() => _hasPermission = status.isGranted);
      if (status.isGranted) {
        _controller = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          returnImage: false,
        );
      }
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _controller?.stop();
    setState(() {
      _scanning = false;
      _resolving = true;
    });

    try {
      final data = await DioClient.instance.get<Map<String, dynamic>>(
          '/wristbands/resolve?qr=${Uri.encodeComponent(code)}');
      if (mounted) {
        setState(() {
          _wristband = data;
          _resolving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Wristband not found');
        setState(() {
          _scanning = true;
          _resolving = false;
          _wristband = null;
        });
        _controller?.start();
      }
    }
  }

  Future<void> _charge() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      AppSnackbar.showError(context, 'Enter a valid amount');
      return;
    }
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      AppSnackbar.showError(context, 'Enter item/description');
      return;
    }

    final nfcId = _wristband?['nfcId']?.toString() ?? '';
    setState(() => _charging = true);

    try {
      final result = await DioClient.instance
          .post<Map<String, dynamic>>('/wristbands/charge', data: {
        'nfcId': nfcId,
        'amount': amount,
        'description': desc,
      });
      if (mounted) {
        setState(() {
          _chargeResult = result;
          _charging = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.toString());
        setState(() => _charging = false);
      }
    }
  }

  void _reset() {
    setState(() {
      _scanning = true;
      _wristband = null;
      _chargeResult = null;
      _amountCtrl.clear();
      _descCtrl.clear();
    });
    _controller?.start();
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
        title: const Text('Wristband POS'),
        actions: [
          if (!_scanning)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'Scan another',
              onPressed: _reset,
            ),
        ],
      ),
      body: _chargeResult != null
          ? _buildSuccess(dark)
          : _scanning
              ? _buildScanner(dark)
              : _wristband != null
                  ? _buildChargeForm(dark)
                  : const Center(
                      child: CircularProgressIndicator(color: kPrimary)),
    );
  }

  // ─── Scanner view ──────────────────────────────────────────────────────────

  Widget _buildScanner(bool dark) {
    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_rounded,
                  size: 56, color: dark ? kDarkTextMuted : kTextMuted),
              const SizedBox(height: 16),
              Text(
                'Camera permission required',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: dark ? kDarkTextPrimary : kTextPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'PartyPass needs camera access to scan wristband QR codes.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: dark ? kDarkTextMuted : kTextMuted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _requestPermission,
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text('Grant Permission',
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
      );
    }

    return Stack(
      children: [
        if (_controller != null)
          MobileScanner(controller: _controller!, onDetect: _onDetect),
        CustomPaint(
          painter: _WristbandViewfinderPainter(),
          child: const SizedBox.expand(),
        ),
        if (_resolving)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text('Resolving wristband…',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Scan wristband QR to charge',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Charge form ───────────────────────────────────────────────────────────

  Widget _buildChargeForm(bool dark) {
    final wb = _wristband!;
    final balance = (wb['balance'] as num?)?.toDouble() ?? 0;
    final user = wb['user'] as Map<String, dynamic>?;
    final nfcId = wb['nfcId']?.toString() ?? '';
    final isActive = wb['isActive'] as bool? ?? true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        const SizedBox(height: 8),

        // ── Wristband owner card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD93B2F), Color(0xFFB02B20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(user),
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName(user),
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      nfcId,
                      style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'BALANCE',
                    style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        letterSpacing: 0.8),
                  ),
                  Text(
                    'KES ${balance.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (!isActive)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kWarning.withValues(alpha: dark ? 0.08 : 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: kWarning.withValues(alpha: 0.4), width: 0.8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: kWarning),
                const SizedBox(width: 10),
                Text(
                  'This wristband is deactivated',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kWarning,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

        if (isActive) ...[
          const SizedBox(height: 4),
          Text(
            'Charge',
            style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: dark ? kDarkTextPrimary : kTextPrimary),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            children: [100, 200, 300, 500, 1000].map((a) {
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
          const SizedBox(height: 14),

          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: dark ? kDarkTextPrimary : kTextPrimary),
            decoration: InputDecoration(
              labelText: 'Amount (KES)',
              prefixText: 'KES ',
              labelStyle: GoogleFonts.inter(
                  color: dark ? kDarkTextMuted : kTextMuted),
              prefixStyle: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: dark ? kDarkTextPrimary : kTextPrimary),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _descCtrl,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: dark ? kDarkTextPrimary : kTextPrimary),
            decoration: InputDecoration(
              labelText: 'Item / Description',
              hintText: 'e.g. 2x Beer, VIP table',
              labelStyle: GoogleFonts.inter(
                  color: dark ? kDarkTextMuted : kTextMuted),
              hintStyle: GoogleFonts.inter(
                  color: dark ? kDarkTextMuted : kTextMuted),
              prefixIcon: Icon(Icons.receipt_long_rounded,
                  color: dark ? kDarkTextMuted : kTextMuted, size: 18),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _charging ? null : _charge,
              icon: _charging
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bolt_rounded, size: 20),
              label: Text(
                _charging ? 'Processing…' : 'Charge Wristband',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _reset,
              child: Text(
                'Scan Different Wristband',
                style: GoogleFonts.inter(
                    color: dark ? kDarkTextMuted : kTextMuted,
                    fontSize: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Success view ──────────────────────────────────────────────────────────

  Widget _buildSuccess(bool dark) {
    final newBalance =
        ((_chargeResult?['newBalance'] as num?)?.toDouble() ?? 0);
    final charged =
        ((_chargeResult?['charged'] as num?)?.toDouble() ?? 0);

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
                color: kSuccess.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 52, color: kSuccess),
            ),
            const SizedBox(height: 24),
            Text(
              'Charged!',
              style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: dark ? kDarkTextPrimary : kTextPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'KES ${charged.toStringAsFixed(0)} deducted',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  color: dark ? kDarkTextMuted : kTextMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Remaining balance: KES ${newBalance.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: dark ? kDarkTextMuted : kTextMuted,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: Text(
                  'Scan Next Wristband',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700),
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

  String _initials(Map<String, dynamic>? user) {
    if (user == null) return '?';
    final first = (user['firstName']?.toString() ?? '').isNotEmpty
        ? user['firstName'].toString()[0]
        : '';
    final last = (user['lastName']?.toString() ?? '').isNotEmpty
        ? user['lastName'].toString()[0]
        : '';
    return (first + last).toUpperCase().isNotEmpty
        ? (first + last).toUpperCase()
        : '?';
  }

  String _fullName(Map<String, dynamic>? user) {
    if (user == null) return 'Unknown';
    final first = user['firstName']?.toString() ?? '';
    final last = user['lastName']?.toString() ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Unknown' : name;
  }
}

// ─── Viewfinder painter ───────────────────────────────────────────────────────

class _WristbandViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    const boxSize = 260.0;
    final left = (size.width - boxSize) / 2;
    final top = (size.height - boxSize) / 2 - 30;
    final rect = Rect.fromLTWH(left, top, boxSize, boxSize);
    final rRect =
        RRect.fromRectAndRadius(rect, const Radius.circular(16));

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    final cp = Paint()
      ..color = kPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const cl = 24.0;
    const r = 16.0;
    canvas.drawLine(
        Offset(left + r, top), Offset(left + r + cl, top), cp);
    canvas.drawLine(
        Offset(left, top + r), Offset(left, top + r + cl), cp);
    canvas.drawLine(Offset(left + boxSize - r, top),
        Offset(left + boxSize - r - cl, top), cp);
    canvas.drawLine(Offset(left + boxSize, top + r),
        Offset(left + boxSize, top + r + cl), cp);
    canvas.drawLine(Offset(left + r, top + boxSize),
        Offset(left + r + cl, top + boxSize), cp);
    canvas.drawLine(Offset(left, top + boxSize - r),
        Offset(left, top + boxSize - r - cl), cp);
    canvas.drawLine(Offset(left + boxSize - r, top + boxSize),
        Offset(left + boxSize - r - cl, top + boxSize), cp);
    canvas.drawLine(Offset(left + boxSize, top + boxSize - r),
        Offset(left + boxSize, top + boxSize - r - cl), cp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
