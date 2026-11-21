import 'dart:async';
import 'dart:convert';

import 'package:greymushaf/sync_local.dart';
import 'package:http/http.dart' as http;

const fakeDevice = '0b7c4f2e-1111-4111-8111-111111111111';
const fakeWord = 'qul-v4-hafs:2:255:1';

class FakeLocal implements SyncLocal {
  final values = <String, String>{};
  final pending = <SyncRecord>[];
  final uploaded = <String>{};
  final applied = <SyncRecord>[];
  final _local = StreamController<void>.broadcast();

  @override
  String get deviceId => fakeDevice;
  @override
  String? syncValue(String key) => values[key];
  @override
  Future<void> saveSyncValues(Map<String, String?> changes) async {
    if (failSaves) throw StateError('disk full');
    changes.forEach((k, v) => v == null ? values.remove(k) : values[k] = v);
  }

  bool failSaves = false;
  @override
  Future<List<SyncRecord>> pendingUploads(
    SyncKind kind, {
    int limit = 200,
  }) async => failPending != null
      ? throw failPending!
      : [
          for (final r in pending)
            if (r.kind == kind && !uploaded.contains(r.uuid)) r,
        ].take(limit).toList();
  @override
  Future<int> pendingCount() async =>
      pending.where((r) => !uploaded.contains(r.uuid)).length;
  final serverTimes = <String, int>{};
  Future<void> Function()? pauseAck;
  Object? failPending;
  @override
  Future<void> markUploaded(
    SyncRecord record, {
    required int serverTime,
  }) async {
    await pauseAck?.call();
    uploaded.add(record.uuid);
    serverTimes[record.uuid] = serverTime;
  }

  @override
  Future<SyncChange> applyRemote(
    List<SyncRecord> records, {
    Map<String, String?> metadata = const {},
  }) async {
    applied.addAll(records);
    await saveSyncValues(metadata);
    return SyncChange({for (final r in records) '${r.fields['word']}'}, false);
  }

  final remote = StreamController<SyncChange>.broadcast();
  @override
  Stream<SyncChange> get remoteChanges => remote.stream;
  @override
  Stream<void> get localChanges => _local.stream;
}

class FakeServer {
  final records = <String, List<Map<String, Object?>>>{
    for (final kind in SyncKind.values) kind.collection: [],
  };
  final requests = <String>[];
  int? failNextWith;
  Future<void> Function(http.Request)? pauseCreate;
  var verified = true;
  int? clampTo;
  String user = 'user-a';
  final sessions = <String>[];
  int sessionStatus = 204;
  Future<void> Function(http.Request)? pauseSession;
  int Function(http.Request)? sessionStatusOf;

  Future<http.Response> handle(http.Request request) async {
    requests.add('${request.method} ${request.url.path}');
    if (failNextWith case final status?) {
      failNextWith = null;
      return http.Response('{"message":"x"}', status);
    }
    final path = request.url.path;
    if (path == '/api/mushaf/session') {
      sessions.add('${request.method} ${request.headers['Authorization']}');
      await pauseSession?.call(request);
      return http.Response('', sessionStatusOf?.call(request) ?? sessionStatus);
    }
    final body = request.body.isEmpty ? null : jsonDecode(request.body) as Map;
    if (path.endsWith('/auth-with-password')) {
      if (!verified) return http.Response('{"message":"x"}', 403);
      if (body!['password'] != 'right-password') {
        return http.Response('{"message":"x"}', 400);
      }
      return _json({
        'token': 'token-$user',
        'record': {'id': user, 'email': body['identity']},
      });
    }
    if (path.endsWith('/auth-refresh')) {
      return _json({
        'token': 'fresh-$user',
        'record': {'id': user, 'email': 'a@x'},
      });
    }
    final collection = path.split('/')[3];
    final list = records[collection]!;
    if (request.method == 'POST') {
      await pauseCreate?.call(request);
      if (list.any((r) => r['uuid'] == body!['uuid'])) {
        return http.Response(
          '{"data":{"uuid":{"code":"validation_not_unique"}}}',
          400,
        );
      }
      list.add({
        ...body!.cast<String, Object?>(),
        'seq': list.length + 1,
        if (clampTo != null) 'created_at': clampTo,
      });
      return _json(list.last);
    }
    final filter = request.url.queryParameters['filter']!;
    final perPage = int.parse(request.url.queryParameters['perPage']!);
    final items = filter.startsWith('seq>')
        ? list.where((r) => (r['seq'] as int) > int.parse(filter.substring(4)))
        : list.where((r) => filter == 'uuid="${r['uuid']}"');
    return _json({'items': items.take(perPage).toList()});
  }

  static http.Response _json(Object body) =>
      http.Response(jsonEncode(body), 200);
}

SyncRecord wordRecord(String uuid, {int at = 1000, bool black = true}) =>
    SyncRecord(SyncKind.word, uuid, fakeDevice, at, {
      'word': fakeWord,
      'black': black,
      'counted': black,
    });
