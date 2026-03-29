import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/auth_provider.dart';
import '../../../core/config/constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/red_button.dart';
import '../../../shared/widgets/app_snackbar.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _orgNameCtrl = TextEditingController();
  final _paybillCtrl = TextEditingController();
  final _accountRefCtrl = TextEditingController();
  final _tillCtrl = TextEditingController();

  File? _avatarFile;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isOrganizer = false;
  String _payoutMethod = 'PLATFORM_WALLET';

  @override
  void initState() {
    super.initState();
    // MIUI keyboard sends × (U+00D7) instead of x — normalize silently
    void normalizeMiui(TextEditingController ctrl) {
      ctrl.addListener(() {
        final val = ctrl.text;
        final normalized = val.replaceAll('\u00d7', 'x');
        if (normalized != val) {
          ctrl.value = ctrl.value.copyWith(
            text: normalized,
            selection: TextSelection.collapsed(
                offset: ctrl.selection.baseOffset.clamp(0, normalized.length)),
          );
        }
      });
    }
    normalizeMiui(_passCtrl);
    normalizeMiui(_confirmPassCtrl);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _orgNameCtrl.dispose();
    _paybillCtrl.dispose();
    _accountRefCtrl.dispose();
    _tillCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authStateProvider.notifier).register(
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            password: _passCtrl.text,
            role: _isOrganizer ? 'ORGANIZER' : 'ATTENDEE',
            organizerName: _isOrganizer ? _orgNameCtrl.text.trim() : null,
            payoutMethod: _isOrganizer ? _payoutMethod : null,
            paybillNumber: (_isOrganizer && _payoutMethod == 'OWN_PAYBILL')
                ? _paybillCtrl.text.trim()
                : null,
            mpesaAccountRef: (_isOrganizer && _payoutMethod == 'OWN_PAYBILL')
                ? _accountRefCtrl.text.trim()
                : null,
            tillNumber: (_isOrganizer && _payoutMethod == 'OWN_TILL')
                ? _tillCtrl.text.trim()
                : null,
          );
      // Upload avatar if picked, then re-fetch user to get updated avatarUrl
      if (_avatarFile != null) {
        try {
          await DioClient.instance.uploadFile(
            '/users/avatar',
            _avatarFile!.path,
            field: 'avatar',
          );
          // Re-fetch user so storage has the real avatarUrl
          final userData = await DioClient.instance
              .get<Map<String, dynamic>>('/users/me');
          final updatedUser = User.fromJson(userData);
          await const FlutterSecureStorage().write(
            key: AppConstants.userKey,
            value: jsonEncode(updatedUser.toJson()),
          );
          ref.invalidate(currentUserProvider);
        } catch (_) {
          // Avatar upload failure is non-fatal
        }
      }
      if (mounted) context.go('/home');
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
          onPressed: () => context.go('/login'),
        ),
        title: Text(
          'Create Account',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Join the party 🎉',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: dark ? kDarkTextPrimary : kTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create your account to get started',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: dark ? kDarkTextMuted : kTextMuted),
              ),
              const SizedBox(height: 24),

              // Profile photo picker
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: dark ? kDarkSurface : kSurface,
                        backgroundImage: _avatarFile != null
                            ? FileImage(_avatarFile!) as ImageProvider
                            : null,
                        child: _avatarFile == null
                            ? Icon(Icons.person_rounded,
                                size: 48,
                                color: dark ? kDarkTextMuted : kTextMuted)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: kPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Add photo (optional)',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: dark ? kDarkTextMuted : kTextMuted)),
              ),
              const SizedBox(height: 20),

              // Account type toggle
              Container(
                decoration: BoxDecoration(
                  color: dark ? kDarkSurface : kSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _TypeTab(
                      label: 'Attendee',
                      icon: Icons.person_rounded,
                      selected: !_isOrganizer,
                      onTap: () => setState(() => _isOrganizer = false),
                    ),
                    _TypeTab(
                      label: 'Organizer',
                      icon: Icons.event_rounded,
                      selected: _isOrganizer,
                      onTap: () => setState(() => _isOrganizer = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Basic fields
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration:
                          const InputDecoration(hintText: 'First name'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration:
                          const InputDecoration(hintText: 'Last name'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.email_rounded,
                      color: dark ? kDarkTextMuted : kTextMuted),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Phone number (optional)',
                  prefixIcon: Icon(Icons.phone_rounded,
                      color: dark ? kDarkTextMuted : kTextMuted),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: Icon(Icons.lock_rounded,
                      color: dark ? kDarkTextMuted : kTextMuted),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: dark ? kDarkTextMuted : kTextMuted,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 8) return 'Min 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirm,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: _isOrganizer
                    ? TextInputAction.next
                    : TextInputAction.done,
                onFieldSubmitted:
                    _isOrganizer ? null : (_) => _register(),
                decoration: InputDecoration(
                  hintText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_rounded,
                      color: dark ? kDarkTextMuted : kTextMuted),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: dark ? kDarkTextMuted : kTextMuted,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _passCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),

              // Organizer section
              if (_isOrganizer) ...[
                const SizedBox(height: 24),
                _SectionLabel('Organizer Details'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _orgNameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Business / Organization name',
                    prefixIcon: Icon(Icons.business_rounded,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                  validator: (v) {
                    if (!_isOrganizer) return null;
                    return (v == null || v.isEmpty)
                        ? 'Organization name required'
                        : null;
                  },
                ),
                const SizedBox(height: 20),
                _SectionLabel('How do you want to receive payments?'),
                const SizedBox(height: 12),
                _PayoutOption(
                  value: 'PLATFORM_WALLET',
                  groupValue: _payoutMethod,
                  title: 'Use PartyPass Wallet',
                  subtitle:
                      'We collect on your behalf and settle to your M-Pesa.',
                  icon: Icons.account_balance_wallet_rounded,
                  onChanged: (v) => setState(() => _payoutMethod = v!),
                ),
                const SizedBox(height: 8),
                _PayoutOption(
                  value: 'OWN_PAYBILL',
                  groupValue: _payoutMethod,
                  title: 'My Own Paybill',
                  subtitle:
                      'Payments go directly to your M-Pesa Paybill.',
                  icon: Icons.receipt_long_rounded,
                  onChanged: (v) => setState(() => _payoutMethod = v!),
                ),
                if (_payoutMethod == 'OWN_PAYBILL') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _paybillCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Paybill number (e.g. 174379)',
                      prefixIcon: Icon(Icons.dialpad_rounded,
                          color: dark ? kDarkTextMuted : kTextMuted),
                    ),
                    validator: (v) {
                      if (_payoutMethod != 'OWN_PAYBILL') return null;
                      return (v == null || v.isEmpty)
                          ? 'Paybill number required'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accountRefCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Account reference (e.g. EVENTSCO)',
                      prefixIcon: Icon(Icons.tag_rounded,
                          color: dark ? kDarkTextMuted : kTextMuted),
                    ),
                    validator: (v) {
                      if (_payoutMethod != 'OWN_PAYBILL') return null;
                      return (v == null || v.isEmpty)
                          ? 'Account reference required'
                          : null;
                    },
                  ),
                ],
                const SizedBox(height: 8),
                _PayoutOption(
                  value: 'OWN_TILL',
                  groupValue: _payoutMethod,
                  title: 'My Own Till Number',
                  subtitle:
                      'Payments go directly to your M-Pesa Till.',
                  icon: Icons.point_of_sale_rounded,
                  onChanged: (v) => setState(() => _payoutMethod = v!),
                ),
                if (_payoutMethod == 'OWN_TILL') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tillCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _register(),
                    decoration: InputDecoration(
                      hintText: 'Till number (e.g. 5678901)',
                      prefixIcon: Icon(Icons.dialpad_rounded,
                          color: dark ? kDarkTextMuted : kTextMuted),
                    ),
                    validator: (v) {
                      if (_payoutMethod != 'OWN_TILL') return null;
                      return (v == null || v.isEmpty)
                          ? 'Till number required'
                          : null;
                    },
                  ),
                ],
              ],

              const SizedBox(height: 28),
              RedButton(
                label: 'Create Account',
                onTap: _register,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: GoogleFonts.inter(
                          color: dark ? kDarkTextMuted : kTextMuted,
                          fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Log in',
                          style: GoogleFonts.inter(
                            color: kPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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

class _TypeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? Colors.white
                      : dark
                          ? kDarkTextMuted
                          : kTextMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : dark
                          ? kDarkTextMuted
                          : kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: dark ? kDarkTextMuted : kTextMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _PayoutOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _PayoutOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
  });

  bool get selected => value == groupValue;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? kPrimary.withValues(alpha: 0.08)
              : (dark ? kDarkSurface : kSurface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kPrimary : (dark ? kDarkBorder : kBorder),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? kPrimary.withValues(alpha: 0.12)
                    : (dark ? kDarkBorder : kBorder).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 20,
                  color: selected
                      ? kPrimary
                      : dark
                          ? kDarkTextMuted
                          : kTextMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? kPrimary
                          : dark
                              ? kDarkTextPrimary
                              : kTextPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: dark ? kDarkTextMuted : kTextMuted),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? kPrimary
                      : dark
                          ? kDarkTextMuted
                          : kTextMuted,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
