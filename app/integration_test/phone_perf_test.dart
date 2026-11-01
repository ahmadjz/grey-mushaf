import 'dart:ui' show FramePhase;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:greymushaf/main.dart' as app;
import 'package:greymushaf/loaded_page_controller.dart';
import 'package:greymushaf/page_ink.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('repeatable reader profile baseline', (tester) async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await app.main();
    await tester.pumpAndSettle();
    final samples = <String, Object>{};
    final motion = <String, Object>{};
    var blank = false;
    PageController controller() =>
        tester.widget<PageView>(find.byType(PageView)).controller!;
    final swipeMetrics = <Object>[];
    Future<void> settle() async {
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    Future<void> capture(String name, Future<void> Function() action) async {
      await Future<void>.delayed(const Duration(seconds: 1));
      final frames = <List<double>>[];
      void timing(List<FrameTiming> values) {
        for (final f in values) {
          frames.add([
            f.buildDuration.inMicroseconds / 1000,
            f.rasterDuration.inMicroseconds / 1000,
            f.timestampInMicroseconds(FramePhase.buildStart).toDouble(),
            f.timestampInMicroseconds(FramePhase.rasterStart).toDouble(),
          ]);
        }
      }

      SchedulerBinding.instance.addTimingsCallback(timing);
      await action();
      await Future<void>.delayed(const Duration(seconds: 1));
      SchedulerBinding.instance.removeTimingsCallback(timing);
      expect(frames, isNotEmpty, reason: name);
      samples[name] = frames;
    }

    Future<void> swipe() async {
      final width = tester.getSize(find.byType(PageView)).width;
      final before = controller().page!;
      final clock = Stopwatch()..start();
      final offsets = <List<num>>[];
      final c = controller();
      void moved() {
        offsets.add([clock.elapsedMicroseconds, c.page!]);
      }

      c.addListener(moved);
      await tester.timedDrag(
        find.byType(PageView),
        Offset(width * .75, 0),
        const Duration(milliseconds: 250),
      );
      final released = clock.elapsedMicroseconds;
      await settle();
      c.removeListener(moved);
      swipeMetrics.add({
        'blank': blank,
        'landscape':
            tester.view.physicalSize.width > tester.view.physicalSize.height,
        'release_us': released,
        'offsets': offsets,
      });
      expect(controller().page, closeTo(before + 1, .01));
    }

    await capture('portrait_first_glyph_cold_swipe', swipe);
    await capture('portrait_20_swipes', () async {
      for (var i = 0; i < 20; i++) {
        await swipe();
      }
    });
    // Physics prevents gestures into unloaded pages; measure a cold jump separately.
    await capture('unloaded_page_450_jump', () async {
      controller().jumpToPage(449);
      await (controller() as LoadedPageController).pending;
      await settle();
      expect(find.byKey(const ValueKey('page-450')), findsOneWidget);
    });
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    await Future<void>.delayed(const Duration(seconds: 2));
    await settle();
    expect(
      tester.view.physicalSize.width,
      greaterThan(tester.view.physicalSize.height),
    );
    await capture('landscape_20_swipes', () async {
      for (var i = 0; i < 20; i++) {
        await swipe();
      }
    });
    // Instrumented paint traces are separate from the headline frame samples.
    binding.reportData ??= {};
    binding.reportData!['trace_colour_groups'] = [
      for (final w in tester.widgetList<PaintedInkPage>(
        find.byType(PaintedInkPage),
      ))
        {
          'words': w.controller.words.length,
          'cached': w.controller.hasCachedImage,
          'groups': w.controller.words.map(w.controller.color).toSet().length,
        },
    ];
    debugProfilePaintsEnabled = true;
    debugProfileBuildsEnabled = true;
    debugProfileLayoutsEnabled = true;
    await binding.traceAction(
      swipe,
      streams: ['all'],
      reportKey: 'landscape_trace',
    );
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await Future<void>.delayed(const Duration(seconds: 2));
    await settle();
    await binding.traceAction(
      swipe,
      streams: ['all'],
      reportKey: 'portrait_trace',
    );
    debugProfilePaintsEnabled = false;
    debugProfileBuildsEnabled = false;
    debugProfileLayoutsEnabled = false;
    blank = true;
    final floorController = PageController();
    await tester.pumpWidget(
      MaterialApp(
        home: PageView.builder(
          controller: floorController,
          reverse: true,
          physics: const PageScrollPhysics(),
          itemCount: 604,
          itemBuilder: (_, index) => const ColoredBox(color: Colors.white),
        ),
      ),
    );
    await settle();
    await capture('blank_portrait_20_swipes', () async {
      for (var i = 0; i < 20; i++) {
        await swipe();
      }
    });
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    await Future<void>.delayed(const Duration(seconds: 2));
    await settle();
    await capture('blank_landscape_20_swipes', () async {
      for (var i = 0; i < 20; i++) {
        await swipe();
      }
    });
    motion['swipes'] = swipeMetrics;
    binding.reportData ??= {};
    binding.reportData!['motion'] = motion;
    binding.reportData!['frame_samples_ms'] = samples;
    await SystemChrome.setPreferredOrientations([]);
  });
}
