# Plan: run 3 of R57 (R27, R52–R55, R63–R66)

Base 939b6b7 (rulings committed). Writer: the Opus session.

1. **Index data, out of the repo.** `scripts/bundle_index.py --source assets-src/qul-v4
   [--imlaei assets-src/qul-v4/words/imlaei-simple.db] --output app/assets/index` reads the QUL layout
   (`pages`: line_type, first/last_word_id, surah_number) and words DB (`words.location`) and writes
   `index.json` = `{surahs: [{page, ayahPages: [firstPage per ayah]}] x114, juz: [page] x30}` (surah
   page = the page holding its surah_name line; juz page = page of its first ayah, from the existing
   `_juzStarts` table copied into the script) and, when Imlaei is given, `search.json` =
   `[[surah, ayah, page, text]] x6236` (text = Imlaei words of the ayah joined by spaces). Output dir
   is gitignored (`/app/assets/index/`), added to pubspec assets. Pytest on tiny synthetic DBs (red first).
2. **`lib/quran_index.dart`.** `QuranIndex.load(AssetBundle)` → surah start page, ayah count,
   `pageOf(surah, ayah)`, juz start page, surah+juz of any page (first ayah on it) for not-yet-loaded
   pages. Medinan surah set as a const. `SearchIndex.load` (null when `search.json` is missing →
   text search shows a short "word text not installed" row). `normalize()` folds أإآٱ→ا, ى→ي, ة→ه,
   strips tatweel/diacritics; `find(query)` returns ayahs whose normalized text contains the
   normalized query, plus number hits (page N, juz N), and surah-name hits.
3. **Store v3** (`reveal_store.dart`). `bookmark_actions(local_seq AUTOINCREMENT, action_uuid UNIQUE,
   device_id, created_at, page CHECK 1..604, bookmarked CHECK 0/1)`; `bookmarks(page PK, bookmarked
   CHECK 0/1, created_at, last_action_uuid FK→bookmark_actions)`; removal keeps the row with
   bookmarked=0 (tombstone for later sync, like word_marks). onCreate = v1+v2+v3 DDL; onUpgrade adds
   v2 tables if old<2 and v3 tables if old<3. `BookmarkStore { Map<int,int> bookmarks;
   Future<void> saveBookmark(BookmarkAction) }` — duplicate uuid / no change → no-op; projection
   updates only after the transaction commits. Last page read: `local_metadata('reader_last_page')`
   via `ReaderSettings.lastPage/saveLastPage`, written when a page settles; invalid values → 1.
4. **Reader** (`main.dart`). Initial page = last page. `_goTo(page, {ayah})` maps page→group index
   and calls `_controller.jumpToPage` (LoadedPageController loads first). Top bar (RTL): back arrow
   → pushes `NavigationScreen` (tabs السور | العلامات) which pops a target; bookmark icon (filled if
   any shown page is saved; tap removes those or saves the right-hand page; R24-style: icon changes
   only after save, failure → "Couldn't save bookmark" + Retry); ⋮ = Search, Quick jump, Dark mode,
   Show toolbar (when hidden), Settings. Search highlight: a translucent overlay painter outside
   `PaintedInkPage` (so the page image cache and FlatInk colours are untouched) drawing one rect per
   line run of the target ayah's words, from `PageInkController.words`; cleared on next tap or page
   change.
5. **Screens.** `lib/navigation_screen.dart`: surah rows (number, name, مكية/مدنية · N آية, page) with
   a `الجزء N` row (with the juz page) placed before the first surah whose start page is at or after
   the juz start page, so a juz beginning mid-surah sits after that surah's row (reference app:
   الأعراف ١٥١, then الجزء ٩ ١٦٢, then الأنفال); bookmarks tab newest first with remove. `lib/search_screen.dart`: field with up to
   5 live suggestions + "نتائج كاملة" row; full results with count and the matched span coloured.
   `lib/quick_jump.dart`: dialog with page field, surah dropdown + ayah field, validation.
6. **Run-2 leftovers.** Mark box gets its own "Couldn't save · Retry" row while open (listens to a
   save-failure notifier); widget test that Retry in the box saves. Snackbar inset test with a
   non-zero cutout (mock `getInsets`).
7. **Proof.** Widget tests per ruling; emulator integration: exact v2 DDL DB (reveals + marks) and v1
   DB upgrade to v3 keep all rows; bookmarks survive reopen; failed upgrade rolls back; downgrade
   refused at v4. Gates: flutter analyze, flutter test, pytest. Emulator screenshots: surah list,
   search suggestions, highlight.
