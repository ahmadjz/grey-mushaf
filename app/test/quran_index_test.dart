import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/quran_index.dart';

import 'navigation_fixture.dart';

void main() {
  final index = QuranIndex.fromJson(fixtureIndexJson());

  test('pages resolve for surahs, ayahs and juz', () {
    expect(index.surahPage(2), 2);
    expect(index.ayahCount(2), 286);
    expect(index.pageOf(2, 142), 22);
    expect(index.pageOf(2, 287), isNull);
    expect(index.pageOf(115, 1), isNull);
    expect(index.juzPage(2), 22);
    expect(index.place(22), (surah: 2, juz: 1));
    expect(index.place(23), (surah: 2, juz: 2));
  });

  test('an incomplete index is refused', () {
    final json = fixtureIndexJson()
      ..['pages'] = (fixtureIndexJson()['pages'] as List).take(603).toList();
    expect(() => QuranIndex.fromJson(json), throwsFormatException);
  });

  test('text search folds hamza forms, alif maqsura and ta marbuta', () {
    final search = SearchIndex([
      AyahText(2, 104, 16, 'يا ايها الذين امنوا لا تقولوا راعنا'),
      AyahText(2, 2, 2, 'ذلك الكتاب لا ريب فيه هدى للمتقين'),
      AyahText(1, 2, 1, 'الحمد لله رب العالمين'),
      AyahText(2, 3, 2, 'ويقيمون الصلاة'),
    ]);
    expect(search.find('أيها الذين').map((a) => a.ayah), [104]);
    expect(search.find('هُدَى').map((a) => a.ayah), [2]);
    expect(search.find('هدي').map((a) => a.ayah), [2]);
    expect(search.find('الصلاه').map((a) => a.ayah), [3]);
    expect(search.find('  ـ  '), isEmpty);
    final hit = search.find('الذين').single;
    final start = hit.folded.indexOf(foldQuery('الذين'));
    expect(hit.text.substring(start, start + 5), 'الذين');
  });

  test('numbers read in either digit form', () {
    expect(readNumber('٢١٦'), 216);
    expect(readNumber(' 30 '), 30);
    expect(readNumber('2a'), isNull);
    expect(readNumber('1000'), isNull);
  });

  test('surah names match without hamza or ta marbuta', () {
    expect(surahsNamed('البقره'), [2]);
    expect(surahsNamed('الانفال'), [8]);
    expect(surahsNamed('اسراء'), [17]);
    expect(surahsNamed(''), isEmpty);
  });
}
