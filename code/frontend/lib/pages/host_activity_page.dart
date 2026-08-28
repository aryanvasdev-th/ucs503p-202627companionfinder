import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Create-activity form. Not wired to a backend yet — there's no
/// activities endpoint to post to. UI only for now.
class HostActivityPage extends StatefulWidget {
  const HostActivityPage({super.key});

  @override
  State<HostActivityPage> createState() => _HostActivityPageState();
}

class _HostActivityPageState extends State<HostActivityPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'Hiking';
  int _maxPeople = 4;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  static const _categories = ['Hiking', 'Coffee', 'Gaming', 'Sports', 'More...'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Host Activity', style: theme.textTheme.titleLarge?.copyWith(color: extras.brandInk, fontSize: 19)),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shield_outlined, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text('SOS', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
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
              _Label('ACTIVITY TITLE'),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'e.g. Weekend Morning Hike'),
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
                      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                      decoration: BoxDecoration(
                        color: active ? theme.colorScheme.primary : extras.field,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : extras.text2),
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
                decoration: const InputDecoration(hintText: 'What are we doing? What should people bring?'),
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
                          label: _selectedTime == null ? 'Select time' : _selectedTime!.format(context),
                          selected: _selectedTime != null,
                          onTap: _pickTime,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Label('MAXIMUM PEOPLE'),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: extras.field, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepButton(
                      icon: Icons.remove_rounded,
                      onTap: () => setState(() => _maxPeople = (_maxPeople - 1).clamp(1, 50)),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '$_maxPeople',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                      ),
                    ),
                    _StepButton(
                      icon: Icons.add_rounded,
                      onTap: () => setState(() => _maxPeople = (_maxPeople + 1).clamp(1, 50)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _Label('LOCATION'),
              Container(
                height: 118,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: theme.brightness == Brightness.dark ? const Color(0xFF201C22) : const Color(0xFFE4EEE6),
                ),
                child: Stack(
                  children: [
                    Center(child: Icon(Icons.location_on_outlined, size: 26, color: extras.brandInk)),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: extras.field,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.place_outlined, size: 15, color: extras.text3),
                            const SizedBox(width: 8),
                            Text('Select Location...', style: TextStyle(fontSize: 13, color: extras.text3)),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hosting isn\'t wired up yet — design preview only.')),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
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
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.extras.text2),
      ),
    );
  }
}

class _IconField extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _IconField({required this.icon, required this.label, this.selected = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final extras = context.extras;
    final textColor = selected ? Theme.of(context).colorScheme.onSurface : extras.text3;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: extras.field, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13.5, color: textColor, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
        ),
        child: Icon(icon, size: 16, color: theme.colorScheme.primary),
      ),
    );
  }
}
