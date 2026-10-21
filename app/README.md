# Grey Mushaf phase 0

Personal Android spike, application ID `tech.ahmadjz.greymushaf`.

From the repository root, generate the offline bundle from the owner's QUL downloads:

```sh
python3 scripts/bundle_mushaf.py --pages 1 2 47 48
cd app
flutter pub get
flutter run
```

The default source is `assets-src/qul-v4`: layout database in
`layout/qpc-v4-tajweed-15-lines.db`, words in `words/qpc-v4.db`, and
`fonts/p1.ttf` through `fonts/p604.ttf`. The generated `app/assets/mushaf/`
directory is gitignored. No assets are fetched by the app. `--all` bundles all
604 pages; `--source` and `--output` can override paths. Fonts are copied unchanged.
Assets and their notices must remain outside the public repository.

Long-press a word, then drag to reveal crossed words. Lift to restore page swiping.
A tap on a black word turns it grey; a tap on a grey word does nothing.
Reveals count only grey-to-black transitions, once per word per drag.
Swipe right to advance, or use the page selector. Landscape pairs consecutive
odd/even pages with the odd page on the right. Rotation preserves the current
page's spread and reveal state.

Reveal state and counts are **in memory only** and reset on process restart.
Surah headings and the separate basmallah use centred system-font placeholders;
the V4 heading font is not included. Ordinary pages retain their database line
slots; opening pages retain their shorter centred layout. Decoration is minimal.
Word colours are applied after rendering with an alpha-preserving `srcIn` filter.

Checks (local source data and generated bundle required):

```sh
uv venv .venv
uv pip install --python .venv/bin/python pytest
. .venv/bin/activate
python3 -m pytest -q tests/
cd app
flutter analyze
flutter test
```

Widget tests use the real bundled fonts, exercise gestures and compare page
1/2/48 line ranges with the source SQLite database through Python's standard
library. No accounts or backend are used by this spike.
