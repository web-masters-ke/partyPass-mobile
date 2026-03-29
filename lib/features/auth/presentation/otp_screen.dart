import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/red_button.dart';
import '../../../shared/widgets/app_snackbar.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) {
        t.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  String get _otpValue =>
      _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final otp = _otpValue;
    if (otp.length < 6) {
      AppSnackbar.showError(context, 'Enter the full 6-digit code');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).verifyOTP(widget.phone, otp);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    try {
      await ref.read(authRepositoryProvider).sendOTP(widget.phone);
      _startCountdown();
      if (mounted) AppSnackbar.showSuccess(context, 'OTP resent');
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
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
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Verify your number',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: dark ? kDarkTextPrimary : kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit code sent to ${widget.phone}',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: dark ? kDarkTextMuted : kTextMuted),
            ),
            const SizedBox(height: 40),
            // OTP input boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 48,
                  height: 56,
                  child: TextFormField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: dark ? kDarkTextPrimary : kTextPrimary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: dark ? kDarkBorder : kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: kPrimary, width: 2),
                      ),
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) {
                        _focusNodes[i + 1].requestFocus();
                      } else if (v.isEmpty && i > 0) {
                        _focusNodes[i - 1].requestFocus();
                      }
                      if (i == 5 && v.isNotEmpty) _verify();
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            RedButton(
              label: 'Verify',
              onTap: _verify,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: _countdown == 0 ? _resend : null,
                child: RichText(
                  text: TextSpan(
                    text: "Didn't receive it? ",
                    style: GoogleFonts.inter(
                        color: dark ? kDarkTextMuted : kTextMuted,
                        fontSize: 14),
                    children: [
                      TextSpan(
                        text: _countdown > 0
                            ? 'Resend in ${_countdown}s'
                            : 'Resend OTP',
                        style: GoogleFonts.inter(
                          color: _countdown > 0
                              ? (dark ? kDarkTextMuted : kTextMuted)
                              : kPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
