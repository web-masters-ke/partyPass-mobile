import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';

class WaitingRoomScreen extends ConsumerStatefulWidget {
  final String eventId;
  const WaitingRoomScreen({super.key, required this.eventId});

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  Timer? _pollTimer;
  bool _entered = false;
  bool _admitted = false;
  bool _entering = false;
  int? _position;
  int? _queueSize;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final data = await DioClient.instance
          .get<Map<String, dynamic>>('/waiting-room/${widget.eventId}/status');
      if (!mounted) return;
      setState(() {
        _entered = data['entered'] == true || data['position'] != null;
        _admitted = data['admitted'] == true;
        _position = data['position'] as int?;
        _queueSize = data['queueSize'] as int?;
      });
      if (_entered && !_admitted) {
        _startPolling();
      }
    } catch (_) {
      // Not yet in queue — that's fine
    }
  }

  Future<void> _enterQueue() async {
    setState(() => _entering = true);
    try {
      final data = await DioClient.instance
          .post<Map<String, dynamic>>('/waiting-room/${widget.eventId}/enter');
      if (!mounted) return;
      setState(() {
        _entered = true;
        _position = data['position'] as int?;
        _entering = false;
      });
      _startPolling();
    } catch (e) {
      if (mounted) {
        setState(() => _entering = false);
        AppSnackbar.showError(context, e.toString());
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        final data = await DioClient.instance
            .get<Map<String, dynamic>>('/waiting-room/${widget.eventId}/status');
        if (!mounted) return;
        final admitted = data['admitted'] == true;
        setState(() {
          _position = data['position'] as int?;
          _queueSize = data['queueSize'] as int?;
          _admitted = admitted;
        });
        if (admitted) {
          _pollTimer?.cancel();
          if (mounted) _onAdmitted();
        }
      } catch (_) {}
    });
  }

  void _onAdmitted() {
    AppSnackbar.showSuccess(context, 'You\'re in! Redirecting to buy tickets...');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.push('/event/${widget.eventId}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Waiting Room'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Builder(builder: (context) {
            final dark =
                Theme.of(context).brightness == Brightness.dark;
            return _admitted
                ? _buildAdmitted(dark)
                : _entered
                    ? _buildInQueue(dark)
                    : _buildJoinQueue(dark);
          }),
        ),
      ),
    );
  }

  Widget _buildJoinQueue(bool dark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.people_alt_rounded, size: 52, color: kPrimary),
        ),
        const SizedBox(height: 28),
        Text(
          'This Event is Very Popular!',
          style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: dark ? kDarkTextPrimary : kTextPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Due to high demand, tickets are being released in batches. Join the virtual queue to get your spot.',
          style: GoogleFonts.inter(
              fontSize: 14,
              color: dark ? kDarkTextMuted : kTextMuted,
              height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (_queueSize != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: dark ? kDarkSurface : kSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_queueSize people in queue',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: dark ? kDarkTextMuted : kTextMuted),
            ),
          ),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _entering ? null : _enterQueue,
            icon: _entering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.queue_rounded),
            label: Text(
              _entering ? 'Joining Queue...' : 'Join the Queue',
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
        const SizedBox(height: 16),
        Text(
          'Keep this screen open. You\'ll be notified when it\'s your turn.',
          style: GoogleFonts.inter(
              fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInQueue(bool dark) {
    final progress = _position != null && _queueSize != null && _queueSize! > 0
        ? ((_queueSize! - _position!) / _queueSize!).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated spinner
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 6,
                backgroundColor: kBorder,
                color: kPrimary,
              ),
            ),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  size: 44, color: kPrimary),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          "You're in the Queue!",
          style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: dark ? kDarkTextPrimary : kTextPrimary),
        ),
        const SizedBox(height: 16),
        if (_position != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: dark ? kDarkSurface : kSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('Your Position',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: dark ? kDarkTextMuted : kTextMuted)),
                const SizedBox(height: 4),
                Text(
                  '#$_position',
                  style: GoogleFonts.inter(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: kPrimary,
                  ),
                ),
                if (_queueSize != null)
                  Text(
                    'of $_queueSize people',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: kTextMuted),
            ),
            const SizedBox(width: 8),
            Text(
              'Checking every 5 seconds...',
              style: GoogleFonts.inter(
                  fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFFED7AA), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: Color(0xFFEA580C)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Keep this screen open. Closing the app may cause you to lose your position.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF9A3412)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdmitted(bool dark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              size: 64, color: Color(0xFF16A34A)),
        ),
        const SizedBox(height: 28),
        Text(
          "You're Admitted!",
          style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: dark ? kDarkTextPrimary : kTextPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          'Redirecting you to the event page to complete your purchase...',
          style: GoogleFonts.inter(
              fontSize: 14,
              color: dark ? kDarkTextMuted : kTextMuted,
              height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const CircularProgressIndicator(color: kPrimary),
      ],
    );
  }
}
