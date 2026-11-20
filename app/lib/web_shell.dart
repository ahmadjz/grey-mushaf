import 'dart:async';

import 'package:flutter/material.dart';

import 'account_screen.dart';
import 'sync.dart';

class WebShell extends StatefulWidget {
  const WebShell({super.key, required this.engine, required this.openReader});
  final SyncEngine engine;
  final Future<Widget> Function() openReader;

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  String? _cookieToken;
  Future<Widget>? _readerLoad;
  Widget? _reader;
  SyncProblem? _problem;
  int _attempt = 0;

  String? get _token => widget.engine.local.syncValue('token');

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_changed);
    if (_token case final token?) unawaited(_open(token));
  }

  @override
  void dispose() {
    widget.engine.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final token = _token;
    if (token == null) {
      _attempt++;
      if (_cookieToken != null || _reader != null) {
        _closeCookie();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      _cookieToken = null;
      _readerLoad = null;
      setState(() {
        _reader = null;
        _problem = null;
      });
      return;
    }
    if (token != _cookieToken) unawaited(_open(token));
  }

  void _closeCookie() =>
      unawaited(widget.engine.api.closeWebSession().catchError((_) {}));

  Future<void> _open(String token) async {
    final attempt = ++_attempt;
    _cookieToken = token;
    _problem = null;
    try {
      await widget.engine.api.openWebSession(token);
      if (attempt != _attempt) {
        if (_token == null) _closeCookie();
        return;
      }
      final reader = await (_readerLoad ??= widget.openReader());
      if (attempt != _attempt || !mounted) return;
      setState(() => _reader = reader);
    } on SignedOut {
      if (attempt != _attempt) return;
      await widget.engine.signOut();
    } on SyncProblem catch (problem) {
      if (attempt != _attempt || !mounted) return;
      _cookieToken = null;
      setState(() => _problem = problem);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_reader case final reader?) return reader;
    final token = _token;
    if (token == null) {
      return AccountScreen(engine: widget.engine, popOnSignIn: false);
    }
    if (_problem case final problem?) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(problem.message),
              TextButton(
                onPressed: () => unawaited(_open(token)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
