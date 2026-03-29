import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/ticket.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/tier_badge.dart';
import '../../../shared/widgets/app_snackbar.dart';

class TicketQRScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketQRScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketQRScreen> createState() => _TicketQRScreenState();
}

class _TicketQRScreenState extends ConsumerState<TicketQRScreen> {
  final _storage = const FlutterSecureStorage();
  final _ticketCardKey = GlobalKey();

  Ticket? _ticket;
  String? _qrData;
  bool _loading = true;
  bool _sharing = false;
  Timer? _refreshTimer;
  int _secondsUntilRefresh = 30;

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadTicket() async {
    final cacheKey = 'qr_${widget.ticketId}';
    final cachedQr = await _storage.read(key: cacheKey);
    try {
      final data = await DioClient.instance
          .get<Map<String, dynamic>>('/tickets/${widget.ticketId}');
      final ticket = Ticket.fromJson(data);

      final qrData = await DioClient.instance
          .get<Map<String, dynamic>>('/tickets/${widget.ticketId}/qr');
      final qrString = qrData['qrCode']?.toString() ??
          qrData['qr']?.toString() ??
          ticket.qrCode;

      await _storage.write(key: cacheKey, value: qrString);

      if (mounted) {
        setState(() {
          _ticket = ticket;
          _qrData = qrString;
          _loading = false;
        });
        _startRefreshTimer();
      }
    } catch (_) {
      if (cachedQr != null && mounted) {
        setState(() { _qrData = cachedQr; _loading = false; });
      } else if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.showError(context, 'Could not load ticket QR');
      }
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _secondsUntilRefresh = 30;
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsUntilRefresh--);
      if (_secondsUntilRefresh <= 0) { t.cancel(); _refreshQR(); }
    });
  }

  Future<void> _refreshQR() async {
    try {
      final qrData = await DioClient.instance
          .get<Map<String, dynamic>>('/tickets/${widget.ticketId}/qr');
      final qrString = qrData['qrCode']?.toString() ?? qrData['qr']?.toString() ?? '';
      if (qrString.isNotEmpty) {
        await _storage.write(key: 'qr_${widget.ticketId}', value: qrString);
        if (mounted) setState(() => _qrData = qrString);
      }
    } catch (_) {}
    if (mounted) _startRefreshTimer();
  }

  // ── Fullscreen QR ─────────────────────────────────────────────────────────

  void _showFullscreenQR() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => GestureDetector(
        onTap: () => context.pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: _qrData!,
                    version: QrVersions.auto,
                    size: MediaQuery.of(context).size.width - 96,
                    eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black),
                  ),
                ),
                Text('Tap anywhere to close',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.white60)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Share ticket as image ─────────────────────────────────────────────────

  Future<void> _shareTicket() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final boundary = _ticketCardKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        _shareAsText();
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _shareAsText();
        return;
      }

      final bytes = byteData.buffer.asUint8List();
      final tmpFile = File(
          '${Directory.systemTemp.path}/partypass_ticket_${widget.ticketId}.png');
      await tmpFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(tmpFile.path, mimeType: 'image/png')],
        text:
            'My PartyPass ticket${_ticket?.event != null ? ' for ${_ticket!.event!.title}' : ''}',
      );
    } catch (_) {
      _shareAsText();
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _shareAsText() {
    final t = _ticket;
    final lines = [
      'PartyPass Ticket',
      if (t?.event?.title != null) 'Event: ${t!.event!.title}',
      if (t?.event != null)
        'Date: ${AppDateUtils.formatDateTime(t!.event!.startDateTime)}',
      'Ticket ID: ${t?.shortId ?? widget.ticketId}',
      if (t?.tier?.name != null) 'Tier: ${t!.tier!.name}',
      if (t?.holderName != null) 'Name: ${t!.holderName}',
      'Status: ${t?.status ?? 'VALID'}',
    ];
    Share.share(lines.join('\n'), subject: 'My PartyPass Ticket');
  }

  // ── Info row helper ───────────────────────────────────────────────────────

  Widget _row(IconData icon, String label, String value,
      {bool mono = false, Color? valueColor, required bool dark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: dark ? kDarkTextMuted : kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: dark ? kDarkTextMuted : kTextMuted,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(value,
                    style: mono
                        ? GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: valueColor ??
                                (dark ? kDarkTextPrimary : kTextPrimary),
                            letterSpacing: 2)
                        : GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: valueColor ??
                                (dark ? kDarkTextPrimary : kTextPrimary))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status, {required bool dark}) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'VALID':
        bg = dark ? kSuccess.withValues(alpha: 0.15) : const Color(0xFFDCFCE7);
        fg = dark ? kSuccess : const Color(0xFF166534);
        label = '✓  Valid';
      case 'USED':
        bg = dark ? kDarkSurface : const Color(0xFFF3F4F6);
        fg = dark ? kDarkTextMuted : const Color(0xFF6B7280);
        label = 'Used';
      case 'TRANSFERRED':
        bg = dark
            ? const Color(0xFF1D4ED8).withValues(alpha: 0.15)
            : const Color(0xFFDBEAFE);
        fg = dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        label = 'Transferred';
      default:
        bg = dark ? kDanger.withValues(alpha: 0.15) : const Color(0xFFFEE2E2);
        fg = dark ? kDanger : const Color(0xFFDC2626);
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    final attendeeName = _ticket?.holderName?.isNotEmpty == true
        ? _ticket!.holderName!
        : user?.fullName ?? '—';
    final attendeeEmail = _ticket?.holderEmail?.isNotEmpty == true
        ? _ticket!.holderEmail!
        : user?.email ?? '—';
    final attendeePhone = _ticket?.holderPhone?.isNotEmpty == true
        ? _ticket!.holderPhone!
        : null;

    final wristbandBtnColor =
        dark ? const Color(0xFF93C5FD) : const Color(0xFF1565C0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Your Ticket',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kPrimary))
                : const Icon(Icons.share_rounded),
            onPressed: _qrData != null ? _shareTicket : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _qrData == null
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
                          'QR unavailable',
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
                              _loadTicket();
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    children: [
                      // ── Capturable ticket card ─────────────────────
                      RepaintBoundary(
                        key: _ticketCardKey,
                        child: Container(
                          color: dark ? kDarkBackground : kBackground,
                          child: Column(
                            children: [
                              // Event header
                              if (_ticket?.event != null) ...[
                                Text(
                                  _ticket!.event!.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: dark
                                        ? kDarkTextPrimary
                                        : kTextPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppDateUtils.formatDateTime(
                                      _ticket!.event!.startDateTime),
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: dark
                                          ? kDarkTextMuted
                                          : kTextMuted),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // QR card — always white for scan readability
                              GestureDetector(
                                onTap: _showFullscreenQR,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: dark ? kDarkBorder : kBorder,
                                        width: 0.8),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: kCardShadow,
                                          blurRadius: 12,
                                          offset: Offset(0, 3)),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      QrImageView(
                                        data: _qrData!,
                                        version: QrVersions.auto,
                                        size: 200,
                                        eyeStyle: const QrEyeStyle(
                                          eyeShape: QrEyeShape.square,
                                          color: Colors.black,
                                        ),
                                        dataModuleStyle:
                                            const QrDataModuleStyle(
                                          dataModuleShape:
                                              QrDataModuleShape.square,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                              Icons.fullscreen_rounded,
                                              size: 13,
                                              color: kTextMuted),
                                          const SizedBox(width: 4),
                                          Text('Tap to expand',
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: kTextMuted)),
                                          const SizedBox(width: 14),
                                          const Icon(Icons.refresh_rounded,
                                              size: 13,
                                              color: kTextMuted),
                                          const SizedBox(width: 4),
                                          Text(
                                              'Refreshes in ${_secondsUntilRefresh}s',
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: kTextMuted)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Ticket info card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: dark ? kDarkSurface : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  border: Border.all(
                                      color: dark ? kDarkBorder : kBorder,
                                      width: 0.8),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: kCardShadow,
                                        blurRadius: 8,
                                        offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Tier badge + status chip
                                    Row(
                                      children: [
                                        if (_ticket?.tier != null)
                                          TierBadge(
                                              tier: _ticket!.tier!
                                                  .tierType),
                                        const Spacer(),
                                        if (_ticket != null)
                                          _statusChip(_ticket!.status,
                                              dark: dark),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Divider(
                                        height: 1,
                                        color: dark ? kDarkBorder : kBorder),
                                    const SizedBox(height: 16),

                                    // Attendee info
                                    _row(
                                      Icons.person_rounded,
                                      'ATTENDEE',
                                      attendeeName,
                                      dark: dark,
                                    ),
                                    _row(
                                      Icons.email_rounded,
                                      'EMAIL',
                                      attendeeEmail,
                                      dark: dark,
                                    ),
                                    if (attendeePhone != null)
                                      _row(
                                        Icons.phone_rounded,
                                        'PHONE',
                                        attendeePhone,
                                        dark: dark,
                                      ),
                                    if (_ticket?.tier?.name != null)
                                      _row(
                                        Icons.local_activity_rounded,
                                        'TICKET TIER',
                                        _ticket!.tier!.name,
                                        valueColor: kPrimary,
                                        dark: dark,
                                      ),
                                    _row(
                                      Icons.confirmation_number_rounded,
                                      'TICKET ID',
                                      _ticket?.shortId ?? widget.ticketId,
                                      mono: true,
                                      dark: dark,
                                    ),
                                    if (_ticket?.event?.venueName != null ||
                                        _ticket?.event?.venueCity != null)
                                      _row(
                                        Icons.location_on_rounded,
                                        'VENUE',
                                        [
                                          _ticket?.event?.venueName,
                                          _ticket?.event?.venueCity
                                        ]
                                            .where((e) => e != null)
                                            .join(', '),
                                        dark: dark,
                                      ),
                                    if (_ticket?.entryCount != null &&
                                        _ticket!.entryCount > 0)
                                      _row(
                                        Icons.door_front_door_rounded,
                                        'ENTRY COUNT',
                                        '${_ticket!.entryCount}',
                                        dark: dark,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Share / save button ────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _sharing ? null : _shareTicket,
                          icon: _sharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.share_rounded, size: 18),
                          label: Text(
                            _sharing ? 'Preparing…' : 'Share Ticket',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: kPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50)),
                          ),
                        ),
                      ),

                      // ── Cashless Wristband ─────────────────────────
                      if (_ticket?.event != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final eventId = _ticket!.event!.id;
                              final title = Uri.encodeComponent(
                                  _ticket!.event!.title);
                              context.push(
                                  '/wristband/$eventId?title=$title');
                            },
                            icon: Icon(Icons.credit_card_rounded,
                                size: 18, color: wristbandBtnColor),
                            label: Text('Cashless Wristband',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: wristbandBtnColor,
                              side: BorderSide(color: wristbandBtnColor),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(50)),
                            ),
                          ),
                        ),
                      ],

                      // ── Write review (used tickets) ────────────────
                      if (_ticket?.status == 'USED' &&
                          _ticket?.event != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () {
                              final eventId = _ticket!.event!.id;
                              final title = Uri.encodeComponent(
                                  _ticket!.event!.title);
                              context.push(
                                  '/review/$eventId?title=$title');
                            },
                            icon: const Icon(Icons.star_rounded),
                            label: const Text('Write a Review'),
                            style: FilledButton.styleFrom(
                              backgroundColor: kWarning,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(50)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
