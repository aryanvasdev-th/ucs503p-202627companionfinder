import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../widgets/verified_badge.dart';
import 'user_profile_page.dart';

/// Look someone up by name and open their profile, e.g. to check a host's
/// reviews before requesting to join.
class PeopleSearchPage extends StatefulWidget {
  const PeopleSearchPage({super.key});

  @override
  State<PeopleSearchPage> createState() => _PeopleSearchPageState();
}

class _PeopleSearchPageState extends State<PeopleSearchPage> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  int _requestSeq = 0;

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    final seq = ++_requestSeq;
    if (q.length < 2) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('${ApiConfig.apiRoot}/api/users/search')
          .replace(queryParameters: {'q': q});
      final response = await http.get(uri, headers: AuthSession.authHeaders);
      final data = jsonDecode(response.body);
      // Ignore replies to older keystrokes that arrive late.
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = data['success'] == true ? null : data['message'];
        _results = data['success'] == true
            ? (data['users'] as List).cast<Map<String, dynamic>>()
            : [];
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = 'Network error. Check your connection and try again.';
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final typedEnough = _query.text.trim().length >= 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Find people')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search by name',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: TextStyle(color: extras.text2),
                      ),
                    )
                  : _results.isEmpty
                  ? Center(
                      child: Text(
                        typedEnough && !_loading
                            ? 'No one found.'
                            : 'Type at least 2 letters.',
                        style: TextStyle(color: extras.text2),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final u = _results[i];
                        final id = u['id'] as int;
                        final name = (u['name'] as String?) ?? 'Unnamed';
                        final avg = u['avgRating'] as num?;
                        final avatar = u['avatarUrl'] as String?;
                        return ListTile(
                          leading: avatar != null && avatar.isNotEmpty
                              ? CircleAvatar(
                                  backgroundImage: CachedNetworkImageProvider(
                                    '${ApiConfig.apiRoot}$avatar',
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: colorForSeed(id),
                                  child: Text(
                                    initialsFor(name),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                          title: NameWithBadge(
                            name: name,
                            verified: u['verified'] == true,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            avg == null
                                ? 'No ratings yet'
                                : '★ ${avg.toStringAsFixed(1)} · ${u['ratingCount']} ratings',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UserProfilePage(
                                userId: id,
                                initialName: name,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
