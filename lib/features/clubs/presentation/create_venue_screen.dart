import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/red_button.dart';


class CreateVenueScreen extends ConsumerStatefulWidget {
  const CreateVenueScreen({super.key});

  @override
  ConsumerState<CreateVenueScreen> createState() => _CreateVenueScreenState();
}

class _CreateVenueScreenState extends ConsumerState<CreateVenueScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _amenitiesCtrl = TextEditingController(); // comma-separated

  bool _submitting = false;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final amenities = _amenitiesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      await DioClient.instance.post<dynamic>('/venues', data: {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'country': 'Kenya',
        'capacity': _capacityCtrl.text.isEmpty ? null : int.tryParse(_capacityCtrl.text),
        'amenities': amenities,
      });
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Venue registered successfully');
        context.pop(true); // return true = refresh list
      }
    } catch (e) {
      if (mounted) {
        final msg = e is AppException ? e.message : 'Something went wrong';
        AppSnackbar.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Register Venue', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            _Section(
              title: 'Venue Info',
              dark: dark,
              children: [
                _Field(
                  label: 'Venue Name *',
                  ctrl: _nameCtrl,
                  hint: 'e.g. Altitude The Club',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'Description',
                  ctrl: _descCtrl,
                  hint: 'What makes your venue special?',
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Section(
              title: 'Location',
              dark: dark,
              children: [
                _Field(
                  label: 'Address *',
                  ctrl: _addressCtrl,
                  hint: 'Street address',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'City *',
                  ctrl: _cityCtrl,
                  hint: 'e.g. Nairobi',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Section(
              title: 'Details',
              dark: dark,
              children: [
                _Field(
                  label: 'Capacity',
                  ctrl: _capacityCtrl,
                  hint: 'Max number of guests',
                  inputType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'Amenities',
                  ctrl: _amenitiesCtrl,
                  hint: 'Parking, VIP Lounge, Bar (comma separated)',
                ),
              ],
            ),
            const SizedBox(height: 32),
            RedButton(
              label: 'Register Venue',
              onTap: _submit,
              isLoading: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final bool dark;
  final List<Widget> children;

  const _Section({required this.title, required this.dark, required this.children});

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
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final int maxLines;
  final TextInputType inputType;
  final List<TextInputFormatter> inputFormatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.ctrl,
    this.hint,
    this.maxLines = 1,
    this.inputType = TextInputType.text,
    this.inputFormatters = const [],
    this.validator,
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
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
