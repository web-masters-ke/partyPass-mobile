import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/gate_entry.dart';

class GateDashboardScreen extends StatefulWidget {
  final String eventId;
  const GateDashboardScreen({super.key, required this.eventId});

  @override
  State<GateDashboardScreen> createState() => _GateDashboardScreenState();
}

class _GateDashboardScreenState extends State<GateDashboardScreen> {
  Map<String, dynamic>? _dashboard;
  List<GateEntry> _recentScans = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetch());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final data = await DioClient.instance
          .get<Map<String, dynamic>>('/gates/events/${widget.eventId}/dashboard');
      final scansRaw = data['recentScans'] as List? ?? [];
      if (mounted) {
        setState(() {
          _dashboard = data;
          _recentScans = scansRaw
              .map((e) => GateEntry.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inside = int.tryParse(
            _dashboard?['insideCount']?.toString() ?? '0') ?? 0;
    final capacity = int.tryParse(
            _dashboard?['maxCapacity']?.toString() ?? '500') ?? 500;
    final pct = capacity > 0 ? inside / capacity : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Gate Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Capacity gauge
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: dark ? kDarkSurface : kSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Current Capacity',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: dark ? kDarkTextMuted : kTextMuted)),
                            Text(
                              '$inside / $capacity',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: pct > 0.9
                                    ? kDanger
                                    : pct > 0.7
                                        ? kWarning
                                        : kSuccess,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            minHeight: 12,
                            backgroundColor: dark ? kDarkBorder : kBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              pct > 0.9
                                  ? kDanger
                                  : pct > 0.7
                                      ? kWarning
                                      : kSuccess,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}% full',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: dark ? kDarkTextMuted : kTextMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats row
                  Row(
                    children: [
                      _StatCard(
                        label: 'Total Entries',
                        value: _dashboard?['totalEntries']?.toString() ?? '0',
                        color: kPrimary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Denied',
                        value: _dashboard?['deniedCount']?.toString() ?? '0',
                        color: kDanger,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Re-entries',
                        value: _dashboard?['reEntryCount']?.toString() ?? '0',
                        color: kWarning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent scans
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Scans',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: dark ? kDarkTextPrimary : kTextPrimary)),
                      Text('Last ${_recentScans.length}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: dark ? kDarkTextMuted : kTextMuted)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_recentScans.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('No scans yet',
                            style: GoogleFonts.inter(
                                color: dark ? kDarkTextMuted : kTextMuted)),
                      ),
                    )
                  else
                    ...(_recentScans.take(20).map((e) => _ScanRow(entry: e))),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: dark ? kDarkTextMuted : kTextMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ScanRow extends StatelessWidget {
  final GateEntry entry;
  const _ScanRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isApproved = entry.isApproved;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: entry.isDenied
                  ? kDanger
                  : entry.isReEntry
                      ? kWarning
                      : kSuccess,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.attendee?.fullName ?? 'Unknown',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                ),
                Text(
                  isApproved ? entry.action : entry.resultDisplayText,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: entry.isDenied
                          ? kDanger
                          : dark
                              ? kDarkTextMuted
                              : kTextMuted),
                ),
              ],
            ),
          ),
          Text(
            entry.scannedAt.isNotEmpty
                ? AppDateUtils.formatTime(
                    DateTime.parse(entry.scannedAt))
                : '—',
            style: GoogleFonts.inter(
                fontSize: 11,
                color: dark ? kDarkTextMuted : kTextMuted),
          ),
        ],
      ),
    );
  }
}
