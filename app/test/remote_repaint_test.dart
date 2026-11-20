import 'word_target.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:greymushaf/sync.dart';
import 'package:greymushaf/sync_local.dart';
import 'package:http/testing.dart';

import 'memory_reveal_store.dart';
import 'sync_fakes.dart';

void main() {
  late List<Map<String, dynamic>> pages;
  setUpAll(() async {
    pages = await loadPages();
  });

  testWidgets('a word synced from another device repaints without a restart', (
    tester,
  ) async {
    final store = MemoryRevealStore();
    final local = FakeLocal();
    final engine = SyncEngine(
      local,
      PocketBaseApi('http://pb', client: MockClient(FakeServer().handle)),
      online: const Stream.empty(),
      poll: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: pages, store: store, sync: engine),
      ),
    );
    await tester.pumpAndSettle();
    const word = WordTarget(1);
    expect(testSemantics(tester, word).label, contains('; unrevealed;'));

    store.states[wordKey('1:1:1')] = (black: true, count: 1);
    local.remote.add(SyncChange({wordKey('1:1:1')}, false));
    await tester.pumpAndSettle();
    expect(await wordColor(tester, word), Colors.black);
    expect(
      testSemantics(tester, word).label,
      contains('; revealed; reveals 1'),
    );

    await openMenuItem(tester, 'Settings');
    expect(find.text('Not signed in · sync is off'), findsOneWidget);
  });
}
