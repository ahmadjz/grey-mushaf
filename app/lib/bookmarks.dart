import 'package:uuid/uuid.dart';

class BookmarkAction {
  BookmarkAction(this.page, this.saved, {int? createdAt})
    : uuid = const Uuid().v4(),
      createdAt = createdAt ?? DateTime.now().toUtc().millisecondsSinceEpoch {
    if (page < 1 || page > 604) throw RangeError.range(page, 1, 604, 'page');
  }
  final int page;
  final bool saved;
  final String uuid;
  final int createdAt;
}

abstract class NavigationStore {
  int get lastPage;
  Future<void> saveLastPage(int page);
  Map<int, int> get bookmarkSavedAt;
  Future<void> saveBookmarks(List<BookmarkAction> actions);
}
