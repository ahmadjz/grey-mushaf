import 'dart:async';

import 'package:flutter/material.dart';

import 'bookmarks.dart';
import 'mushaf_index.dart';
import 'quran_index.dart';

typedef NavTarget = ({int page, int? surah, int? ayah});

NavTarget pageTarget(int page) => (page: page, surah: null, ayah: null);

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, required this.index, this.store});
  final QuranIndex index;
  final NavigationStore? store;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _removing = <int>{};

  Future<void> _remove(int page) async {
    final store = widget.store;
    if (store == null || !_removing.add(page)) return;
    final action = BookmarkAction(page, false);
    Future<void> attempt() async {
      try {
        await store.saveBookmarks([action]);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't save bookmark"),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(attempt()),
            ),
          ),
        );
        return;
      }
      if (mounted) setState(() => _removing.remove(page));
    }

    await attempt();
  }

  List<Widget> _surahRows(BuildContext context) {
    final index = widget.index;
    final muted = Theme.of(context).colorScheme.surfaceContainerHighest;
    final rows = <Widget>[];
    var juz = 1;
    for (var surah = 1; surah <= 114; surah++) {
      final page = index.surahPage(surah);
      while (juz <= 30 && index.juzPage(juz) <= page) {
        final juzPage = index.juzPage(juz);
        rows.add(
          ListTile(
            key: ValueKey('juz-$juz'),
            tileColor: muted,
            dense: true,
            title: Text('الجزء ${arabicDigits(juz)}'),
            trailing: Text(arabicDigits(juzPage)),
            onTap: () => Navigator.pop(context, pageTarget(juzPage)),
          ),
        );
        juz++;
      }
      final count = index.ayahCount(surah);
      rows.add(
        ListTile(
          key: ValueKey('surah-$surah'),
          leading: SizedBox(
            width: 32,
            child: Center(child: Text(arabicDigits(surah))),
          ),
          title: Text('سورة ${surahNames[surah - 1]}'),
          subtitle: Text(
            '${medinanSurahs.contains(surah) ? 'مدنية' : 'مكية'} - ${arabicDigits(count)} آيات',
          ),
          trailing: Text(arabicDigits(page)),
          onTap: () => Navigator.pop(context, pageTarget(page)),
        ),
      );
    }
    return rows;
  }

  Widget _bookmarks(BuildContext context) {
    final saved = widget.store?.bookmarkSavedAt ?? const <int, int>{};
    final pages = saved.keys.toList()
      ..sort((a, b) => saved[b]!.compareTo(saved[a]!));
    if (pages.isEmpty) {
      return const Center(child: Text('لا توجد علامات'));
    }
    return ListView(
      children: [
        for (final page in pages)
          ListTile(
            key: ValueKey('bookmark-$page'),
            leading: const Icon(Icons.bookmark),
            title: Text('صفحة ${arabicDigits(page)}'),
            subtitle: Text(
              'سورة ${surahNames[widget.index.place(page).surah - 1]}، جزء ${arabicDigits(widget.index.place(page).juz)}',
            ),
            trailing: IconButton(
              tooltip: 'Remove bookmark',
              icon: const Icon(Icons.delete_outline),
              onPressed: _removing.contains(page)
                  ? null
                  : () => unawaited(_remove(page)),
            ),
            onTap: () => Navigator.pop(context, pageTarget(page)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('القرآن الكريم'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'السور'),
              Tab(text: 'العلامات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(children: _surahRows(context)),
            _bookmarks(context),
          ],
        ),
      ),
    ),
  );
}
