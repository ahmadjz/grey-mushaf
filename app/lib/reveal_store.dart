import 'dart:ui';

import 'reader_settings.dart';
import 'word_marks.dart';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

typedef WordState = ({bool black, int count});
const greyWord = (black: false, count: 0);
String wordKey(String location) => 'qul-v4-hafs:$location';

class WordAction {
  WordAction(this.key, this.black) : uuid = const Uuid().v4();
  final String key;
  final bool black;
  final String uuid;
}

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

/// SQLite owns state; this map is only its committed rendering projection.
class SqliteRevealStore
    implements RevealStore, ReaderSettings, ToolbarSettings {
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
  );
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
  final String deviceId;
  final Map<String, WordState> _states;

  static Future<SqliteRevealStore> open({String? databasePath}) async {
    final db = await openDatabase(
      databasePath ?? path.join(await getDatabasesPath(), 'reveals.db'),
      version: 2,
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createMarkTables(db);
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
    final kind = action.kind.name;
    final committed = await _db.transaction((txn) async {
      final rows = await txn.query(
        'word_marks',
        where: 'word_key = ?',
        whereArgs: [action.key],
      );
      var before = noMarks;
      for (final row in rows) {
        before = before.withMark(
          MarkKind.values.byName(row['kind'] as String),
          _decodeMark(row),
        );
      }
      final duplicate = await txn.query(
        'mark_actions',
        columns: ['action_uuid'],
        where: 'action_uuid = ?',
        whereArgs: [action.uuid],
      );
      if (duplicate.isNotEmpty || before.of(action.kind) == action.mark) {
        return before;
      }
      final style = action.mark?.style.name, color = action.mark?.color.name;
      await txn.insert('mark_actions', {
        'action_uuid': action.uuid,
        'device_id': deviceId,
        'created_at': action.createdAt,
        'word_key': action.key,
        'kind': kind,
        'style': style,
        'color': color,
      });
      await txn.insert('word_marks', {
        'word_key': action.key,
        'kind': kind,
        'style': style,
        'color': color,
        'last_action_uuid': action.uuid,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return before.withMark(action.kind, action.mark);
    });
    if (committed.isEmpty) {
      _marks.remove(action.key);
    } else {
      _marks[action.key] = committed;
    }
  }

  @override
  Future<void> save(WordAction action) async {
    final committed = await _db.transaction((txn) async {
      final rows = await txn.query(
        'word_state',
        where: 'word_key = ?',
        whereArgs: [action.key],
      );
      final before = rows.isEmpty ? greyWord : _decode(rows.single);
      final duplicate = await txn.query(
        'word_actions',
        columns: ['action_uuid'],
        where: 'action_uuid = ?',
        whereArgs: [action.uuid],
      );
      if (duplicate.isNotEmpty || before.black == action.black) return before;
      await txn.insert('word_actions', {
        'action_uuid': action.uuid,
        'device_id': deviceId,
        'word_key': action.key,
        'target_black': action.black ? 1 : 0,
      });
      if (action.black) {
        await txn.insert('reveal_events', {'action_uuid': action.uuid});
      }
      final after = (
        black: action.black,
        count: before.count + (action.black ? 1 : 0),
      );
      final values = <String, Object?>{
        'word_key': action.key,
        'is_black': after.black ? 1 : 0,
        'reveal_count': after.count,
        'last_action_uuid': action.uuid,
      };
      if (rows.isEmpty) {
        await txn.insert('word_state', values);
      } else {
        await txn.update(
          'word_state',
          values,
          where: 'word_key = ?',
          whereArgs: [action.key],
        );
      }
      return after;
    });
    _states[action.key] = committed;
  }

  Future<void> close() => _db.close();
}
