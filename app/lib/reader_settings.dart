import 'dart:ui';

/// Device-local display preference, deliberately separate from word actions.
abstract class ReaderSettings {
  int get greyLevel;
  int get darkLevel;
  bool get arrowsShown;
  Map<String, Offset> get arrowSpots;
  bool? get blackWhite;
  Future<void> saveBlackWhite(bool on);
  Future<void> saveDarkLevel(int level);
  Future<void> saveGreyLevel(int level);
  Future<void> saveArrowsShown(bool shown);
  Future<void> saveArrowSpot(String key, Offset spot);
}
