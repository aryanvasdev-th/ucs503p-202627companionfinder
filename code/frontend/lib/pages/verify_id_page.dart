import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../api_config.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../utils/image_mime.dart';
import '../widgets/verified_badge.dart';

/// Thapar ID verification: photos of the front and back of the ID card.
/// The server reads the name and roll number on the front, the barcode on
/// the back, and checks both against the account's @thapar.edu email.
/// Neither photo is stored — only the result.
class VerifyIdPage extends StatefulWidget {
  final bool alreadyVerified;
  const VerifyIdPage({super.key, this.alreadyVerified = false});

  @override
  State<VerifyIdPage> createState() => _VerifyIdPageState();
}

class _PickedPhoto {
  final Uint8List bytes;
  final String name;
  const _PickedPhoto(this.bytes, this.name);
}

class _VerifyIdPageState extends State<VerifyIdPage> {
  _PickedPhoto? _front;
  _PickedPhoto? _back;
  bool _submitting = false;
  bool? _verified;
  String? _resultMessage;

  Future<void> _pick({required bool front}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      // Kept fairly large: the small printed roll number and the barcode
      // bars need the detail.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
      );
      if (picked == null) return;
      final photo = _PickedPhoto(await picked.readAsBytes(), picked.name);
      setState(() {
        if (front) {
          _front = photo;
        } else {
          _back = photo;
        }
        _resultMessage = null;
        _verified = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Camera unavailable on this device.'
                : 'Could not open photos.',
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_front == null || _back == null) return;
    setState(() {
      _submitting = true;
      _resultMessage = null;
      _verified = null;
    });
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.apiRoot}/api/users/me/verify-id'),
      );
      request.headers.addAll(AuthSession.authHeaders);
      for (final (field, photo) in [('idFront', _front!), ('idBack', _back!)]) {
        request.files.add(
          http.MultipartFile.fromBytes(
            field,
            photo.bytes,
            filename: photo.name,
            contentType: mediaTypeForPath(photo.name),
          ),
        );
      }
      final response = await http.Response.fromStream(await request.send());
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _verified = data['verified'] == true;
        _resultMessage = data['message'] ?? 'Verification failed';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _verified = false;
        _resultMessage = 'Network error. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your ID')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (widget.alreadyVerified && _verified == null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: extras.brandTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const VerifiedBadge(size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You\'re already verified. Others see the red tick next to your name.',
                        style: TextStyle(color: extras.brandInk),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Get the red tick next to your name so others know you\'re a real Thapar student.',
              style: theme.textTheme.bodyMedium?.copyWith(color: extras.text2),
            ),
            const SizedBox(height: 6),
            Text(
              'We read the name and roll number on your card and the barcode on the back, and check they match your Thapar email. The photos are checked once and never saved.',
              style: TextStyle(fontSize: 12.5, color: extras.text3),
            ),
            const SizedBox(height: 20),
            _PhotoSlot(
              step: '1',
              title: 'Front of your ID card',
              hint: 'The side with your photo and name. Lay it flat, fill most of the frame, avoid glare.',
              icon: Icons.badge_outlined,
              photo: _front,
              onTap: _submitting ? null : () => _pick(front: true),
            ),
            const SizedBox(height: 14),
            _PhotoSlot(
              step: '2',
              title: 'Back of your ID card',
              hint: 'The side with the barcode. Keep the whole barcode sharp and in frame.',
              icon: Icons.qr_code_2_rounded,
              photo: _back,
              onTap: _submitting ? null : () => _pick(front: false),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting || _front == null || _back == null
                    ? null
                    : _submit,
                child: _submitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Reading your card…'),
                        ],
                      )
                    : const Text('Verify'),
              ),
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 18),
              _ResultCard(
                verified: _verified == true,
                message: _resultMessage!,
                onDone: _verified == true
                    ? () => Navigator.of(context).pop(true)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final String step;
  final String title;
  final String hint;
  final IconData icon;
  final _PickedPhoto? photo;
  final VoidCallback? onTap;

  const _PhotoSlot({
    required this.step,
    required this.title,
    required this.hint,
    required this.icon,
    required this.photo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: photo != null ? extras.green : theme.dividerColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 76,
                height: 76,
                child: photo != null
                    ? Image.memory(photo!.bytes, fit: BoxFit.cover)
                    : Container(
                        color: extras.field,
                        child: Icon(icon, color: extras.text3, size: 30),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$step. $title',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    style: TextStyle(fontSize: 12.5, color: extras.text2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    photo != null ? 'Tap to retake' : 'Tap to add',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (photo != null)
              Icon(Icons.check_circle_rounded, color: extras.green),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final bool verified;
  final String message;
  final VoidCallback? onDone;

  const _ResultCard({
    required this.verified,
    required this.message,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final color = verified ? extras.green : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: verified ? extras.greenTint : extras.brandTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.verified_rounded : Icons.error_outline_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                verified ? 'Verified' : 'Not verified',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message),
          if (onDone != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onDone,
                child: const Text('Done'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
