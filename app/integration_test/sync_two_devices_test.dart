import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:greymushaf/sync.dart';
import 'package:greymushaf/word_marks.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

const _email = String.fromEnvironment('SYNC_EMAIL');
const _password = String.fromEnvironment('SYNC_PASSWORD');
const _otherEmail = String.fromEnvironment('SYNC_OTHER_EMAIL');

Future<(SqliteRevealStore, SyncEngine)> _device(String name) async {
  final store = await SqliteRevealStore.open(
    databasePath: path.join(await getDatabasesPath(), name),
  );
  final engine = SyncEngine(
    store,
    PocketBaseApi(syncServer),
    online: const Stream.empty(),
    poll: null,
  );
  return (store, engine);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline reveal on one device and a mark on the other agree', (
    tester,
  ) async {
    for (final name in ['sync-a.db', 'sync-b.db', 'sync-c.db']) {
      await deleteDatabase(path.join(await getDatabasesPath(), name));
    }
    final revealed = wordKey('2:255:1');
    final regreyed = wordKey('2:255:2');
    final marked = wordKey('2:255:3');
    const line = (style: MarkStyle.doubleLine, color: MarkColor.blue);

    var (a, syncA) = await _device('sync-a.db');
    var (b, syncB) = await _device('sync-b.db');
    await syncB.signIn(_email, _password);
    await syncB.sync();
    await a.save(WordAction(revealed, true));
    await a.save(WordAction(regreyed, true));
    await b.saveMark(MarkAction(marked, MarkKind.line, line));
    await b.save(
      WordAction(
        regreyed,
        false,
        createdAt: DateTime.now().toUtc().millisecondsSinceEpoch + 50,
      ),
    );
    await syncB.sync();
    expect(syncB.waiting, 0);
    expect(await a.pendingCount(), 2);

    syncA.dispose();
    syncB.dispose();
    await a.close();
    await b.close();
    (a, syncA) = await _device('sync-a.db');
    (b, syncB) = await _device('sync-b.db');
    expect(a.state(revealed), (black: true, count: 1));
    expect(b.marks(marked), (line: line, shape: null));

    await syncA.signIn(_email, _password);
    await syncA.sync();
    await syncB.sync();
    for (final store in [a, b]) {
      expect(store.state(revealed), (black: true, count: 1));
      expect(store.state(regreyed), (black: false, count: 1));
      expect(store.marks(marked), (line: line, shape: null));
      expect(await store.pendingCount(), 0);
    }
    expect(syncA.problem, isNull);
    expect(syncB.problem, isNull);

    final (c, syncC) = await _device('sync-c.db');
    await syncC.signIn(_otherEmail, _password);
    await syncC.sync();
    expect(syncC.problem, isNull);
    expect(c.state(revealed), greyWord);
    expect(c.marks(marked), noMarks);

    for (final engine in [syncA, syncB, syncC]) {
      engine.dispose();
    }
    for (final store in [a, b, c]) {
      await store.close();
    }
  });
}
