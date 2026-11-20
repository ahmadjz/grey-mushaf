import 'package:flutter/material.dart';

import 'mushaf_index.dart';
import 'navigation_screen.dart';
import 'quran_index.dart';

const suggestionCount = 5;

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.index,
    required this.search,
    this.blackWhite = false,
  });
  final bool blackWhite;
  final QuranIndex index;
  final Future<SearchIndex?> search;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  bool _full = false;
  bool _loading = true;
  SearchIndex? _search;

  @override
  void initState() {
    super.initState();
    widget.search.then(
      (search) {
        if (mounted) {
          setState(() {
            _search = search;
            _loading = false;
          });
        }
      },
      onError: (Object _) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Widget> _placeRows(String query) {
    final number = readNumber(query);
    return [
      if (number != null && number >= 1 && number <= 604)
        ListTile(
          key: const ValueKey('search-page'),
          leading: const Icon(Icons.description_outlined),
          title: Text('صفحة ${arabicDigits(number)}'),
          onTap: () => Navigator.pop(context, pageTarget(number)),
        ),
      if (number != null && number >= 1 && number <= 30)
        ListTile(
          key: const ValueKey('search-juz'),
          leading: const Icon(Icons.menu_book_outlined),
          title: Text('الجزء ${arabicDigits(number)}'),
          onTap: () =>
              Navigator.pop(context, pageTarget(widget.index.juzPage(number))),
        ),
      for (final surah in surahsNamed(query))
        ListTile(
          key: ValueKey('search-surah-$surah'),
          leading: const Icon(Icons.list),
          title: Text('سورة ${surahNames[surah - 1]}'),
          trailing: Text(arabicDigits(widget.index.surahPage(surah))),
          onTap: () =>
              Navigator.pop(context, pageTarget(widget.index.surahPage(surah))),
        ),
    ];
  }

  Widget _ayahRow(AyahText ayah, String query, {required int maxLines}) {
    final theme = Theme.of(context);
    final spans = <TextSpan>[];
    var at = 0;
    for (final match in ayah.matches(query)) {
      spans
        ..add(TextSpan(text: ayah.text.substring(at, match.start)))
        ..add(
          TextSpan(
            text: ayah.text.substring(match.start, match.end),
            style: widget.blackWhite
                ? const TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  )
                : TextStyle(color: theme.colorScheme.primary),
          ),
        );
      at = match.end;
    }
    spans.add(TextSpan(text: ayah.text.substring(at)));
    return ListTile(
      key: ValueKey('search-ayah-${ayah.surah}:${ayah.ayah}'),
      title: Text.rich(
        TextSpan(children: spans),
        maxLines: maxLines,
        overflow: maxLines == 1 ? TextOverflow.ellipsis : null,
      ),
      subtitle: Text(
        'سورة (${arabicDigits(ayah.surah)}) ${surahNames[ayah.surah - 1]}: ${arabicDigits(ayah.ayah)} (صفحة ${arabicDigits(ayah.page)})',
      ),
      onTap: () => Navigator.pop(context, (
        page: ayah.page,
        surah: ayah.surah,
        ayah: ayah.ayah,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text;
    final search = _search;
    final hits = search?.find(query) ?? const <AyahText>[];
    final showFull = _full && hits.isNotEmpty;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            key: const ValueKey('search-field'),
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'بحث',
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() => _full = false),
            onSubmitted: (_) => setState(() => _full = true),
          ),
          actions: [
            if (query.isNotEmpty)
              IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _query.clear();
                  _full = false;
                }),
              ),
          ],
        ),
        body: ListView(
          children: showFull
              ? [
                  ListTile(
                    key: const ValueKey('search-count'),
                    title: Text(
                      '${arabicDigits(hits.length)} نتيجة في البحث عن "$query"',
                    ),
                  ),
                  for (final ayah in hits) _ayahRow(ayah, query, maxLines: 10),
                ]
              : [
                  ..._placeRows(query),
                  if (_loading && foldQuery(query).isNotEmpty)
                    const LinearProgressIndicator(),
                  if (!_loading &&
                      search == null &&
                      foldQuery(query).isNotEmpty)
                    const ListTile(
                      key: ValueKey('search-unavailable'),
                      title: Text('البحث في النص غير متاح'),
                      subtitle: Text(
                        'Word text not installed: run scripts/bundle_index.py',
                      ),
                    ),
                  for (final ayah in hits.take(suggestionCount))
                    _ayahRow(ayah, query, maxLines: 1),
                  if (hits.isNotEmpty)
                    ListTile(
                      key: const ValueKey('search-full'),
                      title: const Text('نتائج كاملة'),
                      subtitle: const Text('ابحث في المصحف بأكمله'),
                      onTap: () => setState(() => _full = true),
                    ),
                ],
        ),
      ),
    );
  }
}
