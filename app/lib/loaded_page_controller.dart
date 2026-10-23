import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keep the current page visible until a programmatic destination is ready.
class LoadedPageController extends PageController {
  LoadedPageController({required this.prepare, super.initialPage});
  final Future<void> Function(int index) prepare;
  Future<void> pending = Future<void>.value();
  int _request = 0;

  void cancelPendingNavigation() => _request++;

  @override
  void jumpToPage(int page) {
    pending = _jump(page, ++_request);
    unawaited(pending);
  }

  Future<void> _jump(int page, int request) async {
    await prepare(page);
    if (request == _request && hasClients) super.jumpToPage(page);
  }

  @override
  Future<void> animateToPage(
    int page, {
    required Duration duration,
    required Curve curve,
  }) {
    final request = ++_request;
    return pending = () async {
      await prepare(page);
      if (request == _request && hasClients) {
        // A far destination has no loaded intermediate pages to animate over.
        if (((this.page ?? initialPage.toDouble()) - page).abs() > 1) {
          super.jumpToPage(page);
        } else {
          await super.animateToPage(page, duration: duration, curve: curve);
        }
      }
    }();
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }
}

/// While neighbours load, a fast gesture stops at the last ready page.
class LoadedPagePhysics extends PageScrollPhysics {
  const LoadedPagePhysics({
    required this.first,
    required this.last,
    super.parent,
  });
  final int Function() first;
  final int Function() last;

  @override
  LoadedPagePhysics applyTo(ScrollPhysics? ancestor) => LoadedPagePhysics(
    first: first,
    last: last,
    parent: buildParent(ancestor),
  );

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final min = first() * position.viewportDimension;
    final max = last() * position.viewportDimension;
    if (value < position.pixels && position.pixels <= min) {
      return value - position.pixels;
    }
    if (value > position.pixels && position.pixels >= max) {
      return value - position.pixels;
    }
    if (value < min && position.pixels > min) return value - min;
    if (value > max && position.pixels < max) return value - max;
    return super.applyBoundaryConditions(position, value);
  }
}
