# Real-phone performance — HEAD a90f672

Redmi Note 9 Pro (2be3110f), Android 12/API31, arm64. Impeller OpenGLES. Active/supported refresh 60.000004 Hz, frame budget 16.666666 ms (display.txt). No production changes or commits. Existing owner changes untouched.

Every frame row is this Redmi Note 9 Pro, arm64 PROFILE. avg/p90/worst in ms; p90 nearest rank; jank = individual UI/raster duration over budget, not a measured count of missed screen presentations.

| Device/build/workload | Frames | UI avg/p90/worst | UI jank | Raster avg/p90/worst | Raster jank |
|---|---:|---|---:|---|---:|
| Redmi Note 9 Pro / arm64 profile / portrait_first_glyph_cold_swipe | 55 | 0.742/0.699/13.617 | 0 | 6.837/11.882/18.033 | 1 |
| Redmi Note 9 Pro / arm64 profile / portrait_20_swipes | 989 | 1.511/0.833/78.203 | 28 | 12.177/22.038/151.935 | 152 |
| Redmi Note 9 Pro / arm64 profile / unloaded_page_450_jump | 2 | 16.313/32.467/32.467 | 1 | 49.840/84.747/84.747 | 1 |
| Redmi Note 9 Pro / arm64 profile / landscape_20_swipes | 1048 | 1.992/0.844/73.902 | 24 | 10.040/14.809/82.676 | 92 |
| Redmi Note 9 Pro / arm64 profile / blank_portrait_20_swipes | 1096 | 0.649/0.807/2.478 | 0 | 3.218/3.806/19.235 | 1 |
| Redmi Note 9 Pro / arm64 profile / blank_landscape_20_swipes | 1171 | 0.651/0.790/2.678 | 0 | 3.189/3.752/9.441 | 0 |

| Device/build | Cold reader median of 5 | Android TotalTime median of 5 | PSS after 20 turns |
|---|---:|---:|---:|
| Redmi Note 9 Pro / arm64 profile | 1670 ms | 1765 ms | 204.35 MiB |
| Redmi Note 9 Pro / arm64 release | 1176 ms | 1255 ms | 168.81 MiB |

Cold means force-stopped process with warm filesystem/font disk caches; reader callback precedes actual display. Five raw samples and Android meminfo are in profile/ and release/. PSS follows a fresh fifth launch and 20 verified turns (pages 2 through 21). Frame capture starts with page 1; first swipe goes to preloaded but not previously painted page 2. The page-450 jump is a programmatic cold load, two frames, not a swipe into unavailable data. Synthetic drags are 250 ms across 75% viewport width, with settle/prefetch and idle time inside capture. Blank A/B replaces the reader tree with a plain white PageView, same reverse direction and default page physics; it omits prefetch, semantics and reader gestures. It is a motion floor, not an isolated filter-only experiment.

## Cause split and evidence

Raster dominates steady-state budget misses: portrait raster p90 22.038 ms versus blank 3.806 ms; landscape 14.809 versus blank 3.752 ms. Reader UI p90 remains below 0.85 ms but has 73.902–78.203 ms outliers. Traced layout peaks are 34.678 ms portrait and 64.635 ms landscape when page content enters; ordinary BUILD averages 0.507/0.897 ms in the traced windows. SEMANTICS runs each traced frame and averages 4.607/6.168 ms (inclusive), extra UI work not adequately described by the headline buildDuration alone. Do not sum overlapping timeline durations.

Retained Dart painting is working. Bounded portrait trace: 55 Animator frames, 50 raster draws, one _PageRender.paint call in one frame; 54 UI frames call it zero times. Landscape: 55 Animator/raster frames, six _PageRender.paint calls, distributed as 53 frames with zero, one frame with two, one with four. Each invokes PageInkPainter.paint once per nonempty colour group. Observed controllers have one group; read-only DB audit confirms zero word actions, reveal events or word states, so all words remain dim: these counts also give 1 and 6 word-painter calls, respectively (0.018 and 0.109 per UI frame averaged). This count is derived from render-paint instrumentation and the verified one-group branch at page_ink.dart:245–263, not a newly inserted painter counter.

RasterCache counters show zero pictures/layers/bytes throughout both traces. Engine GPUSurfaceGLImpeller::EnableRasterCache() returns false (local Flutter engine shell/gpu/gpu_surface_gl_impeller.cc:170). RepaintBoundary retains display lists, not cached page bitmaps here. GLES render passes continue each draw (200 in 50 portrait draws, 309 in 55 landscape draws); Canvas::saveLayer is recorded 300/508 times. Glyph-atlas checks occur each draw; bitmap updates occur only 8/15 times, peaking at 16.140/35.682 ms, and CreateGlyphAtlas peaks at 21.388/52.360 ms. This supports replay/filter work plus glyph-atlas cold/subpixel updates, not repainting Dart words every frame. Exact GPU filter-versus-glyph shares are not isolated by this experiment.

The actual backend is Impeller OpenGLES. profile-engine.log:37 and :48 show Vulkan initialization followed by GLES. SurfaceGLES/ReactorGLES trace events confirm GLES rendering. Local engine driver_info_vk.cc:397 blocks Adreno <=650; android_context_dynamic_impeller.cc:198 falls back to GL when Vulkan context is rejected. The early Vulkan message occurs before final context validation. Do not force Vulkan as the proposed fix.

## Motion

Redmi Note 9 Pro / arm64 PROFILE: controller last-offset-after-release median is 630.0 ms reader portrait and 710.3 ms reader landscape; blank 599.7 and 682.6 ms. This is a long settle tail even with almost no rendering jank. First injected-test-to-logical-offset medians are 54.35/56.03 ms reader versus 35.22/34.91 ms blank. These include test setup, gesture slop, recognizer and scheduling; they are proxies, not Android hardware pointer-to-photon latency. No claim of exact physical input latency or exact missed-presentation counts. Engine frame durations show real budget misses, so the remaining heaviness is both rendering and a separate long-tail motion issue.

main.dart:726–741 uses PageView/LoadedPagePhysics. loaded_page_controller.dart:74–112 only clamps unloaded boundaries. Local Flutter page_view.dart:601–617 uses velocity-dependent ScrollSpringSimulation; scroll_physics.dart:411–418 defaults to mass .5, stiffness 100, damping ratio 1.1. There is no app-set settle duration or named curve for swipe gestures. Classic AndroidX ViewPager uses quintic ease-out, velocity/distance-dependent duration capped at 600 ms; zero-velocity duration is (remaining page fraction + 1)*100 ms. This is a source comparison, not an on-device native-pager benchmark. ViewPager2 and other Quran apps may differ. Source: https://android.googlesource.com/platform/frameworks/support/+/4c3178d8a79df359648d82807f3b00e568f063b5/viewpager/viewpager/src/main/java/androidx/viewpager/widget/ViewPager.java

## Proposed next implementation

First experiment: explicitly cache the final coloured page into a physical-resolution ui.Image at page_ink.dart:241, preserving existing live layout, hit rectangles and semantics. main.dart:751 page selection/prefetch schedules nearby snapshots once idle; do not block a swipe waiting for an image. Existing display-list path remains the fallback until ready. Draw the cached image at its exact DPR geometry; include headings/page number consistently. ui.Picture alone still replays glyphs/filters. isComplex/willChange is insufficient here because the custom paint override bypasses hints and this GLES backend disables raster caching.

Key by page, physical geometry/DPR, saved reveal revision, foreground/background and dim level. At main.dart:377 saved-state notification / page_ink.dart:44 changed(), discard that page image only after successful save, immediately show current live saved colours, and rebuild asynchronously. Reject stale completion by generation/revision. Slider, dark-mode and orientation changes invalidate affected snapshots; preserve R2/R3/R24/R29 and semantics. Keep persistence and the underlying assets unchanged.

Bound cache to at most TWO portrait pages or FOUR landscape half-screen pages, AND 24 MiB of accounted pixel bytes including pending captures. A 1080x2400 RGBA image is 9.89 MiB; two screen equivalents are 19.78 MiB. Dispose the furthest image before allocating a replacement that would exceed the limit; count actual image dimensions, cap concurrency at one, drop on memory pressure, and avoid keeping duplicate old/new page images. GPU/driver residency may exceed pixel accounting. R39 release PSS <300 MiB after ALL 604 pages must be measured on this phone before acceptance; today only after-20 PSS is proven. Lower the byte cap if the full sweep needs it.

Second, separate A/B: a PageScrollPhysics subclass in loaded_page_controller.dart:74 preserving loaded-page clamping and gesture cancellation, with a quicker native-like settle (distance/velocity-aware, experimentally target 200–300 ms for a typical 25%-remaining release). This changes what the owner sees and must be compared on the phone before choosing it. Keep it separate so rendering improvement and motion preference can be assessed independently.

R40: unchanged words, geometry, sizes, line breaks and colours; full existing 84-image proof at <=5 changed edge pixels/image, repeat stability, plus phone DPR/orientation samples. Reject visible changes or non-edge differences. Cached fractional translation may differ from rerasterized vectors, so also inspect representative mid-swipe frames; snapshots are a proposal, not parity-proven implementation.

## Open decisions (owner-visible options)

- Existing long settling versus a quicker finish after finger release. Recommend testing the quicker finish as a separate A/B after the rendering trial; no choice is needed to continue technical measurement.

## Wrong premises

- Pages lack repaint boundaries or repaint their word painter every swipe frame: disproven.
- RepaintBoundary/isComplex guarantees cached GPU page textures: disproven for this Impeller GLES engine.
- A Vulkan startup log proves Vulkan is used: this phone falls back to GLES.
- First swipe means unloaded data/fonts: neighbouring data/fonts are already preloaded.
- Over-budget FrameTiming counts are exact dropped-display-frame counts, or synthetic controller latency is physical touch latency: neither follows.
- All native Android pagers share one duration/curve: comparison here is specifically classic ViewPager.

## Gaps

- No hardware touch-to-photon measurement, compositor presentation-frame loss count, native/reference Quran-app benchmark, isolated filter-only A/B, or full-604 phone PSS sweep.
- No proposed cache or physics implementation, so no new parity/speed-up proof. No production screenshot needed: no UI change was made.

## Risks

- GPU memory overhead and retained fonts can exceed the proposed pixel-byte budget or R39 total.
- Wrong revision/order can display stale reveal/style data; snapshots must preserve save-before-colour and live semantics/hit-testing.
- Texture resampling/fractional translation can break R40.
- Snapshot creation can shift stalls earlier; capture must be bounded and idle-scheduled.
- Synthetic fullyLive test scheduling, charging, thermal state and sequential A/B order limit generalization; instrumentation windows are separate from headline frame samples.

## Checks and cleanup

Corrected harness passed on first attempt this turn. Production profile build/cold/memory passed. Build orchestration initially rejected unsupported --offline; corrected. First release --no-pub build failed on stale integration-test generated registration; normal pub generation retry passed. Release build/install/cold/memory passed. Raw failure logs retained; they are not performance evidence. Temporary app harness files are copied here and removed from app/. No production diff, no commits, no source assets staged. No accounts/tokens/reveal records created. Database audit found only metadata row identifiers device_id and identity_version; retained as normal app metadata. Temporary read-only DB snapshot deleted. Final release restore result: final-restore.log and final-package.txt.
analyze: PASS
test: PASS
