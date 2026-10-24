import 'dart:ui' show FramePhase;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:greymushaf/main.dart' as app;
import 'package:greymushaf/loaded_page_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('repeatable reader profile baseline', (tester) async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await app.main();
    await tester.pumpAndSettle();
    final samples = <String, Object>{};
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

    LoadedPageController controller() =>
        tester.widget<PageView>(find.byType(PageView)).controller!
            as LoadedPageController;
    Future<void> swipe() async {
      final width = tester.getSize(find.byType(PageView)).width;
      final before = controller().page!;
      await tester.timedDrag(
        find.byType(PageView),
        Offset(width * .75, 0),
        const Duration(milliseconds: 250),
      );
      await settle();
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
      await controller().pending;
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
    binding.reportData ??= {};
    binding.reportData!['frame_samples_ms'] = samples;
    await SystemChrome.setPreferredOrientations([]);
  });
}
