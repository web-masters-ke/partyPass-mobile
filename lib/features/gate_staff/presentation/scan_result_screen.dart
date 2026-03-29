import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/gate_entry.dart';
import '../../../shared/widgets/tier_badge.dart';
import '../../../shared/widgets/app_snackbar.dart';

class ScanResultScreen extends StatefulWidget {
  final GateEntry entry;
  const ScanResultScreen({super.key, required this.entry});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  Timer? _autoAdvanceTimer;
  int _countdown = 4;

  @override
  void initState() {
    super.initState();
    if (widget.entry.isApproved) _startAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _goBack();
      }
    });
  }

  void _goBack() {
    if (mounted) context.pop();
  }

  Color get _bgColor {
    if (widget.entry.isDenied) return kDanger;
    if (widget.entry.isReEntry) return kWarning;
    return kSuccess;
  }

  String get _headline {
    if (widget.entry.isDenied) return '✗  DENIED';
    if (widget.entry.isReEntry) return '↩  RE-ENTRY #${widget.entry.entryNumber}';
    return '✓  APPROVED';
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final attendee = entry.attendee;
    final ticket = entry.ticket;
    final tier = ticket?.tier;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Result headline
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _headline,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (widget.entry.isApproved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_countdown}s',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Main white card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: kSurface,
                          backgroundImage: attendee?.avatarUrl != null
                              ? CachedNetworkImageProvider(
                                  attendee!.avatarUrl!)
                              : null,
                          child: attendee?.avatarUrl == null
                              ? Text(
                                  attendee != null
                                      ? attendee.firstName[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.inter(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: kTextPrimary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Name
                        Text(
                          attendee?.fullName ?? 'Unknown Attendee',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // Tier badge
                        TierBadge(tier: tier?.tierType ?? 'GA'),
                        const SizedBox(height: 16),

                        // Re-entry info
                        if (entry.isReEntry) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kWarning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _infoRow('First entered',
                                    ticket?.lastEntryAt != null
                                        ? AppDateUtils.formatTime(
                                            DateTime.parse(ticket!.lastEntryAt!))
                                        : '—'),
                                const SizedBox(height: 6),
                                _infoRow('Exited',
                                    ticket?.lastExitAt != null
                                        ? AppDateUtils.formatTime(
                                            DateTime.parse(ticket!.lastExitAt!))
                                        : '—'),
                                const SizedBox(height: 6),
                                _infoRow('Re-entering now',
                                    AppDateUtils.formatTime(DateTime.now())),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Deny reason
                        if (entry.isDenied) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kDanger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: kDanger.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              entry.resultDisplayText,
                              style: GoogleFonts.inter(
                                color: kDanger,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Ticket details
                        _infoRow('Entry #', '#${entry.entryNumber}'),
                        const SizedBox(height: 6),
                        _infoRow('Time',
                            AppDateUtils.formatTime(
                                entry.scannedAt.isNotEmpty
                                    ? DateTime.parse(entry.scannedAt)
                                    : DateTime.now())),
                        const SizedBox(height: 6),

                        // Add-ons
                        if (tier?.perks.isNotEmpty ?? false) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Add-ons to collect:',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: kTextMuted)),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: tier!.perks
                                .map((p) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: kSuccess.withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: kSuccess
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: Text(p,
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: kSuccess,
                                              fontWeight: FontWeight.w600)),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Re-entry allowed
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: (tier?.allowReEntry ?? false)
                                ? kSuccess.withValues(alpha: 0.1)
                                : kSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Re-entry: ${(tier?.allowReEntry ?? false) ? "Allowed" : "Not Allowed"}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (tier?.allowReEntry ?? false)
                                  ? kSuccess
                                  : kTextMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ID verified badge
                        if (attendee?.isVerified ?? false)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded,
                                    size: 14,
                                    color: Color(0xFF3B82F6)),
                                const SizedBox(width: 4),
                                Text(
                                  'ID Verified',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom action buttons
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, MediaQuery.of(context).padding.bottom + 12),
              child: entry.isDenied
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showOverridePinDialog(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              minimumSize: const Size(0, 50),
                            ),
                            child: const Text('Override (PIN)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _goBack,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: kTextPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              minimumSize: const Size(0, 50),
                            ),
                            child: const Text('Scan Next →'),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _goBack,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kTextPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: const Text('SCAN NEXT →',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 13, color: kTextMuted)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kTextPrimary)),
      ],
    );
  }

  void _showOverridePinDialog(BuildContext context) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manager Override'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter manager PIN to override this denial:'),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: 'PIN',
                counterText: '',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppSnackbar.showSuccess(
                  context, 'Override submitted');
            },
            style: FilledButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
