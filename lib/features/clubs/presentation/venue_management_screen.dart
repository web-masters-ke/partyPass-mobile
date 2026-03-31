import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/red_button.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _venueDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  return DioClient.instance.get<Map<String, dynamic>>('/organizer/venues/$id');
});

final _venueNightsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final data = await DioClient.instance.get<dynamic>('/organizer/venues/$id/nights');
  if (data is List) return data.cast<Map<String, dynamic>>();
  return ((data as Map<String, dynamic>)['items'] as List? ?? []).cast<Map<String, dynamic>>();
});

final _venueBookingsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final data = await DioClient.instance.get<dynamic>('/organizer/venues/$id/bookings');
  if (data is List) return data.cast<Map<String, dynamic>>();
  return ((data as Map<String, dynamic>)['items'] as List? ?? []).cast<Map<String, dynamic>>();
});

final _venueMembersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final data = await DioClient.instance.get<dynamic>('/organizer/venues/$id/members');
  if (data is List) return data.cast<Map<String, dynamic>>();
  return ((data as Map<String, dynamic>)['items'] as List? ?? []).cast<Map<String, dynamic>>();
});

const _kDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const _kBookingColors = {
  'PENDING': Color(0xFFFEF3C7),
  'CONFIRMED': Color(0xFFDCFCE7),
  'CANCELLED': Color(0xFFFEE2E2),
  'NO_SHOW': Color(0xFFF3F4F6),
};
const _kBookingTextColors = {
  'PENDING': Color(0xFFD97706),
  'CONFIRMED': Color(0xFF16A34A),
  'CANCELLED': Color(0xFFDC2626),
  'NO_SHOW': Color(0xFF6B7280),
};
const _kMemberColors = {
  'ACTIVE': Color(0xFFDCFCE7),
  'EXPIRED': Color(0xFFF3F4F6),
  'CANCELLED': Color(0xFFFEE2E2),
};
const _kMemberTextColors = {
  'ACTIVE': Color(0xFF16A34A),
  'EXPIRED': Color(0xFF6B7280),
  'CANCELLED': Color(0xFFDC2626),
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class VenueManagementScreen extends ConsumerStatefulWidget {
  final String venueId;
  const VenueManagementScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueManagementScreen> createState() => _VenueManagementScreenState();
}

class _VenueManagementScreenState extends ConsumerState<VenueManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final venueAsync = ref.watch(_venueDetailProvider(widget.venueId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/organizer/clubs'),
        ),
        title: venueAsync.when(
          data: (v) => Text(v['name']?.toString() ?? 'Venue',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          loading: () => const Text('Loading…'),
          error: (_, __) => const Text('Venue'),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.nightlife_rounded),
            tooltip: 'Add Club Night',
            onPressed: () async {
              final added = await context.push<bool>('/organizer/clubs/${widget.venueId}/nights/new');
              if (added == true) ref.invalidate(_venueNightsProvider(widget.venueId));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: kPrimary,
          labelColor: kPrimary,
          unselectedLabelColor: dark ? kDarkTextMuted : kTextMuted,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Nights'),
            Tab(text: 'Bookings'),
            Tab(text: 'Members'),
            Tab(text: 'Edit'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Venue header stats
          venueAsync.when(
            data: (v) => _VenueHeader(venue: v, dark: dark),
            loading: () => const SizedBox(height: 70, child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _NightsTab(venueId: widget.venueId),
                _BookingsTab(venueId: widget.venueId),
                _MembersTab(venueId: widget.venueId),
                venueAsync.when(
                  data: (v) => _EditTab(venueId: widget.venueId, venue: v, onSaved: () {
                    ref.invalidate(_venueDetailProvider(widget.venueId));
                    _tab.animateTo(0);
                  }),
                  loading: () => const Center(child: CircularProgressIndicator(color: kPrimary)),
                  error: (_, __) => const Center(child: Text('Failed to load venue')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _VenueHeader extends StatelessWidget {
  final Map<String, dynamic> venue;
  final bool dark;
  const _VenueHeader({required this.venue, required this.dark});

  @override
  Widget build(BuildContext context) {
    final count = venue['_count'] as Map<String, dynamic>?;
    return Container(
      color: dark ? kDarkSurface : kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, size: 14, color: dark ? kDarkTextMuted : kTextMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${venue['address'] ?? ''}, ${venue['city'] ?? ''}',
              style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          if (venue['capacity'] != null) ...[
            const SizedBox(width: 12),
            Icon(Icons.people_rounded, size: 14, color: dark ? kDarkTextMuted : kTextMuted),
            const SizedBox(width: 4),
            Text('${venue['capacity']}',
                style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted)),
          ],
          if (count != null) ...[
            const SizedBox(width: 12),
            const Icon(Icons.nightlife_rounded, size: 14, color: kPrimary),
            const SizedBox(width: 3),
            Text('${count['clubNights'] ?? 0}',
                style: GoogleFonts.inter(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

// ─── Edit tab ─────────────────────────────────────────────────────────────────

class _EditTab extends ConsumerStatefulWidget {
  final String venueId;
  final Map<String, dynamic> venue;
  final VoidCallback onSaved;
  const _EditTab({required this.venueId, required this.venue, required this.onSaved});

  @override
  ConsumerState<_EditTab> createState() => _EditTabState();
}

class _EditTabState extends ConsumerState<_EditTab> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _amenitiesCtrl;

  final List<File> _newPhotos = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.venue;
    _nameCtrl = TextEditingController(text: v['name']?.toString() ?? '');
    _descCtrl = TextEditingController(text: v['description']?.toString() ?? '');
    _addressCtrl = TextEditingController(text: v['address']?.toString() ?? '');
    _cityCtrl = TextEditingController(text: v['city']?.toString() ?? '');
    _capacityCtrl = TextEditingController(text: v['capacity']?.toString() ?? '');
    final amenities = (v['amenities'] as List?)?.map((e) => e.toString()).join(', ') ?? '';
    _amenitiesCtrl = TextEditingController(text: amenities);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _capacityCtrl.dispose();
    _amenitiesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = 5 - _newPhotos.length;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85, limit: remaining);
    if (picked.isEmpty) return;
    setState(() {
      for (final xf in picked) {
        if (_newPhotos.length < 5) _newPhotos.add(File(xf.path));
      }
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      AppSnackbar.showError(context, 'Venue name is required');
      return;
    }
    setState(() => _saving = true);
    try {
      final amenities = _amenitiesCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await DioClient.instance.patch<dynamic>('/venues/${widget.venueId}', data: {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'capacity': _capacityCtrl.text.isEmpty ? null : int.tryParse(_capacityCtrl.text),
        'amenities': amenities,
      });

      if (_newPhotos.isNotEmpty) {
        await Future.wait(_newPhotos.map((file) async {
          final fd = FormData.fromMap({
            'photo': await MultipartFile.fromFile(file.path),
          });
          await DioClient.instance.post<dynamic>('/venues/${widget.venueId}/upload-photo', data: fd);
        }));
      }

      if (mounted) {
        AppSnackbar.showSuccess(context, 'Venue updated');
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is AppException ? e.message : 'Failed to save changes';
        AppSnackbar.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final existingPhotos = (widget.venue['photos'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Existing photos
        if (existingPhotos.isNotEmpty) ...[
          _EditSection(
            title: 'Current Photos',
            dark: dark,
            child: SizedBox(
              height: 88,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: existingPhotos.length,
                itemBuilder: (_, i) {
                  final url = existingPhotos[i]['url']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(url, width: 88, height: 88, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 88, height: 88,
                            color: dark ? kDarkBorder : kBorder,
                            child: const Icon(Icons.broken_image_rounded),
                          )),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Add new photos
        _EditSection(
          title: 'Add Photos',
          dark: dark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._newPhotos.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(entry.value, width: 88, height: 88, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _newPhotos.removeAt(entry.key)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(3),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                    if (_newPhotos.length < 5)
                      GestureDetector(
                        onTap: _pickPhotos,
                        child: Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(
                            border: Border.all(color: dark ? kDarkBorder : kBorder, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            color: dark ? kDarkSurface : kSurface,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, color: dark ? kDarkTextMuted : kTextMuted, size: 22),
                              const SizedBox(height: 4),
                              Text('Add photo', style: GoogleFonts.inter(fontSize: 10, color: dark ? kDarkTextMuted : kTextMuted)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('New photos will be added to existing ones.',
                  style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Venue info
        _EditSection(
          title: 'Venue Info',
          dark: dark,
          child: Column(
            children: [
              _EditField(label: 'Venue Name *', ctrl: _nameCtrl, hint: 'e.g. Altitude The Club'),
              const SizedBox(height: 14),
              _EditField(label: 'Description', ctrl: _descCtrl, hint: 'What makes your venue special?', maxLines: 3),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Location
        _EditSection(
          title: 'Location',
          dark: dark,
          child: Column(
            children: [
              _EditField(label: 'Address', ctrl: _addressCtrl, hint: 'Street address'),
              const SizedBox(height: 14),
              _EditField(label: 'City', ctrl: _cityCtrl, hint: 'e.g. Nairobi'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Details
        _EditSection(
          title: 'Details',
          dark: dark,
          child: Column(
            children: [
              _EditField(
                label: 'Capacity',
                ctrl: _capacityCtrl,
                hint: 'Max guests',
                inputType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 14),
              _EditField(label: 'Amenities', ctrl: _amenitiesCtrl, hint: 'Parking, VIP Lounge (comma separated)'),
            ],
          ),
        ),
        const SizedBox(height: 32),

        RedButton(label: 'Save Changes', onTap: _save, isLoading: _saving),
      ],
    );
  }
}

class _EditSection extends StatelessWidget {
  final String title;
  final bool dark;
  final Widget child;
  const _EditSection({required this.title, required this.dark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? kDarkBorder : kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13,
              color: dark ? kDarkTextMuted : kTextMuted)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final int maxLines;
  final TextInputType inputType;
  final List<TextInputFormatter> inputFormatters;

  const _EditField({
    required this.label,
    required this.ctrl,
    this.hint,
    this.maxLines = 1,
    this.inputType = TextInputType.text,
    this.inputFormatters = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: inputType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

// ─── Nights tab ───────────────────────────────────────────────────────────────

class _NightsTab extends ConsumerWidget {
  final String venueId;
  const _NightsTab({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ref.watch(_venueNightsProvider(venueId)).when(
      loading: () => const Center(child: CircularProgressIndicator(color: kPrimary)),
      error: (e, _) => _Retry(onRetry: () => ref.invalidate(_venueNightsProvider(venueId))),
      data: (nights) {
        if (nights.isEmpty) {
          return const _Empty(
            icon: Icons.nightlife_rounded,
            message: 'No club nights yet',
            sub: 'Tap + in the top bar to add your first night',
          );
        }
        return RefreshIndicator(
          color: kPrimary,
          onRefresh: () async => ref.invalidate(_venueNightsProvider(venueId)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: nights.length,
            itemBuilder: (_, i) => _NightCard(night: nights[i], dark: dark),
          ),
        );
      },
    );
  }
}

class _NightCard extends StatelessWidget {
  final Map<String, dynamic> night;
  final bool dark;
  const _NightCard({required this.night, required this.dark});

  @override
  Widget build(BuildContext context) {
    final day = int.tryParse(night['dayOfWeek']?.toString() ?? '0') ?? 0;
    final isActive = night['isActive'] as bool? ?? true;
    final cover = night['coverImageUrl']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? kDarkBorder : kBorder),
      ),
      child: Row(
        children: [
          if (cover != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(cover, width: 52, height: 52, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _NightIcon()),
            )
          else
            _NightIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(night['name']?.toString() ?? '',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14,
                        color: dark ? kDarkTextPrimary : kTextPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${_kDays[day]} · ${night['startTime'] ?? ''}${night['endTime'] != null ? ' – ${night['endTime']}' : ''}',
                  style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
                ),
                if (night['description'] != null) ...[
                  const SizedBox(height: 2),
                  Text(night['description'].toString(),
                      style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Off',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                  color: isActive ? const Color(0xFF16A34A) : const Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NightIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.nightlife_rounded, color: kPrimary, size: 26),
    );
  }
}

// ─── Bookings tab ─────────────────────────────────────────────────────────────

class _BookingsTab extends ConsumerWidget {
  final String venueId;
  const _BookingsTab({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ref.watch(_venueBookingsProvider(venueId)).when(
      loading: () => const Center(child: CircularProgressIndicator(color: kPrimary)),
      error: (_, __) => _Retry(onRetry: () => ref.invalidate(_venueBookingsProvider(venueId))),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const _Empty(icon: Icons.chair_rounded, message: 'No table bookings yet');
        }
        return RefreshIndicator(
          color: kPrimary,
          onRefresh: () async => ref.invalidate(_venueBookingsProvider(venueId)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: bookings.length,
            itemBuilder: (_, i) => _BookingCard(booking: bookings[i], dark: dark),
          ),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool dark;
  const _BookingCard({required this.booking, required this.dark});

  @override
  Widget build(BuildContext context) {
    final status = booking['status']?.toString() ?? 'PENDING';
    final bg = _kBookingColors[status] ?? const Color(0xFFF3F4F6);
    final fg = _kBookingTextColors[status] ?? const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? kDarkBorder : kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.chair_rounded, color: kPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${booking['tableName'] ?? 'Table'} (${booking['tableType'] ?? ''})',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13,
                      color: dark ? kDarkTextPrimary : kTextPrimary),
                ),
                Text(
                  'Party of ${booking['partySize']} · Min KES ${booking['minSpend']}',
                  style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
                ),
                if (booking['notes'] != null)
                  Text(booking['notes'].toString(),
                      style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
          ),
        ],
      ),
    );
  }
}

// ─── Members tab ──────────────────────────────────────────────────────────────

class _MembersTab extends ConsumerWidget {
  final String venueId;
  const _MembersTab({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ref.watch(_venueMembersProvider(venueId)).when(
      loading: () => const Center(child: CircularProgressIndicator(color: kPrimary)),
      error: (_, __) => _Retry(onRetry: () => ref.invalidate(_venueMembersProvider(venueId))),
      data: (members) {
        if (members.isEmpty) {
          return const _Empty(icon: Icons.people_rounded, message: 'No members yet');
        }
        return RefreshIndicator(
          color: kPrimary,
          onRefresh: () async => ref.invalidate(_venueMembersProvider(venueId)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: members.length,
            itemBuilder: (_, i) => _MemberCard(member: members[i], dark: dark),
          ),
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool dark;
  const _MemberCard({required this.member, required this.dark});

  @override
  Widget build(BuildContext context) {
    final user = member['user'] as Map<String, dynamic>?;
    final firstName = user?['firstName']?.toString() ?? '';
    final lastName = user?['lastName']?.toString() ?? '';
    final name = '$firstName $lastName'.trim();
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
    final status = member['status']?.toString() ?? 'ACTIVE';
    final plan = member['plan']?.toString() ?? '';
    final bg = _kMemberColors[status] ?? const Color(0xFFF3F4F6);
    final fg = _kMemberTextColors[status] ?? const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? kDarkBorder : kBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: kPrimary.withValues(alpha: 0.15),
            child: Text(initials.isEmpty ? '?' : initials,
                style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Unknown' : name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13,
                        color: dark ? kDarkTextPrimary : kTextPrimary)),
                if (user?['email'] != null)
                  Text(user!['email'].toString(),
                      style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
              ),
              const SizedBox(height: 3),
              Text(plan, style: GoogleFonts.inter(fontSize: 11, color: dark ? kDarkTextMuted : kTextMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? sub;
  const _Empty({required this.icon, required this.message, this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: kPrimary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub!, style: GoogleFonts.inter(fontSize: 13, color: kTextMuted), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  final VoidCallback onRetry;
  const _Retry({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 40, color: kDanger),
        const SizedBox(height: 12),
        const Text('Failed to load'),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
