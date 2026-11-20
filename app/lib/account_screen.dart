import 'dart:async';

import 'package:flutter/material.dart';

import 'sync.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.engine});
  final SyncEngine engine;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _address => _email.text.trim();

  Future<void> _run(Future<String?> Function() action) async {
    if (_address.isEmpty) {
      setState(() => _message = 'Enter your email');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      message = await action();
    } on SyncProblem catch (error) {
      message = error.message;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  Future<void> _signIn() => _run(() async {
    await widget.engine.signIn(_address, _password.text);
    if (mounted) Navigator.pop(context);
    return null;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const ValueKey('account-email'),
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('account-password'),
            controller: _password,
            enabled: !_busy,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => unawaited(_signIn()),
          ),
          const SizedBox(height: 16),
          if (_message != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_message!),
              ),
            ),
          FilledButton(
            onPressed: _busy ? null : _signIn,
            child: const Text('Sign in'),
          ),
          const SizedBox(height: 8),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}

String syncSummary(SyncEngine engine, DateTime now) {
  final last = engine.lastSync;
  String time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  const months = [
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
  final when = last == null
      ? 'Not synced yet'
      : last.year == now.year && last.month == now.month && last.day == now.day
      ? 'Last sync ${time(last)}'
      : 'Last sync ${last.day} ${months[last.month - 1]} ${time(last)}';
  final waiting = switch (engine.waiting) {
    0 => 'no changes waiting',
    1 => '1 change waiting',
    final n => '$n changes waiting',
  };
  return '$when · $waiting';
}

class SyncSettings extends StatelessWidget {
  const SyncSettings({super.key, required this.engine, required this.theme});
  final SyncEngine engine;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final problem = engine.problem?.message;
      if (!engine.signedIn) {
        return ListTile(
          key: const ValueKey('account-row'),
          leading: const Icon(Icons.account_circle_outlined),
          title: const Text('Account'),
          subtitle: Text(problem ?? 'Not signed in · sync is off'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => Theme(
                data: theme,
                child: AccountScreen(engine: engine),
              ),
            ),
          ),
        );
      }
      return Column(
        children: [
          ListTile(
            key: const ValueKey('account-row'),
            leading: const Icon(Icons.account_circle),
            title: const Text('Account'),
            subtitle: Text(engine.email ?? ''),
            trailing: TextButton(
              onPressed: () => unawaited(engine.signOut()),
              child: const Text('Sign out'),
            ),
          ),
          ListTile(
            key: const ValueKey('sync-now'),
            leading: const Icon(Icons.sync),
            title: const Text('Sync now'),
            subtitle: Text(
              [syncSummary(engine, DateTime.now()), ?problem].join('\n'),
            ),
            trailing: engine.syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: engine.syncing ? null : () => unawaited(engine.sync()),
          ),
        ],
      );
    },
  );
}
