enum SyncKind {
  word('word_actions'),
  mark('mark_actions'),
  bookmark('bookmark_actions');

  const SyncKind(this.collection);
  final String collection;
}

/// Wire shape: word {word, black, counted}; mark {word, kind, style, color}
/// with '' for a removal; bookmark {page, saved}.
class SyncRecord {
  const SyncRecord(
    this.kind,
    this.uuid,
    this.device,
    this.createdAt,
    this.fields,
  );
  final SyncKind kind;
  final String uuid;
  final String device;
  final int createdAt;
  final Map<String, Object?> fields;
}

class SyncChange {
  const SyncChange(this.words, this.bookmarks);
  final Set<String> words;
  final bool bookmarks;
  bool get isEmpty => words.isEmpty && !bookmarks;
}

abstract class SyncLocal {
  String get deviceId;
  String? syncValue(String key);
  Future<void> saveSyncValues(Map<String, String?> values);
  Future<List<SyncRecord>> pendingUploads(SyncKind kind, {int limit});
  Future<int> pendingCount();
  Future<void> markUploaded(Iterable<String> uuids);
  Future<void> forgetUploads();
  Future<SyncChange> applyRemote(
    List<SyncRecord> records, {
    Map<String, String?> metadata,
  });
  Stream<SyncChange> get remoteChanges;
  Stream<void> get localChanges;
}
