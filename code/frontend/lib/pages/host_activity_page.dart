import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../api_config.dart';
import '../models/categories.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../utils/image_mime.dart';
import 'activity_detail_page.dart';

/// Form for hosting either a single activity or an event — an umbrella such
/// as a fest, whose activities (Football, Quiz…) the host adds afterwards
/// from the event page.
class HostActivityPage extends StatefulWidget {
  final bool isEvent;
  const HostActivityPage({super.key, this.isEvent = false});

  @override
  State<HostActivityPage> createState() => _HostActivityPageState();
}

class _HostActivityPageState extends State<HostActivityPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _landmarkController = TextEditingController();
  String _category = kHostableCategories.first;
  int _maxPeople = 4;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  File? _bannerFile;
  bool _hasDuration = false;
  int _durationMinutes = 60;
  // Events can run over several days (a 3-day fest): they take an end
  // date and time instead of a duration.
  DateTime? _endsAt;
  bool _isSubmitting = false;
  // Umbrella event split into teams (hackathon, tournament, quiz night).

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

  static const _weekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// "Thu, Nov 19 · 11:00 AM", or null until a time is picked.
  String? get _whenLabel {
    if (_selectedDate == null || _selectedTime == null) return null;
    final d = _selectedDate!;
    return '${_weekdayNames[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day} · '
        '${_selectedTime!.format(context)}';
  }

  String _formatEnd(DateTime d) =>
      '${_weekdayNames[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day} · '
      '${TimeOfDay.fromDateTime(d).format(context)}';

  Future<void> _pickEnd() async {
    final start = _selectedDate == null || _selectedTime == null
        ? null
        : DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          );
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WhenPickerSheet(
        title: 'When does it end?',
        // Default to the next day at the same time, the common fest case.
        initial: _endsAt ?? start?.add(const Duration(days: 1)),
      ),
    );
    if (picked != null) setState(() => _endsAt = picked);
  }

  /// One sheet for both: quick day chips plus a time wheel, instead of two
  /// separate Material dialogs.
  Future<void> _pickWhen() async {
    final initial = (_selectedDate != null && _selectedTime != null)
        ? DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          )
        : null;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WhenPickerSheet(initial: initial),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _selectedTime = TimeOfDay(hour: picked.hour, minute: picked.minute);
    });
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
        await http.MultipartFile.fromPath(
          'banner',
          _bannerFile!.path,
          contentType: mediaTypeForPath(_bannerFile!.path),
        ),
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

    if (widget.isEvent && _endsAt != null && !_endsAt!.isAfter(startsAt)) {
      _showMessage('The end has to be after the start');
      return;
    }

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
          if (!widget.isEvent && _hasDuration)
            'durationMinutes': _durationMinutes,
          if (widget.isEvent && _endsAt != null)
            'durationMinutes': _endsAt!.difference(startsAt).inMinutes,
          if (widget.isEvent) 'isEvent': true,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true && _bannerFile != null) {
        await _uploadBanner(data['activityId']);
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (data['success'] == true) {
        if (widget.isEvent) {
          // Straight to the event page, where the host adds its activities.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  ActivityDetailPage(activityId: data['activityId'] as int),
            ),
          );
          _showMessage(
            'Event created! Now add the activities happening at it.',
          );
        } else {
          _showMessage('Activity created!');
          Navigator.pop(context);
        }
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
          widget.isEvent ? 'Host Event' : 'Host Activity',
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
      // Tapping anywhere outside a field or dragging the form puts the
      // keyboard away; the iOS number pad has no return key of its own.
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
              children: [
                _Label(widget.isEvent ? 'EVENT NAME' : 'ACTIVITY TITLE'),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: widget.isEvent
                        ? 'e.g. Saturnalia 2026'
                        : 'e.g. Chai and cards after class',
                  ),
                ),
                if (!widget.isEvent) ...[
                  const SizedBox(height: 20),
                  _Label('CATEGORY'),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: kHostableCategories.map((c) {
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
                ],
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
                _Label('WHEN'),
                _IconField(
                  icon: Icons.event_outlined,
                  label: _whenLabel ?? 'Pick a date and time',
                  selected: _whenLabel != null,
                  onTap: _pickWhen,
                ),
                const SizedBox(height: 20),
                if (widget.isEvent) ...[
                  _Label('ENDS (OPTIONAL)'),
                  _IconField(
                    icon: Icons.event_available_outlined,
                    label: _endsAt == null
                        ? 'Same day — set an end for multi-day events'
                        : _formatEnd(_endsAt!),
                    selected: _endsAt != null,
                    onTap: _pickEnd,
                  ),
                  if (_endsAt != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _endsAt = null),
                        child: const Text('Remove end date'),
                      ),
                    ),
                ] else ...[
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
                    _StepperBox(
                      onMinus: () => setState(
                        () => _durationMinutes = (_durationMinutes - 15).clamp(
                          15,
                          720,
                        ),
                      ),
                      onPlus: () => setState(
                        () => _durationMinutes = (_durationMinutes + 15).clamp(
                          15,
                          720,
                        ),
                      ),
                      child: Text(
                        _formatDuration(_durationMinutes),
                        textAlign: TextAlign.center,
                        style: numberStyle(context),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                _Label(widget.isEvent ? 'MAXIMUM ATTENDEES' : 'MAXIMUM PEOPLE'),
                NumberStepper(
                  value: _maxPeople,
                  min: 2,
                  max: 50000,
                  onChanged: (v) => setState(() => _maxPeople = v),
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
                const SizedBox(height: 20),
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
              ],
            ),
            // Hidden while typing so it doesn't sit on top of the field.
            if (MediaQuery.of(context).viewInsets.bottom == 0)
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
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.isEvent
                                    ? 'Create Event'
                                    : 'Create Activity',
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
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

/// Numbers on this screen use the body font with even-width digits; the
/// rounded heading font made them look cartoonish.
TextStyle? numberStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class _StepperBox extends StatelessWidget {
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final Widget child;

  const _StepperBox({
    required this.onMinus,
    required this.onPlus,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: context.extras.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _StepButton(icon: Icons.remove_rounded, onTap: onMinus),
          Expanded(child: child),
          _StepButton(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

/// − value + where the value itself is a text field: tap it and type 120
/// rather than pressing + a hundred times. Out-of-range input is clamped
/// when editing finishes.
class NumberStepper extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const NumberStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late final _controller = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(NumberStepper old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text) ?? widget.value;
    final clamped = parsed.clamp(widget.min, widget.max);
    _controller.text = '$clamped';
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  void _step(int delta) {
    _focus.unfocus();
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    _controller.text = '$next';
    widget.onChanged(next);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StepperBox(
      onMinus: () => _step(-1),
      onPlus: () => _step(1),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter('${widget.max}'.length),
        ],
        style: numberStyle(context),
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _focus.unfocus(),
      ),
    );
  }
}

/// Bottom sheet for picking when an activity starts: a row of day chips
/// (Today, Tomorrow, then weekday + date for two weeks, plus a calendar for
/// anything further out) and an iOS-style time wheel in 5-minute steps.
class WhenPickerSheet extends StatefulWidget {
  final DateTime? initial;
  final String title;
  const WhenPickerSheet({super.key, this.initial, this.title = 'When is it?'});

  @override
  State<WhenPickerSheet> createState() => _WhenPickerSheetState();
}

class _WhenPickerSheetState extends State<WhenPickerSheet> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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

  late DateTime _day;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    // Default: the next half hour, at least 30 minutes from now.
    final base =
        widget.initial ?? DateTime.now().add(const Duration(minutes: 30));
    final rounded = widget.initial != null
        ? base
        : DateTime(
            base.year,
            base.month,
            base.day,
            base.hour,
            base.minute < 30 ? 30 : 0,
          ).add(Duration(hours: base.minute < 30 ? 0 : 1));
    _day = DateTime(rounded.year, rounded.month, rounded.day);
    _hour = rounded.hour;
    _minute = rounded.minute - rounded.minute % 5;
  }

  DateTime get _picked =>
      DateTime(_day.year, _day.month, _day.day, _hour, _minute);

  bool get _inPast => _picked.isBefore(DateTime.now());

  String _chipLabel(DateTime d, int index) {
    if (index == 0) return 'Today';
    if (index == 1) return 'Tomorrow';
    return '${_weekdays[d.weekday - 1]} ${d.day}';
  }

  Future<void> _pickOtherDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(14, (i) => today.add(Duration(days: i)));
    final dayIsInChips = days.any((d) => d == _day);
    final hour12 = _hour % 12 == 0 ? 12 : _hour % 12;
    final summary =
        '${_weekdays[_day.weekday - 1]}, ${_months[_day.month - 1]} ${_day.day} · '
        '$hour12:${_minute.toString().padLeft(2, '0')} ${_hour >= 12 ? 'PM' : 'AM'}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_chipLabel(days[i], i)),
                        selected: _day == days[i],
                        onSelected: (_) => setState(() => _day = days[i]),
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(
                      dayIsInChips
                          ? 'Later…'
                          : '${_months[_day.month - 1]} ${_day.day}',
                    ),
                    onPressed: _pickOtherDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: theme.brightness,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: theme.textTheme.bodyLarge
                        ?.copyWith(
                          fontSize: 21,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  minuteInterval: 5,
                  initialDateTime: DateTime(2000, 1, 1, _hour, _minute),
                  onDateTimeChanged: (t) => setState(() {
                    _hour = t.hour;
                    _minute = t.minute;
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _inPast ? 'That time has already passed' : summary,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _inPast ? theme.colorScheme.error : extras.text2,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _inPast
                    ? null
                    : () => Navigator.pop(context, _picked),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
