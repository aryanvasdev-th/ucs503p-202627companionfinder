import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'login_page.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 70,
                ),

                const SizedBox(height: 20),

                const Text(
                  'Enter Verification Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'We sent a 6-digit code to ${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),

                const SizedBox(height: 35),

                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(),
                    hintText: '------',
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : verifyOtp,
                    child: _isVerifying
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(fontSize: 17),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: (_resendCooldown > 0 || _isResending) ? null : resendOtp,
                  child: Text(
                    _resendCooldown > 0
                        ? 'Resend code in ${_resendCooldown}s'
                        : (_isResending ? 'Sending...' : 'Resend code'),
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
