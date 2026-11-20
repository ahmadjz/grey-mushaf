import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mushaf_index.dart';

class QuranIndex {
  QuranIndex.fromJson(Map<String, dynamic> json)
    : _surahPages = [
        for (final surah in json['surahs'] as List) surah['page'] as int,
      ],
      _ayahPages = [
        for (final surah in json['surahs'] as List)
          (surah['ayahPages'] as List).cast<int>(),
      ],
      _pageStarts = [
        for (final start in json['pages'] as List)
          (surah: start[0] as int, ayah: start[1] as int),
      ] {
    if (_surahPages.length != 114 || _pageStarts.length != 604) {
      throw const FormatException('Incomplete index: run bundle_index.py');
    }
  }

  static Future<QuranIndex> load(AssetBundle assets) async =>
      QuranIndex.fromJson(
        jsonDecode(await assets.loadString('assets/index/index.json'))
            as Map<String, dynamic>,
      );

  final List<int> _surahPages;
  final List<List<int>> _ayahPages;
  final List<({int surah, int ayah})> _pageStarts;

  int surahPage(int surah) => _surahPages[surah - 1];
  int ayahCount(int surah) => _ayahPages[surah - 1].length;
  int? pageOf(int surah, int ayah) {
    if (surah < 1 || surah > 114 || ayah < 1 || ayah > ayahCount(surah)) {
      return null;
    }
    return _ayahPages[surah - 1][ayah - 1];
  }

  int juzPage(int juz) {
    final start = juzStarts[juz - 1];
    return pageOf(start.$1, start.$2)!;
  }

  ({int surah, int juz}) place(int page) {
    final start = _pageStarts[page - 1];
    return (surah: start.surah, juz: juzOf(start.surah, start.ayah));
  }
}

const _folds = {
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ؤ': 'و', 'ئ': 'ي', //
  'ى': 'ي', 'ة': 'ه',
};

String foldLetters(String text) =>
    text.split('').map((letter) => _folds[letter] ?? letter).join();

final _marksAndTatweel = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');

String foldQuery(String query) => foldLetters(
  query.replaceAll(_marksAndTatweel, '').trim().replaceAll(RegExp(r'\s+'), ' '),
);

class AyahText {
  AyahText(this.surah, this.ayah, this.page, this.text) {
    if (!_marksAndTatweel.hasMatch(text)) {
      folded = foldLetters(text);
      return;
    }
    final letters = StringBuffer();
    final origins = <int>[];
    for (var i = 0; i < text.length; i++) {
      final letter = text[i];
      if (_marksAndTatweel.hasMatch(letter)) continue;
      letters.write(_folds[letter] ?? letter);
      origins.add(i);
    }
    folded = letters.toString();
    _origins = origins;
  }
  final int surah, ayah, page;
  final String text;
  late final String folded;
  List<int>? _origins;
  int _origin(int at) => _origins?[at] ?? at;

  List<({int start, int end})> matches(String query) {
    final folded = foldQuery(query);
    if (folded.isEmpty) return const [];
    final ranges = <({int start, int end})>[];
    for (
      var at = this.folded.indexOf(folded);
      at >= 0;
      at = this.folded.indexOf(folded, at + folded.length)
    ) {
      var end = _origin(at + folded.length - 1) + 1;
      while (end < text.length && _marksAndTatweel.hasMatch(text[end])) {
        end++;
      }
      ranges.add((start: _origin(at), end: end));
    }
    return ranges;
  }
}

class SearchIndex {
  SearchIndex(this.ayahs);
  final List<AyahText> ayahs;

  static Future<SearchIndex?> load(AssetBundle assets) async {
    final String raw;
    try {
      raw = await assets.loadString('assets/index/search.json');
    } on FlutterError {
      return null;
    }
    return SearchIndex([
      for (final row in jsonDecode(raw) as List)
        AyahText(row[0] as int, row[1] as int, row[2] as int, row[3] as String),
    ]);
  }

  List<AyahText> find(String query) {
    final folded = foldQuery(query);
    if (folded.isEmpty) return const [];
    return [
      for (final ayah in ayahs)
        if (ayah.folded.contains(folded)) ayah,
    ];
  }
}

int? readNumber(String text) {
  final western = text.trim().split('').map((c) {
    final arabic = '٠١٢٣٤٥٦٧٨٩'.indexOf(c);
    return arabic < 0 ? c : '$arabic';
  }).join();
  return RegExp(r'^\d{1,3}$').hasMatch(western) ? int.parse(western) : null;
}

List<int> surahsNamed(String query) {
  final folded = foldQuery(query);
  if (folded.isEmpty) return const [];
  return [
    for (var i = 0; i < surahNames.length; i++)
      if (foldLetters(surahNames[i]).contains(folded)) i + 1,
  ];
}
