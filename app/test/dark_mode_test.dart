import 'word_target.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/flat_ink.dart';
import 'package:greymushaf/heading_ink.dart';
import 'package:greymushaf/main.dart';

import 'memory_reveal_store.dart';
import 'save_feedback_test.dart' show ControlledStore;

Future<void> openSettings(WidgetTester tester) async {
  await tester.tapAt(const Offset(3, 450));
  await tester.pumpAndSettle();
  await tapTarget(tester, find.text('Settings'));
  await tester.pumpAndSettle();
}

Future<void> toggleDark(WidgetTester tester) async {
  await tapTarget(tester, find.byType(SwitchListTile));
  await tester.pumpAndSettle();
}

void main() {
  late List<Map<String, dynamic>> pages;
  setUpAll(() async => pages = await loadPages());

  for (final brightness in Brightness.values) {
    testWidgets(
      'manual mode ignores platform $brightness and survives resume',
      (tester) async {
        tester.view.physicalSize = const Size(411, 914);
        tester.view.devicePixelRatio = 1;
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(
          tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
        );
        final modes = <bool>[];
        const channel = MethodChannel('tech.ahmadjz.greymushaf/reader');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            if (call.method == 'setDarkMode') modes.add(call.arguments as bool);
            if (call.method == 'getInsets') return <String, double>{};
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final store = MemoryRevealStore();
        var measures = 0;
        Widget app() => MaterialApp(
          home: Reader(
            pages: pages,
            store: store,
            onMeasureWord: () => measures++,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final initialMeasures = measures;
        Color? pageColor() =>
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;
        expect(pageColor(), Colors.white);
        expect(modes.last, false);
        await openSettings(tester);
        await toggleDark(tester);
        expect(pageColor(), Colors.black);
        expect(modes.last, true);
        expect(tester.widget<Slider>(find.byType(Slider)).value, 80);
        expect(tester.widget<Slider>(find.byType(Slider)).min, 32);
        expect(tester.widget<Slider>(find.byType(Slider)).max, 128);
        expect(
          Theme.of(tester.element(find.text('Dark mode'))).brightness,
          Brightness.dark,
        );
        for (final value in [32.0, 128.0]) {
          final slider = tester.widget<Slider>(find.byType(Slider));
          slider.onChanged!(value);
          await tester.pump();
          final word = WordTarget.key(const ValueKey('word-1'));
          expect(
            await wordColor(tester, word),
            Color.fromARGB(255, value.toInt(), value.toInt(), value.toInt()),
          );
        }
        await toggleDark(tester);
        expect(tester.widget<Slider>(find.byType(Slider)).value, 176);
        await toggleDark(tester);
        expect(tester.widget<Slider>(find.byType(Slider)).value, 128);
        await tapTarget(tester, find.byTooltip('Close Settings'));
        await tester.pumpAndSettle();
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            brightness == Brightness.dark ? Brightness.light : Brightness.dark;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(pageColor(), Colors.black);
        expect(modes.last, true);
        expect(measures, initialMeasures);
        expect(store.states, isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(pageColor(), Colors.white);
        expect(modes.last, false);
      },
    );
  }

  testWidgets(
    'dark page-1 basmallah uses committed state through failures and Retry',
    (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ControlledStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(pages: pages, store: store),
        ),
      );
      await tester.pumpAndSettle();
      await openSettings(tester);
      await toggleDark(tester);
      await tapTarget(tester, find.byTooltip('Close Settings'));
      await tester.pumpAndSettle();
      final word = WordTarget.key(const ValueKey('word-1'));
      Future<Color> ink() => wordColor(tester, word);
      expect(await ink(), const Color(0xFF505050));
      for (final reveal in [true, false]) {
        if (reveal) {
          await longPressTarget(tester, word);
        } else {
          await tapTarget(tester, word);
        }
        await tester.pump();
        final old = reveal ? const Color(0xFF505050) : Colors.white;
        expect(await ink(), old);
        store.pending!.completeError(StateError('injected failure'));
        await tester.pumpAndSettle();
        expect(await ink(), old);
        expect(find.text("Couldn't save"), findsOneWidget);
        expect(
          tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
          const Color(0xFF303030),
        );
        expect(
          testText(tester, find.text("Couldn't save")).style!.color,
          Colors.white,
        );
        await tapTarget(tester, find.text('Retry'));
        await tester.pump();
        store.pending!.complete();
        await tester.pumpAndSettle();
        expect(await ink(), reveal ? Colors.white : const Color(0xFF505050));
        expect(
          testSemantics(tester, word).label,
          contains('; ${reveal ? 'revealed' : 'unrevealed'}; reveals 1'),
        );
      }
    },
  );

  testWidgets('production page marker preserves numeral and black field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: pages, store: MemoryRevealStore()),
      ),
    );
    await tester.pumpAndSettle();
    const marker = WordTarget(5);
    await longPressTarget(tester, marker);
    await tester.pumpAndSettle();
    expect(
      testSemantics(tester, marker).label,
      contains('; revealed; reveals 1'),
    );
    final light = await wordPixels(tester, marker);
    await openSettings(tester);
    await toggleDark(tester);
    await tester.tap(find.byTooltip('Close Settings'));
    await tester.pumpAndSettle();
    for (final level in [255, 80]) {
      if (level == 80) {
        await tapTarget(tester, marker);
        await tester.pumpAndSettle();
      }
      final dark = await wordPixels(tester, marker);
      expect(dark.ink, light.ink);
      expect(dark.width, light.width);
      final r = light.ink, scale = light.scale;
      var numeral = 0, field = 0;
      // Compare actual page pixels over the whole marker, including its interior.
      // Alpha composites onto the page's known light/dark background.
      for (
        var y = (r.top * scale).ceil();
        y < (r.bottom * scale).floor();
        y++
      ) {
        for (
          var x = (r.left * scale).ceil();
          x < (r.right * scale).floor();
          x++
        ) {
          final i = (y * light.width + x) * 4;
          final a = light.rgba[i + 3] / 255, b = dark.rgba[i + 3] / 255;
          // rawRgba is premultiplied: add only the uncovered background.
          final lightValue = light.rgba[i] + 255 * (1 - a);
          final darkValue = dark.rgba[i].toDouble();
          expect(darkValue, closeTo((255 - lightValue) * level / 255, 2));
          expect(dark.rgba[i], dark.rgba[i + 1]);
          expect(dark.rgba[i], dark.rgba[i + 2]);
          if ((x / scale - r.center.dx).abs() < r.width * .2 &&
              (y / scale - r.center.dy).abs() < r.height * .3 &&
              b == 1) {
            if (darkValue > level * .9) numeral++;
            if (darkValue < 3) field++;
          }
        }
      }
      expect(numeral, greaterThan(10), reason: 'numeral remains inside circle');
      expect(field, greaterThan(10), reason: 'opaque marker field is black');
    }
  });

  testWidgets('all three heading forms render white pixels on black', (
    tester,
  ) async {
    for (final pair in [(2, 0), (2, 1), (50, 1)]) {
      final page = pages.singleWhere((p) => p['page'] == pair.$1);
      final painter = HeadingInk(
        page['lines'][pair.$2]['heading'] as Map<String, dynamic>,
        opening: pair.$1 <= 2,
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: Colors.black,
                child: FlatInk(
                  color: Colors.white,
                  background: Colors.black,
                  child: CustomPaint(
                    size: const Size(600, 120),
                    painter: painter,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var white = 0;
        var black = 0;
        for (var i = 0; i < bytes.length; i += 4) {
          expect(bytes[i], bytes[i + 1]);
          expect(bytes[i], bytes[i + 2]);
          expect(bytes[i + 3], 255);
          if (bytes[i] > 245) white++;
          if (bytes[i] < 10) black++;
        }
        expect(white, greaterThan(100));
        expect(black, greaterThan(100));
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      painter.dispose();
    }
  });
}
