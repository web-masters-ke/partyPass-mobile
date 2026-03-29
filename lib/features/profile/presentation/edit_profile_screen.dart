import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/app_snackbar.dart';

const _genders = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  String? _email; // readonly
  String? _gender;
  DateTime? _dob;
  bool _isLoading = false;
  File? _avatarFile;
  String? _existingAvatarUrl;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final user = await ref.read(currentUserProvider.future);
    if (user != null && mounted) {
      _firstNameCtrl.text = user.firstName;
      _lastNameCtrl.text = user.lastName;
      _phoneCtrl.text = user.phone ?? '';
      _cityCtrl.text = user.city ?? '';
      final rawDob = user.dateOfBirth;
      setState(() {
        _email = user.email;
        _existingAvatarUrl = user.avatarUrl;
        _gender = (user.gender?.isNotEmpty == true &&
                _genders.contains(user.gender))
            ? user.gender
            : null;
        _dob = rawDob != null ? DateTime.tryParse(rawDob) : null;
      });
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 13),
      helpText: 'Select date of birth',
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_avatarFile != null) {
        await DioClient.instance.uploadFile<dynamic>(
          '/users/avatar',
          _avatarFile!.path,
          field: 'avatar',
        );
      }

      final body = <String, dynamic>{
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
      };
      final phone = _phoneCtrl.text.trim();
      if (phone.isNotEmpty) body['phone'] = phone;
      if (_gender != null) body['gender'] = _gender;
      if (_dob != null) body['dateOfBirth'] = _dob!.toIso8601String();

      await DioClient.instance.patch<dynamic>('/users/me', data: body);
      ref.invalidate(currentUserProvider);

      if (mounted) {
        AppSnackbar.showSuccess(context, 'Profile updated');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ──────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: dark ? kDarkSurface : kSurface,
                        backgroundImage: _avatarFile != null
                            ? FileImage(_avatarFile!) as ImageProvider
                            : _existingAvatarUrl != null
                                ? CachedNetworkImageProvider(_existingAvatarUrl!)
                                : null,
                        child: (_avatarFile == null && _existingAvatarUrl == null)
                            ? Icon(Icons.person_rounded,
                                size: 52,
                                color: dark ? kDarkTextMuted : kTextMuted)
                            : null,
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: kPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 15, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Tap to change photo',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: dark ? kDarkTextMuted : kTextMuted)),
              ),
              const SizedBox(height: 32),

              // ── Section: Personal Info ───────────────────────────────
              _SectionLabel(label: 'Personal Info', dark: dark),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.inter(
                          color: dark ? kDarkTextPrimary : kTextPrimary),
                      decoration: InputDecoration(
                        labelText: 'First name',
                        labelStyle: GoogleFonts.inter(
                            color: dark ? kDarkTextMuted : kTextMuted),
                        prefixIcon: Icon(Icons.person_rounded,
                            color: dark ? kDarkTextMuted : kTextMuted,
                            size: 20),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.inter(
                          color: dark ? kDarkTextPrimary : kTextPrimary),
                      decoration: InputDecoration(
                        labelText: 'Last name',
                        labelStyle: GoogleFonts.inter(
                            color: dark ? kDarkTextMuted : kTextMuted),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gender dropdown
              DropdownButtonFormField<String>(
                initialValue: _gender,
                dropdownColor: dark ? kDarkSurface : Colors.white,
                style: GoogleFonts.inter(
                    color: dark ? kDarkTextPrimary : kTextPrimary,
                    fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Gender',
                  labelStyle: GoogleFonts.inter(
                      color: dark ? kDarkTextMuted : kTextMuted),
                  prefixIcon: Icon(Icons.wc_rounded,
                      color: dark ? kDarkTextMuted : kTextMuted, size: 20),
                ),
                items: _genders
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(g,
                              style: GoogleFonts.inter(
                                  color: dark
                                      ? kDarkTextPrimary
                                      : kTextPrimary,
                                  fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 16),

              // Date of birth
              GestureDetector(
                onTap: _pickDob,
                child: AbsorbPointer(
                  child: TextFormField(
                    readOnly: true,
                    style: GoogleFonts.inter(
                        color: dark ? kDarkTextPrimary : kTextPrimary),
                    controller: TextEditingController(
                      text: _dob != null
                          ? '${_dob!.day.toString().padLeft(2, '0')}/'
                              '${_dob!.month.toString().padLeft(2, '0')}/'
                              '${_dob!.year}'
                          : '',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Date of birth',
                      labelStyle: GoogleFonts.inter(
                          color: dark ? kDarkTextMuted : kTextMuted),
                      hintText: 'DD/MM/YYYY',
                      hintStyle: GoogleFonts.inter(
                          color: dark ? kDarkTextMuted : kTextMuted),
                      prefixIcon: Icon(Icons.cake_rounded,
                          color: dark ? kDarkTextMuted : kTextMuted,
                          size: 20),
                      suffixIcon: Icon(Icons.calendar_today_rounded,
                          color: dark ? kDarkTextMuted : kTextMuted,
                          size: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Section: Contact ────────────────────────────────────
              _SectionLabel(label: 'Contact', dark: dark),
              const SizedBox(height: 14),

              // Email — read-only
              TextFormField(
                readOnly: true,
                initialValue: _email ?? '',
                style: GoogleFonts.inter(
                    color: dark ? kDarkTextMuted : kTextMuted),
                decoration: InputDecoration(
                  labelText: 'Email address',
                  labelStyle: GoogleFonts.inter(
                      color: dark ? kDarkTextMuted : kTextMuted),
                  prefixIcon: Icon(Icons.email_rounded,
                      color: dark ? kDarkTextMuted : kTextMuted, size: 20),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.lock_rounded,
                        size: 15,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                  filled: true,
                  fillColor:
                      (dark ? kDarkSurface : kSurface).withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Email cannot be changed. Contact support if needed.',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: dark ? kDarkTextMuted : kTextMuted),
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneCtrl,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(
                    color: dark ? kDarkTextPrimary : kTextPrimary),
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  labelStyle: GoogleFonts.inter(
                      color: dark ? kDarkTextMuted : kTextMuted),
                  hintText: '07XXXXXXXX',
                  hintStyle: GoogleFonts.inter(
                      color: dark ? kDarkTextMuted : kTextMuted),
                  prefixIcon: Icon(Icons.phone_rounded,
                      color: dark ? kDarkTextMuted : kTextMuted, size: 20),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final digits = v.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 9 || digits.length > 13) {
                      return 'Enter a valid phone number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // ── Section: Location ────────────────────────────────────
              _SectionLabel(label: 'Location', dark: dark),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cityCtrl,
                textInputAction: TextInputAction.done,
                style: GoogleFonts.inter(
                    color: dark ? kDarkTextPrimary : kTextPrimary),
                decoration: InputDecoration(
                  labelText: 'City',
                  labelStyle: GoogleFonts.inter(
                      color: dark ? kDarkTextMuted : kTextMuted),
                  hintText: 'e.g. Nairobi',
                  hintStyle: GoogleFonts.inter(
                      color: dark ? kDarkTextMuted : kTextMuted),
                  prefixIcon: Icon(Icons.location_city_rounded,
                      color: dark ? kDarkTextMuted : kTextMuted, size: 20),
                ),
              ),
              const SizedBox(height: 36),

              // ── Save button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isLoading ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text('Save Changes',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool dark;
  const _SectionLabel({required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: dark ? kDarkTextMuted : kTextMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Divider(
                height: 1, color: dark ? kDarkBorder : kBorder)),
      ],
    );
  }
}
