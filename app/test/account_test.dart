import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/account_screen.dart';
import 'package:greymushaf/sync.dart';
import 'package:http/testing.dart';

import 'sync_fakes.dart';

void main() {
  late FakeLocal local;
  late FakeServer server;
  late SyncEngine engine;

  setUp(() {
    local = FakeLocal();
    server = FakeServer();
    engine = SyncEngine(
      local,
      PocketBaseApi('http://pb', client: MockClient(server.handle)),
      online: const Stream.empty(),
      poll: null,
    );
  });

  Future<void> showSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncSettings(engine: engine, theme: ThemeData()),
        ),
      ),
    );
  }

  testWidgets(
    'signed out, the Account row opens the sign-in screen (R78, R82)',
    (tester) async {
      await showSettings(tester);
      expect(find.text('Not signed in · sync is off'), findsOneWidget);
      expect(find.text('Sync now'), findsNothing);
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create account'), findsNothing);
      expect(find.text('Forgot password'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        'a@x',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        'bad',
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong email or password'), findsOneWidget);

      server.verified = false;
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('This account is not verified yet'), findsOneWidget);

      server.verified = true;
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        'right-password',
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('a@x'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
    },
  );

  testWidgets(
    'signed in, Settings shows the last sync and changes waiting (R58)',
    (tester) async {
      local.pending.addAll([wordRecord('u1'), wordRecord('u2')]);
      await engine.signIn('a@x', 'right-password');
      await engine.sync();
      local.pending.add(wordRecord('u3'));
      engine.localChanged();
      await showSettings(tester);
      await tester.pump();
      expect(
        find.textContaining(
          RegExp(r'^Last sync \d\d:\d\d · 1 change waiting$'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Sync now'));
      await tester.runAsync(() => engine.sync());
      await tester.pump();
      expect(find.textContaining('no changes waiting'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      expect(find.text('Not signed in · sync is off'), findsOneWidget);
      expect(await local.pendingCount(), 0);
      expect(local.values['owner'], 'user-a');
      engine.dispose();
    },
  );

  test('the summary names the day for an older sync', () {
    local.values['last_sync'] =
        '${DateTime(2026, 11, 18, 9, 5).millisecondsSinceEpoch}';
    expect(
      syncSummary(engine, DateTime(2026, 11, 20, 12)),
      'Last sync 18 Nov 09:05 · no changes waiting',
    );
    local.values.remove('last_sync');
    expect(
      syncSummary(engine, DateTime(2026, 11, 20, 12)),
      'Not synced yet · no changes waiting',
    );
  });
}
