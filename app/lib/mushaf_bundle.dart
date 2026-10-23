import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'bundle_metrics.dart';

/// Page data stays within the current spread and its two neighbouring spreads.
/// Flutter retains registered fonts; each font is registered only once.
class MushafBundle {
  MushafBundle._(this.metrics);
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

  static Future<MushafBundle> open() async {
    final numbers = jsonDecode(
      await rootBundle.loadString('assets/mushaf/pages.json'),
    ) as List;
    if (numbers.length != 604 ||
        List.generate(604, (i) => i + 1).any((n) => numbers[n - 1] != n)) {
      throw StateError('Incomplete mushaf: run bundle_mushaf.py --all');
    }
    final data = jsonDecode(
      await rootBundle.loadString('assets/mushaf/metrics.json'),
    ) as Map<String, dynamic>;
    final bundle = MushafBundle._(BundleMetrics.fromJson(data));
    bundle._drawing = jsonDecode(
      await rootBundle.loadString('assets/mushaf/basmallah.json'),
    ) as Map<String, dynamic>;
    await (FontLoader(
      'surah-name-v4',
    )..addFont(rootBundle.load('assets/mushaf/surah-name-v4.ttf'))).load();
    await bundle.loadNear(1);
    return bundle;
  }

  Future<Map<String, dynamic>> _load(int number) =>
      _pending.putIfAbsent(number, () async {
        if (_fonts.add(number)) {
          try {
            await (FontLoader(
              'mushaf-$number',
            )..addFont(rootBundle.load('assets/mushaf/p$number.ttf'))).load();
          } catch (_) {
            _fonts.remove(number);
            rethrow;
          }
        }
        final page = jsonDecode(
          await rootBundle.loadString('assets/mushaf/$number.json'),
        ) as Map<String, dynamic>;
        for (final line in page['lines'] as List) {
          final heading = line['heading'] as Map<String, dynamic>?;
          if (heading?['kind'] == 'wide') heading!['drawing'] = _drawing;
        }
        return page;
      });

  Future<void> loadNear(int number) async {
    final generation = ++_generation;
    final odd = number.isOdd ? number : number - 1;
    final wanted = [
      for (var n = math.max(1, odd - 2); n <= math.min(604, odd + 3); n++) n,
    ];
    if (loadedNumbers.length == wanted.length &&
        wanted.every((n) => pages[n - 1]['lines'] != null)) {
      return;
    }
    try {
      final loaded = await Future.wait(wanted.map(_load));
      if (generation != _generation) return;
      for (var i = 0; i < pages.length; i++) {
        if (!wanted.contains(i + 1)) pages[i] = {'page': i + 1};
      }
      for (final page in loaded) {
        pages[(page['page'] as int) - 1] = page;
      }
    } finally {
      if (generation == _generation) _pending.clear();
    }
  }
}
