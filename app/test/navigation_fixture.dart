int fixtureAyahPage(int surah, int ayah) => surah == 1
    ? 1
    : surah == 2
    ? 2 + (ayah - 1) ~/ 7
    : 43 + (surah - 3) * 5;

int fixtureSurahPage(int surah) => fixtureAyahPage(surah, 1);

Map<String, dynamic> fixtureIndexJson() {
  final surahs = [
    for (var surah = 1; surah <= 114; surah++)
      {
        'page': fixtureSurahPage(surah),
        'ayahPages': [
          for (var ayah = 1; ayah <= 286; ayah++) fixtureAyahPage(surah, ayah),
        ],
      },
  ];
  final starts = <int, List<int>>{};
  for (var surah = 1; surah <= 114; surah++) {
    for (var ayah = 1; ayah <= 286; ayah++) {
      starts.putIfAbsent(fixtureAyahPage(surah, ayah), () => [surah, ayah]);
    }
  }
  var last = [1, 1];
  return {
    'surahs': surahs,
    'pages': [
      for (var page = 1; page <= 604; page++) last = starts[page] ?? last,
    ],
  };
}
