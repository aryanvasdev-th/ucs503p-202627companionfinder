import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'login_page.dart';
import 'theme/app_theme.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;

  const OtpVerificationPage({super.key, required this.email});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final otpController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown(); // matches the backend's 60s resend cooldown
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.length != 6) {
      _showMessage('Please enter the 6-digit code');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'otp': otp}),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (data['success'] == true) {
        _showMessage('Email verified! You can now log in.');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } else {
        _showMessage(data['message'] ?? 'Verification failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  Future<void> resendOtp() async {
    if (_resendCooldown > 0) return;

    setState(() => _isResending = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;
      setState(() => _isResending = false);

      if (data['success'] == true) {
        _showMessage('A new code has been sent to your email');
        _startCooldown();
      } else {
        _showMessage(data['message'] ?? 'Could not resend code');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  @override
  void dispose() {
    otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Verify Email',
          style: theme.textTheme.titleLarge?.copyWith(
            color: extras.brandInk,
            fontSize: 19,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: extras.brandTint,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    size: 34,
                    color: theme.colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  'Enter Verification Code',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(fontSize: 23),
                ),

                const SizedBox(height: 8),

                Text(
                  'We sent a 6-digit code to\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    color: extras.text2,
                  ),
                ),

                const SizedBox(height: 30),

                Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) {
                        final text = otpController.text;
                        final char = i < text.length ? text[i] : '';
                        final active = i == text.length;
                        return Container(
                          width: 46,
                          height: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active
                                ? theme.colorScheme.surface
                                : extras.field,
                            borderRadius: BorderRadius.circular(14),
                            border: active
                                ? Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Text(
                            char,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 22,
                            ),
                          ),
                        );
                      }),
                    ),
                    Opacity(
                      opacity: 0,
                      child: SizedBox(
                        width: 310,
                        child: TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(counterText: ''),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : verifyOtp,
                    child: _isVerifying
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Verify'),
                  ),
                ),

                const SizedBox(height: 18),

                TextButton(
                  onPressed: (_resendCooldown > 0 || _isResending)
                      ? null
                      : resendOtp,
                  child: Text(
                    _resendCooldown > 0
                        ? 'Resend code in ${_resendCooldown}s'
                        : (_isResending ? 'Sending...' : 'Resend code'),
                    style: TextStyle(color: extras.text3, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
