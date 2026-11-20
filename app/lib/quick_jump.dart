import 'package:flutter/material.dart';

import 'mushaf_index.dart';
import 'navigation_screen.dart';
import 'quran_index.dart';

Future<NavTarget?> showQuickJump(
  BuildContext context,
  QuranIndex index,
  int currentPage, {
  required ThemeData theme,
}) => showDialog<NavTarget>(
  context: context,
  builder: (context) => Theme(
    data: theme,
    child: _QuickJump(index: index, currentPage: currentPage),
  ),
);

class _QuickJump extends StatefulWidget {
  const _QuickJump({required this.index, required this.currentPage});
  final QuranIndex index;
  final int currentPage;

  @override
  State<_QuickJump> createState() => _QuickJumpState();
}

class _QuickJumpState extends State<_QuickJump> {
  final _page = TextEditingController();
  final _ayah = TextEditingController();
  late int _surah = widget.index.place(widget.currentPage).surah;
  String? _error;

  @override
  void dispose() {
    _page.dispose();
    _ayah.dispose();
    super.dispose();
  }

  void _go() {
    final index = widget.index;
    if (_page.text.trim().isNotEmpty) {
      final page = readNumber(_page.text);
      if (page == null || page < 1 || page > 604) {
        setState(() => _error = 'صفحة من ١ إلى ٦٠٤');
        return;
      }
      Navigator.pop(context, pageTarget(page));
      return;
    }
    if (_ayah.text.trim().isEmpty) {
      Navigator.pop(context, pageTarget(index.surahPage(_surah)));
      return;
    }
    final ayah = readNumber(_ayah.text);
    final page = ayah == null ? null : index.pageOf(_surah, ayah);
    if (page == null) {
      setState(
        () => _error = 'آية من ١ إلى ${arabicDigits(index.ayahCount(_surah))}',
      );
      return;
    }
    Navigator.pop(context, (page: page, surah: _surah, ayah: ayah));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      key: const ValueKey('quick-jump'),
      title: const Text('انتقال سريع'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('jump-page'),
            controller: _page,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'الصفحة',
              hintText: arabicDigits(widget.currentPage),
            ),
            onSubmitted: (_) => _go(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: const ValueKey('jump-surah'),
            initialValue: _surah,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'السورة'),
            items: [
              for (var surah = 1; surah <= 114; surah++)
                DropdownMenuItem(
                  value: surah,
                  child: Text(
                    '${arabicDigits(surah)}. ${surahNames[surah - 1]}',
                  ),
                ),
            ],
            onChanged: (surah) => setState(() {
              _surah = surah ?? _surah;
              _page.clear();
              _error = null;
            }),
          ),
          TextField(
            key: const ValueKey('jump-ayah'),
            controller: _ayah,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'الآية',
              hintText: '١–${arabicDigits(widget.index.ayahCount(_surah))}',
            ),
            onChanged: (_) {
              if (_page.text.isNotEmpty) _page.clear();
            },
            onSubmitted: (_) => _go(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                key: const ValueKey('jump-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const ValueKey('jump-go'),
          onPressed: _go,
          child: const Text('انتقال'),
        ),
      ],
    ),
  );
}
