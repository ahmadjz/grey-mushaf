import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  Future<void> _cookieCalls = Future.value();
  String? _cookieToken;
  bool _cookieCleared = false;
  Future<Widget>? _readerLoad;
  Widget? _reader;
  String? _problem;

  String? get _token => widget.engine.local.syncValue('token');

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_changed);
    _settleCookie();
  }

  @override
  void dispose() {
    widget.engine.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_token == null && (_reader != null || _readerLoad != null)) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      _reader = null;
      _readerLoad = null;
      _problem = null;
    }
    setState(() {});
    _settleCookie();
  }

  void _settleCookie() {
    _cookieCalls = _cookieCalls.then((_) => _cookieStep());
  }

  Future<void> _cookieStep() async {
    if (!mounted) return;
    final token = _token;
    final api = widget.engine.api;
    if (token == null) {
      if (_cookieCleared) return;
      try {
        await api.closeWebSession();
        _cookieCleared = true;
        _cookieToken = null;
      } on Object {
        return;
      }
      return;
    }
    if (token != _cookieToken) {
      try {
        await api.openWebSession(token);
      } on SignedOut {
        await widget.engine.signOut();
        return;
      } on SyncProblem catch (problem) {
        if (mounted && _token == token) {
          setState(() => _problem = problem.message);
        }
        return;
      }
      _cookieToken = token;
      _cookieCleared = false;
    }
    _loadReader();
  }

  void _loadReader() {
    if (_token == null) return;
    if (_reader != null || _readerLoad != null || _problem != null) return;
    final load = _readerLoad = widget.openReader();
    load.then(
      (reader) {
        if (!mounted || _readerLoad != load) return;
        setState(() => _reader = reader);
      },
      onError: (Object _) {
        if (!mounted || _readerLoad != load) return;
        setState(() {
          _readerLoad = null;
          _problem = "Couldn't load the mushaf";
        });
      },
    );
  }

  void _retry() {
    rootBundle.clear();
    setState(() => _problem = null);
    _settleCookie();
  }

  @override
  Widget build(BuildContext context) {
    if (_reader case final reader?) return reader;
    if (_token == null) {
      return AccountScreen(engine: widget.engine, popOnSignIn: false);
    }
    if (_problem case final problem?) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(problem),
              TextButton(onPressed: _retry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
