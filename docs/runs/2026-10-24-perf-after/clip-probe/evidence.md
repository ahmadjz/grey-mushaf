# Hard-edge clipping probe: exact-pixel gate failed

Base production: 52e1e11. HEAD: dda9f8a (Stage 0 harness). No new commit. The grouped-filter candidate and this probe remain uncommitted. Fonts were neither converted nor modified. Existing owner edits were left untouched.

Device: Medium_Phone, 4096 MB, x86_64, API 37, DPR 2.625, profile, Impeller OpenGLES. This is not the owner's arm64 phone. Same 84 reference cases, persisted mixed reveals, raw RGBA comparison without alignment, thresholds or masks. All 84 repeat captures match the probe exactly.

## Result

Against the unchanged base reference: **20,429 differing pixels across all 84 images**, maximum channel delta 192. Of the previous 84 differing pixels, 72 are corrected and 12 remain; 20,417 additional pixels now differ. These totals sum pixel occurrences across captures, not distinct screen coordinates.

| Case | Original pixels fixed | Original pixels remaining | New differing pixels | Total now |
|---|---:|---:|---:|---:|
| 1 | 0 | 0 | 1214 | 1214 |
| 2 | 0 | 12 | 1052 | 1064 |
| 50 | 0 | 0 | 3707 | 3707 |
| 187 | 12 | 0 | 4048 | 4048 |
| 604 | 0 | 0 | 2558 | 2558 |
| 63 | 36 | 0 | 4344 | 4344 |
| spread 49–50 | 24 | 0 | 3494 | 3494 |

Page 187 dark128 unrevealed, physical (153,1540): reference [0,0,0,255], original grouped [24,24,24,255], clipped [0,0,0,255]. Its source word 9:5:3 has modeled physical bounds [154.1184,1468.1104,301.8861,1544.2863], rounded outward to [154,1468,302,1545]. The pixel falls outside that model.

All 12 original overlap-pixel differences on page 2 survive clipping. Example dark128 unrevealed at (748,1226): reference [53,53,53,255], grouped and clipped [52,52,52,255]. Clipping therefore does not resolve those differences; no order fix was attempted after the failed gate.

## Bounds evidence and limits

Native ColorFilterLayer uses its children's display-list paint bounds, not simply the SizedBox. Local Flutter engine source: flutter/flow/layers/color_filter_layer.cc:39–105; flutter/flow/layers/display_list_layer.cc:23,106; flutter/display_list/dl_builder.cc:1839 (text GetBounds); flutter/impeller/typographer/backends/skia/text_frame_skia.cc:90 (SkTextBlob bounds); flutter/impeller/display_list/canvas.cc:1740–1780 (outward-rounded subpass coverage),1907–1925 (subpass clip),1990–2006 (restore origin). Paths are relative to ~/src/flutter/engine/src/.

**Actual native per-word layer bounds were not captured.** The diagnostic model combines prepared shaped horizontal extents, fontTools COLR-outline vertical union, the existing baseline, render transforms and DPR, then rounds outward. bounds-audit.json records every original changed pixel against nearby modeled physical rectangles, including fractional and rounded coordinates. This is not engine telemetry and must not be presented as such. Native SkTextBlob bounds, coverage adjustments and glyph raster coverage can differ from this model. The successful correction of 72 pixels is consistent with the overhang hypothesis but does not prove identical native bounds. The additional differences reject this model as an exact replacement.

Implementation probe: app/lib/grouped_ink.dart:7 rounds physical bounds; :95 applies Clip.hardEdge without a saveLayer; :149 maps local bounds through the global transform. app/lib/main.dart:1046 accepts diagnostic paintInkY. app/integration_test/parity_test.dart:27 enables PARITY_WORD_CLIP and :112 injects generated bounds for the seven parity cases. This is a parity-only probe, not a completed all-604-page production implementation. The ignored app/assets/mushaf/clip-probe.json contains generated bounds, not changed fonts.

## Checks and artifacts

- Red-first clip-rounding unit test failed on the missing helper (red.log); focused tests then passed (green.log). This verifies rounding arithmetic, not native-bound equivalence.
- flutter analyze: passed, no issues (analyze.log).
- Full flutter test --concurrency=2: passed (tests.log; all 61 tests).
- Profile device capture: passed (parity.log); exact repeat diff: passed (repeat-diff.log).
- Reference diff: failed as above (reference-diff.log; ../parity/clip-probe/images/diff.json).
- Per-original-pixel before/after RGBA and aggregated counts: pixel-comparison.json.
- Live device capture also saved at docs/runs/shots/2026-10-24-clip-probe-page187-dark128.png (ignored).
- git diff --check: passed.
- Private reference/candidate/repeat images and generated bundle are gitignored (git check-ignore verified).
- Dedicated perf-parity-proof.db was deleted at teardown; every proof record/device/word identifier is in ../parity/clip-probe/capture.json records. No accounts or tokens were created. The normal reveals.db was untouched.

Not run: native engine instrumentation; Stage 1 performance, cold-start or profile/release PSS; Stages 2–3; process-restart persistence integration; physical arm64 proof. The capture verifies durable SQLite close/reopen and Reader recreation, not Android process restart. Performance measurement was deliberately not started after the parity gate failed. No Stage 1 commit or speedup claim.

NEEDS_DECISION: Keep the current appearance and continue investigating with native per-word bounds instrumentation (recommended), or keep the current appearance by retaining per-word filters and pursue other performance changes. Exact pixels remain mandatory under either option. Work stopped before either path.
