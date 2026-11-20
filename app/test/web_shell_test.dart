import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/sync.dart';
import 'package:greymushaf/web_shell.dart';
import 'package:http/testing.dart';

import 'sync_fakes.dart';

void main() {
  late FakeLocal local;
  late FakeServer server;
  late SyncEngine engine;
  late int readersOpened;

  setUp(() {
    local = FakeLocal();
    server = FakeServer();
    engine = SyncEngine(
      local,
      PocketBaseApi('http://pb', client: MockClient(server.handle)),
      online: const Stream.empty(),
      poll: null,
    );
    readersOpened = 0;
  });

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WebShell(
          engine: engine,
          openReader: () async {
            readersOpened++;
            return const Scaffold(body: Text('reader'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.byKey(const ValueKey('account-email')), 'a@x');
    await tester.enterText(
      find.byKey(const ValueKey('account-password')),
      'right-password',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
  }

  testWidgets('signed out, the web opens on sign-in and loads no mushaf', (
    tester,
  ) async {
    await show(tester);
    expect(find.byKey(const ValueKey('account-email')), findsOneWidget);
    expect(find.text('reader'), findsNothing);
    expect(readersOpened, 0);
    expect(server.sessions, isEmpty);
  });

  testWidgets('signing in opens the cookie session, then the reader', (
    tester,
  ) async {
    await show(tester);
    await signIn(tester);
    expect(server.sessions, ['POST token-user-a']);
    expect(find.text('reader'), findsOneWidget);
    expect(readersOpened, 1);
  });

  testWidgets('a signed-in browser reopens the session before the reader', (
    tester,
  ) async {
    await local.saveSyncValues({'token': 'old', 'owner': 'user-a'});
    await show(tester);
    expect(server.sessions, ['POST old']);
    expect(find.text('reader'), findsOneWidget);
  });

  testWidgets('a refused session signs out and shows sign-in again', (
    tester,
  ) async {
    await local.saveSyncValues({'token': 'expired', 'owner': 'user-a'});
    server.sessionStatus = 401;
    await show(tester);
    expect(engine.signedIn, isFalse);
    expect(find.byKey(const ValueKey('account-email')), findsOneWidget);
    expect(readersOpened, 0);
  });

  testWidgets('a renewed token renews the cookie', (tester) async {
    await local.saveSyncValues({'token': 'old', 'owner': 'user-a'});
    await show(tester);
    await engine.sync();
    await tester.pumpAndSettle();
    expect(server.sessions, ['POST old', 'POST fresh-user-a']);
    expect(readersOpened, 1);
  });

  testWidgets('signing out clears the cookie and closes every screen', (
    tester,
  ) async {
    await show(tester);
    await signIn(tester);
    final context = tester.element(find.text('reader'));
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const Text('settings')));
    await tester.pumpAndSettle();
    await engine.signOut();
    await tester.pumpAndSettle();
    expect(server.sessions.last, 'DELETE null');
    expect(find.text('settings'), findsNothing);
    expect(find.text('reader'), findsNothing);
    expect(find.byKey(const ValueKey('account-email')), findsOneWidget);
  });

  testWidgets('no connection offers a retry instead of the reader', (
    tester,
  ) async {
    await local.saveSyncValues({'token': 'old', 'owner': 'user-a'});
    server.failNextWith = null;
    server.sessionStatus = 503;
    await show(tester);
    expect(find.text('reader'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    server.sessionStatus = 204;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('reader'), findsOneWidget);
  });
}
