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
  testWidgets(
    'committed colours only; failed reveal and re-grey retry same action',
    (tester) async {
      final store = ControlledStore();
      final pages = await loadPages();
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
