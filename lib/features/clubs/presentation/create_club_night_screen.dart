import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/red_button.dart';

const _kDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

class CreateClubNightScreen extends ConsumerStatefulWidget {
  final String venueId;
  const CreateClubNightScreen({super.key, required this.venueId});

  @override
  ConsumerState<CreateClubNightScreen> createState() => _CreateClubNightScreenState();
}

class _CreateClubNightScreenState extends ConsumerState<CreateClubNightScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _endTimeCtrl = TextEditingController();

  int _dayOfWeek = 5; // Friday by default
  bool _isActive = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (t != null) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      ctrl.text = '$h:$m';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      await DioClient.instance.post<dynamic>('/clubs/${widget.venueId}/nights', data: {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'dayOfWeek': _dayOfWeek,
        'startTime': _startTimeCtrl.text.isEmpty ? '22:00' : _startTimeCtrl.text,
        'endTime': _endTimeCtrl.text.isEmpty ? null : _endTimeCtrl.text,
        'isActive': _isActive,
      });
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Club night added');
        context.pop(true);
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e is AppException ? e.message : 'Something went wrong');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => context.pop()),
        title: Text('Add Club Night', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // Name
            _label('Night Name *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: const InputDecoration(hintText: 'e.g. Friday Afrobeats Night'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Description
            _label('Description'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: const InputDecoration(hintText: 'What happens this night?'),
            ),
            const SizedBox(height: 16),

            // Day of week
            _label('Day of Week'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: List.generate(7, (i) => ChoiceChip(
                label: Text(_kDays[i].substring(0, 3)),
                selected: _dayOfWeek == i,
                selectedColor: kPrimary,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: _dayOfWeek == i ? Colors.white : (dark ? kDarkTextPrimary : kTextPrimary),
                ),
                onSelected: (_) => setState(() => _dayOfWeek = i),
              )),
            ),
            const SizedBox(height: 16),

            // Times
            Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Start Time'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _startTimeCtrl,
                      readOnly: true,
                      onTap: () => _pickTime(_startTimeCtrl),
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: '22:00',
                        suffixIcon: Icon(Icons.access_time_rounded, size: 18),
                      ),
                    ),
                  ],
                )),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('End Time'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _endTimeCtrl,
                      readOnly: true,
                      onTap: () => _pickTime(_endTimeCtrl),
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: '04:00',
                        suffixIcon: Icon(Icons.access_time_rounded, size: 18),
                      ),
                    ),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 16),

            // Active toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: dark ? kDarkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dark ? kDarkBorder : kBorder),
              ),
              child: Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('Show this night on the public schedule',
                          style: GoogleFonts.inter(fontSize: 12, color: dark ? kDarkTextMuted : kTextMuted)),
                    ],
                  )),
                  Switch(
                    value: _isActive,
                    activeThumbColor: kPrimary,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            RedButton(label: 'Add Club Night', onTap: _submit, isLoading: _submitting),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
  );
}
