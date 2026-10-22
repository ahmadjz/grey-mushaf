/// Device-local display preference, deliberately separate from word actions.
abstract class ReaderSettings {
  int get greyLevel;
  int get darkLevel;
  Future<void> saveDarkLevel(int level);
  Future<void> saveGreyLevel(int level);
}
