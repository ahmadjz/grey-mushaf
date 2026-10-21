import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'flat_ink.dart';
import 'heading_ink.dart';

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
  final fonts = jsonDecode(
    await rootBundle.loadString('assets/mushaf/fonts.json'),
  ) as List;
  for (final filename in fonts.cast<String>()) {
    final family = filename == 'surah-name-v4.ttf'
        ? 'surah-name-v4'
        : 'mushaf-${filename.substring(1, filename.length - 4)}';
    await (FontLoader(
      family,
    )..addFont(rootBundle.load('assets/mushaf/$filename'))).load();
  }
  final drawings = <String, Map<String, dynamic>>{};
  final pages = <Map<String, dynamic>>[];
  for (final number in numbers) {
    final page = jsonDecode(
      await rootBundle.loadString('assets/mushaf/$number.json'),
    ) as Map<String, dynamic>;
    for (final line in page['lines'] as List) {
      final heading = line['heading'] as Map<String, dynamic>?;
      if (heading?['kind'] == 'wide') {
        final asset = heading!['asset'] as String;
        drawings[asset] ??= jsonDecode(
          await rootBundle.loadString('assets/mushaf/$asset'),
        ) as Map<String, dynamic>;
        heading['drawing'] = drawings[asset];
      }
    }
    pages.add(page);
  }
  return pages;
}

class Reader extends StatefulWidget {
  const Reader({super.key, required this.pages, this.onMeasureWord});
  final VoidCallback? onMeasureWord;
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
  final _viewport = GlobalKey();
  final _metrics = <int, ({double width, double left, double right})>{};
  final _headings = <String, HeadingInk>{};
  double _widest = 1;
  double _edgeInk = 0;
  double _tallest = 1;
  double _size = 1;

  @override
  void initState() {
    super.initState();
    _measureBundle();
  }

  @override
  void didUpdateWidget(covariant Reader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pages, widget.pages)) _measureBundle();
  }

  void _measureBundle() {
    for (final ink in _headings.values) {
      ink.dispose();
    }
    _headings.clear();
    _metrics.clear();
    _widest = 1;
    _edgeInk = 0;
    _tallest = 1;
    for (final page in widget.pages) {
      _tallest = math.max(_tallest, _inkHeight(page));
      for (final line in page['lines'] as List) {
        final words = line['words'] as List;
        if (line['heading'] != null) {
          _headings['${page['page']}-${line['number']}'] = HeadingInk(
            line['heading'] as Map<String, dynamic>,
            opening: (page['page'] as int) <= 2,
          );
        }
        if (words.isEmpty) continue;
        var width = (words.length - 1) * .09;
        for (final word in words) {
          final metric = _measureWord(word as Map<String, dynamic>, page);
          _metrics[word['id'] as int] = metric;
          width += metric.width;
        }
        _widest = math.max(_widest, width);
        // RTL starts at the right. Advance boxes exclude glyph overhangs;
        // preserve room at both outer ink edges when width limits the page.
        final first = _metrics[words.first['id']]!;
        final last = _metrics[words.last['id']]!;
        if (line['centered'] != true) {
          _edgeInk = math.max(
            _edgeInk,
            (first.right - first.width - last.left) / 2,
          );
        }
      }
    }
  }

  bool _dragging = false;
  bool? _spread;
  int _selected = 0;
  Offset? _previous;
  PageController _controller = PageController();

  @override
  void dispose() {
    for (final ink in _headings.values) {
      ink.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  int? _wordAt(Offset point) {
    final viewport = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return null;
    final visible = viewport.localToGlobal(Offset.zero) & viewport.size;
    if (!visible.contains(point)) return null;
    int? nearestWord;
    var bestOutside = double.infinity;
    var bestEdge = double.infinity;
    for (final entry in _bands.entries) {
      final band = entry.value.currentContext?.findRenderObject();
      if (band is! RenderBox || !band.attached || !band.hasSize) continue;
      final rect = band.localToGlobal(Offset.zero) & band.size;
      // Full vertical line bands, clipped to this PageView's visible viewport.
      // No nearest-band fallback into another page or an off-screen child.
      if (!rect.overlaps(visible) ||
          point.dy < rect.top ||
          point.dy >= rect.bottom) {
        continue;
      }
      for (final id in _bandWords[entry.key] ?? <int>[]) {
        final box = _targets[id]?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize) continue;
        final metric = _metrics[id]!;
        final origin = box.localToGlobal(Offset.zero).dx;
        final left = origin + metric.left * _size;
        final right = origin + metric.right * _size;
        final outside = (point.dx - point.dx.clamp(left, right)).abs();
        // 0.08 em horizontally; vertical hit areas remain the entire line band.
        if (outside > _size * .08) continue;
        final edge = math.min(
          (point.dx - left).abs(),
          (point.dx - right).abs(),
        );
        // Containment beats tolerance. In overlapping extents, use the nearest
        // ink edge rather than the advance-box centre (which can be far away).
        if (outside < bestOutside ||
            (outside == bestOutside && edge < bestEdge)) {
          bestOutside = outside;
          bestEdge = edge;
          nearestWord = id;
        }
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
              key: _viewport,
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

  ({double width, double left, double right}) _measureWord(
    Map<String, dynamic> word,
    Map<String, dynamic> page,
  ) {
    widget.onMeasureWord?.call();
    const reference = 100.0;
    final text = word['text'] as String;
    final painter = TextPainter(
      text: TextSpan(text: text, style: _style(page['page'] as int, reference)),
      textDirection: TextDirection.rtl,
    )..layout();
    final units = (page['font']['unitsPerEm'] as num).toDouble();
    final ink = word['ink'] as List;
    var left = double.infinity;
    var right = double.negativeInfinity;
    var offset = 0;
    var index = 0;
    for (final rune in text.runes) {
      final end = offset + String.fromCharCode(rune).length;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: end),
      );
      // Some QUL words include an intentionally empty glyph (e.g. page 249).
      for (final box in ink[index] == null ? <TextBox>[] : boxes) {
        left = math.min(
          left,
          box.left / reference + (ink[index][0] as num) / units,
        );
        right = math.max(
          right,
          box.left / reference + (ink[index][1] as num) / units,
        );
      }
      offset = end;
      index++;
    }
    final width = painter.width / reference;
    painter.dispose();
    if (!left.isFinite || !right.isFinite) {
      throw StateError('Missing shaped ink bounds for ${word['location']}');
    }
    return (width: width, left: left, right: right);
  }

  double _inkHeight(Map<String, dynamic> page) {
    final font = page['font'] as Map<String, dynamic>;
    return ((font['yMax'] as num) - (font['yMin'] as num)) /
        (font['unitsPerEm'] as num);
  }

  ({double size, double width}) _textSize(double width, double height) {
    _size = math.min(width / (_widest + 2 * _edgeInk), height / _tallest);
    return (size: _size, width: _size * _widest);
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
    final height = number <= 2 ? textWidth * 47 / 543 : slotHeight;
    return SizedBox(
      key: ValueKey('page-$number'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
        child: Column(
          children: [
            Expanded(
              child: number <= 2
                  ? Center(
                      child: SizedBox(
                        height: textWidth * 892 / 543,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final line in lines)
                              Positioned(
                                left: 0,
                                right: 0,
                                // Source coordinates relative to the normal
                                // 543 x 892 ink block beginning at y=157.
                                top:
                                    textWidth *
                                    (line['type'] == 'surah_name'
                                        ? 142
                                        : 278.5 +
                                              ((line['number'] as int) - 2) *
                                                  47) /
                                    543,
                                child: _line(
                                  page,
                                  line as Map<String, dynamic>,
                                  fontSize,
                                  textWidth,
                                  height,
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : Column(
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
      // Reference ink boxes at the same scale as the 543 px normal text
      // block: pages 1/2/50, rendered from the owner's 1441 .ai originals.
      final kind = (line['heading'] as Map<String, dynamic>)['kind'];
      final dimensions = kind == 'compact'
          ? const Size(172, 40)
          : kind == 'wide'
          ? const Size(307, 40)
          : number == 1
          ? const Size(101, 29)
          : number == 2
          ? const Size(93, 31)
          : Size(133 * _headings[band]!.bounds.width / 295.9669529186764, 45);
      content = Center(
        child: SizedBox(
          key: ValueKey('heading-$band'),
          width: textWidth * dimensions.width / 543,
          height: textWidth * dimensions.height / 543,
          child: FlatInk(
            color: Colors.black,
            child: CustomPaint(painter: _headings[band]),
          ),
        ),
      );
      if (number > 2) {
        content = Transform.translate(
          offset: Offset(0, textWidth * 29.5 / 543 - height / 2),
          child: content,
        );
      }
      if (kind == 'wide') {
        // Preserve the printed heading-to-basmallah distance even when the
        // full-screen line bands are taller than the natural text scale.
        content = Transform.translate(
          offset: Offset(0, textWidth * 63.5 / 543 - height),
          child: content,
        );
      }
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
    if (words.isNotEmpty && line['centered'] != true) {
      final first = _metrics[words.first['id']]!;
      final last = _metrics[words.last['id']]!;
      // Only correct ink that would cross this page's physical edge. In
      // height-limited views the existing spare margin already contains it.
      final viewport = MediaQuery.sizeOf(context);
      final pageWidth =
          viewport.width / (viewport.width > viewport.height ? 2 : 1);
      final spare = math.max(0.0, (pageWidth - 4 - textWidth) / 2);
      final right = (first.right - first.width) * size;
      final left = last.left * size;
      final shift = right > spare
          ? spare - right
          : left < -spare
          ? -spare - left
          : 0.0;
      content = Transform.translate(offset: Offset(shift, 0), child: content);
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
        width: _metrics[id]!.width * size,
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
