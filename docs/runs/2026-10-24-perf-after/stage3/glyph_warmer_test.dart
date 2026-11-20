import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/glyph_warmer.dart';

void main() {
  testWidgets('warming cancels obsolete work and bounds retained identities', (
    tester,
  ) async {
    final started = <int>[];
    final first = Completer<void>();
    final warmer = GlyphWarmer<int>((page) async {
      started.add(page);
      if (page == 1) await first.future;
    });
    warmer.request([1, 2, 3]);
    await tester.pump();
    expect(started, [1]);
    warmer.request([4, 5]);
    first.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(started, [1, 4, 5]);
    warmer.request([4, 5]);
    await tester.pump();
    expect(started, [1, 4, 5]);
    warmer.dispose();
    warmer.request([6]);
    await tester.pump();
    expect(started, [1, 4, 5]);
  });
}
