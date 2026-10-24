# Investigation at 52e1e11

Production code and assets unchanged. Existing owner edits to the two .claude files untouched.

## Measured outcome and limits

Medium_Phone (4 GB, x86_64, profile): median reader callback 449 ms / Android display 526 ms; R39 startup target passes. Full-read log verifies all 604 pages. PSS after page 604 is 335.97 MiB immediately and 334.42 MiB after 30 seconds; R39 memory target fails in this profile build. This is not a release-build or physical-phone verdict.

The successful provisional swipe sample is raster-dominated: Medium_Phone portrait raster p90 43.567 ms vs UI 0.457 ms; landscape raster p90 60.579 ms vs UI 0.713 ms. UI has substantial outliers too. Filters and colour-font composition are leading raster suspects supported by layer traces; no A/B test establishes their causal share. Registered fonts accumulate (`mushaf_bundle.dart:18,71–77`), but attribution of the memory increase requires a heap/native/GPU memory breakdown.

The reusable harness is `app/integration_test/perf_baseline_test.dart:9`, driver `app/test_driver/perf_baseline_driver.dart:6`; run-profile.sh uses the successful bounded trace configuration. Timeline JSON is a standard merged traceEvents export; frame-samples.json retains complete FrameTiming arrays. Trace tails are not complete 20-swipe event coverage. A clean isolated, bounded-memory trace collection is still needed before performance acceptance.

## Suspects

1. **Confirmed filter/layer work; exact per-word GPU-pass claim not established.**
   `app/lib/main.dart:1031–1052` builds Semantics → keyed SizedBox → FlatInk → Baseline → Text per word.
   `app/lib/flat_ink.dart:23,46` creates two nested matrix filters. Heading artwork also uses FlatInk (`main.dart:952`).
   The pilot trace contains thousands of Canvas::saveLayer events and GLES render-pass events. These are nested B/E events, not each an independent GPU allocation. Engine `flow/layers/color_filter_layer.cc:66–91` has cache paths and applies a filter through the state stack. Do not multiply words by two and call the result measured offscreen allocations. No app-level keep-alive mixin exists; PageView's delegate defaults are not proof that all visited pages remain painted.
2. **Confirmed per-word widget/layout structure and broad rebuild scope.**
   `_targets` is at `main.dart:406`; `_word` at 1018. Page change calls reader setState at 765, successful save at 378, drag movement at 626. The enclosing Reader rebuilds; that does not imply every retained word relayouts on every call. Trace has RenderParagraph.getDryBaseline and LAYOUT events. Gesture `_wordAt` at 565–610 scans bands, resolves RenderBoxes and localToGlobal for candidate words. CPU improvement is plausible; raster dominance must come from frame measurements, not widget counts.
3. **Confirmed repeated bookkeeping, refuted repeated full text measurement.**
   `main.dart:531–532` calls setState(_measureBundle) after loadNear, including unchanged windows because `mushaf_bundle.dart:95–97` returns true. `_measureBundle` (`main.dart:437–509`) scans the 604-slot list, then loaded word maps, reuses cached/prepared metrics and heading objects, and prunes keys. It does not shape all 604 pages on each turn. Orientation/programmatic navigation also invokes it at 685–688. No named CPU span isolates its duration in the baseline; don't assign a percentage without instrumentation.
4. **Refuted registration exactly at first display; glyph warming absent.**
   `mushaf_bundle.dart:43–46,71–86,89–106` registers fonts for the current and neighbouring spreads before publishing page data. Registered families stay in the engine and `_fonts` prevents registration twice. First painting still needs glyph atlas/raster work; no explicit warmup exists. Timeline CreateGlyphAtlas proves atlas work, not which glyph was newly rasterized. A normal swipe is clamped to loaded pages (`loaded_page_controller.dart:86–103`); slow prefetch can cause a stopped gesture instead of a blank destination.

## Design to implement after approval of any parity relaxation

Implement and measure stages independently: font conversion first with existing widgets; page painter second; bounded warming third. Write failing conversion/parity/gesture/save-order tests before each production change. Preserve global prepared metrics and all line justification, centering, baseline, overhang correction and special heading artwork.

**Font conversion:** all 604 page fonts are COLR v0. Font audit finds 6,236 marker bases, with 6,220 containing one pale field layer; 16 contain multiple fields. For 6,228 marker bases the monochrome base outline equals the final ink layer; eight differ (see marker-exceptions.txt). Example page 1 uniFC45 has cyan, magenta, pale-field, then black ink layers. Dropping COLR/CPAL blindly loses the composition, including the outer decorative layers and background knockout. The base glyph is not a reliable flattened replacement.

Use fontTools to inspect and flatten the actual ordered layer composition. Preserve glyph IDs, cmap, GSUB/GPOS, hmtx/vmtx, global metrics and hinting where valid. Foreground silhouettes must include all ink layers with pale-field knockouts; drawing all ink layers and merely omitting the field can leave a solid interior. Build explicit background/foreground marker geometry if subtraction cannot preserve rendering. Paint the field in the page background (white/light, black/dark), followed by remaining foreground ink in the saved word colour. This may require per-marker ordered drawing or companion glyphs, rather than a single monochrome text pass. Do not approximate the marker by a generic circle. Fail bundle conversion on unknown palettes/layer structures. Regenerate and compare all shaped word metrics and bounds; fonts remain ignored.

COLR v0 specifies an ordered layer stack; palette index 0xFFFF means application foreground. Source: https://learn.microsoft.com/en-us/typography/opentype/spec/colr . A foreground-COLR variant is a useful fallback experiment if flattening changes edges, but is not assumed faster or identical.

**Page painter:** one CustomPainter and RepaintBoundary per page, with a bounded immutable geometry cache keyed by page, viewport/scale and font revision. Retain separately shaped word Paragraphs/TextPainters at exactly the current RTL positions; do not reshape an entire line and accidentally change spacing. Draw heading artwork at the existing transforms. Precompute both advance and ink rects, full line bands and viewport clipping. Mirror nearest-ink-edge tie-breaking, .08em horizontal tolerance, short-tap ink-height limit and drag sampling. Use painter semanticsBuilder with the existing location/state/count labels and equivalent bounds; expose a test geometry hook and update finder-based tests without dropping their behavioral assertions. A hook alone does not replace accessibility.

**Reveal:** page-scoped notifier fires only after durable save succeeds (R24); invalidate that page's paint and semantics. Retain failure/retry, reveal counts, drag deduplication and swipe lock. Settings/orientation may invalidate all visible pages. Avoid reader-wide setState for each drag sample.

**Preload/warm:** reuse existing neighbouring-spread loads; add bounded actual raster warmup at current font size/DPR for incoming pages. Paragraph layout alone is not raster warming; an offscreen/unpainted widget is not proof of warm glyphs. Schedule after current frame, limit per-frame work, cancel stale viewport work, and measure whether engine atlas eviction defeats warming. Don't cache 604 page images or paragraphs. Font registration remains cumulative, so recheck full-session PSS.

## Parity proof plan

Before changing production code, capture baseline on the same backend/device/build/DPR for pages 1, 2, 50, 187, 604 and spread 49–50. Test light levels 128/176/224 and dark 32/80/128, both unrevealed and representative saved revealed words including every marker shape. Add marker exception pages from the audit. Freeze bars, orientation, viewport and animation; compare raw RGBA crops with no alignment correction. Also compare every word's layout metrics/rects and gesture/save/accessibility behavior.

Exact geometry is required. Exact raster equality is a goal, not a promise: thresholding an already antialiased colour composite is mathematically different from antialiasing a flattened monochrome outline. Differences can exceed one RGB level, especially at overlapping layers; no evidence yet supports a blanket one-level assumption. First attempt zero pixel differences. Proposed fallback, only with owner ruling: max absolute RGB delta <=1 solely on the union of reference/candidate antialias edge pixels; zero differences in solid interiors/background, alpha, geometry or marker topology; report count and max delta, fail anything larger. Never use a permissive global similarity score. If this narrow rule fails, retain the old rendering for the affected glyphs or return for a decision.

## Open decisions (owner-visible)

- Exact pixels remain mandatory by default. If geometry and solid colours match but a few edge pixels differ by one shade, accept the edge-only rule above (recommended only after reviewing diff evidence), or retain exact pixels even if that limits speed gains. No relaxation applied in this turn.

## Wrong premises

- Two filter widgets do not establish exactly two fresh offscreen allocations per word per frame.
- Nearby fonts already preload; they are not all first registered on the visible frame.
- `_measureBundle` does bookkeeping over prepared metrics, not full text shaping each turn.
- Normal gestures cannot enter an unloaded page; first-glyph-cold swipe and unloaded programmatic jump are different cases.
- Deleting COLR/CPAL alone is not a safe marker conversion; base outlines and layer composition differ.
- R39 as written names Medium_Phone, not the owner's physical phone. Meeting it does not establish real arm64 smoothness.

## Gaps

- Successful frame measurements are provisional: verification jobs overlapped part of the pilot, and trace rings retain only tails. Two isolated unbounded-trace attempts failed with allocator/service-disconnection evidence; clean isolated frame comparison remains outstanding.

- Owner phone/Boox/arm64 GPU measurements unavailable; emulator is x86_64.
- No filter-removal A/B experiment or per-widget CPU instrumentation this turn, so causal shares remain unmeasured.
- No new conversion, parity screenshots/diffs, reveal/settings performance run, or old five-page APK comparison.
- First unpainted page may be partially painted as the gesture begins; no assertion that every destination glyph is cold.
- Process-cold startup is not device-reboot/filesystem-cache-cold startup.

## Risks

- Marker topology, contour winding, overlapping layer antialiasing, hinting and glyph substitution can defeat naive flattening.
- Whole-line shaping or different Paragraph baselines can silently violate layout parity.
- Painter migration can regress accessibility, overlapping-word hit targets, durable-save ordering and drag/swipe arbitration.
- Warming may move jank earlier, increase PSS or be evicted; registered fonts cannot be assumed unloaded with page data.
- Tracing and emulator host contention affect timings; GPU/thermal behavior on the phone may differ substantially.
