# Grey Mushaf offline reader

Personal Android reader, application ID `tech.ahmadjz.greymushaf`.

From the repository root, generate the offline bundle from the owner's QUL downloads:

```sh
python3 scripts/bundle_mushaf.py --all
cd app
flutter pub get
flutter test tool/prepare_metrics.dart
flutter run
```

The default source is `assets-src/qul-v4`: layout database in
`layout/qpc-v4-tajweed-15-lines.db`, words in `words/qpc-v4.db`, and
`fonts/p1.ttf` through `fonts/p604.ttf`. The generated `app/assets/mushaf/`
directory is gitignored. No assets are fetched by the app. `--all` bundles all
604 pages. `--source` can override the input path; `--output` must remain under
`app/assets/mushaf/`. Symlinked outputs are refused, and cleanup only removes
files named in the previous generated manifest. Fonts are copied unchanged.
Assets and their notices must remain outside the public repository.

Re-run the bundler after updating: each word now includes horizontal glyph ink
bounds from the TrueType/COLR layers. The reader combines these with Flutter's
shaped character positions. The preparation command measures all 604 pages with
real Flutter shaping and saves global size constraints. Android builds verify
asset and shaping-source hashes, refusing partial or stale bundles. Regenerate
metrics after changing assets, the shaping code, or the Flutter SDK. At runtime
only the current spread and its neighbours load; their words are shaped at the
same global size. Far jumps keep the current page visible until their destination
is ready; fast swipes stop at the loaded boundary while neighbours load. Flutter
retains registered fonts as pages are visited.
Revealing words and rotating do not re-measure the bundle.
Hit testing retains full vertical line bands, but stops horizontally at 0.08 em
beyond the ink; empty margins and spread gutters do nothing. Overlapping ink
extents use the nearest ink edge, not an advance-box centre.

Long-press a word, then drag to reveal crossed words. Lift to restore page swiping.
A tap on a black word turns it grey; a tap on a grey word does nothing.
Reveals count only grey-to-black transitions, once per word per drag.
Swipe right to advance. Landscape pairs consecutive
odd/even pages with the odd page on the right. Rotation preserves the current
page's spread and reveal state.

Reveal state and counts are saved locally in SQLite.
Surah headings use the bundled V4 calligraphy font. Page 2 uses the compact
basmallah; other basmallah headings use artwork traced from the owner’s page 50.
Headings have full contrast and are never revealable words. Ordinary pages retain their database line
slots; opening pages retain their shorter centred layout. Decoration is minimal.
Word colours are applied after rendering with two alpha-preserving colour matrices.
The first separates the default V4 palette’s pale marker backgrounds from ink;
the second maps ink to black/grey and backgrounds to white. A plain `srcIn`
filter obscures the ayah numerals because those backgrounds are opaque. The
raster test covers every default palette entry in the four spike fonts.

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

## Spike proof

For the later phone/tablet R19 and round-2 regression proofs, see
[`docs/runs/2026-10-21-phase0-spike-run-log.md`](../docs/runs/2026-10-21-phase0-spike-run-log.md).

Verified on `Tablet_API_37` (Android 17 / API 37, Impeller OpenGLES), in
portrait and landscape. The phone emulator crashed during startup; the tablet
booted with host graphics and cameras disabled. Screenshots are gitignored:

- `docs/runs/shots/phase0-page1-grey.png`
- `docs/runs/shots/phase0-page48-revealed.png`
- `docs/runs/shots/phase0-spread1-2.png`
- `docs/runs/shots/phase0-spread47-48.png`

Page 48's long-press and cross-line drag revealed locations `2:282:1` through
`2:282:12`, each with count one, confirmed through Android accessibility output.
All four screenshot bodies had zero pixels with unequal RGB channels (excluding
system chrome). Ayah numerals remain legible. All 15 page-48 line starts and ends
visually match the owner's outline render; typography spacing and decoration
are not pixel-identical. The special opening layouts retain their line breaks.
Physical phone and Boox behaviour have not been tested. The all-pages bundler
was exercised for 604 pages; full-mushaf rendering has not been reviewed.
