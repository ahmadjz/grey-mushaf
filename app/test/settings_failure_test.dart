import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/reader_settings.dart';

import 'memory_reveal_store.dart';

class FailingSettings implements ReaderSettings {
  @override
  int greyLevel = 176;
  @override
  int darkLevel = 80;
  @override
  Future<void> saveDarkLevel(int level) async {
    pending = Completer<void>();
    await pending!.future;
    darkLevel = level;
  }

  Completer<void>? pending;
  @override
  Future<void> saveGreyLevel(int level) async {
    pending = Completer<void>();
    await pending!.future;
    greyLevel = level;
  }
}

void main() {
  late List<Map<String, dynamic>> pages;
  setUpAll(() async => pages = await loadPages());
  testWidgets(
    'dark saves serialize and retry the dark level after switching light',
    (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = FailingSettings();
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(
            pages: pages,
            store: MemoryRevealStore(),
            settings: settings,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(3, 450));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      var slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(32);
      slider.onChangeEnd!(32);
      await tester.pump();
      final first = settings.pending!;
      slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(128);
      slider.onChangeEnd!(128);
      await tester.pump();
      expect(identical(settings.pending, first), true);
      first.complete();
      await tester.pump();
      expect(settings.darkLevel, 32);
      expect(identical(settings.pending, first), false);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      settings.pending!.completeError(StateError('dark save failure'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't save dark level").hitTestable(),
        findsOneWidget,
      );
      expect(tester.widget<Slider>(find.byType(Slider)).value, 176);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      settings.pending!.complete();
      await tester.pumpAndSettle();
      expect(settings.darkLevel, 128);
      expect(settings.greyLevel, 176);
      expect(find.text("Couldn't save dark level"), findsNothing);
    },
  );

  testWidgets(
    'failed grey save offers visible Retry inside the open Settings sheet',
    (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = FailingSettings();
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(
            pages: pages,
            store: MemoryRevealStore(),
            settings: settings,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(3, 450));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(224);
      slider.onChangeEnd!(224);
      await tester.pump();
      settings.pending!.completeError(StateError('injected write failure'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      final error = find.descendant(
        of: sheet,
        matching: find.text("Couldn't save grey level"),
      );
      final retry = find.descendant(of: sheet, matching: find.text('Retry'));
      expect(error.hitTestable(), findsOneWidget);
      expect(retry.hitTestable(), findsOneWidget);
      expect(settings.greyLevel, 176);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 224);
      await tester.tap(retry);
      await tester.pump();
      settings.pending!.complete();
      await tester.pumpAndSettle();
      expect(settings.greyLevel, 224);
      expect(error, findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      // If the sheet closes before a pending write fails, feedback belongs
      // to the reader instead, and its retry must still work.
      final next = tester.widget<Slider>(find.byType(Slider));
      next.onChanged!(128);
      next.onChangeEnd!(128);
      await tester.pump();
      await tester.tap(find.byTooltip('Close Settings'));
      await tester.pumpAndSettle();
      settings.pending!.completeError(StateError('late write failure'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't save grey level").hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry').hitTestable());
      await tester.pump();
      settings.pending!.complete();
      await tester.pumpAndSettle();
      expect(settings.greyLevel, 128);
    },
  );
}
