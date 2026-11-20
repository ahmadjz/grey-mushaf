import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'account_screen.dart';
import 'bookmarks.dart';
import 'flat_ink.dart';
import 'page_ink.dart';
import 'bundle_metrics.dart';
import 'mushaf_bundle.dart';
import 'loaded_page_controller.dart';
import 'heading_ink.dart';
import 'mushaf_index.dart';
import 'navigation_screen.dart';
import 'quick_jump.dart';
import 'quran_index.dart';
import 'reveal_store.dart';
import 'search_screen.dart';
import 'sync.dart';
import 'sync_local.dart';
import 'reader_settings.dart';
import 'word_marks.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = await SqliteRevealStore.open();
    final bundle = await MushafBundle.open(near: store.lastPage);
    final index = await QuranIndex.load(rootBundle);
    final eInk = await isEInkDevice();
    final sync = SyncEngine(store, PocketBaseApi(syncServer));
    unawaited(
      sync.start().catchError(
        (Object error) => debugPrint('Sync could not start: $error'),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('READER_FIRST_FRAME ${DateTime.now().millisecondsSinceEpoch}');
    });
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        ),
        home: Reader(
          pages: bundle.pages,
          bundle: bundle,
          store: store,
          settings: store,
          toolbarSettings: store,
          navigation: store,
          index: index,
          loadSearch: () => SearchIndex.load(rootBundle),
          eInk: eInk,
          sync: sync,
        ),
      ),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('Cannot open reader: $error'))),
      ),
    );
  }
}

Future<bool> isEInkDevice() async {
  try {
    return await const MethodChannel('tech.ahmadjz.greymushaf/reader')
            .invokeMethod<bool>('isEInk') ??
        false;
  } on MissingPluginException {
    return false;
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
  const Reader({
    super.key,
    required this.pages,
    required this.store,
    this.onMeasureWord,
    this.settings,
    this.toolbarSettings,
    this.bundle,
    this.navigation,
    this.index,
    this.loadSearch,
    this.eInk = false,
    this.sync,
  });
  final bool eInk;
  final SyncEngine? sync;
  final MushafBundle? bundle;
  final NavigationStore? navigation;
  final QuranIndex? index;
  final Future<SearchIndex?> Function()? loadSearch;
  final RevealStore store;
  final ReaderSettings? settings;
  final ToolbarSettings? toolbarSettings;
  final VoidCallback? onMeasureWord;
  final List<Map<String, dynamic>> pages;

  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader> with WidgetsBindingObserver {
  static const _platform = MethodChannel('tech.ahmadjz.greymushaf/reader');
  bool _barsVisible = false;
  EdgeInsets _cutout = EdgeInsets.zero;
  double _statusTop = 0;
  late int _greyLevel;
  late int _darkLevel;
  bool _darkMode = false;
  late bool _blackWhite;
  Color get _background => _darkMode ? Colors.black : Colors.white;
  Color get _foreground => _darkMode ? Colors.white : Colors.black;
  int get _activeLevel => _darkMode ? _darkLevel : _greyLevel;
  Color get _dim =>
      Color.fromARGB(255, _activeLevel, _activeLevel, _activeLevel);
  Color _markInk(MarkColor colour) =>
      _blackWhite ? _foreground : colour.paint(_foreground);
  ColorScheme get _scheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.grey,
      dynamicSchemeVariant: _blackWhite
          ? DynamicSchemeVariant.monochrome
          : DynamicSchemeVariant.tonalSpot,
      brightness: _darkMode ? Brightness.dark : Brightness.light,
    );
    if (!_blackWhite) return scheme;
    return scheme.copyWith(
      error: scheme.onSurface,
      onError: scheme.surface,
      errorContainer: scheme.surfaceContainerHighest,
      onErrorContainer: scheme.onSurface,
    );
  }

  ThemeData get _theme => ThemeData(
    colorScheme: _scheme,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _darkMode ? const Color(0xFF303030) : null,
      contentTextStyle: _darkMode ? const TextStyle(color: Colors.white) : null,
      actionTextColor: _darkMode ? Colors.white : null,
      behavior: SnackBarBehavior.floating,
      insetPadding: EdgeInsets.fromLTRB(
        _cutout.left + _arrowInset + _arrowSize + 8,
        0,
        _cutout.right + _arrowInset + _arrowSize + 8,
        _cutout.bottom + 8,
      ),
    ),
  );

  Future<void> _settingWrites = Future<void>.value();
  final _settingFailures = ValueNotifier<Set<bool>>({});
  bool _settingsOpen = false;
  double _contentWidth = 0;
  static const _headerHeight = 14.0;
  bool get _largeScreen =>
      (MediaQuery.maybeSizeOf(context)?.shortestSide ?? 0) >= 600;
  double get _arrowSize => _largeScreen ? 64 : 44;
  double get _arrowInset => _largeScreen ? 16 : 0;
  late bool _arrowsShown;
  late final Map<String, Offset> _arrowSpots;
  final _arrowDragOrigins = <String, Offset>{};
  int? _arrowTarget;
  int _arrowTurns = 0;
  int _groupCount = 0;
  late final _shownPage = ValueNotifier<int>(
    widget.pages.isEmpty ? 1 : widget.pages[_selected]['page'] as int,
  );
  final _highlight = ValueNotifier<({int page, int surah, int ayah})?>(null);
  List<List<Map<String, dynamic>>> _groups = const [];
  late final Map<int, int> _bookmarks = {
    ...?widget.navigation?.bookmarkSavedAt,
  };
  bool _bookmarkSaving = false;
  Future<SearchIndex?>? _search;
  int? _requestedPage;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _saveMessage;
  int? _savedLastPage;

  List<int> get _shownPages => [
    for (final page
        in _groups.isEmpty
            ? const <Map<String, dynamic>>[]
            : _groups[_groupOf(_shownPage.value)])
      page['page'] as int,
  ];

  int _groupOf(int page) =>
      math.max(0, _groups.indexWhere((g) => g.any((p) => p['page'] == page)));

  Future<void> _toggleBookmark() async {
    final store = widget.navigation;
    if (store == null || _bookmarkSaving) return;
    final shown = _shownPages;
    final saved = shown.where(_bookmarks.containsKey).toList();
    final actions = saved.isEmpty
        ? [BookmarkAction(shown.first, true)]
        : [for (final page in saved) BookmarkAction(page, false)];
    await _saveBookmarks(actions);
  }

  Future<void> _saveBookmarks(List<BookmarkAction> actions) async {
    final store = widget.navigation!;
    setState(() => _bookmarkSaving = true);
    try {
      await store.saveBookmarks(actions);
      if (!mounted) return;
      setState(() {
        _bookmarks
          ..clear()
          ..addAll(store.bookmarkSavedAt);
      });
    } catch (_) {
      _showSaveFailure(
        'bookmark',
        retry: () => unawaited(_saveBookmarks(actions)),
      );
    } finally {
      if (mounted) setState(() => _bookmarkSaving = false);
    }
  }

  void _saveLastPage(int page) {
    final store = widget.navigation;
    if (store == null || page == _savedLastPage) return;
    _savedLastPage = page;
    unawaited(
      store.saveLastPage(page).catchError((Object _) {
        if (_savedLastPage == page) _savedLastPage = null;
      }),
    );
  }

  void _goTo(NavTarget? target) {
    if (target == null || !mounted || _groups.isEmpty) return;
    final selected = widget.pages.indexWhere((p) => p['page'] == target.page);

    if (selected < 0) return;
    final group = _groupOf(target.page);
    final ayah = target.ayah;
    _highlight.value = ayah == null
        ? null
        : (page: target.page, surah: target.surah!, ayah: ayah);
    _arrowTarget = null;
    if (group == _groupOf(_shownPage.value)) {
      final controller = _controller;
      if (controller is LoadedPageController) {
        controller.cancelPendingNavigation();
        widget.bundle?.cancelPendingLoads();
        unawaited(_prefetch(target.page));
      }
      _requestedPage = null;
      _selected = selected;
      _saveLastPage(target.page);
      return;
    }
    _requestedPage = target.page;
    _controller.jumpToPage(group);
  }

  Future<void> _openNavigation() async {
    final index = widget.index;
    if (index == null) return;
    final target = await Navigator.of(context).push<NavTarget>(
      MaterialPageRoute(
        builder: (context) => Theme(
          data: _theme,
          child: NavigationScreen(index: index, store: widget.navigation),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _bookmarks
        ..clear()
        ..addAll(widget.navigation?.bookmarkSavedAt ?? const {});
    });
    _goTo(target);
  }

  Future<void> _openSearch() async {
    final index = widget.index;
    if (index == null) return;
    final target = await Navigator.of(context).push<NavTarget>(
      MaterialPageRoute(
        builder: (context) => Theme(
          data: _theme,
          child: SearchScreen(
            index: index,
            blackWhite: _blackWhite,
            search: _search ??=
                widget.loadSearch?.call() ?? Future<SearchIndex?>.value(),
          ),
        ),
      ),
    );
    _goTo(target);
  }

  Future<void> _openQuickJump() async {
    final index = widget.index;
    if (index == null) return;
    final target = await showQuickJump(
      context,
      index,
      _shownPage.value,
      theme: _theme,
    );
    _goTo(target);
  }

  void _setDarkMode(bool dark) {
    setState(() => _darkMode = dark);
    unawaited(_setBars());
  }

  void _showSaveFailure(String what, {VoidCallback? retry}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _darkMode ? const Color(0xFF303030) : null,
        content: Text(
          "Couldn't save $what",
          style: _darkMode ? const TextStyle(color: Colors.white) : null,
        ),
        action: retry == null
            ? null
            : SnackBarAction(
                textColor: _darkMode ? Colors.white : null,
                label: 'Retry',
                onPressed: retry,
              ),
      ),
    );
  }

  Future<void> _saveBlackWhite(bool on) async {
    try {
      await widget.settings?.saveBlackWhite(on);
    } catch (_) {
      _showSaveFailure('black & white setting');
    }
  }

  Future<void> _saveArrowsShown(bool shown) async {
    try {
      await widget.settings?.saveArrowsShown(shown);
    } catch (_) {
      _showSaveFailure('arrows setting');
    }
  }

  Future<void> _saveArrowSpot(String key) async {
    try {
      await widget.settings?.saveArrowSpot(key, _arrowSpots[key]!);
    } catch (_) {
      _showSaveFailure(
        'arrow position',
        retry: () => unawaited(_saveArrowSpot(key)),
      );
    }
  }

  late ToolbarPrefs _toolbar;
  bool _stripOpen = false;
  Offset? _ballDrag;
  static const _ballSize = 48.0;

  Future<void> _saveToolbar(ToolbarPrefs prefs) async {
    setState(() => _toolbar = prefs);
    try {
      await widget.toolbarSettings?.saveToolbar(prefs);
    } catch (_) {
      _showSaveFailure(
        'toolbar',
        retry: () => unawaited(_saveToolbar(_toolbar)),
      );
    }
  }

  void _turn(int delta) {
    final controller = _controller;
    if (!controller.hasClients) return;
    final base =
        _arrowTarget ??
        (controller.page ?? controller.initialPage.toDouble()).round();
    final target = base + delta;
    if (target < 0 || target >= _groupCount) return;
    _arrowTarget = target;
    final turn = ++_arrowTurns;
    controller.jumpToPage(target);
    unawaited(
      (controller is LoadedPageController
              ? controller.pending
              : Future<void>.value())
          .whenComplete(() {
            if (turn == _arrowTurns) _arrowTarget = null;
          }),
    );
  }

  Future<void> _readInsets() async {
    try {
      final data = await _platform.invokeMapMethod<String, dynamic>(
        'getInsets',
      );
      if (!mounted || data == null) return;
      double value(String key) => (data[key] as num?)?.toDouble() ?? 0;
      final cutout = EdgeInsets.fromLTRB(
        value('left'),
        value('top'),
        value('right'),
        value('bottom'),
      );
      final status = value('statusTop');
      if (cutout != _cutout || status != _statusTop) {
        setState(() {
          _cutout = cutout;
          _statusTop = status;
        });
      }
    } on MissingPluginException {
      // Widget tests and non-Android hosts have no system bars to control.
    }
  }

  Future<void> _setBars() async {
    try {
      await _platform.invokeMethod<void>('setDarkMode', _darkMode);
      await _platform.invokeMethod<void>('setBarsVisible', _barsVisible);
      await _readInsets();
    } on MissingPluginException {
      // Native Android owns the system bars.
    }
  }

  @override
  void didChangeMetrics() {
    unawaited(_readInsets());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.sync?.foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) return;
    unawaited(_setBars());
    if (widget.sync case final sync?) unawaited(sync.sync());
  }

  StreamSubscription<SyncChange>? _remoteChanges;

  void _showRemoteChange(SyncChange change) {
    if (!mounted) return;
    for (final key in change.words) {
      _pageInk[_wordPages[key]]?.changed();
    }
    if (change.words.isNotEmpty) _wordRevision.value++;
    if (change.bookmarks) {
      setState(() {
        _bookmarks
          ..clear()
          ..addAll(widget.navigation?.bookmarkSavedAt ?? const {});
      });
    }
  }

  void _toggleBars() {
    setState(() => _barsVisible = !_barsVisible);
    unawaited(_setBars());
  }

  void _saveLevel(int level, {required bool dark}) {
    _settingWrites = _settingWrites.then((_) async {
      try {
        if (dark) {
          await widget.settings?.saveDarkLevel(level);
        } else {
          await widget.settings?.saveGreyLevel(level);
        }
        if (mounted) {
          _settingFailures.value = {..._settingFailures.value}..remove(dark);
        }
      } catch (_) {
        if (!mounted) return;
        _settingFailures.value = {..._settingFailures.value, dark};
        if (_settingsOpen) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _darkMode ? const Color(0xFF303030) : null,
            content: Text(
              "Couldn't save ${dark ? 'dark' : 'grey'} level",
              style: _darkMode ? const TextStyle(color: Colors.white) : null,
            ),
            action: SnackBarAction(
              textColor: _darkMode ? Colors.white : null,
              label: 'Retry',
              onPressed: () =>
                  _saveLevel(dark ? _darkLevel : _greyLevel, dark: dark),
            ),
          ),
        );
      }
    });
  }

  Future<void> _openSettings() async {
    _settingsOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, updateSheet) {
          final sample = widget.pages.firstWhere(
            (page) => page['lines'] != null,
          );
          final line = (sample['lines'] as List).firstWhere(
            (line) => (line['words'] as List).isNotEmpty,
          );
          final word = (line['words'] as List).first;
          return Theme(
            data: _theme,
            child: Material(
              color: _darkMode
                  ? const Color(0xFF181818)
                  : _theme.colorScheme.surface,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Settings',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close Settings',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        title: const Text('Page-turn arrows'),
                        value: _arrowsShown,
                        onChanged: (value) {
                          setState(() => _arrowsShown = value);
                          updateSheet(() {});
                          unawaited(_saveArrowsShown(value));
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Black & white'),
                        value: _blackWhite,
                        onChanged: (value) {
                          setState(() => _blackWhite = value);
                          updateSheet(() {});
                          unawaited(_saveBlackWhite(value));
                        },
                      ),
                      if (widget.sync case final sync?)
                        SyncSettings(engine: sync, theme: _theme),
                      Text(
                        _darkMode
                            ? 'Dark text brightness'
                            : 'Grey text lightness',
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final color in [_dim, _foreground])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: FlatInk(
                                color: color,
                                background: _background,
                                child: Text(
                                  word['text'] as String,
                                  style: wordStyle(sample['page'] as int, 36),
                                  textScaler: TextScaler.noScaling,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Slider(
                        min: _darkMode ? 32 : 128,
                        max: _darkMode ? 128 : 224,
                        divisions: 96,
                        value: _activeLevel.toDouble(),
                        semanticFormatterCallback: (value) =>
                            '${_darkMode ? 'Dark brightness' : 'Grey lightness'} ${((value - (_darkMode ? 32 : 128)) / 96 * 100).round()} percent',
                        onChanged: (value) {
                          setState(() {
                            if (_darkMode) {
                              _darkLevel = value.round();
                            } else {
                              _greyLevel = value.round();
                            }
                          });
                          updateSheet(() {});
                        },
                        onChangeEnd: (value) =>
                            _saveLevel(value.round(), dark: _darkMode),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_darkMode ? 'Dimmer' : 'Darker'),
                          Text(_darkMode ? 'Brighter' : 'Lighter'),
                        ],
                      ),
                      ValueListenableBuilder<Set<bool>>(
                        valueListenable: _settingFailures,
                        builder: (context, failures, child) => Column(
                          children: [
                            for (final dark in failures)
                              Semantics(
                                liveRegion: true,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Couldn't save ${dark ? 'dark' : 'grey'} level",
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _saveLevel(
                                        dark ? _darkLevel : _greyLevel,
                                        dark: dark,
                                      ),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    _settingsOpen = false;
  }

  final _wordKeys = <int, String>{};
  final _pending = Queue<Object>();
  final _wordRevision = ValueNotifier<int>(0);
  bool _saving = false;
  bool _saveFailed = false;
  final _saveFailure = ValueNotifier<bool>(false);

  void _enqueue(Object action) {
    assert(action is WordAction || action is MarkAction);
    _pending.add(action);
    _wordRevision.value++;
    if (!_saveFailed) unawaited(_savePending());
  }

  ({bool black, WordMarks marks}) _projected(String key) {
    var black = widget.store.state(key).black;
    var marks = widget.store.marks(key);
    for (final action in _pending) {
      if (action is WordAction && action.key == key) black = action.black;
      if (action is MarkAction && action.key == key) {
        marks = marks.withMark(action.kind, action.mark);
      }
    }
    return (black: black, marks: marks);
  }

  bool _hasPending(String key) => _pending.any(
    (action) =>
        (action is WordAction ? action.key : (action as MarkAction).key) == key,
  );

  Future<void> _savePending() async {
    if (_saving) return;
    _saving = true;
    _saveFailed = false;
    _saveFailure.value = false;
    try {
      while (_pending.isNotEmpty) {
        final next = _pending.first;
        if (next is WordAction) {
          await widget.store.save(next);
        } else {
          await widget.store.saveMark(next as MarkAction);
        }
        _pending.removeFirst();
        final key = next is WordAction ? next.key : (next as MarkAction).key;
        if (mounted) _pageInk[_wordPages[key]]?.changed();
        if (mounted) _wordRevision.value++;
      }
      if (mounted) _closeSaveMessage();
    } catch (_) {
      _saveFailed = true;
      if (mounted) {
        _saveFailure.value = true;
        if (_saveMessage == null) {
          final message = _saveMessage = ScaffoldMessenger.of(context)
              .showSnackBar(
                SnackBar(
                  backgroundColor: _darkMode ? const Color(0xFF303030) : null,
                  content: Text(
                    "Couldn't save",
                    style: _darkMode
                        ? const TextStyle(color: Colors.white)
                        : null,
                  ),
                  dismissDirection: DismissDirection.none,
                  action: SnackBarAction(
                    textColor: _darkMode ? Colors.white : null,
                    label: 'Retry',
                    onPressed: () {
                      _saveMessage = null;
                      unawaited(_savePending());
                    },
                  ),
                ),
              );
          unawaited(
            message.closed.then((_) {
              if (identical(_saveMessage, message)) _saveMessage = null;
            }),
          );
        }
      }
    } finally {
      _saving = false;
    }
  }

  void _closeSaveMessage() {
    if (_saveMessage == null) return;
    _saveMessage = null;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  final _pageInk = <int, PageInkController>{};
  final _wordPages = <String, int>{};
  final _bundleRevision = ValueNotifier<int>(0);
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
    _greyLevel = widget.settings?.greyLevel ?? 176;
    _darkLevel = widget.settings?.darkLevel ?? 80;
    _arrowsShown = widget.settings?.arrowsShown ?? true;
    _blackWhite = widget.settings?.blackWhite ?? widget.eInk;
    _arrowSpots = {...?widget.settings?.arrowSpots};
    final last = widget.navigation?.lastPage;
    _selected = math.max(0, widget.pages.indexWhere((p) => p['page'] == last));
    _savedLastPage = last;
    _toolbar = widget.toolbarSettings?.toolbar ?? const ToolbarPrefs();
    WidgetsBinding.instance.addObserver(this);
    _remoteChanges = widget.sync?.local.remoteChanges.listen(_showRemoteChange);
    unawaited(_setBars());
    _measureBundle();
  }

  @override
  void didUpdateWidget(covariant Reader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pages, widget.pages)) _measureBundle();
  }

  MushafBundle? _measuredBundle;

  void _measureBundle() {
    final reuse =
        widget.bundle != null && identical(_measuredBundle, widget.bundle);
    _measuredBundle = widget.bundle;
    final previousMetrics = Map.of(_metrics);
    final previousHeadings = Map.of(_headings);
    if (!reuse) {
      previousMetrics.clear();
      for (final ink in previousHeadings.values) {
        ink.dispose();
      }
      previousHeadings.clear();
    }
    _headings.clear();
    _metrics.clear();
    _widest = widget.bundle?.metrics.widest ?? 1;
    _edgeInk = widget.bundle?.metrics.edgeInk ?? 0;
    _tallest = widget.bundle?.metrics.tallest ?? 1;
    _wordKeys.clear();
    _wordPages.clear();
    for (final page in widget.pages) {
      if (page['lines'] == null) continue;
      _tallest = math.max(_tallest, inkHeight(page));
      for (final line in page['lines'] as List) {
        final words = line['words'] as List;
        if (line['heading'] != null) {
          final band = '${page['page']}-${line['number']}';
          _headings[band] =
              previousHeadings.remove(band) ??
              HeadingInk(
                line['heading'] as Map<String, dynamic>,
                opening: (page['page'] as int) <= 2,
              );
        }
        if (words.isEmpty) continue;
        var width = (words.length - 1) * .09;
        for (final word in words) {
          final cached = previousMetrics[word['id']];
          final prepared = widget.bundle == null
              ? null
              : word['metrics'] as List;
          if (cached == null && prepared == null) widget.onMeasureWord?.call();
          final metric =
              cached ??
              (prepared == null
                  ? measureWord(word as Map<String, dynamic>, page)
                  : (
                      width: (prepared[0] as num).toDouble(),
                      left: (prepared[1] as num).toDouble(),
                      right: (prepared[2] as num).toDouble(),
                    ));
          _metrics[word['id'] as int] = metric;
          _wordKeys[word['id'] as int] = wordKey(word['location'] as String);
          _wordPages[wordKey(word['location'] as String)] = page['page'] as int;
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
    for (final ink in previousHeadings.values) {
      ink.dispose();
    }
    final retained = {
      for (final p in widget.pages)
        if (p['lines'] != null) p['page'],
    };
    _pageInk.removeWhere((number, ink) {
      if (retained.contains(number) || ink.owner != null) return false;
      ink.dispose();
      return true;
    });
  }

  void _showLoadError(VoidCallback retry) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _darkMode ? const Color(0xFF303030) : null,
        content: Text(
          "Couldn't load page",
          style: _darkMode ? const TextStyle(color: Colors.white) : null,
        ),
        action: SnackBarAction(label: 'Retry', onPressed: retry),
      ),
    );
  }

  Future<void> _prefetch(int number) async {
    try {
      final loaded = await widget.bundle!.loadNear(number);
      if (mounted && loaded) {
        _measureBundle();
        _bundleRevision.value++;
        if (!_scrolling) _prewarm();
      }
    } catch (_) {
      _showLoadError(
        () => unawaited(_prefetch(widget.pages[_selected]['page'] as int)),
      );
    }
  }

  bool _dragging = false;
  bool? _spread;
  int _selected = 0;
  int? _pendingPrefetch;
  int _warmGeneration = 0;
  Timer? _warmTimer;
  TextStyle? _baseTextStyle;
  double? _wordSize;
  PageController _controller = PageController();

  @override
  void dispose() {
    unawaited(_remoteChanges?.cancel());
    _warmTimer?.cancel();
    widget.bundle?.cancelPendingLoads();
    WidgetsBinding.instance.removeObserver(this);
    _settingFailures.dispose();
    _shownPage.dispose();
    _highlight.dispose();
    _saveFailure.dispose();
    _bundleRevision.dispose();
    _wordRevision.dispose();
    for (final ink in _pageInk.values) {
      ink.dispose();
    }
    for (final ink in _headings.values) {
      ink.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  int? _wordAt(Offset point, {bool shortTap = false}) {
    final viewport = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return null;
    final visible = viewport.localToGlobal(Offset.zero) & viewport.size;
    if (!visible.contains(point)) return null;
    int? nearestWord;
    var bestOutside = double.infinity;
    var bestEdge = double.infinity;
    for (final ink in _pageInk.values) {
      if (ink.owner == null || !ink.owner!.attached || !ink.owner!.hasSize) {
        continue;
      }
      if (!ink.globalRect(Offset.zero & ink.owner!.size).overlaps(visible)) {
        continue;
      }
      final hit = ink.hitAt(point, shortTap: shortTap);
      if (hit != null &&
          (hit.outside < bestOutside ||
              (hit.outside == bestOutside && hit.edge < bestEdge))) {
        bestOutside = hit.outside;
        bestEdge = hit.edge;
        nearestWord = hit.id;
      }
    }
    return nearestWord;
  }

  void _start(LongPressStartDetails details) {
    setState(() => _dragging = true);
    final id = _wordAt(details.globalPosition);
    if (id == null) return;
    final key = _wordKeys[id]!;
    final now = _projected(key);
    for (final tool in _toolbar.tools) {
      final style = tool.style;
      if (style == null) {
        if (!now.black) _enqueue(WordAction(key, true));
      } else if (now.marks.of(style.kind)?.style != style) {
        _enqueue(
          MarkAction(key, style.kind, (style: style, color: _toolbar.color)),
        );
      }
    }
  }

  void _tapWord(int id) {
    final key = _wordKeys[id]!;
    final shown = (
      black: widget.store.state(key).black,
      marks: widget.store.marks(key),
    );
    if (!shown.marks.isEmpty) {
      unawaited(_openMarkBox(key, shown));
    } else if (shown.black && _projected(key).black) {
      _enqueue(WordAction(key, false));
    }
  }

  Future<void> _openMarkBox(
    String key,
    ({bool black, WordMarks marks}) original,
  ) async {
    final rows =
        <
          ({
            String label,
            Color? swatch,
            bool Function(({bool black, WordMarks marks}) word) on,
            Object Function(bool on) act,
          })
        >[
          if (original.black)
            (
              label: 'Visible',
              swatch: null,
              on: (word) => word.black,
              act: (on) => WordAction(key, on),
            ),
          for (final kind in MarkKind.values)
            if (original.marks.of(kind) case final mark?)
              (
                label: _styleLabels[mark.style]!,
                swatch: _markInk(mark.color),
                on: (word) => word.marks.of(kind) != null,
                act: (on) => MarkAction(key, kind, on ? mark : null),
              ),
        ];
    var closing = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Theme(
        data: _theme,
        child: ValueListenableBuilder<int>(
          valueListenable: _wordRevision,
          builder: (dialogContext, _, _) {
            final intended = _projected(key);
            if (!closing &&
                !rows.any((row) => row.on(intended)) &&
                !_hasPending(key)) {
              closing = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogContext.mounted &&
                    ModalRoute.of(dialogContext)?.isCurrent == true) {
                  Navigator.of(dialogContext).pop();
                }
              });
            }
            return AlertDialog(
              key: const ValueKey('mark-box'),
              contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _saveFailure,
                    builder: (context, failed, _) => failed
                        ? Row(
                            key: const ValueKey('mark-box-failure'),
                            children: [
                              const SizedBox(width: 16),
                              const Expanded(child: Text("Couldn't save")),
                              TextButton(
                                onPressed: () => unawaited(_savePending()),
                                child: const Text('Retry'),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  for (final row in rows)
                    CheckboxListTile(
                      key: ValueKey('mark-row-${row.label}'),
                      dense: true,
                      value: row.on(intended),
                      title: Text(row.label),
                      secondary: row.swatch == null
                          ? null
                          : CircleAvatar(
                              radius: 8,
                              backgroundColor: row.swatch,
                            ),
                      onChanged: (on) {
                        if (on == null || on == row.on(_projected(key))) return;
                        _enqueue(row.act(on));
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    final now = _projected(key);
                    if (now.black) _enqueue(WordAction(key, false));
                    for (final kind in MarkKind.values) {
                      if (now.marks.of(kind) != null) {
                        _enqueue(MarkAction(key, kind, null));
                      }
                    }
                    closing = true;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Clear all'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const _styleLabels = {
    MarkStyle.singleLine: 'Single line',
    MarkStyle.doubleLine: 'Double line',
    MarkStyle.rectangle: 'Rectangle',
    MarkStyle.circle: 'Circle',
  };

  void _end() {
    if (!_dragging) return;
    setState(() => _dragging = false);
  }

  bool get _scrolling =>
      _controller.hasClients && _controller.position.isScrollingNotifier.value;

  bool get _onPage {
    final page = _controller.hasClients ? _controller.page : null;
    return page == null || (page - page.round()).abs() < 1e-3;
  }

  void _afterScroll() {
    if (!_onPage) return;
    if (widget.pages.isNotEmpty) {
      _saveLastPage(widget.pages[_selected]['page'] as int);
    }
    final pending = _pendingPrefetch;
    _pendingPrefetch = null;
    if (pending != null && widget.bundle != null) {
      unawaited(_prefetch(pending));
    }
    _prewarm();
  }

  void _prewarm() {
    final base = _baseTextStyle, size = _wordSize;
    if (!mounted || base == null || size == null || widget.pages.isEmpty) {
      return;
    }
    final generation = ++_warmGeneration;
    final current = widget.pages[_selected]['page'] as int;
    final odd = current.isOdd ? current : current - 1;
    final wanted = _spread == true
        ? [odd - 2, odd - 1, odd + 2, odd + 3]
        : [current - 1, current + 1];
    final work = <({List words, TextStyle style})>[
      for (final page in widget.pages)
        if (wanted.contains(page['page']) && page['lines'] != null)
          for (final line in page['lines'] as List)
            if (line['type'] == 'ayah')
              (
                words: line['words'] as List,
                style: base.merge(wordStyle(page['page'] as int, size)),
              ),
    ];
    var next = 0;
    void step() {
      if (generation != _warmGeneration || !mounted || _scrolling || !_onPage) {
        return;
      }
      if (next == work.length) return;
      final scheduler = SchedulerBinding.instance;
      if (scheduler.transientCallbackCount > 0) {
        scheduler.addPostFrameCallback((_) => step());
        return;
      }
      final line = work[next++];
      for (final word in line.words) {
        final metric = _metrics[word['id']];
        if (metric == null) continue;
        paragraphPool.prewarm(
          word['text'] as String,
          line.style,
          metric.width * size,
        );
      }
      _warmTimer = Timer(Duration.zero, step);
    }

    _warmTimer?.cancel();
    _warmTimer = Timer(Duration.zero, step);
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
      widget.bundle?.cancelPendingLoads();
      final selectedPage = widget.pages.isEmpty
          ? 1
          : widget.pages[_selected]['page'];
      final index = groups.indexWhere(
        (g) => g.any((p) => p['page'] == selectedPage),
      );
      final old = _controller;
      _controller = widget.bundle == null
          ? PageController(initialPage: math.max(0, index))
          : LoadedPageController(
              initialPage: math.max(0, index),
              onLoadError: (index, error) {
                final number = spread ? index * 2 + 1 : index + 1;
                _showLoadError(
                  () => _controller.jumpToPage(
                    _spread == true ? (number - 1) ~/ 2 : number - 1,
                  ),
                );
              },
              prepare: (index) async {
                final bundle = widget.bundle!;
                final first = spread ? index * 2 + 1 : index + 1;
                final shown = [first, if (spread && first < 604) first + 1];
                if (shown.every((n) => bundle.pages[n - 1]['lines'] != null)) {
                  return;
                }
                final loaded = await bundle.loadNear(first);
                if (mounted && loaded) {
                  _measureBundle();
                  _bundleRevision.value++;
                }
              },
            );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
        if (mounted && index >= 0) {
          _shownPage.value = groups[index].first['page'] as int;
        }
        if (mounted && widget.bundle != null) {
          // Rotation invalidates navigation and prefetch alike. Restore the
          // visible window even when no page-change callback follows.
          unawaited(_prefetch(widget.pages[_selected]['page'] as int));
        }
      });
      _spread = spread;
      _arrowTarget = null;
    }
    _groupCount = groups.length;
    _groups = groups;
    final screen = MediaQuery.sizeOf(context);
    return Theme(
      data: _theme,
      child: Scaffold(
        backgroundColor: _background,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: _cutout,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final pageWidth = constraints.maxWidth / (spread ? 2 : 1);
                  final pageHeight = constraints.maxHeight - 4 - _headerHeight;
                  final side = spread
                      ? 7.0
                      : MediaQuery.sizeOf(context).width * .02;
                  _contentWidth = pageWidth - side * 2;
                  // Reserve number clearance only when the last line's spare ink
                  // space cannot contain it. This bound keeps one font size throughout.
                  final text = _textSize(_contentWidth, (pageHeight - 14) / 15);
                  final base = DefaultTextStyle.of(context).style;
                  final restyled =
                      base != _baseTextStyle || text.size != _wordSize;
                  _baseTextStyle = base;
                  _wordSize = text.size;
                  if (restyled) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _prewarm(),
                    );
                  }
                  return GestureDetector(
                    key: _viewport,
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: _start,
                    onLongPressEnd: (_) => _end(),
                    onLongPressCancel: _end,
                    onTapUp: (details) {
                      _highlight.value = null;
                      final id = _wordAt(
                        details.globalPosition,
                        shortTap: true,
                      );
                      if (id == null) {
                        _toggleBars();
                      } else {
                        _tapWord(id);
                      }
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.depth != 0) return false;
                        if (notification is ScrollStartNotification) {
                          _warmGeneration++;
                          if (notification.dragDetails != null) {
                            _arrowTarget = null;
                            _arrowTurns++;
                          }
                        } else if (notification is ScrollEndNotification) {
                          _afterScroll();
                        }
                        return false;
                      },
                      child: PageView.builder(
                        key: ValueKey(spread),
                        controller: _controller,
                        reverse: true,
                        physics: _dragging
                            ? const NeverScrollableScrollPhysics()
                            : widget.bundle == null
                            ? const PageScrollPhysics()
                            : LoadedPagePhysics(
                                first: () =>
                                    (widget.bundle!.loadedNumbers.first - 1) ~/
                                    (spread ? 2 : 1),
                                last: () =>
                                    (widget.bundle!.loadedNumbers.last - 1) ~/
                                    (spread ? 2 : 1),
                              ),
                        itemCount: groups.length,
                        onPageChanged: (index) {
                          debugPrint(
                            'READER_PAGE ${groups[index].first['page']}',
                          );
                          final controller = _controller;
                          if (controller is LoadedPageController) {
                            controller.cancelPendingNavigation();
                          }
                          final requested = _requestedPage;
                          _requestedPage = null;
                          final keep =
                              requested ?? widget.pages[_selected]['page'];
                          final kept =
                              groups[index].any((p) => p['page'] == keep)
                              ? widget.pages.indexWhere(
                                  (p) => p['page'] == keep,
                                )
                              : -1;
                          _selected = kept >= 0
                              ? kept
                              : spread
                              ? index * 2
                              : index;
                          final highlight = _highlight.value;
                          if (highlight != null &&
                              !groups[index].any(
                                (p) => p['page'] == highlight.page,
                              )) {
                            _highlight.value = null;
                          }
                          _shownPage.value = groups[index].first['page'] as int;
                          _pendingPrefetch = groups[index].first['page'] as int;
                          if (!_scrolling) _afterScroll();
                        },
                        itemBuilder: (context, index) => Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            for (final page in groups[index])
                              Expanded(
                                child: _LoadedReaderPage(
                                  revision: _bundleRevision,
                                  page: () => widget.pages.firstWhere(
                                    (p) => p['page'] == page['page'],
                                  ),
                                  buildPage: (page) => _page(
                                    page,
                                    text.size,
                                    text.width,
                                    pageHeight,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_arrowsShown) ...[
              _arrow('next', screen, spread),
              _arrow('previous', screen, spread),
            ],
            if (_barsVisible) _topBar(),
            if (_stripOpen)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('toolbar-barrier'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _stripOpen = false),
                ),
              ),
            if (!_toolbar.hidden) ..._ball(screen),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Positioned(
    key: const ValueKey('top-bar'),
    top: 0,
    left: 0,
    right: 0,
    child: Material(
      color: _darkMode ? const Color(0xFF181818) : Colors.white,
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.only(
          top: math.max(_statusTop, _cutout.top),
          left: _cutout.left + 4,
          right: _cutout.right + 16,
        ),
        child: SizedBox(
          height: 56,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              if (widget.index != null)
                IconButton(
                  tooltip: 'Surah list',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => unawaited(_openNavigation()),
                ),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _shownPage,
                  builder: (context, number, _) {
                    final place = pagePlace(
                      widget.pages.firstWhere((page) => page['page'] == number),
                    );
                    return Column(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (place != null)
                          Text(
                            surahNames[place.surah - 1],
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          place == null
                              ? 'صفحة ${arabicDigits(number)}'
                              : 'صفحة ${arabicDigits(number)}، جزء ${arabicDigits(place.juz)}',
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (widget.navigation != null)
                ValueListenableBuilder<int>(
                  valueListenable: _shownPage,
                  builder: (context, _, _) {
                    final saved = _shownPages.any(_bookmarks.containsKey);
                    return IconButton(
                      key: const ValueKey('bookmark-button'),
                      tooltip: saved ? 'Remove bookmark' : 'Bookmark page',
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      onPressed: _bookmarkSaving
                          ? null
                          : () => unawaited(_toggleBookmark()),
                    );
                  },
                ),
              PopupMenuButton<String>(
                tooltip: 'Menu',
                icon: const Icon(Icons.more_vert),
                onSelected: (item) {
                  if (item == 'search') {
                    unawaited(_openSearch());
                  } else if (item == 'jump') {
                    unawaited(_openQuickJump());
                  } else if (item == 'dark') {
                    _setDarkMode(!_darkMode);
                  } else if (item == 'toolbar') {
                    unawaited(_saveToolbar(_toolbar.copyWith(hidden: false)));
                  } else {
                    unawaited(_openSettings());
                  }
                },
                itemBuilder: (context) => [
                  if (widget.index != null)
                    const PopupMenuItem(value: 'search', child: Text('Search')),
                  PopupMenuItem(
                    value: 'dark',
                    child: Row(
                      children: [
                        const Expanded(child: Text('Dark mode')),
                        IgnorePointer(
                          child: Switch(value: _darkMode, onChanged: (_) {}),
                        ),
                      ],
                    ),
                  ),
                  if (widget.index != null)
                    const PopupMenuItem(
                      value: 'jump',
                      child: Text('Quick jump'),
                    ),
                  if (_toolbar.hidden)
                    const PopupMenuItem(
                      value: 'toolbar',
                      child: Text('Show toolbar'),
                    ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Text('Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  static const _toolIcons = {
    MarkTool.visible: Icons.visibility,
    MarkTool.singleLine: Icons.format_underlined,
    MarkTool.doubleLine: Icons.format_underlined,
    MarkTool.rectangle: Icons.crop_square,
    MarkTool.circle: Icons.circle_outlined,
  };
  static const _toolLabels = {
    MarkTool.visible: 'Visible',
    MarkTool.singleLine: 'Single line',
    MarkTool.doubleLine: 'Double line',
    MarkTool.rectangle: 'Rectangle',
    MarkTool.circle: 'Circle',
  };

  Widget _toolIcon(MarkTool tool, Color color) {
    final icon = Icon(_toolIcons[tool], color: color);
    if (tool != MarkTool.doubleLine) return icon;
    return Stack(
      alignment: Alignment.center,
      children: [
        icon,
        Positioned(
          bottom: 0,
          child: Container(width: 14, height: 2, color: color),
        ),
      ],
    );
  }

  List<Widget> _ball(Size screen) {
    const half = _ballSize / 2;
    final left = _cutout.left, right = screen.width - _cutout.right;
    final top = _cutout.top + half,
        bottom = screen.height - _cutout.bottom - half;
    Offset clamp(Offset point) => Offset(
      point.dx.clamp(left, math.max(left, right)),
      point.dy.clamp(top, math.max(top, bottom)),
    );
    final spot = _toolbar.spot;
    final center = clamp(
      _ballDrag ??
          (spot == null
              ? Offset(right, screen.height / 2)
              : Offset(spot.dx * screen.width, spot.dy * screen.height)),
    );
    final colour = _markInk(_toolbar.color);
    final shown = _toolbar.tools.lastOrNull;
    void drop() {
      final at = _ballDrag;
      if (at == null) return;
      var x = clamp(at).dx;
      if (x - left < _ballSize) x = left;
      if (right - x < _ballSize) x = right;
      final y = clamp(at).dy;
      _ballDrag = null;
      unawaited(
        _saveToolbar(
          _toolbar.copyWith(spot: Offset(x / screen.width, y / screen.height)),
        ),
      );
    }

    return [
      Positioned(
        left: center.dx - half,
        top: center.dy - half,
        child: GestureDetector(
          key: const ValueKey('toolbar-ball'),
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTap: () => setState(() => _stripOpen = !_stripOpen),
          onPanStart: (_) {
            if (!_toolbar.pinned) setState(() => _ballDrag = center);
          },
          onPanUpdate: (details) {
            final at = _ballDrag;
            if (at != null) setState(() => _ballDrag = at + details.delta);
          },
          onPanEnd: (_) => drop(),
          onPanCancel: drop,
          child: Semantics(
            button: true,
            label: 'Toolbar',
            value: [for (final tool in _toolbar.tools) _toolLabels[tool]]
                .join(', '),
            child: Container(
              width: _ballSize,
              height: _ballSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _foreground.withValues(alpha: .08),
                border: Border.all(color: colour.withValues(alpha: .5)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (shown == null)
                    Icon(Icons.block, color: _foreground.withValues(alpha: .35))
                  else
                    _toolIcon(shown, colour),
                  if (_toolbar.tools.length > 1)
                    Positioned(
                      right: 6,
                      top: 4,
                      child: Text(
                        '${_toolbar.tools.length}',
                        style: TextStyle(fontSize: 10, color: colour),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (_stripOpen) _strip(screen, center),
    ];
  }

  Widget _strip(Size screen, Offset ball) {
    const width = 300.0;
    final below = ball.dy < screen.height / 2;
    final left = (ball.dx - width / 2)
        .clamp(8.0, math.max(8.0, screen.width - width - 8))
        .toDouble();
    Widget toggle({
      required String key,
      required String tooltip,
      required bool on,
      required Widget icon,
      required VoidCallback onPressed,
    }) => IconButton(
      key: ValueKey(key),
      tooltip: tooltip,
      isSelected: on,
      style: IconButton.styleFrom(
        backgroundColor: on ? _foreground.withValues(alpha: .12) : null,
      ),
      onPressed: onPressed,
      icon: icon,
    );
    return Positioned(
      left: left,
      top: below ? ball.dy + _ballSize / 2 + 8 : null,
      bottom: below ? null : screen.height - ball.dy + _ballSize / 2 + 8,
      width: width,
      child: Material(
        key: const ValueKey('toolbar-strip'),
        color: _darkMode ? const Color(0xFF181818) : Colors.white,
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final tool in MarkTool.values)
                    toggle(
                      key: 'tool-${tool.name}',
                      tooltip: _toolLabels[tool]!,
                      on: _toolbar.tools.contains(tool),
                      icon: _toolIcon(
                        tool,
                        _toolbar.tools.contains(tool)
                            ? _markInk(_toolbar.color)
                            : _foreground.withValues(alpha: .5),
                      ),
                      onPressed: () =>
                          unawaited(_saveToolbar(_toolbar.toggle(tool))),
                    ),
                ],
              ),
              if (!_blackWhite)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final colour in MarkColor.values)
                      InkResponse(
                        key: ValueKey('colour-${colour.name}'),
                        onTap: () => unawaited(
                          _saveToolbar(_toolbar.copyWith(color: colour)),
                        ),
                        child: Semantics(
                          selected: _toolbar.color == colour,
                          label: colour.name,
                          child: Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colour.paint(_foreground),
                              border: _toolbar.color == colour
                                  ? Border.all(
                                      color: _foreground.withValues(alpha: .6),
                                      width: 3,
                                    )
                                  : Border.all(
                                      color: _foreground.withValues(alpha: .15),
                                    ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  toggle(
                    key: 'toolbar-top-bar',
                    tooltip: _barsVisible ? 'Hide top bar' : 'Show top bar',
                    on: _barsVisible,
                    icon: const Icon(Icons.vertical_align_top),
                    onPressed: _toggleBars,
                  ),
                  toggle(
                    key: 'toolbar-pin',
                    tooltip: _toolbar.pinned ? 'Unpin toolbar' : 'Pin toolbar',
                    on: _toolbar.pinned,
                    icon: const Icon(Icons.push_pin_outlined),
                    onPressed: () => unawaited(
                      _saveToolbar(_toolbar.copyWith(pinned: !_toolbar.pinned)),
                    ),
                  ),
                  toggle(
                    key: 'toolbar-hide',
                    tooltip: 'Hide toolbar',
                    on: false,
                    icon: const Icon(Icons.visibility_off_outlined),
                    onPressed: () {
                      _stripOpen = false;
                      unawaited(_saveToolbar(_toolbar.copyWith(hidden: true)));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrow(String name, Size screen, bool spread) {
    final key = '${spread ? 'landscape' : 'portrait'}-$name';
    final half = _arrowSize / 2;
    final safe = Rect.fromLTRB(
      _cutout.left + half,
      _cutout.top + half,
      screen.width - _cutout.right - half,
      screen.height - _cutout.bottom - half,
    );
    final spot = _arrowSpots[key];
    final corner = safe.deflate(_arrowInset);
    final wanted = spot == null
        ? Offset(name == 'next' ? corner.left : corner.right, corner.bottom)
        : Offset(spot.dx * screen.width, spot.dy * screen.height);
    final center = Offset(
      wanted.dx.clamp(safe.left, math.max(safe.left, safe.right)),
      wanted.dy.clamp(safe.top, math.max(safe.top, safe.bottom)),
    );
    void moveTo(Offset target) => setState(
      () => _arrowSpots[key] = Offset(
        (target.dx.clamp(safe.left, math.max(safe.left, safe.right))) /
            screen.width,
        (target.dy.clamp(safe.top, math.max(safe.top, safe.bottom))) /
            screen.height,
      ),
    );
    return Positioned(
      left: center.dx - half,
      top: center.dy - half,
      child: GestureDetector(
        key: ValueKey('arrow-$name'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _turn(name == 'next' ? 1 : -1),
        onLongPressStart: (_) => _arrowDragOrigins[name] = center,
        onLongPressMoveUpdate: (details) =>
            moveTo(_arrowDragOrigins[name]! + details.offsetFromOrigin),
        onLongPressEnd: (_) {
          _arrowDragOrigins.remove(name);
          if (_arrowSpots.containsKey(key)) unawaited(_saveArrowSpot(key));
        },
        child: Semantics(
          button: true,
          label: name == 'next' ? 'Next page' : 'Previous page',
          child: Container(
            width: _arrowSize,
            height: _arrowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _foreground.withValues(alpha: .06),
            ),
            child: Icon(
              name == 'next' ? Icons.chevron_left : Icons.chevron_right,
              size: _largeScreen ? 36 : null,
              color: _foreground.withValues(alpha: .35),
            ),
          ),
        ),
      ),
    );
  }

  ({double size, double width}) _textSize(double width, double height) {
    _size = math.min(width / (_widest + 2 * _edgeInk), height / _tallest);
    return (size: _size, width: _size * _widest);
  }

  Widget _page(
    Map<String, dynamic> page,
    double fontSize,
    double textWidth,
    double pageHeight,
  ) {
    final number = page['page'] as int;
    if (page['lines'] == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final lines = page['lines'] as List;
    final spare = (pageHeight / 15 - inkHeight(page) * fontSize) / 2;
    final strip = number <= 2 ? 0.0 : math.max(0.0, (14 - spare) * 30 / 29);
    final slotHeight = (pageHeight - strip) / 15;
    final height = number <= 2 ? textWidth * 47 / 543 : slotHeight;
    final ink = _pageInk.putIfAbsent(
      number,
      () => PageInkController(widget.store),
    );
    ink.store = widget.store;
    ink.dim = _dim;
    ink.foreground = _foreground;
    ink.background = _background;
    ink.blackWhite = _blackWhite;
    final place = pagePlace(page);
    final chrome = _darkMode ? const Color(0xFFB0B0B0) : Colors.black;
    final spread = _spread == true;
    final painted = PaintedInkPage(
      controller: ink,
      child: SizedBox(
        key: ValueKey('page-$number'),
        child: Stack(
          children: [
            Positioned.fill(
              child: PageBorder(
                key: ValueKey('page-border-$number'),
                right: number.isOdd,
                left: number.isEven || spread,
                color: chrome,
                thinnest: _blackWhite ? 1 : .6,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
              child: Column(
                children: [
                  Center(
                    child: SizedBox(
                      key: ValueKey('page-header-$number'),
                      width: textWidth,
                      height: _headerHeight,
                      child: RepaintBoundary(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: chrome,
                                  width: _blackWhite ? 1 : .5,
                                ),
                              ),
                            ),
                            child: Row(
                              textDirection: TextDirection.rtl,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (place != null)
                                  for (final label in [
                                    'الجزء ${arabicDigits(place.juz)}',
                                    surahNames[place.surah - 1],
                                  ])
                                    Flexible(
                                      child: Text(
                                        label,
                                        textDirection: TextDirection.rtl,
                                        textScaler: TextScaler.noScaling,
                                        softWrap: false,
                                        overflow: TextOverflow.clip,
                                        style: TextStyle(
                                          fontSize: 10,
                                          height: 1.2,
                                          color: chrome,
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: pageHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          bottom: strip,
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
                                                          ((line['number']
                                                                      as int) -
                                                                  2) *
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
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: SizedBox(
                                height: 12,
                                child: Center(
                                  child: Text(
                                    arabicDigits(number),
                                    key: ValueKey('page-number-$number'),
                                    textScaler: TextScaler.noScaling,
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.2,
                                      color: chrome,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: ValueKey('ayah-shade-$number'),
              painter: AyahShadePainter(
                ink: ink,
                page: number,
                highlight: _highlight,
                dark: _darkMode,
                blackWhite: _blackWhite,
              ),
            ),
          ),
        ),
        painted,
      ],
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
            color: _foreground,
            background: _background,
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
      final font = page['font'] as Map<String, dynamic>;
      content = PaintedWordLine(
        controller: _pageInk[number]!,
        words: words,
        metrics: _metrics,
        fontSize: size,
        height: height,
        inkHeight: inkHeight(page) * size,
        baseline:
            (height - inkHeight(page) * size) / 2 +
            size * (font['yMax'] as num) / (font['unitsPerEm'] as num),
        centered: line['centered'] == true,
        style: wordStyle(number, size),
      );
    }
    if (words.isNotEmpty && line['centered'] != true) {
      final first = _metrics[words.first['id']]!;
      final last = _metrics[words.last['id']]!;
      // Only correct ink that would cross this page's physical edge. In
      // height-limited views the existing spare margin already contains it.
      final spare = math.max(0.0, (_contentWidth - textWidth) / 2);
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
        child: Center(
          child: SizedBox(width: textWidth, child: content),
        ),
      ),
    );
  }
}

// Bundle arrivals rebuild only slots whose parsed page object changed.
class _LoadedReaderPage extends StatefulWidget {
  const _LoadedReaderPage({
    required this.revision,
    required this.page,
    required this.buildPage,
  });
  final ValueNotifier<int> revision;
  final Map<String, dynamic> Function() page;
  final Widget Function(Map<String, dynamic>) buildPage;
  @override
  State<_LoadedReaderPage> createState() => _LoadedReaderPageState();
}

class _LoadedReaderPageState extends State<_LoadedReaderPage> {
  late Map<String, dynamic> page;
  late Widget content;
  void refresh() {
    final next = widget.page();
    if (!identical(next, page)) {
      setState(() {
        page = next;
        content = widget.buildPage(page);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    page = widget.page();
    content = widget.buildPage(page);
    widget.revision.addListener(refresh);
  }

  @override
  void didUpdateWidget(covariant _LoadedReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      oldWidget.revision.removeListener(refresh);
      widget.revision.addListener(refresh);
    }
    page = widget.page();
    content = widget.buildPage(page);
  }

  @override
  void dispose() {
    widget.revision.removeListener(refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => content;
}

class PageBorder extends StatelessWidget {
  const PageBorder({
    super.key,
    required this.left,
    required this.right,
    required this.color,
    this.thinnest = .6,
  });
  final bool left;
  final bool right;
  final Color color;
  final double thinnest;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _PageBorderPainter(left, right, color, thinnest),
    ),
  );
}

class _PageBorderPainter extends CustomPainter {
  _PageBorderPainter(this.left, this.right, this.color, this.thinnest);
  final bool left;
  final bool right;
  final Color color;
  final double thinnest;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    final inner = Paint()
      ..color = color
      ..strokeWidth = thinnest;
    for (final (show, outerX, innerX) in [
      (right, size.width - 2, size.width - 4.5),
      (left, 2.0, 4.5),
    ]) {
      if (!show) continue;
      canvas.drawLine(
        Offset(outerX, 2),
        Offset(outerX, size.height - 2),
        outer,
      );
      canvas.drawLine(
        Offset(innerX, 3),
        Offset(innerX, size.height - 3),
        inner,
      );
    }
  }

  @override
  bool shouldRepaint(_PageBorderPainter old) =>
      old.left != left ||
      old.right != right ||
      old.color != color ||
      old.thinnest != thinnest;
}

class AyahShadePainter extends CustomPainter {
  AyahShadePainter({
    required this.ink,
    required this.page,
    required this.highlight,
    required this.dark,
    this.blackWhite = false,
  }) : super(repaint: Listenable.merge([ink, highlight]));
  final bool blackWhite;
  final PageInkController ink;
  final int page;
  final ValueNotifier<({int page, int surah, int ayah})?> highlight;
  final bool dark;

  static const _lightShade = Color(0xFFD3E6F2);
  static const _darkShade = Color(0xFF1F3A48);
  static const _lightGreyShade = Color(0xFFDDDDDD);
  static const _darkGreyShade = Color(0xFF383838);
  Color get shade => switch ((dark, blackWhite)) {
    (false, false) => _lightShade,
    (true, false) => _darkShade,
    (false, true) => _lightGreyShade,
    (true, true) => _darkGreyShade,
  };

  List<Rect> runs() {
    final target = highlight.value;
    if (target == null || target.page != page) return const [];
    final prefix = '${target.surah}:${target.ayah}:';
    final lines = <double, Rect>{};
    for (final word in ink.words) {
      if (!word.location.startsWith(prefix)) continue;
      final rect = Rect.fromLTRB(
        word.box.left,
        word.band.top,
        word.box.right,
        word.band.bottom,
      );
      lines.update(
        word.band.top,
        (run) => run.expandToInclude(rect),
        ifAbsent: () => rect,
      );
    }
    return lines.values.toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = shade;
    for (final run in runs()) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(run.left - 3, run.top, run.right + 3, run.bottom),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(AyahShadePainter old) =>
      old.ink != ink ||
      old.page != page ||
      old.dark != dark ||
      old.blackWhite != blackWhite;
}
