import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'login_page.dart';
import 'theme/app_theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final otpController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _resendCooldown = 0;
  Timer? _timer;

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateOtp(String? value) {
    final otp = value?.trim() ?? '';
    if (otp.length != 6) {
      return 'Enter the 6-digit code';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a new password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> requestCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': emailController.text.trim()}),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (data['success'] == true) {
        setState(() => _codeSent = true);
        _startCooldown();
        _showMessage('If an account exists for that email, a reset code has been sent.');
      } else {
        _showMessage(data['message'] ?? 'Could not send reset code');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  Future<void> resendCode() async {
    if (_resendCooldown > 0) return;

    setState(() => _isResending = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': emailController.text.trim()}),
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

  Future<void> resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailController.text.trim(),
          'otp': otpController.text.trim(),
          'newPassword': passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (data['success'] == true) {
        _showMessage('Password reset! You can now log in.');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } else {
        _showMessage(data['message'] ?? 'Password reset failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    otpController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
          'Reset Password',
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
            child: _codeSent ? _buildResetForm(theme, extras) : _buildEmailForm(theme, extras),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm(ThemeData theme, AppExtras extras) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 76,
            height: 76,
            margin: const EdgeInsets.only(bottom: 22),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: extras.brandTint,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.lock_reset_outlined,
              size: 34,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            'Forgot your password?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontSize: 23),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter your college email and we'll send you a code to reset it.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13.5,
              color: extras.text2,
            ),
          ),
          const SizedBox(height: 30),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'College Email',
              hintText: 'you@college.edu',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Please enter your email';
              return null;
            },
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : requestCode,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Send Reset Code'),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Back to log in', style: TextStyle(color: extras.text2, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildResetForm(ThemeData theme, AppExtras extras) {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter Reset Code',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontSize: 23),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to\n${emailController.text.trim()}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13.5,
              color: extras.text2,
            ),
          ),
          const SizedBox(height: 26),
          TextFormField(
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Reset Code',
              prefixIcon: Icon(Icons.pin_outlined),
              counterText: '',
            ),
            validator: _validateOtp,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: _validatePassword,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: _validateConfirmPassword,
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : resetPassword,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Reset Password'),
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: (_resendCooldown > 0 || _isResending) ? null : resendCode,
            child: Text(
              _resendCooldown > 0
                  ? 'Resend code in ${_resendCooldown}s'
                  : (_isResending ? 'Sending...' : 'Resend code'),
              style: TextStyle(color: extras.text3, fontSize: 13.5),
            ),
          ),
          TextButton(
            onPressed: () {
              _timer?.cancel();
              setState(() {
                _codeSent = false;
                _resendCooldown = 0;
                otpController.clear();
                passwordController.clear();
                confirmPasswordController.clear();
              });
            },
            child: Text('Use a different email', style: TextStyle(color: extras.text2, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
