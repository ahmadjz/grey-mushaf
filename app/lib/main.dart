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
  final _bands = <String, GlobalKey>{};
  final _bandWords = <String, List<int>>{};
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
    String? nearestBand;
    var distance = double.infinity;
    for (final entry in _bands.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = Rect.fromPoints(
        box.localToGlobal(Offset.zero),
        box.localToGlobal(box.size.bottomRight(Offset.zero)),
      );
      // Adjacent slots use half-open vertical intervals: exactly one line.
      if (point.dy < rect.top || point.dy >= rect.bottom) continue;
      final dx = (point.dx - point.dx.clamp(rect.left, rect.right)).abs();
      if (dx < distance) {
        distance = dx;
        nearestBand = entry.key;
      }
    }
    int? nearestWord;
    distance = double.infinity;
    for (final id in _bandWords[nearestBand] ?? <int>[]) {
      final box = _targets[id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final center = box.localToGlobal(box.size.center(Offset.zero));
      final dx = (point.dx - center.dx).abs();
      if (dx < distance) {
        distance = dx;
        nearestWord = id;
      }
    }
    return nearestWord;
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pageWidth = constraints.maxWidth / (spread ? 2 : 1);
            final slotHeight = (constraints.maxHeight - 24) / 15;
            final text = _textSize(pageWidth - 4, slotHeight);
            void select(int number) {
              final index = groups.indexWhere(
                (g) => g.any((p) => p['page'] == number),
              );
              if (index >= 0) _controller.jumpToPage(index);
            }

            return GestureDetector(
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
                onPageChanged: (index) => setState(
                  () => _selected = widget.pages.indexOf(groups[index].first),
                ),
                itemBuilder: (context, index) => Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    for (final page in groups[index])
                      Expanded(
                        child: _page(
                          page,
                          text.size,
                          text.width,
                          slotHeight,
                          select,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  TextStyle _style(int page, double size) => TextStyle(
    fontFamily: 'mushaf-$page',
    fontSize: size,
    height: 1,
    color: Colors.black,
  );

  double _width(Map<String, dynamic> word, int page, double size) {
    final painter = TextPainter(
      text: TextSpan(text: word['text'] as String, style: _style(page, size)),
      textDirection: TextDirection.rtl,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  double _inkHeight(Map<String, dynamic> page) {
    final font = page['font'] as Map<String, dynamic>;
    return ((font['yMax'] as num) - (font['yMin'] as num)) /
        (font['unitsPerEm'] as num);
  }

  ({double size, double width}) _textSize(double width, double height) {
    var widest = 1.0;
    var tallest = 1.0;
    // One size across the bundle: opening pages share the normal-page size.
    // Include their bounds too so their diacritics cannot exceed the slots.
    for (final page in widget.pages) {
      tallest = math.max(tallest, _inkHeight(page));
      for (final line in page['lines'] as List) {
        final words = line['words'] as List;
        if (words.isEmpty) continue;
        final lineWidth =
            words.fold<double>(
              0,
              (sum, w) => sum + _width(w, page['page'] as int, 100),
            ) /
            100;
        widest = math.max(widest, lineWidth + (words.length - 1) * .09);
      }
    }
    final size = math.min(width / widest, height / tallest);
    return (size: size, width: size * widest);
  }

  Widget _page(
    Map<String, dynamic> page,
    double fontSize,
    double textWidth,
    double slotHeight,
    ValueChanged<int> select,
  ) {
    final number = page['page'] as int;
    final lines = page['lines'] as List;
    final height = number <= 2
        ? fontSize * widget.pages.map(_inkHeight).reduce(math.max)
        : slotHeight;
    return SizedBox(
      key: ValueKey('page-$number'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: number <= 2
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  for (final line in lines)
                    _line(
                      page,
                      line as Map<String, dynamic>,
                      fontSize,
                      textWidth,
                      height,
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 20,
              child: PopupMenuButton<int>(
                key: ValueKey('page-picker-$number'),
                enabled: !_dragging,
                tooltip: 'Choose page',
                onSelected: select,
                itemBuilder: (_) => [
                  for (final p in widget.pages)
                    PopupMenuItem(
                      value: p['page'] as int,
                      child: Text('Page ${p['page']}'),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$number',
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(
    Map<String, dynamic> page,
    Map<String, dynamic> line,
    double size,
    double textWidth,
    double height,
  ) {
    final number = page['page'] as int;
    final words = line['words'] as List;
    final band = '$number-${line['number']}';
    final bandKey = _bands.putIfAbsent(band, GlobalKey.new);
    _bandWords[band] = [for (final word in words) word['id'] as int];
    Widget content;
    if (line['type'] != 'ayah') {
      // Deliberate spike placeholders; the V4 heading font is not supplied.
      final title = line['type'] == 'basmallah'
          ? 'بسم الله الرحمن الرحيم'
          : switch (line['surah']) {
              1 => 'سورة الفاتحة',
              2 => 'سورة البقرة',
              _ => 'سورة ${line['surah']}',
            };
      content = Center(
        child: Text(
          title,
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: math.min(size, height / 1.5),
            color: Colors.black,
          ),
        ),
      );
    } else {
      content = Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: line['centered'] == true
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < words.length; i++) ...[
            if (i > 0 && line['centered'] == true) SizedBox(width: size * .09),
            _word(words[i] as Map<String, dynamic>, page, size, height),
          ],
        ],
      );
    }
    return SizedBox(
      key: ValueKey('line-$number-${line['number']}'),
      height: height,
      width: double.infinity,
      // Keep the complete hit band while scaling justified lines with the font.
      // A height-limited spread must not stretch its inter-word gaps sideways.
      child: SizedBox(
        key: bandKey,
        child: Center(
          child: SizedBox(width: textWidth, child: content),
        ),
      ),
    );
  }

  Widget _word(
    Map<String, dynamic> word,
    Map<String, dynamic> page,
    double size,
    double height,
  ) {
    final id = word['id'] as int;
    final black = _black.contains(id);
    final font = page['font'] as Map<String, dynamic>;
    final baseline =
        (height - _inkHeight(page) * size) / 2 +
        size * (font['yMax'] as num) / (font['unitsPerEm'] as num);
    return Semantics(
      key: ValueKey('word-$id'),
      container: true,
      label:
          '${word['location']}; ${black ? 'black' : 'grey'}; reveals ${_counts[id] ?? 0}',
      child: SizedBox(
        key: _targets.putIfAbsent(id, GlobalKey.new),
        width: _width(word, page['page'] as int, size),
        height: height,
        child: FlatInk(
          color: black ? Colors.black : const Color(0xFFB0B0B0),
          child: Baseline(
            baseline: baseline,
            baselineType: TextBaseline.alphabetic,
            child: Text(
              word['text'] as String,
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
              style: _style(page['page'] as int, size),
            ),
          ),
        ),
      ),
    );
  }
}
