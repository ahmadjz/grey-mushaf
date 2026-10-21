import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/reveal_store.dart';

import 'memory_reveal_store.dart';

class ControlledStore extends MemoryRevealStore {
  final calls = <WordAction>[];
  Completer<void>? pending;
  @override
  Future<void> save(WordAction action) async {
    calls.add(action);
    pending = Completer<void>();
    await pending!.future;
    await super.save(action);
  }
}

void main() {
  late List<Map<String, dynamic>> pages;
  setUpAll(() async {
    pages = await loadPages();
  });
  testWidgets(
    'failed mid-drag save retains later words until Retry commits each',
    (tester) async {
      final store = ControlledStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(pages: pages, store: store),
        ),
      );
      await tester.pumpAndSettle();
      Finder word(int id) => find.byKey(ValueKey('word-$id'));
      String label(int id) =>
          tester.widget<Semantics>(word(id)).properties.label!;
      void expectCommittedThrough(int last) {
        for (var id = 1; id <= 4; id++) {
          expect(
            label(id),
            contains(id <= last ? 'black; reveals 1' : 'grey; reveals 0'),
          );
        }
      }

      final drag = await tester.startGesture(tester.getCenter(word(1)));
      await tester.pump(const Duration(milliseconds: 600));
      await drag.moveTo(tester.getCenter(word(2)));
      await tester.pump();
      expect(store.calls.length, 1);
      expectCommittedThrough(0);
      store.pending!.completeError(StateError('disk full'));
      await tester.pumpAndSettle();
      await drag.moveTo(tester.getCenter(word(3)));
      await drag.moveTo(tester.getCenter(word(4)));
      await drag.moveTo(tester.getCenter(word(1)));
      await drag.up();
      await tester.pumpAndSettle();
      expect(
        store.calls.length,
        1,
        reason: 'later words wait for explicit Retry',
      );
      expectCommittedThrough(0);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(store.calls[1].uuid, store.calls[0].uuid);
      for (var id = 1; id <= 4; id++) {
        expect(store.calls.length, id + 1, reason: 'word $id must be queued');
        expect(store.calls.last.key, wordKey('1:1:$id'));
        expectCommittedThrough(id - 1);
        store.pending!.complete();
        await tester.pumpAndSettle();
        expectCommittedThrough(id);
      }
      expect(
        store.calls.length,
        5,
        reason: 'one retry, no duplicate from revisit',
      );
    },
  );
  testWidgets(
    'committed colours only; failed reveal and re-grey retry same action',
    (tester) async {
      final store = ControlledStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(pages: pages, store: store),
        ),
      );
      await tester.pumpAndSettle();
      final word = find.byKey(const ValueKey('word-1'));
      String label() => tester.widget<Semantics>(word).properties.label!;
      await tester.longPress(word);
      await tester.pump();
      expect(label(), contains('grey; reveals 0'));
      store.pending!.completeError(StateError('disk full'));
      await tester.pumpAndSettle();
      expect(label(), contains('grey; reveals 0'));
      expect(find.text("Couldn't save"), findsOneWidget);
      await tester.drag(find.byType(SnackBar), const Offset(0, 300));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(store.calls[1].uuid, store.calls[0].uuid);
      store.pending!.complete();
      await tester.pumpAndSettle();
      expect(label(), contains('black; reveals 1'));
      await tester.tap(word);
      await tester.pump();
      expect(label(), contains('black; reveals 1'));
      store.pending!.completeError(StateError('disk full'));
      await tester.pumpAndSettle();
      expect(label(), contains('black; reveals 1'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(store.calls[3].uuid, store.calls[2].uuid);
      store.pending!.complete();
      await tester.pumpAndSettle();
      expect(label(), contains('grey; reveals 1'));
    },
  );
}
