import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';

class EmergencyContactPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const EmergencyContactPage({super.key, required this.user});

  @override
  State<EmergencyContactPage> createState() => _EmergencyContactPageState();
}

class _EmergencyContactPageState extends State<EmergencyContactPage> {
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactPhoneController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contactNameController = TextEditingController(
      text: widget.user['emergency_contact_name'] ?? '',
    );
    _contactPhoneController = TextEditingController(
      text: widget.user['emergency_contact_phone'] ?? '',
    );
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final contactName = _contactNameController.text.trim();
    final contactPhone = _contactPhoneController.text.trim();

    if (contactName.isEmpty || contactPhone.isEmpty) {
      _showMessage('Enter both an emergency contact name and phone number.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.apiRoot}/api/users/me/emergency-contact'),
        headers: {
          'Content-Type': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: jsonEncode({'name': contactName, 'phone': contactPhone}),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (data['success'] == true) {
        Navigator.of(context).pop(true);
      } else {
        _showMessage(data['message'] ?? 'Could not save emergency contact');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contact')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: extras.brandTint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 30,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Used only if you trigger an SOS alert.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13.5,
                color: extras.text2,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Contact Name',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contactNameController,
              decoration: const InputDecoration(hintText: 'e.g. Mom, roommate...'),
            ),
            const SizedBox(height: 20),
            Text(
              'Contact Phone',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: '+91XXXXXXXXXX'),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
