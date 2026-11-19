import 'package:greymushaf/reveal_store.dart';
import 'package:greymushaf/word_marks.dart';

/// Gesture/layout tests only. Real SQLite is covered on Android.
class MemoryRevealStore implements RevealStore {
  final states = <String, WordState>{};
  final wordMarks = <String, WordMarks>{};
  @override
  WordState state(String key) => states[key] ?? greyWord;
  @override
  Future<void> save(WordAction action) async {
    final before = state(action.key);
    if (before.black != action.black) {
      states[action.key] = (
        black: action.black,
        count: before.count + (action.black ? 1 : 0),
      );
    }
  }

  @override
  WordMarks marks(String key) => wordMarks[key] ?? noMarks;
  @override
  Future<void> saveMark(MarkAction action) async {
    wordMarks[action.key] = marks(action.key)
        .withMark(action.kind, action.mark);
  }
}
