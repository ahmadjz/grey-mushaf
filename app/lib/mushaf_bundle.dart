import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'bundle_metrics.dart';

/// Page data stays within the current spread and its two neighbouring spreads.
/// Flutter retains registered fonts; each font is registered only once.
class MushafBundle {
  MushafBundle._(this.metrics, this._assets);
  final AssetBundle _assets;
  final BundleMetrics metrics;
  final pages = List<Map<String, dynamic>>.generate(
    604,
    (i) => {'page': i + 1},
  );
  final _fonts = <int>{};
  final _pending = <int, Future<Map<String, dynamic>>>{};
  late final Map<String, dynamic> _drawing;
  int _generation = 0;

  List<int> get loadedNumbers => [
    for (final p in pages)
      if (p['lines'] != null) p['page'] as int,
  ];

  static Future<MushafBundle> open({AssetBundle? assets}) async {
    assets ??= rootBundle;
    final numbers =
        jsonDecode(await assets.loadString('assets/mushaf/pages.json')) as List;
    if (numbers.length != 604 ||
        List.generate(604, (i) => i + 1).any((n) => numbers[n - 1] != n)) {
      throw StateError('Incomplete mushaf: run bundle_mushaf.py --all');
    }
    final data = jsonDecode(
      await assets.loadString('assets/mushaf/metrics.json'),
    ) as Map<String, dynamic>;
    final bundle = MushafBundle._(BundleMetrics.fromJson(data), assets);
    bundle._drawing = jsonDecode(
      await assets.loadString('assets/mushaf/basmallah.json'),
    ) as Map<String, dynamic>;
    await (FontLoader(
      'surah-name-v4',
    )..addFont(assets.load('assets/mushaf/surah-name-v4.ttf'))).load();
    await bundle.loadNear(1);
    return bundle;
  }

  // Invalidate publication, without dropping ownership of in-flight font loads.
  void cancelPendingLoads() => _generation++;

  Future<Map<String, dynamic>> _load(int number) {
    final ready = pages[number - 1];
    if (ready['lines'] != null) return Future.value(ready);
    return _pending.putIfAbsent(
      number,
      () => _readPage(number).then(
        (page) {
          _pending.remove(number);
          return page;
        },
        onError: (Object error, StackTrace stack) {
          _pending.remove(number);
          Error.throwWithStackTrace(error, stack);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _readPage(int number) async {
    if (!_fonts.contains(number)) {
      await (FontLoader(
        'mushaf-$number',
      )..addFont(_assets.load('assets/mushaf/p$number.ttf'))).load();
      // A registered family is usable only after the engine finishes loading it.
      _fonts.add(number);
    }
    final page = jsonDecode(
      await _assets.loadString('assets/mushaf/$number.json', cache: false),
    ) as Map<String, dynamic>;
    for (final line in page['lines'] as List) {
      final heading = line['heading'] as Map<String, dynamic>?;
      if (heading?['kind'] == 'wide') heading!['drawing'] = _drawing;
    }
    return page;
  }

  Future<bool> loadNear(int number) async {
    final generation = ++_generation;
    final odd = number.isOdd ? number : number - 1;
    final wanted = [
      for (var n = math.max(1, odd - 2); n <= math.min(604, odd + 3); n++) n,
    ];
    if (loadedNumbers.length == wanted.length &&
        wanted.every((n) => pages[n - 1]['lines'] != null)) {
      return true;
    }
    try {
      final loaded = await Future.wait(wanted.map(_load));
      if (generation != _generation) return false;
      for (var i = 0; i < pages.length; i++) {
        if (!wanted.contains(i + 1)) pages[i] = {'page': i + 1};
      }
      for (final page in loaded) {
        pages[(page['page'] as int) - 1] = page;
      }
      return true;
    } catch (_) {
      if (generation != _generation) return false;
      rethrow;
    }
  }
}
