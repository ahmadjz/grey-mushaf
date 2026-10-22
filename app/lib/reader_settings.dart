/// Device-local display preference, deliberately separate from word actions.
abstract class ReaderSettings {
  int get greyLevel;
  Future<void> saveGreyLevel(int level);
}
