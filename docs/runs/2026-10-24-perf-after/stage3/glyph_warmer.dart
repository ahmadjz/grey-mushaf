import 'dart:async';

import 'package:flutter/scheduler.dart';

/// A bounded, replaceable queue. At most one raster operation is in flight.
class GlyphWarmer<T> {
  GlyphWarmer(this.raster);
  final Future<void> Function(T) raster;
  List<T> _wanted = [];
  final _done = <T>{};
  bool _running = false, _disposed = false;
  void request(List<T> pages) {
    if (_disposed) return;
    _wanted = pages.take(4).toList();
    _done.removeWhere((page) => !_wanted.contains(page));
    if (!_running) {
      _running = true;
      unawaited(_run());
    }
  }

  Future<void> _run() async {
    try {
      while (!_disposed) {
        await SchedulerBinding.instance.endOfFrame;
        if (_disposed) break;
        final next = _wanted.where((page) => !_done.contains(page));
        if (next.isEmpty) break;
        final page = next.first;
        // Warming is optional; a failed offscreen allocation must not break reading.
        try {
          await raster(page);
        } catch (_) {
          /* retry on a later window */
        }
        if (_wanted.contains(page)) _done.add(page);
      }
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _wanted = [];
    _done.clear();
  }
}
