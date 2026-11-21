import 'dart:async';

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
  late int failReaderLoads;

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
    failReaderLoads = 0;
  });

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WebShell(
          engine: engine,
          openReader: () async {
            if (failReaderLoads-- > 0) throw StateError('asset 503');
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
    expect(server.sessions, ['DELETE null']);
  });

  testWidgets('signing in opens the cookie session, then the reader', (
    tester,
  ) async {
    await show(tester);
    await signIn(tester);
    expect(server.sessions, ['DELETE null', 'POST token-user-a']);
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
    expect(server.sessions, [
      'DELETE null',
      'POST token-user-a',
      'DELETE null',
    ]);
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

  testWidgets('a failed mushaf load offers Retry, which loads again', (
    tester,
  ) async {
    await local.saveSyncValues({'token': 'old', 'owner': 'user-a'});
    failReaderLoads = 1;
    await show(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('reader'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('reader'), findsOneWidget);
  });

  testWidgets('sign-out waits for a slow sign-in cookie, then clears it', (
    tester,
  ) async {
    await local.saveSyncValues({'token': 'old', 'owner': 'user-a'});
    final release = Completer<void>();
    server.pauseSession = (request) async {
      if (request.method == 'POST') await release.future;
    };
    await tester.pumpWidget(
      MaterialApp(
        home: WebShell(
          engine: engine,
          openReader: () async => const Text('reader'),
        ),
      ),
    );
    await engine.signOut();
    await tester.pump();
    expect(server.sessions, ['POST old']);
    release.complete();
    await tester.pumpAndSettle();
    expect(server.sessions, ['POST old', 'DELETE null']);
    expect(find.text('reader'), findsNothing);
    expect(find.byKey(const ValueKey('account-email')), findsOneWidget);
  });

  testWidgets('a sign-in after a slow sign-out sets the cookie last', (
    tester,
  ) async {
    final release = Completer<void>();
    server.pauseSession = (request) async {
      if (request.method == 'DELETE') await release.future;
    };
    await show(tester);
    await tester.enterText(find.byKey(const ValueKey('account-email')), 'a@x');
    await tester.enterText(
      find.byKey(const ValueKey('account-password')),
      'right-password',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump();
    expect(server.sessions, ['DELETE null']);
    release.complete();
    await tester.pumpAndSettle();
    expect(server.sessions, ['DELETE null', 'POST token-user-a']);
    expect(find.text('reader'), findsOneWidget);
  });

  testWidgets('a failed cookie clear is retried at the next start', (
    tester,
  ) async {
    server.sessionStatus = 503;
    await show(tester);
    expect(tester.takeException(), isNull);
    expect(server.sessions, ['DELETE null']);
  });
}
