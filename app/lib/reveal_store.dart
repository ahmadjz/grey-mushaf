import 'dart:async';
import 'dart:ui';

import 'bookmarks.dart';
import 'reader_settings.dart';
import 'sync_local.dart';
import 'word_marks.dart';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

typedef WordState = ({bool black, int count});
const greyWord = (black: false, count: 0);
String wordKey(String location) => 'qul-v4-hafs:$location';

class WordAction {
  WordAction(this.key, this.black, {int? createdAt})
    : uuid = const Uuid().v4(),
      createdAt = createdAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
  final String key;
  final bool black;
  final String uuid;
  final int createdAt;
}

final _wordKeyPattern = RegExp(r'^qul-v4-hafs:\d{1,3}:\d{1,3}:\d{1,3}$');

abstract class RevealStore {
  WordState state(String key);
  Future<void> save(WordAction action);
  WordMarks marks(String key);
  Future<void> saveMark(MarkAction action);
}

const _styles = "'singleLine','doubleLine','rectangle','circle'";
const _colors = "'red','blue','green','orange','purple','black'";
const _markCheck =
    '''CHECK ((style IS NULL AND color IS NULL) OR (style IS NOT NULL AND color IS NOT NULL
    AND color IN ($_colors)
    AND ((kind = 'line' AND style IN ('singleLine','doubleLine'))
      OR (kind = 'shape' AND style IN ('rectangle','circle')))))''';

Future<void> _createMarkTables(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE mark_actions (
    local_seq INTEGER PRIMARY KEY AUTOINCREMENT,
    action_uuid TEXT UNIQUE NOT NULL, device_id TEXT NOT NULL,
    created_at INTEGER NOT NULL, word_key TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('line','shape')),
    style TEXT CHECK(style IS NULL OR style IN ($_styles)), color TEXT,
    $_markCheck)''');
  await db.execute(
    'CREATE INDEX mark_actions_by_word ON mark_actions(word_key)',
  );
  await db.execute('''CREATE TABLE word_marks (
    word_key TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('line','shape')),
    style TEXT, color TEXT,
    last_action_uuid TEXT NOT NULL REFERENCES mark_actions(action_uuid),
    PRIMARY KEY (word_key, kind),
    $_markCheck)''');
}

Future<void> _createBookmarkTables(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE bookmark_actions (
    local_seq INTEGER PRIMARY KEY AUTOINCREMENT,
    action_uuid TEXT UNIQUE NOT NULL, device_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    page INTEGER NOT NULL CHECK(page BETWEEN 1 AND 604),
    saved INTEGER NOT NULL CHECK(saved IN (0,1)))''');
  await db.execute(
    '''CREATE TABLE bookmarks (
    page INTEGER PRIMARY KEY NOT NULL CHECK(page BETWEEN 1 AND 604),
    saved INTEGER NOT NULL CHECK(saved IN (0,1)),
    saved_at INTEGER NOT NULL,
    last_action_uuid TEXT NOT NULL REFERENCES bookmark_actions(action_uuid))''',
  );
}

// Pre-v4 word actions have no time row and sort by local_seq, before any timed action.
Future<void> _createSyncTables(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE word_action_times (
    action_uuid TEXT PRIMARY KEY NOT NULL REFERENCES word_actions(action_uuid),
    created_at INTEGER NOT NULL)''');
  await db.execute(
    'CREATE TABLE uploaded_actions (action_uuid TEXT PRIMARY KEY NOT NULL)',
  );
}

const _wordTime = 'COALESCE(t.created_at, w.local_seq)';
const _wordActionsTimed =
    'word_actions w LEFT JOIN word_action_times t ON t.action_uuid = w.action_uuid';
String _notUploaded(String alias) =>
    'NOT EXISTS (SELECT 1 FROM uploaded_actions u WHERE u.action_uuid = $alias.action_uuid)';
const _syncPrefix = 'sync_';

/// SQLite owns state; this map is only its committed rendering projection.
class SqliteRevealStore
    implements
        RevealStore,
        ReaderSettings,
        ToolbarSettings,
        NavigationStore,
        SyncLocal {
  SqliteRevealStore._(
    this._db,
    this.deviceId,
    this._states,
    this._marks,
    this._toolbar,
    this._greyLevel,
    this._darkLevel,
    this._arrowsShown,
    this._arrowSpots,
    this._lastPage,
    this._bookmarks,
    this._blackWhite,
    this._sync,
  );
  bool? _blackWhite;
  final Map<String, String> _sync;
  final _remoteChanges = StreamController<SyncChange>.broadcast();

  @override
  bool? get blackWhite => _blackWhite;

  @override
  Future<void> saveBlackWhite(bool on) async {
    await _db.insert('local_metadata', {
      'key': _blackWhiteKey,
      'value': on ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _blackWhite = on;
  }

  static const _blackWhiteKey = 'reader_black_white';
  int _lastPage;
  final Map<int, int> _bookmarks;

  @override
  int get lastPage => _lastPage;

  @override
  Future<void> saveLastPage(int page) async {
    if (page < 1 || page > 604) throw RangeError.range(page, 1, 604, 'page');
    await _db.insert('local_metadata', {
      'key': _lastPageKey,
      'value': '$page',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _lastPage = page;
  }

  static const _lastPageKey = 'reader_last_page';

  @override
  Map<int, int> get bookmarkSavedAt => Map.unmodifiable(_bookmarks);

  // A removal keeps its row (saved = 0) so sync knows the latest action.
  @override
  Future<void> saveBookmarks(List<BookmarkAction> actions) async {
    final committed = await _db.transaction((txn) async {
      final changes = <int, int?>{};
      for (final action in actions) {
        if (await _known(txn, 'bookmark_actions', action.uuid)) continue;
        final at = _after(
          await _latest(
            txn,
            'SELECT MAX(created_at) AS latest FROM bookmark_actions WHERE device_id = ?',
            [deviceId],
          ),
          action.createdAt,
        );
        await txn.insert('bookmark_actions', {
          'action_uuid': action.uuid,
          'device_id': deviceId,
          'created_at': at,
          'page': action.page,
          'saved': action.saved ? 1 : 0,
        });
        changes[action.page] = await _settleBookmark(txn, action.page);
      }
      return changes;
    });
    _applyBookmarks(committed);
  }

  void _applyBookmarks(Map<int, int?> changes) => changes.forEach((page, at) {
    if (at == null) {
      _bookmarks.remove(page);
    } else {
      _bookmarks[page] = at;
    }
  });

  static Future<bool> _known(
    DatabaseExecutor txn,
    String table,
    String uuid,
  ) async => (await txn.query(
    table,
    columns: ['action_uuid'],
    where: 'action_uuid = ?',
    whereArgs: [uuid],
  )).isNotEmpty;

  static Future<int?> _latest(
    DatabaseExecutor txn,
    String sql,
    List<Object?> args,
  ) async => (await txn.rawQuery(sql, args)).single['latest'] as int?;

  // This device's actions keep their order even when its clock steps back.
  static int _after(int? latest, int createdAt) =>
      latest != null && latest >= createdAt ? latest + 1 : createdAt;

  static Future<int?> _settleBookmark(DatabaseExecutor txn, int page) async {
    final winner = (await txn.query(
      'bookmark_actions',
      where: 'page = ?',
      whereArgs: [page],
      orderBy: 'created_at DESC, action_uuid DESC',
      limit: 1,
    )).single;
    final saved = winner['saved'] == 1;
    final at = winner['created_at'] as int;
    await txn.insert('bookmarks', {
      'page': page,
      'saved': saved ? 1 : 0,
      'saved_at': at,
      'last_action_uuid': winner['action_uuid'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return saved ? at : null;
  }

  bool _arrowsShown;
  final Map<String, Offset> _arrowSpots;
  final Map<String, WordMarks> _marks;
  ToolbarPrefs _toolbar;
  @override
  ToolbarPrefs get toolbar => _toolbar;

  @override
  Future<void> saveToolbar(ToolbarPrefs prefs) async {
    await _db.insert('local_metadata', {
      'key': _toolbarKey,
      'value': prefs.encode(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _toolbar = prefs;
  }

  static const _toolbarKey = 'reader_toolbar';
  @override
  bool get arrowsShown => _arrowsShown;
  @override
  Map<String, Offset> get arrowSpots => Map.unmodifiable(_arrowSpots);

  @override
  Future<void> saveArrowsShown(bool shown) async {
    await _db.insert('local_metadata', {
      'key': 'reader_arrows_shown',
      'value': shown ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _arrowsShown = shown;
  }

  @override
  Future<void> saveArrowSpot(String key, Offset spot) async {
    if (!_onScreen(spot.dx) || !_onScreen(spot.dy)) {
      throw RangeError('Arrow spot $spot is outside the screen');
    }
    await _db.insert('local_metadata', {
      'key': '$_arrowSpotPrefix$key',
      'value': '${spot.dx},${spot.dy}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _arrowSpots[key] = spot;
  }

  static const _arrowSpotPrefix = 'reader_arrow_spot_';
  static bool _onScreen(double fraction) => fraction >= 0 && fraction <= 1;

  int _greyLevel;
  int _darkLevel;
  @override
  int get darkLevel => _darkLevel;

  @override
  Future<void> saveDarkLevel(int level) async {
    if (level < 32 || level > 128) throw RangeError.range(level, 32, 128);
    await _db.insert('local_metadata', {
      'key': 'reader_dark_level',
      'value': '$level',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _darkLevel = level;
  }

  @override
  int get greyLevel => _greyLevel;

  @override
  Future<void> saveGreyLevel(int level) async {
    if (level < 128 || level > 224) throw RangeError.range(level, 128, 224);
    await _db.insert('local_metadata', {
      'key': 'reader_grey_level',
      'value': '$level',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _greyLevel = level;
  }

  final Database _db;
  @override
  final String deviceId;
  final Map<String, WordState> _states;

  static Future<SqliteRevealStore> open({String? databasePath}) async {
    final db = await openDatabase(
      databasePath ?? path.join(await getDatabasesPath(), 'reveals.db'),
      version: 4,
      onDowngrade: (db, oldVersion, newVersion) {
        throw StateError(
          'Database version $oldVersion is newer than supported version $newVersion. '
          'Use a newer app to open this data.',
        );
      },
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE local_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          '''CREATE TABLE word_actions (
          local_seq INTEGER PRIMARY KEY AUTOINCREMENT,
          action_uuid TEXT UNIQUE NOT NULL, device_id TEXT NOT NULL,
          word_key TEXT NOT NULL, target_black INTEGER NOT NULL CHECK(target_black IN (0,1)))''',
        );
        await db.execute(
          'CREATE INDEX actions_by_word ON word_actions(word_key)',
        );
        await db.execute(
          '''CREATE TABLE reveal_events (
          action_uuid TEXT PRIMARY KEY NOT NULL REFERENCES word_actions(action_uuid))''',
        );
        await db.execute(
          '''CREATE TABLE word_state (
          word_key TEXT PRIMARY KEY NOT NULL,
          is_black INTEGER NOT NULL CHECK(is_black IN (0,1)),
          reveal_count INTEGER NOT NULL CHECK(reveal_count >= 0),
          last_action_uuid TEXT NOT NULL REFERENCES word_actions(action_uuid))''',
        );
        await db.insert('local_metadata', {
          'key': 'device_id',
          'value': const Uuid().v4(),
        });
        await db.insert('local_metadata', {
          'key': 'identity_version',
          'value': 'qul-v4-hafs:1',
        });
        await _createMarkTables(db);
        await _createBookmarkTables(db);
        await _createSyncTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createMarkTables(db);
        if (oldVersion < 3) await _createBookmarkTables(db);
        if (oldVersion < 4) await _createSyncTables(db);
      },
    );
    try {
      final device =
          (await db.query(
                'local_metadata',
                where: 'key = ?',
                whereArgs: ['device_id'],
              )).single['value']
              as String;
      final states = <String, WordState>{};
      for (final row in await db.query('word_state')) {
        states[row['word_key'] as String] = _decode(row);
      }
      final setting = await db.query(
        'local_metadata',
        where: 'key = ?',
        whereArgs: ['reader_grey_level'],
      );
      final parsed = setting.isEmpty
          ? null
          : int.tryParse(setting.single['value'] as String);
      final grey = parsed != null && parsed >= 128 && parsed <= 224
          ? parsed
          : 176;
      final darkSetting = await db.query(
        'local_metadata',
        where: 'key = ?',
        whereArgs: ['reader_dark_level'],
      );
      final darkParsed = darkSetting.isEmpty
          ? null
          : int.tryParse(darkSetting.single['value'] as String);
      final dark = darkParsed != null && darkParsed >= 32 && darkParsed <= 128
          ? darkParsed
          : 80;
      final arrowsShown =
          (await db.query(
            'local_metadata',
            where: 'key = ?',
            whereArgs: ['reader_arrows_shown'],
          )).firstOrNull?['value'] !=
          '0';
      final spots = <String, Offset>{};
      for (final row in await db.query(
        'local_metadata',
        where: 'key LIKE ?',
        whereArgs: ['$_arrowSpotPrefix%'],
      )) {
        final parts = (row['value'] as String).split(',');
        final x = parts.length == 2 ? double.tryParse(parts[0]) : null;
        final y = parts.length == 2 ? double.tryParse(parts[1]) : null;
        if (x == null || y == null || !_onScreen(x) || !_onScreen(y)) {
          continue;
        }
        spots[(row['key'] as String).substring(_arrowSpotPrefix.length)] =
            Offset(x, y);
      }
      final marks = <String, WordMarks>{};
      for (final row in await db.query(
        'word_marks',
        where: 'style IS NOT NULL',
      )) {
        final key = row['word_key'] as String;
        final kind = MarkKind.values.byName(row['kind'] as String);
        marks[key] = (marks[key] ?? noMarks).withMark(kind, _decodeMark(row));
      }
      final toolbar = ToolbarPrefs.decode(
        (await db.query(
              'local_metadata',
              where: 'key = ?',
              whereArgs: [_toolbarKey],
            )).firstOrNull?['value']
            as String?,
      );
      final lastPage = int.tryParse(
        (await db.query(
                  'local_metadata',
                  where: 'key = ?',
                  whereArgs: [_lastPageKey],
                )).firstOrNull?['value']
                as String? ??
            '',
      );
      final bookmarks = {
        for (final row in await db.query('bookmarks', where: 'saved = 1'))
          row['page'] as int: row['saved_at'] as int,
      };
      return SqliteRevealStore._(
        db,
        device,
        states,
        marks,
        toolbar,
        grey,
        dark,
        arrowsShown,
        spots,
        lastPage != null && lastPage >= 1 && lastPage <= 604 ? lastPage : 1,
        bookmarks,
        switch ((await db.query(
          'local_metadata',
          where: 'key = ?',
          whereArgs: [_blackWhiteKey],
        )).firstOrNull?['value']) {
          '1' => true,
          '0' => false,
          _ => null,
        },
        {
          for (final row in await db.query(
            'local_metadata',
            where: 'key LIKE ?',
            whereArgs: ['$_syncPrefix%'],
          ))
            (row['key'] as String).substring(_syncPrefix.length):
                row['value'] as String,
        },
      );
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  static WordState _decode(Map<String, Object?> row) =>
      (black: row['is_black'] == 1, count: row['reveal_count'] as int);

  static Mark? _decodeMark(Map<String, Object?> row) => row['style'] == null
      ? null
      : (
          style: MarkStyle.values.byName(row['style'] as String),
          color: MarkColor.values.byName(row['color'] as String),
        );

  @override
  WordState state(String key) => _states[key] ?? greyWord;

  @override
  WordMarks marks(String key) => _marks[key] ?? noMarks;

  // A removal keeps its row (null style) so sync knows the latest action.
  @override
  Future<void> saveMark(MarkAction action) async {
    final committed = await _db.transaction((txn) async {
      if (await _known(txn, 'mark_actions', action.uuid)) return null;
      final at = _after(
        await _latest(
          txn,
          'SELECT MAX(created_at) AS latest FROM mark_actions WHERE word_key = ? AND kind = ? AND device_id = ?',
          [action.key, action.kind.name, deviceId],
        ),
        action.createdAt,
      );
      await txn.insert('mark_actions', {
        'action_uuid': action.uuid,
        'device_id': deviceId,
        'created_at': at,
        'word_key': action.key,
        'kind': action.kind.name,
        'style': action.mark?.style.name,
        'color': action.mark?.color.name,
      });
      await _settleMark(txn, action.key, action.kind);
      return _readMarks(txn, action.key);
    });
    if (committed != null) _applyMarks(action.key, committed);
  }

  void _applyMarks(String key, WordMarks marks) {
    if (marks.isEmpty) {
      _marks.remove(key);
    } else {
      _marks[key] = marks;
    }
  }

  static Future<WordMarks> _readMarks(DatabaseExecutor txn, String key) async {
    var marks = noMarks;
    for (final row in await txn.query(
      'word_marks',
      where: 'word_key = ?',
      whereArgs: [key],
    )) {
      marks = marks.withMark(
        MarkKind.values.byName(row['kind'] as String),
        _decodeMark(row),
      );
    }
    return marks;
  }

  static Future<void> _settleMark(
    DatabaseExecutor txn,
    String key,
    MarkKind kind,
  ) async {
    final winner = (await txn.query(
      'mark_actions',
      where: 'word_key = ? AND kind = ?',
      whereArgs: [key, kind.name],
      orderBy: 'created_at DESC, action_uuid DESC',
      limit: 1,
    )).single;
    await txn.insert('word_marks', {
      'word_key': key,
      'kind': kind.name,
      'style': winner['style'],
      'color': winner['color'],
      'last_action_uuid': winner['action_uuid'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> save(WordAction action) async {
    final committed = await _db.transaction((txn) async {
      if (await _known(txn, 'word_actions', action.uuid)) return null;
      final before = await _readWord(txn, action.key);
      final at = _after(
        await _latest(
          txn,
          'SELECT MAX($_wordTime) AS latest FROM $_wordActionsTimed WHERE w.word_key = ? AND w.device_id = ?',
          [action.key, deviceId],
        ),
        action.createdAt,
      );
      await txn.insert('word_actions', {
        'action_uuid': action.uuid,
        'device_id': deviceId,
        'word_key': action.key,
        'target_black': action.black ? 1 : 0,
      });
      await txn.insert('word_action_times', {
        'action_uuid': action.uuid,
        'created_at': at,
      });
      if (action.black && !(before?.black ?? false)) {
        await txn.insert('reveal_events', {'action_uuid': action.uuid});
      }
      return _settleWord(txn, action.key, exists: before != null);
    });
    if (committed != null) _states[action.key] = committed;
  }

  static Future<WordState?> _readWord(DatabaseExecutor txn, String key) async {
    final rows = await txn.query(
      'word_state',
      where: 'word_key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : _decode(rows.single);
  }

  static Future<WordState> _settleWord(
    DatabaseExecutor txn,
    String key, {
    required bool exists,
  }) async {
    final winner = (await txn.rawQuery(
      'SELECT w.action_uuid, w.target_black FROM $_wordActionsTimed '
      'WHERE w.word_key = ? ORDER BY $_wordTime DESC, w.action_uuid DESC LIMIT 1',
      [key],
    )).single;
    final count =
        (await txn.rawQuery(
              'SELECT COUNT(*) AS n FROM reveal_events r JOIN word_actions w '
              'ON w.action_uuid = r.action_uuid WHERE w.word_key = ?',
              [key],
            )).single['n']
            as int;
    final values = <String, Object?>{
      'word_key': key,
      'is_black': winner['target_black'],
      'reveal_count': count,
      'last_action_uuid': winner['action_uuid'],
    };
    if (exists) {
      await txn.update(
        'word_state',
        values,
        where: 'word_key = ?',
        whereArgs: [key],
      );
    } else {
      await txn.insert('word_state', values);
    }
    return _decode(values);
  }

  @override
  String? syncValue(String key) => _sync[key];

  @override
  Future<void> saveSyncValues(Map<String, String?> values) async {
    await _db.transaction((txn) => _writeSyncValues(txn, values));
    _cacheSyncValues(values);
  }

  static Future<void> _writeSyncValues(
    DatabaseExecutor txn,
    Map<String, String?> values,
  ) async {
    for (final MapEntry(:key, :value) in values.entries) {
      if (value == null) {
        await txn.delete(
          'local_metadata',
          where: 'key = ?',
          whereArgs: ['$_syncPrefix$key'],
        );
      } else {
        await txn.insert('local_metadata', {
          'key': '$_syncPrefix$key',
          'value': value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  void _cacheSyncValues(Map<String, String?> values) {
    for (final MapEntry(:key, :value) in values.entries) {
      if (value == null) {
        _sync.remove(key);
      } else {
        _sync[key] = value;
      }
    }
  }

  @override
  Future<List<SyncRecord>> pendingUploads(
    SyncKind kind, {
    int limit = 200,
  }) async {
    switch (kind) {
      case SyncKind.word:
        final rows = await _db.rawQuery(
          'SELECT w.action_uuid, w.device_id, $_wordTime AS created_at, w.word_key, '
          'w.target_black, r.action_uuid IS NOT NULL AS counted '
          'FROM $_wordActionsTimed LEFT JOIN reveal_events r ON r.action_uuid = w.action_uuid '
          'WHERE ${_notUploaded('w')} ORDER BY w.local_seq LIMIT ?',
          [limit],
        );
        return [
          for (final row in rows)
            _record(kind, row, {
              'word': row['word_key'],
              'black': row['target_black'] == 1,
              'counted': row['counted'] == 1,
            }),
        ];
      case SyncKind.mark:
        final rows = await _db.rawQuery(
          'SELECT * FROM mark_actions a WHERE ${_notUploaded('a')} ORDER BY a.local_seq LIMIT ?',
          [limit],
        );
        return [
          for (final row in rows)
            _record(kind, row, {
              'word': row['word_key'],
              'kind': row['kind'],
              'style': row['style'] ?? '',
              'color': row['color'] ?? '',
            }),
        ];
      case SyncKind.bookmark:
        final rows = await _db.rawQuery(
          'SELECT * FROM bookmark_actions a WHERE ${_notUploaded('a')} ORDER BY a.local_seq LIMIT ?',
          [limit],
        );
        return [
          for (final row in rows)
            _record(kind, row, {
              'page': row['page'],
              'saved': row['saved'] == 1,
            }),
        ];
    }
  }

  static SyncRecord _record(
    SyncKind kind,
    Map<String, Object?> row,
    Map<String, Object?> fields,
  ) => SyncRecord(
    kind,
    row['action_uuid'] as String,
    row['device_id'] as String,
    row['created_at'] as int,
    fields,
  );

  @override
  Future<int> pendingCount() async {
    var total = 0;
    for (final table in ['word_actions', 'mark_actions', 'bookmark_actions']) {
      total +=
          (await _db.rawQuery(
                'SELECT COUNT(*) AS n FROM $table a WHERE ${_notUploaded('a')}',
              )).single['n']
              as int;
    }
    return total;
  }

  @override
  Future<void> markUploaded(Iterable<String> uuids) =>
      _db.transaction((txn) async {
        for (final uuid in uuids) {
          await txn.insert('uploaded_actions', {
            'action_uuid': uuid,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      });

  @override
  Future<void> forgetUploads() => _db.delete('uploaded_actions');

  @override
  Stream<SyncChange> get remoteChanges => _remoteChanges.stream;

  @override
  Future<SyncChange> applyRemote(
    List<SyncRecord> records, {
    Map<String, String?> metadata = const {},
  }) async {
    final (words, marks, pages) = await _db.transaction((txn) async {
      final words = <String, bool>{};
      final marks = <String, Set<MarkKind>>{};
      final pages = <int>{};
      for (final record in records) {
        if (!await _insertRemote(txn, record, words, marks, pages)) continue;
        await txn.insert('uploaded_actions', {
          'action_uuid': record.uuid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      final states = <String, WordState>{
        for (final MapEntry(:key, :value) in words.entries)
          key: await _settleWord(txn, key, exists: value),
      };
      final settledMarks = <String, WordMarks>{};
      for (final MapEntry(:key, :value) in marks.entries) {
        for (final kind in value) {
          await _settleMark(txn, key, kind);
        }
        settledMarks[key] = await _readMarks(txn, key);
      }
      final bookmarks = <int, int?>{
        for (final page in pages) page: await _settleBookmark(txn, page),
      };
      await _writeSyncValues(txn, metadata);
      return (states, settledMarks, bookmarks);
    });
    _states.addAll(words);
    marks.forEach(_applyMarks);
    _applyBookmarks(pages);
    _cacheSyncValues(metadata);
    final change = SyncChange({...words.keys, ...marks.keys}, pages.isNotEmpty);
    if (!change.isEmpty) _remoteChanges.add(change);
    return change;
  }

  // Returns false for a known or malformed record, which is skipped.
  Future<bool> _insertRemote(
    Transaction txn,
    SyncRecord record,
    Map<String, bool> words,
    Map<String, Set<MarkKind>> marks,
    Set<int> pages,
  ) async {
    final fields = record.fields;
    final base = {'action_uuid': record.uuid, 'device_id': record.device};
    switch (record.kind) {
      case SyncKind.word:
        final key = fields['word'], black = fields['black'];
        final counted = fields['counted'] == true;
        if (key is! String ||
            !_wordKeyPattern.hasMatch(key) ||
            black is! bool) {
          return false;
        }
        if (counted && !black) return false;
        if (await _known(txn, 'word_actions', record.uuid)) return false;
        words[key] ??= await _readWord(txn, key) != null;
        await txn.insert('word_actions', {
          ...base,
          'word_key': key,
          'target_black': black ? 1 : 0,
        });
        await txn.insert('word_action_times', {
          'action_uuid': record.uuid,
          'created_at': record.createdAt,
        });
        if (counted) {
          await txn.insert('reveal_events', {'action_uuid': record.uuid});
        }
      case SyncKind.mark:
        final key = fields['word'];
        final kind = MarkKind.values.asNameMap()[fields['kind']];
        final style = MarkStyle.values.asNameMap()[fields['style']];
        final color = MarkColor.values.asNameMap()[fields['color']];
        final removal = fields['style'] == '' && fields['color'] == '';
        if (key is! String || !_wordKeyPattern.hasMatch(key) || kind == null) {
          return false;
        }
        if (!removal && (style?.kind != kind || color == null)) return false;
        if (await _known(txn, 'mark_actions', record.uuid)) return false;
        await txn.insert('mark_actions', {
          ...base,
          'created_at': record.createdAt,
          'word_key': key,
          'kind': kind.name,
          'style': removal ? null : style!.name,
          'color': removal ? null : color!.name,
        });
        (marks[key] ??= {}).add(kind);
      case SyncKind.bookmark:
        final page = fields['page'], saved = fields['saved'];
        if (page is! int || page < 1 || page > 604 || saved is! bool) {
          return false;
        }
        if (await _known(txn, 'bookmark_actions', record.uuid)) return false;
        await txn.insert('bookmark_actions', {
          ...base,
          'created_at': record.createdAt,
          'page': page,
          'saved': saved ? 1 : 0,
        });
        pages.add(page);
    }
    return true;
  }

  Future<void> close() async {
    await _remoteChanges.close();
    await _db.close();
  }
}
