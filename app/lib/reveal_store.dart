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
}

/// SQLite owns state; this map is only its committed rendering projection.
class SqliteRevealStore implements RevealStore {
  SqliteRevealStore._(this._db, this.deviceId, this._states);
  final Database _db;
  final String deviceId;
  final Map<String, WordState> _states;

  static Future<SqliteRevealStore> open({String? databasePath}) async {
    final db = await openDatabase(
      databasePath ?? path.join(await getDatabasesPath(), 'reveals.db'),
      version: 1,
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
      return SqliteRevealStore._(db, device, states);
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  static WordState _decode(Map<String, Object?> row) =>
      (black: row['is_black'] == 1, count: row['reveal_count'] as int);

  @override
  WordState state(String key) => _states[key] ?? greyWord;

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
