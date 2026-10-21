import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'flat_ink.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final pages = await loadPages();
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        ),
        home: Reader(pages: pages),
      ),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Cannot load bundled mushaf: $error')),
        ),
      ),
    );
  }
}

Future<List<Map<String, dynamic>>> loadPages() async {
  final numbers = jsonDecode(
    await rootBundle.loadString('assets/mushaf/pages.json'),
  ) as List;
  final pages = <Map<String, dynamic>>[];
  for (final number in numbers) {
    final loader = FontLoader('mushaf-$number')
      ..addFont(rootBundle.load('assets/mushaf/p$number.ttf'));
    await loader.load();
    pages.add(
      jsonDecode(await rootBundle.loadString('assets/mushaf/$number.json'))
          as Map<String, dynamic>,
    );
  }
  return pages;
}

class Reader extends StatefulWidget {
  const Reader({super.key, required this.pages});
  final List<Map<String, dynamic>> pages;

  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader> {
  final _black = <int>{};
  final _counts = <int, int>{};
  final _targets = <int, GlobalKey>{};
  final _visited = <int>{};
  bool _dragging = false;
  bool? _spread;
  int _selected = 0;
  Offset? _previous;
  PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _wordAt(Offset point) {
    for (final entry in _targets.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is RenderBox &&
          box.attached &&
          box.hasSize &&
          (Offset.zero & box.size).contains(box.globalToLocal(point))) {
        return entry.key;
      }
    }
    return null;
  }

  void _revealAt(Offset point) {
    final id = _wordAt(point);
    if (id != null && _visited.add(id) && _black.add(id)) {
      _counts[id] = (_counts[id] ?? 0) + 1;
    }
  }

  void _start(LongPressStartDetails details) {
    setState(() {
      _dragging = true;
      _visited.clear();
      _previous = details.globalPosition;
      _revealAt(details.globalPosition);
    });
  }

  void _move(LongPressMoveUpdateDetails details) {
    setState(() {
      final start = _previous ?? details.globalPosition;
      final end = details.globalPosition;
      // Hit every crossed target even when pointer events skip over short words.
      final steps = math.max(1, ((end - start).distance / 2).ceil());
      for (var i = 1; i <= steps; i++) {
        _revealAt(Offset.lerp(start, end, i / steps)!);
      }
      _previous = end;
    });
  }

  void _end() {
    if (!_dragging) return;
    setState(() {
      _dragging = false;
      _previous = null;
      _visited.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final spread =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final groups = <List<Map<String, dynamic>>>[];
    for (final page in widget.pages) {
      final number = page['page'] as int;
      if (spread &&
          groups.isNotEmpty &&
          number.isEven &&
          groups.last.first['page'] == number - 1) {
        groups.last.add(page);
      } else {
        groups.add([page]);
      }
    }
    if (_spread != spread) {
      final selectedPage = widget.pages.isEmpty
          ? 1
          : widget.pages[_selected]['page'];
      final index = groups.indexWhere(
        (g) => g.any((p) => p['page'] == selectedPage),
      );
      final old = _controller;
      _controller = PageController(initialPage: math.max(0, index));
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      _spread = spread;
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Grey Mushaf', style: TextStyle(color: Colors.black)),
        actions: [
          DropdownButton<int>(
            key: const ValueKey('page-picker'),
            value: widget.pages.isEmpty
                ? null
                : widget.pages[_selected]['page'] as int,
            items: [
              for (final p in widget.pages)
                DropdownMenuItem(
                  value: p['page'] as int,
                  child: Text('Page ${p['page']}'),
                ),
            ],
            onChanged: _dragging
                ? null
                : (number) {
                    final index = groups.indexWhere(
                      (g) => g.any((p) => p['page'] == number),
                    );
                    if (index >= 0) _controller.jumpToPage(index);
                  },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: _start,
                onLongPressMoveUpdate: _move,
                onLongPressEnd: (_) => _end(),
                onLongPressCancel: _end,
                onTapUp: (details) {
                  final id = _wordAt(details.globalPosition);
                  if (id != null && _black.contains(id)) {
                    setState(() => _black.remove(id));
                  }
                },
                child: PageView.builder(
                  key: ValueKey(spread),
                  controller: _controller,
                  reverse: true,
                  physics: _dragging
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: groups.length,
                  onPageChanged: (index) => setState(() {
                    _selected = widget.pages.indexOf(groups[index].first);
                  }),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        for (final page in group) Expanded(child: _page(page)),
                      ],
                    );
                  },
                ),
              ),
            ),
            Text(
              'Revealed ${_black.length} · Reveals ${_counts.values.fold(0, (a, b) => a + b)}',
              key: const ValueKey('counts'),
              style: const TextStyle(color: Colors.black),
            ),
            const Text(
              'Long-press and drag to reveal · Tap black to re-grey',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _page(Map<String, dynamic> page) {
    final number = page['page'] as int;
    final lines = page['lines'] as List;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            key: ValueKey('page-$number'),
            width: 420,
            height: 660,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: number <= 2
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          for (final line in lines)
                            _line(number, line as Map<String, dynamic>),
                        ],
                      ),
                    ),
                    Text(
                      '$number',
                      style: const TextStyle(fontSize: 18, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(int page, Map<String, dynamic> line) {
    final words = line['words'] as List;
    final kind = line['type'];
    if (kind != 'ayah') {
      // Deliberate spike placeholders; the V4 heading font is not supplied.
      final title = kind == 'basmallah'
          ? 'بسم الله الرحمن الرحيم'
          : switch (line['surah']) {
              1 => 'سورة الفاتحة',
              2 => 'سورة البقرة',
              _ => 'سورة ${line['surah']}',
            };
      return SizedBox(
        height: 38,
        child: Center(
          child: Text(
            title,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 20, color: Colors.black),
          ),
        ),
      );
    }
    return SizedBox(
      key: ValueKey('line-$page-${line['number']}'),
      height: 38,
      child: LayoutBuilder(
        builder: (context, constraints) {
          TextStyle style(double size) => TextStyle(
            fontFamily: 'mushaf-$page',
            fontSize: size,
            height: 1,
            color: Colors.black,
          );
          double width(Map<String, dynamic> word, double size) {
            final painter = TextPainter(
              text: TextSpan(text: word['text'] as String, style: style(size)),
              textDirection: TextDirection.rtl,
            )..layout();
            final result = painter.width;
            painter.dispose();
            return result;
          }

          final natural = words.fold<double>(
            0,
            (sum, w) => sum + width(w as Map<String, dynamic>, 32),
          );
          final gap = 3.0;
          final fontSize = math.min(
            32.0,
            32 * (constraints.maxWidth - gap * (words.length - 1)) / natural,
          );
          return Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: line['centered'] == true
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < words.length; i++) ...[
                if (i > 0 && line['centered'] == true) SizedBox(width: gap),
                _word(
                  words[i] as Map<String, dynamic>,
                  style(fontSize),
                  width(words[i], fontSize),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _word(Map<String, dynamic> word, TextStyle style, double width) {
    final id = word['id'] as int;
    final black = _black.contains(id);
    return Semantics(
      key: ValueKey('word-$id'),
      label:
          '${word['location']}; ${black ? 'black' : 'grey'}; reveals ${_counts[id] ?? 0}',
      child: SizedBox(
        key: _targets.putIfAbsent(id, GlobalKey.new),
        width: width,
        height: 38,
        child: Center(
          child: FlatInk(
            color: black ? Colors.black : const Color(0xFFB0B0B0),
            child: Text(
              word['text'] as String,
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}
