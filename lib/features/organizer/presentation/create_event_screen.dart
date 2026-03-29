import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/red_button.dart';

const _kCategories = [
  'CLUB_NIGHT',
  'FESTIVAL',
  'CONCERT',
  'COMEDY',
  'SPORTS',
  'CORPORATE',
  'PRIVATE',
  'POP_UP',
  'BOAT_PARTY',
  'ROOFTOP',
];

const _kTierTypes = ['GA', 'VIP', 'EARLY_BIRD', 'TABLE'];

class _TierData {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();
  final maxPerPersonCtrl = TextEditingController();
  String type = 'GA';

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    quantityCtrl.dispose();
    maxPerPersonCtrl.dispose();
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() =>
      _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic info
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'CLUB_NIGHT';

  // Date & time
  DateTime? _startDate;
  DateTime? _endDate;

  // Venue
  final _venueCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // Capacity
  final _capacityCtrl = TextEditingController();

  // Tiers
  final List<_TierData> _tiers = [_TierData()];

  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _venueCtrl.dispose();
    _cityCtrl.dispose();
    _capacityCtrl.dispose();
    for (final t in _tiers) {
      t.dispose();
    }
    super.dispose();
  }

  // ── Date/time pickers ────────────────────────────────────────────────────

  Future<DateTime?> _pickDateTime(
      {DateTime? initial, DateTime? firstDate}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: firstDate ?? now,
      lastDate: now.add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : const TimeOfDay(hour: 20, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      AppSnackbar.showError(context, 'Please select a start date');
      return;
    }
    if (_endDate == null) {
      AppSnackbar.showError(context, 'Please select an end date');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      AppSnackbar.showError(context, 'End date must be after start date');
      return;
    }

    setState(() => _submitting = true);

    try {
      final tiersPayload = _tiers.map((t) {
        return {
          'name': t.nameCtrl.text.trim(),
          'type': t.type,
          'price': double.tryParse(t.priceCtrl.text.trim()) ?? 0,
          'quantity': int.tryParse(t.quantityCtrl.text.trim()) ?? 0,
          'maxCapacity': int.tryParse(t.maxPerPersonCtrl.text.trim()) ?? 10,
        };
      }).toList();

      final result = await DioClient.instance.post<Map<String, dynamic>>(
        '/events',
        data: {
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'category': _category,
          'startDateTime': _startDate!.toIso8601String(),
          'endDateTime': _endDate!.toIso8601String(),
          'venueName': _venueCtrl.text.trim(),
          'venueCity': _cityCtrl.text.trim(),
          'capacity': int.tryParse(_capacityCtrl.text.trim()) ?? 0,
          'ticketTiers': tiersPayload,
        },
      );

      if (mounted) {
        final newId = result['id']?.toString() ?? '';
        context.pushReplacement('/organizer/events/$newId');
        AppSnackbar.showSuccess(context, 'Event created!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.toString());
        setState(() => _submitting = false);
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Event'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            // ── Section 1: Basic Info ────────────────────────────────────
            _SectionHeader(label: 'Basic Info', dark: dark),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Event Title',
                hintText: 'e.g. Saturday Night Fever',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Tell guests what to expect…',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            _LabeledDropdown<String>(
              label: 'Category',
              value: _category,
              items: _kCategories,
              labelFor: (s) => s.replaceAll('_', ' '),
              onChanged: (v) => setState(() => _category = v!),
              dark: dark,
            ),

            // ── Section 2: Date & Time ───────────────────────────────────
            _SectionHeader(label: 'Date & Time', dark: dark),
            _DateTimeTile(
              label: 'Start',
              value: _startDate,
              onTap: () async {
                final dt = await _pickDateTime();
                if (dt != null) setState(() => _startDate = dt);
              },
              dark: dark,
            ),
            const SizedBox(height: 12),
            _DateTimeTile(
              label: 'End',
              value: _endDate,
              onTap: () async {
                final dt = await _pickDateTime(
                    firstDate: _startDate ?? DateTime.now());
                if (dt != null) setState(() => _endDate = dt);
              },
              dark: dark,
            ),

            // ── Section 3: Venue ─────────────────────────────────────────
            _SectionHeader(label: 'Venue', dark: dark),
            TextFormField(
              controller: _venueCtrl,
              decoration: InputDecoration(
                labelText: 'Venue Name / Address',
                hintText: 'e.g. B Club, Westlands',
                prefixIcon: Icon(Icons.location_on_rounded,
                    color: dark ? kDarkTextMuted : kTextMuted),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cityCtrl,
              decoration: InputDecoration(
                labelText: 'City',
                hintText: 'e.g. Nairobi',
                prefixIcon: Icon(Icons.location_city_rounded,
                    color: dark ? kDarkTextMuted : kTextMuted),
              ),
              textCapitalization: TextCapitalization.words,
            ),

            // ── Section 4: Capacity ──────────────────────────────────────
            _SectionHeader(label: 'Capacity', dark: dark),
            TextFormField(
              controller: _capacityCtrl,
              decoration: InputDecoration(
                labelText: 'Total Capacity',
                hintText: '500',
                prefixIcon: Icon(Icons.people_rounded,
                    color: dark ? kDarkTextMuted : kTextMuted),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),

            // ── Section 5: Ticket Tiers ──────────────────────────────────
            _SectionHeader(label: 'Ticket Tiers', dark: dark),
            ...List.generate(_tiers.length, (i) {
              return _TierEditor(
                index: i,
                data: _tiers[i],
                dark: dark,
                onRemove: _tiers.length > 1
                    ? () => setState(() {
                          _tiers[i].dispose();
                          _tiers.removeAt(i);
                        })
                    : null,
                onTypeChanged: (v) =>
                    setState(() => _tiers[i].type = v!),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _tiers.add(_TierData())),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Add Tier',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            // ── Submit ───────────────────────────────────────────────────
            const SizedBox(height: 24),
            RedButton(
              label: 'Create Event',
              isLoading: _submitting,
              onTap: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool dark;

  const _SectionHeader({required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: dark ? kDarkTextPrimary : kTextPrimary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Labeled dropdown
// ---------------------------------------------------------------------------

class _LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelFor;
  final ValueChanged<T?> onChanged;
  final bool dark;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final borderCol = dark ? kDarkBorder : kBorder;
    final fillCol = dark ? kDarkSurface : kBackground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: dark ? kDarkTextMuted : kTextMuted),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimary, width: 2),
            ),
            filled: true,
            fillColor: fillCol,
          ),
          dropdownColor: dark ? kDarkSurface : Colors.white,
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      labelFor(item),
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: dark ? kDarkTextPrimary : kTextPrimary),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Date/time tile
// ---------------------------------------------------------------------------

class _DateTimeTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool dark;

  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.onTap,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final display = value != null
        ? '${_weekday(value!.weekday)}, ${_month(value!.month)} ${value!.day} ${value!.year}  ${_time(value!)}'
        : 'Select date & time';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: dark ? kDarkSurface : kBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dark ? kDarkBorder : kBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 18,
                color: dark ? kDarkTextMuted : kTextMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                  Text(
                    display,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: value != null
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: value != null
                          ? (dark ? kDarkTextPrimary : kTextPrimary)
                          : (dark ? kDarkTextMuted : kTextMuted),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: dark ? kDarkTextMuted : kTextMuted, size: 18),
          ],
        ),
      ),
    );
  }

  String _weekday(int d) =>
      const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d];

  String _month(int m) => const [
        '',
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  String _time(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ---------------------------------------------------------------------------
// Tier editor row
// ---------------------------------------------------------------------------

class _TierEditor extends StatelessWidget {
  final int index;
  final _TierData data;
  final VoidCallback? onRemove;
  final ValueChanged<String?> onTypeChanged;
  final bool dark;

  const _TierEditor({
    required this.index,
    required this.data,
    required this.onRemove,
    required this.onTypeChanged,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final borderCol = dark ? kDarkBorder : kBorder;
    final fillCol = dark ? kDarkSurface : kBackground;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? kDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 0.8),
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
              Text(
                'Tier ${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: dark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: kDanger.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: kDanger),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: data.nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Tier Name',
              hintText: 'e.g. General Admission',
              isDense: true,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: data.type,
            decoration: InputDecoration(
              labelText: 'Type',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderCol)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderCol)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: kPrimary, width: 2)),
              filled: true,
              fillColor: fillCol,
            ),
            dropdownColor: dark ? kDarkSurface : Colors.white,
            items: _kTierTypes
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: dark
                                  ? kDarkTextPrimary
                                  : kTextPrimary)),
                    ))
                .toList(),
            onChanged: onTypeChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: data.priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Price (KES)',
                    hintText: '1000',
                    isDense: true,
                    prefixText: 'KES ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: data.quantityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: '100',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: data.maxPerPersonCtrl,
            decoration: const InputDecoration(
              labelText: 'Max per person',
              hintText: '4',
              isDense: true,
              helperText: 'Max tickets one buyer can purchase',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
    );
  }
}
