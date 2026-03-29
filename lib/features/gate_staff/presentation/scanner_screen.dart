import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/gate_entry.dart';
import '../../../shared/widgets/app_snackbar.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  final String? eventId;
  final String? gateId;

  const ScannerScreen({super.key, this.eventId, this.gateId});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  MobileScannerController? _controller;
  bool _hasPermission = false;
  bool _isProcessing = false;
  int _insideCount = 0;
  int _capacity = 500;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    if (widget.eventId != null) _fetchCapacity();
  }

  @override
  void dispose() {
    _controller?.dispose();
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

  Future<void> _fetchCapacity() async {
    try {
      final data = await DioClient.instance.get<Map<String, dynamic>>(
        '/gates/events/${widget.eventId}/dashboard',
      );
      if (mounted) {
        setState(() {
          _insideCount = int.tryParse(
                  data['insideCount']?.toString() ?? '0') ??
              0;
          _capacity = int.tryParse(
                  data['maxCapacity']?.toString() ?? '500') ??
              500;
        });
      }
    } catch (_) {}
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);
    _controller?.stop();

    try {
      final data = await DioClient.instance.post<Map<String, dynamic>>(
        '/gates/scan',
        data: {
          'qrCode': code,
          if (widget.eventId != null) 'eventId': widget.eventId,
          if (widget.gateId != null) 'gateId': widget.gateId,
        },
      );
      final entry = GateEntry.fromJson(data);
      if (mounted) {
        await context.push('/scan-result', extra: entry);
        // Restart scanner when user returns from result screen
        if (mounted) {
          _controller?.start();
          setState(() => _isProcessing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.toString());
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _controller?.start();
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_hasPermission
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Camera permission required',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _requestPermission,
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50)),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Grant Permission'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Full-screen scanner
                if (_controller != null)
                  MobileScanner(
                    controller: _controller!,
                    onDetect: _onDetect,
                  ),

                // Dark overlay with viewfinder cutout
                CustomPaint(
                  painter: _ViewfinderPainter(),
                  child: const SizedBox.expand(),
                ),

                // Top overlay
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Colors.white,
                                    size: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scan Ticket QR',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (widget.eventId != null)
                                    Text(
                                      'Event scanner active',
                                      style: GoogleFonts.inter(
                                          color: Colors.white60,
                                          fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            // Capacity badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: kSuccess,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_insideCount / $_capacity inside',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                        24,
                        20,
                        24,
                        MediaQuery.of(context).padding.bottom + 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_isProcessing)
                          const CircularProgressIndicator(
                              color: Colors.white)
                        else
                          Text(
                            'Point camera at QR code',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _controlBtn(
                              icon: Icons.flash_off_rounded,
                              label: 'Torch',
                              onTap: () => _controller?.toggleTorch(),
                            ),
                            const SizedBox(width: 24),
                            _controlBtn(
                              icon: Icons.cameraswitch_rounded,
                              label: 'Flip',
                              onTap: () =>
                                  _controller?.switchCamera(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final boxSize = size.width * 0.72;
    final left = (size.width - boxSize) / 2;
    final top = (size.height - boxSize) / 2 - 40;
    final rect = Rect.fromLTWH(left, top, boxSize, boxSize);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Corner brackets
    final cornerPaint = Paint()
      ..color = kPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const cornerLen = 24.0;
    const r = 16.0;

    // Top-left
    canvas.drawLine(
        Offset(left + r, top), Offset(left + r + cornerLen, top), cornerPaint);
    canvas.drawLine(
        Offset(left, top + r), Offset(left, top + r + cornerLen), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(left + boxSize - r, top),
        Offset(left + boxSize - r - cornerLen, top), cornerPaint);
    canvas.drawLine(Offset(left + boxSize, top + r),
        Offset(left + boxSize, top + r + cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(left + r, top + boxSize),
        Offset(left + r + cornerLen, top + boxSize), cornerPaint);
    canvas.drawLine(Offset(left, top + boxSize - r),
        Offset(left, top + boxSize - r - cornerLen), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(left + boxSize - r, top + boxSize),
        Offset(left + boxSize - r - cornerLen, top + boxSize), cornerPaint);
    canvas.drawLine(Offset(left + boxSize, top + boxSize - r),
        Offset(left + boxSize, top + boxSize - r - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
