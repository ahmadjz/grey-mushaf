from pathlib import Path
s=Path('app/integration_test/perf_baseline_test.dart').read_text()
s=s.replace("import 'dart:ui' show FramePhase;", "import 'dart:ui' show FramePhase;\nimport 'package:flutter/rendering.dart';")
s=s.replace("final samples = <String, Object>{};", "final samples = <String, Object>{};\n    final motion = <String, Object>{};\n    var blank = false;\n    PageController controller() => tester.widget<PageView>(find.byType(PageView)).controller!;\n    final swipeMetrics = <Object>[];")
a=s.index('    LoadedPageController controller() =>')
b=s.index('    Future<void> swipe()',a)
s=s[:a]+s[b:]
s=s.replace('      await tester.timedDrag(', '''      final clock = Stopwatch()..start();
      final offsets = <List<num>>[];
      final c = controller();
      void moved() { offsets.add([clock.elapsedMicroseconds, c.page!]); }
      c.addListener(moved);
      await tester.timedDrag(''')
s=s.replace('      await settle();\n      expect(controller().page, closeTo(before + 1, .01));', '''      final released = clock.elapsedMicroseconds;
      await settle();
      c.removeListener(moved);
      swipeMetrics.add({'blank': blank, 'landscape': tester.view.physicalSize.width > tester.view.physicalSize.height,
        'release_us': released, 'offsets': offsets});
      expect(controller().page, closeTo(before + 1, .01));''')
s=s.replace('await controller().pending;', 'await (controller() as LoadedPageController).pending;')
s=s.replace("    binding.reportData ??= {};", '''    // Instrumented paint traces are separate from the headline frame samples.
    debugProfilePaintsEnabled = true;
    debugProfileBuildsEnabled = true;
    await binding.traceAction(swipe, streams: ['Dart', 'Embedder', 'GC'], reportKey: 'landscape_trace');
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await Future<void>.delayed(const Duration(seconds: 2));
    await settle();
    await binding.traceAction(swipe, streams: ['Dart', 'Embedder', 'GC'], reportKey: 'portrait_trace');
    debugProfilePaintsEnabled = false;
    debugProfileBuildsEnabled = false;
    blank = true;
    final floorController = PageController();
    await tester.pumpWidget(MaterialApp(home: PageView.builder(
      controller: floorController, reverse: true, physics: const PageScrollPhysics(), itemCount: 604,
      itemBuilder: (_, index) => const ColoredBox(color: Colors.white))));
    await settle();
    await capture('blank_portrait_20_swipes', () async { for (var i=0; i<20; i++) { await swipe(); } });
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    await Future<void>.delayed(const Duration(seconds: 2));
    await settle();
    await capture('blank_landscape_20_swipes', () async { for (var i=0; i<20; i++) { await swipe(); } });
    motion['swipes'] = swipeMetrics;
    binding.reportData ??= {};
    binding.reportData!['motion'] = motion;''')
Path('app/integration_test/phone_perf_test.dart').write_text(s)
Path('app/test_driver/phone_perf_driver.dart').write_text('''import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';
Future<void> main() => integrationDriver(responseDataCallback: (data) async {
 final dir = Directory(Platform.environment['PERF_OUT']!)..createSync(recursive:true);
 for(final entry in data!.entries) {
   File('${dir.path}/${entry.key}.json').writeAsStringSync(jsonEncode(entry.value));
 }
});
''')
