import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../pages/host_activity_page.dart' show NumberStepper, WhenPickerSheet;
import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';

const _months = [
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

String _timeLabel(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '${_months[d.month - 1]} ${d.day}, $hour:$minute ${d.hour >= 12 ? 'PM' : 'AM'}';
}

/// The activities inside an event (Football, Quiz, Chess at a fest). The
/// host adds and removes them; attendees who've joined the event sign up
/// for as many as have spots left. The host never takes a spot.
class EventActivitiesSection extends StatefulWidget {
  final int eventId;

  /// Where the "Add a time" picker opens — the event's first day.
  final DateTime eventStartsAt;
  final List<Map<String, dynamic>> items;
  final bool isHost;

  /// Attendee of the event, event not over — can sign up and leave.
  final bool canSignUp;

  /// Event not over — the host can still add or remove activities.
  final bool canEdit;
  final Future<void> Function() onChanged;
  final void Function(int userId, String? name) onOpenProfile;

  const EventActivitiesSection({
    super.key,
    required this.eventId,
    required this.eventStartsAt,
    required this.items,
    required this.isHost,
    required this.canSignUp,
    required this.canEdit,
    required this.onChanged,
    required this.onOpenProfile,
  });

  @override
  State<EventActivitiesSection> createState() => _EventActivitiesSectionState();
}

class _EventActivitiesSectionState extends State<EventActivitiesSection> {
  bool _busy = false;

  Future<void> _send(String method, String path, [Object? body]) async {
    setState(() => _busy = true);
    try {
      final uri = Uri.parse(
        '${ApiConfig.apiRoot}/api/activities/${widget.eventId}/event-activities$path',
      );
      final headers = {
        'Content-Type': 'application/json',
        ...AuthSession.authHeaders,
      };
      final response = method == 'POST'
          ? await http.post(uri, headers: headers, body: jsonEncode(body ?? {}))
          : await http.delete(uri, headers: headers);
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Something went wrong')),
        );
      }
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final result = await showDialog<_NewEventActivity>(
      context: context,
      builder: (_) =>
          _AddEventActivityDialog(eventStartsAt: widget.eventStartsAt),
    );
    if (result == null) return;
    await _send('POST', '', {
      'name': result.name,
      'spots': result.spots,
      if (result.teamSize != null) 'teamSize': result.teamSize,
      if (result.startsAt != null)
        'startsAt': result.startsAt!.toUtc().toIso8601String(),
    });
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${item['name']}?'),
        content: const Text('Everyone signed up for it will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await _send('DELETE', '/${item['id']}');
  }

  Widget _memberChips(List<Map<String, dynamic>> members) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: members
        .map(
          (m) => ActionChip(
            visualDensity: VisualDensity.compact,
            avatar: CircleAvatar(
              backgroundColor: colorForSeed(m['id'] as int),
              child: Text(
                initialsFor(m['name'] ?? '?'),
                style: const TextStyle(fontSize: 9, color: Colors.white),
              ),
            ),
            label: Text(
              m['name'] ?? 'Unknown',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => widget.onOpenProfile(m['id'] as int, m['name']),
          ),
        )
        .toList(),
  );

  Future<void> _startTeam(Map<String, dynamic> item) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Start a team for ${item['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Team name'),
                onChanged: (_) => setDialogState(() {}),
              ),
              Text(
                'Others looking for a team can join you, up to ${item['teamSize']} players.',
                style: TextStyle(fontSize: 12.5, color: context.extras.text2),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name == null) return;
    await _send('POST', '/${item['id']}/teams', {'name': name});
  }

  /// Team activity body: its teams with Join buttons, plus Start a team.
  List<Widget> _teamsBody(
    Map<String, dynamic> item, {
    required bool mine,
    required bool isFull,
  }) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final teamSize = item['teamSize'] as int;
    final spots = item['spots'] as int;
    final teams = ((item['teams'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final maxTeams = (spots / teamSize).ceil();
    final canStart =
        widget.canSignUp && !mine && !isFull && teams.length < maxTeams;

    return [
      const SizedBox(height: 10),
      if (teams.isEmpty)
        Text(
          widget.canSignUp
              ? 'No teams yet. Start one and people looking for a team can join you.'
              : 'No teams yet.',
          style: TextStyle(fontSize: 13, color: extras.text2),
        ),
      ...teams.map((team) {
        final teamMembers = (team['members'] as List)
            .cast<Map<String, dynamic>>();
        final inThisTeam = teamMembers.any(
          (m) => m['id'].toString() == AuthSession.userId,
        );
        final teamFull = teamMembers.length >= teamSize;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: extras.field,
            borderRadius: BorderRadius.circular(14),
            border: inThisTeam
                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.groups_rounded, size: 18, color: extras.indigo),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      team['name'],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    teamFull
                        ? 'Full'
                        : '${teamMembers.length}/$teamSize · ${teamSize - teamMembers.length} needed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: teamFull ? extras.text3 : extras.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _memberChips(teamMembers),
              if (widget.canSignUp && !mine && !teamFull && !isFull) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _send(
                            'POST',
                            '/${item['id']}/teams/${team['id']}/join',
                          ),
                    child: const Text('Join this team'),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
      if (canStart) ...[
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _startTeam(item),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Start a team'),
          ),
        ),
      ],
      if (widget.canSignUp && mine) ...[
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _busy
                ? null
                : () => _send('DELETE', '/${item['id']}/join'),
            child: const Text('Leave my team'),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final items = widget.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Activities',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
            ),
            if (widget.isHost && widget.canEdit)
              TextButton.icon(
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add activity'),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          items.isEmpty
              ? (widget.isHost
                    ? 'Add what\'s happening at this event, e.g. Football (22 spots) or Quiz (30 spots). Attendees can sign up for as many as they like.'
                    : 'The host hasn\'t added any activities yet.')
              : widget.isHost
              ? 'You\'re organising, so you don\'t take a spot.'
              : widget.canSignUp
              ? 'Sign up for as many as you like.'
              : 'Join the event to sign up for these.',
          style: TextStyle(fontSize: 13, color: extras.text2),
        ),
        ...items.map((item) {
          final members = (item['members'] as List)
              .cast<Map<String, dynamic>>();
          final spots = item['spots'] as int;
          final mine = members.any(
            (m) => m['id'].toString() == AuthSession.userId,
          );
          final isFull = members.length >= spots;
          final teamSize = item['teamSize'] as int?;
          final startsAt = item['startsAt'] == null
              ? null
              : DateTime.parse(item['startsAt']).toLocal();

          return Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: mine
                  ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (teamSize != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Team activity · teams of $teamSize',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: extras.indigo,
                                ),
                              ),
                            ),
                          if (startsAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _timeLabel(startsAt),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: extras.text2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isFull ? extras.field : extras.indigoTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isFull
                            ? 'Full'
                            : teamSize != null
                            ? '${((item['teams'] as List?) ?? const []).length}/${(spots / teamSize).ceil()} teams'
                            : '${members.length}/$spots joined',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isFull ? extras.text3 : extras.indigo,
                        ),
                      ),
                    ),
                    if (widget.isHost && widget.canEdit)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Remove',
                        onPressed: _busy ? null : () => _remove(item),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: extras.text3,
                        ),
                      ),
                  ],
                ),
                if (teamSize != null)
                  ..._teamsBody(item, mine: mine, isFull: isFull)
                else ...[
                  if (members.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: members
                          .map(
                            (m) => ActionChip(
                              visualDensity: VisualDensity.compact,
                              avatar: CircleAvatar(
                                backgroundColor: colorForSeed(m['id'] as int),
                                child: Text(
                                  initialsFor(m['name'] ?? '?'),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              label: Text(
                                m['name'] ?? 'Unknown',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () => widget.onOpenProfile(
                                m['id'] as int,
                                m['name'],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (widget.canSignUp) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: mine
                          ? OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () =>
                                        _send('DELETE', '/${item['id']}/join'),
                              child: const Text('Leave'),
                            )
                          : ElevatedButton(
                              onPressed: _busy || isFull
                                  ? null
                                  : () => _send('POST', '/${item['id']}/join'),
                              child: Text(isFull ? 'Full' : 'Sign up'),
                            ),
                    ),
                  ],
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _NewEventActivity {
  final String name;
  final int spots;
  final DateTime? startsAt;
  final int? teamSize;
  const _NewEventActivity(this.name, this.spots, this.startsAt, this.teamSize);
}

class _AddEventActivityDialog extends StatefulWidget {
  final DateTime eventStartsAt;
  const _AddEventActivityDialog({required this.eventStartsAt});

  @override
  State<_AddEventActivityDialog> createState() =>
      _AddEventActivityDialogState();
}

class _AddEventActivityDialogState extends State<_AddEventActivityDialog> {
  final _name = TextEditingController();
  // Individual activity: how many people can sign up.
  int _spots = 10;
  // Team activity: capacity is teams x players, so the host never has to
  // work out "spots" for teams themselves.
  bool _isTeam = false;
  int _teamCount = 4;
  int _teamSize = 5;
  DateTime? _startsAt;

  int get _totalSpots => _isTeam ? _teamCount * _teamSize : _spots;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WhenPickerSheet(
        title: 'When is it?',
        initial:
            _startsAt ??
            (widget.eventStartsAt.isAfter(DateTime.now())
                ? widget.eventStartsAt
                : null),
      ),
    );
    if (picked != null) setState(() => _startsAt = picked);
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: context.extras.text2,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final extras = context.extras;
    final canSubmit = _name.text.trim().isNotEmpty && _totalSpots <= 500;
    return AlertDialog(
      title: const Text('Add an activity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              maxLength: 60,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Football, Quiz, Treasure hunt',
              ),
              onChanged: (_) => setState(() {}),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
            Row(
              children: [
                Expanded(child: _label('PLAYED IN TEAMS')),
                Switch(
                  value: _isTeam,
                  onChanged: (v) => setState(() => _isTeam = v),
                ),
              ],
            ),
            if (_isTeam) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('TEAMS'),
                        NumberStepper(
                          value: _teamCount,
                          min: 1,
                          max: 100,
                          onChanged: (v) => setState(() => _teamCount = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('PLAYERS EACH'),
                        NumberStepper(
                          value: _teamSize,
                          min: 2,
                          max: 50,
                          onChanged: (v) => setState(() => _teamSize = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _totalSpots > 500
                    ? 'That\'s $_totalSpots players — the limit is 500 per activity.'
                    : '$_teamCount ${_teamCount == 1 ? 'team' : 'teams'} of $_teamSize = $_totalSpots players. '
                          'People join a team with space or start one.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _totalSpots > 500
                      ? Theme.of(context).colorScheme.error
                      : extras.indigo,
                ),
              ),
            ] else ...[
              _label('HOW MANY PEOPLE CAN JOIN'),
              NumberStepper(
                value: _spots,
                min: 1,
                max: 500,
                onChanged: (v) => setState(() => _spots = v),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(
                _startsAt == null
                    ? 'Add a time (optional)'
                    : _timeLabel(_startsAt!),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canSubmit
              ? () => Navigator.pop(
                  context,
                  _NewEventActivity(
                    _name.text.trim(),
                    _totalSpots,
                    _startsAt,
                    _isTeam ? _teamSize : null,
                  ),
                )
              : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
