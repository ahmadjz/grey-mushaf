import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'sync_local.dart';

const syncServer = String.fromEnvironment(
  'SYNC_URL',
  defaultValue: 'https://mushaf.ahmadjz.tech',
);

sealed class SyncProblem implements Exception {
  const SyncProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

class Offline extends SyncProblem {
  const Offline() : super('No connection');
}

class SignedOut extends SyncProblem {
  const SignedOut() : super('Signed out, sign in again');
}

class NotVerified extends SyncProblem {
  const NotVerified() : super('This account is not verified yet');
}

class Refused extends SyncProblem {
  const Refused(super.message);
}

typedef Session = ({String token, String user, String email});

enum Created { created, duplicate }

class PocketBaseApi {
  PocketBaseApi(
    this.base, {
    http.Client? client,
    this.retryDelay = const Duration(seconds: 1),
  }) : _client = client ?? http.Client();
  final String base;
  final Duration retryDelay;
  final http.Client _client;
  static const _timeout = Duration(seconds: 20);

  Future<(int, Object?)> _send(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    final request = http.Request(method, Uri.parse('$base$path'))
      ..headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = token;
    if (body != null) request.body = jsonEncode(body);
    try {
      for (var attempt = 1; ; attempt++) {
        final response = await http.Response.fromStream(
          await _client.send(_copy(request)).timeout(_timeout),
        ).timeout(_timeout);
        if (response.statusCode == 429 && attempt < 6) {
          await Future<void>.delayed(retryDelay * attempt);
          continue;
        }
        final text = response.body;
        return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
      }
    } on SocketException {
      throw const Offline();
    } on http.ClientException {
      throw const Offline();
    } on TimeoutException {
      throw const Offline();
    } on FormatException {
      throw const Refused('The server sent something unexpected');
    }
  }

  static http.Request _copy(http.Request request) =>
      http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..body = request.body;

  static String? _message(Object? body) =>
      body is Map && body['message'] is String
      ? body['message'] as String
      : null;

  static Session _session(Object? body) {
    final map = body as Map;
    final record = map['record'] as Map;
    return (
      token: map['token'] as String,
      user: record['id'] as String,
      email: (record['email'] as String?) ?? '',
    );
  }

  Future<Session> signIn(String email, String password) async {
    final (status, body) = await _send(
      'POST',
      '/api/collections/users/auth-with-password',
      body: {'identity': email, 'password': password},
    );
    if (status == 200) return _session(body);
    if (status == 403) throw const NotVerified();
    if (status == 400) throw const Refused('Wrong email or password');
    throw Refused(_message(body) ?? 'Sign-in failed ($status)');
  }

  Future<Session> refresh(String token) async {
    final (status, body) = await _send(
      'POST',
      '/api/collections/users/auth-refresh',
      token: token,
    );
    if (status == 200) return _session(body);
    if (status == 401 || status == 403 || status == 404) {
      throw const SignedOut();
    }
    throw Refused(_message(body) ?? 'Server error ($status)');
  }

  Future<Created> create(
    String token,
    String collection,
    Map<String, Object?> body,
  ) async {
    final (status, response) = await _send(
      'POST',
      '/api/collections/$collection/records',
      body: body,
      token: token,
    );
    if (status == 200) return Created.created;
    if (status == 401) throw const SignedOut();
    if (status == 400) {
      final existing = await _find(token, collection, body['uuid'] as String);
      if (existing != null && _samePayload(existing, body)) {
        return Created.duplicate;
      }
    }
    throw Refused(_message(response) ?? 'Server refused a change ($status)');
  }

  static bool _samePayload(Map existing, Map<String, Object?> body) {
    for (final MapEntry(:key, :value) in body.entries) {
      if (key == 'created_at') continue;
      if ((existing[key] ?? '') != (value ?? '')) return false;
    }
    return true;
  }

  Future<Map?> _find(String token, String collection, String uuid) async {
    final filter = Uri.encodeQueryComponent('uuid="$uuid"');
    final (status, body) = await _send(
      'GET',
      '/api/collections/$collection/records?filter=$filter&perPage=1&skipTotal=1',
      token: token,
    );
    if (status != 200) return null;
    return ((body as Map)['items'] as List).cast<Map>().firstOrNull;
  }

  Future<List<Map>> listAfter(
    String token,
    String collection,
    int seq,
    int perPage,
  ) async {
    final filter = Uri.encodeQueryComponent('seq>$seq');
    final (status, body) = await _send(
      'GET',
      '/api/collections/$collection/records?filter=$filter&sort=seq&perPage=$perPage&skipTotal=1',
      token: token,
    );
    if (status == 401 || status == 403) throw const SignedOut();
    if (status != 200) {
      throw Refused(_message(body) ?? 'Server error ($status)');
    }
    return ((body as Map)['items'] as List).cast<Map>();
  }
}

SyncRecord? parseRemote(SyncKind kind, Map item) {
  final uuid = item['uuid'], device = item['device'];
  final createdAt = item['created_at'];
  if (uuid is! String || device is! String || createdAt is! num) return null;
  final Map<String, Object?> fields = switch (kind) {
    SyncKind.word => {
      'word': item['word'],
      'black': item['black'] == true,
      'counted': item['counted'] == true,
    },
    SyncKind.mark => {
      'word': item['word'],
      'kind': item['kind'],
      'style': item['style'] ?? '',
      'color': item['color'] ?? '',
    },
    SyncKind.bookmark => {
      'page': item['page'] is num ? (item['page'] as num).toInt() : null,
      'saved': item['saved'] == true,
    },
  };
  return SyncRecord(kind, uuid, device, createdAt.toInt(), fields);
}

class SyncEngine extends ChangeNotifier {
  SyncEngine(
    this.local,
    this.api, {
    Stream<bool>? online,
    this.poll = const Duration(seconds: 60),
    this.settle = const Duration(seconds: 3),
    this.pageSize = 200,
  }) : _online = online ?? _connectivity();

  final SyncLocal local;
  final PocketBaseApi api;
  final Duration? poll;
  final Duration settle;
  final int pageSize;
  final Stream<bool> _online;
  StreamSubscription<bool>? _onlineSubscription;
  StreamSubscription<void>? _localSubscription;
  Timer? _pollTimer;
  Timer? _settleTimer;
  int _generation = 0;
  Future<void>? _running;
  bool _again = false;

  bool syncing = false;
  int waiting = 0;
  SyncProblem? problem;

  static Stream<bool> _connectivity() => Connectivity().onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));

  String? get email => local.syncValue('email');
  bool get signedIn => local.syncValue('token') != null;
  DateTime? get lastSync {
    final value = int.tryParse(local.syncValue('last_sync') ?? '');
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<void> start() async {
    var wasOnline = true;
    _onlineSubscription = _online.listen((online) {
      if (online && !wasOnline) unawaited(sync());
      wasOnline = online;
    });
    _localSubscription = local.localChanges.listen((_) => localChanged());
    if (poll != null) {
      _pollTimer = Timer.periodic(poll!, (_) => unawaited(sync()));
    }
    await _countWaiting();
    await sync();
  }

  void localChanged() {
    unawaited(_countWaiting());
    _settleTimer?.cancel();
    _settleTimer = Timer(settle, () => unawaited(sync()));
  }

  Future<void> _countWaiting() async {
    waiting = await local.pendingCount();
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final session = await api.signIn(email.trim(), password);
    _generation++;
    final changedAccount = local.syncValue('owner') != session.user;
    if (changedAccount) await local.forgetUploads();
    await local.saveSyncValues({
      'token': session.token,
      'token_at': '${DateTime.now().millisecondsSinceEpoch}',
      'email': session.email,
      'owner': session.user,
      if (changedAccount) ...{
        for (final kind in SyncKind.values) 'cursor_${kind.name}': null,
        'last_sync': null,
      },
    });
    problem = null;
    await _countWaiting();
    unawaited(sync());
  }

  Future<void> signOut() async {
    _generation++;
    await local.saveSyncValues({'token': null, 'token_at': null});
    problem = null;
    notifyListeners();
  }

  Future<void> sync() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _once();
    } while (_again && signedIn);
  }

  Future<void> _once() async {
    final token = local.syncValue('token'), owner = local.syncValue('owner');
    if (token == null || owner == null) return;
    final generation = _generation;
    syncing = true;
    notifyListeners();
    try {
      var current = token;
      final refreshedAt = int.tryParse(local.syncValue('token_at') ?? '') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - refreshedAt > const Duration(hours: 12).inMilliseconds) {
        current = (await api.refresh(token)).token;
        if (generation != _generation) return;
        await local.saveSyncValues({'token': current, 'token_at': '$now'});
      }
      SyncProblem? refused;
      for (final kind in SyncKind.values) {
        try {
          await _push(kind, current, owner, generation);
        } on Refused catch (error) {
          refused = error;
        }
      }
      for (final kind in SyncKind.values) {
        await _pull(kind, current, generation);
      }
      if (generation != _generation) return;
      await local.saveSyncValues({
        'last_sync': '${DateTime.now().millisecondsSinceEpoch}',
      });
      problem = refused;
    } on SignedOut catch (error) {
      if (generation == _generation) {
        _generation++;
        await local.saveSyncValues({'token': null, 'token_at': null});
        problem = error;
      }
    } on SyncProblem catch (error) {
      if (generation == _generation) problem = error;
    } finally {
      syncing = false;
      await _countWaiting();
    }
  }

  Future<void> _push(
    SyncKind kind,
    String token,
    String owner,
    int generation,
  ) async {
    while (true) {
      final batch = await local.pendingUploads(kind, limit: pageSize);
      if (batch.isEmpty) return;
      for (final record in batch) {
        await api.create(token, kind.collection, {
          'user': owner,
          'uuid': record.uuid,
          'device': record.device,
          'created_at': record.createdAt,
          ...record.fields,
        });
        if (generation != _generation) return;
        await local.markUploaded([record.uuid]);
      }
    }
  }

  Future<void> _pull(SyncKind kind, String token, int generation) async {
    final key = 'cursor_${kind.name}';
    var cursor = int.tryParse(local.syncValue(key) ?? '') ?? 0;
    while (true) {
      final items = await api.listAfter(
        token,
        kind.collection,
        cursor,
        pageSize,
      );
      if (generation != _generation || items.isEmpty) return;
      final records = <SyncRecord>[];
      for (final item in items) {
        final record = parseRemote(kind, item);
        if (record != null) records.add(record);
        final seq = item['seq'];
        if (seq is num && seq.toInt() > cursor) cursor = seq.toInt();
      }
      await local.applyRemote(records, metadata: {key: '$cursor'});
      if (items.length < pageSize) return;
    }
  }

  @override
  void dispose() {
    _generation++;
    _pollTimer?.cancel();
    _settleTimer?.cancel();
    unawaited(_onlineSubscription?.cancel());
    unawaited(_localSubscription?.cancel());
    super.dispose();
  }
}
