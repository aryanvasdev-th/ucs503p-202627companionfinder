import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../api_config.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';

class HostActivityPage extends StatefulWidget {
  const HostActivityPage({super.key});

  @override
  State<HostActivityPage> createState() => _HostActivityPageState();
}

class _HostActivityPageState extends State<HostActivityPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _landmarkController = TextEditingController();
  String _category = 'Hiking';
  int _maxPeople = 4;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  File? _bannerFile;
  bool _hasDuration = false;
  int _durationMinutes = 60;
  bool _isSubmitting = false;

  static const _categories = [
    'Hiking',
    'Coffee',
    'Gaming',
    'Sports',
    'More...',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _pickBanner() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _bannerFile = File(picked.path));
  }

  Future<void> _uploadBanner(int activityId) async {
    if (_bannerFile == null) return;
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.apiRoot}/api/activities/$activityId/banner'),
      );
      request.headers.addAll(AuthSession.authHeaders);
      request.files.add(
        await http.MultipartFile.fromPath('banner', _bannerFile!.path),
      );
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        // Activity is already created at this point — a failed banner upload
        // shouldn't block the flow, just surface it so it's not a silent gap.
        _showMessage(
          'Activity created, but the banner photo failed to upload: '
          '${data['message'] ?? 'unknown error'}',
        );
      }
    } catch (e) {
      _showMessage('Activity created, but the banner photo failed to upload.');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createActivity() async {
    if (_titleController.text.trim().isEmpty) {
      _showMessage('Please enter a title');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showMessage('Please select a date and time');
      return;
    }

    final startsAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiRoot}/api/activities'),
        headers: {
          'Content-Type': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: jsonEncode({
          'title': _titleController.text.trim(),
          'category': _category,
          'description': _descriptionController.text.trim(),
          'landmark': _landmarkController.text.trim(),
          'startsAt': startsAt.toIso8601String(),
          'maxPeople': _maxPeople,
          if (_hasDuration) 'durationMinutes': _durationMinutes,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true && _bannerFile != null) {
        await _uploadBanner(data['activityId']);
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (data['success'] == true) {
        _showMessage('Activity created!');
        Navigator.pop(context);
      } else {
        _showMessage(data['message'] ?? 'Could not create activity');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          'Host Activity',
          style: theme.textTheme.titleLarge?.copyWith(
            color: extras.brandInk,
            fontSize: 19,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('SOS isn\'t set up yet — coming soon'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: extras.field,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 13, color: extras.text2),
                    const SizedBox(width: 4),
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: extras.text2,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
            children: [
              _Label('BANNER PHOTO'),
              GestureDetector(
                onTap: _pickBanner,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: extras.field,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _bannerFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 28,
                              color: extras.text2,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add a banner photo (optional)',
                              style: TextStyle(
                                fontSize: 13,
                                color: extras.text2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(_bannerFile!, fit: BoxFit.cover),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _bannerFile = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              _Label('ACTIVITY TITLE'),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Weekend Morning Hike',
                ),
              ),
              const SizedBox(height: 20),
              _Label('CATEGORY'),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: _categories.map((c) {
                  final active = c == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? theme.colorScheme.primary
                            : extras.field,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : extras.text2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _Label('DESCRIPTION'),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'What are we doing? What should people bring?',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('DATE'),
                        _IconField(
                          icon: Icons.calendar_today_outlined,
                          label: _selectedDate == null
                              ? 'Select date'
                              : '${_months[_selectedDate!.month - 1]} ${_selectedDate!.day}, ${_selectedDate!.year}',
                          selected: _selectedDate != null,
                          onTap: _pickDate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('TIME'),
                        _IconField(
                          icon: Icons.access_time_rounded,
                          label: _selectedTime == null
                              ? 'Select time'
                              : _selectedTime!.format(context),
                          selected: _selectedTime != null,
                          onTap: _pickTime,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _Label('DURATION (OPTIONAL)')),
                  Switch(
                    value: _hasDuration,
                    onChanged: (v) => setState(() => _hasDuration = v),
                  ),
                ],
              ),
              if (_hasDuration)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: extras.field,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StepButton(
                        icon: Icons.remove_rounded,
                        onTap: () => setState(
                          () => _durationMinutes =
                              (_durationMinutes - 15).clamp(15, 720),
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          _formatDuration(_durationMinutes),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                          ),
                        ),
                      ),
                      _StepButton(
                        icon: Icons.add_rounded,
                        onTap: () => setState(
                          () => _durationMinutes =
                              (_durationMinutes + 15).clamp(15, 720),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              _Label('MAXIMUM PEOPLE'),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: extras.field,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepButton(
                      icon: Icons.remove_rounded,
                      onTap: () => setState(
                        () => _maxPeople = (_maxPeople - 1).clamp(1, 50),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '$_maxPeople',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                        ),
                      ),
                    ),
                    _StepButton(
                      icon: Icons.add_rounded,
                      onTap: () => setState(
                        () => _maxPeople = (_maxPeople + 1).clamp(1, 50),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _Label('LANDMARK'),
              TextField(
                controller: _landmarkController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Main Gate',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 26,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createActivity,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Create Activity'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: context.extras.text2,
        ),
      ),
    );
  }
}

class _IconField extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _IconField({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.extras;
    final textColor = selected
        ? Theme.of(context).colorScheme.onSurface
        : extras.text3;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: extras.field,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  color: textColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: theme.colorScheme.primary),
      ),
    );
  }
}
