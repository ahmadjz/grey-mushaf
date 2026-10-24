# Review fixes

M1: test/word_target.dart:83 reads actual SemanticsNodes by identifier; :107 captures the production page OffsetLayer; :129 samples opaque rendered ink. Save tests cover pending/success/failure/Retry/re-grey; dark/chrome tests sample slider and dark-mode results. dark_mode_test.dart:182 now checks the production Reader ayah marker. Removing the durable-save page notification made both dedicated pixel and semantics tests fail while their store-state assertion passed (m1-mutation.log); the notification was restored. Forty focused tests passed (m1-green.log). No test calls the painter semantics builder to assert word state.

M2: reader_edge_cases_test.dart:27 covers gutter drags on spreads 1|2 and 49|50, retracing/count-once and swipe locking; :115 covers .08em +/- .000001em; :152 covers same-line blank taps between revealed words; :205 pauses save, swipes through page 7 until the old notifier is disposed, completes save, returns, and asserts rendered black ink/semantics without an exception. All five scenarios passed without production changes (m2-first.log, m2-green.log).

L3: removed hybrid_report.dart, classifier test, unused groupableInk, and hybrid/fractions.json. The retained synthetic grouping paint test still passes; hybrid/evidence.md preserves the 99.9534% portrait fallback finding in one paragraph. No active renderer was changed.

Final gates: flutter analyze clean (m2-green.log); 70 Flutter tests passed (tests.log); 26 pytest tests passed (pytest.log). No analyzer suppressions or weaker expectations were added.

Fresh Medium_Phone profile parity: 4096 MB, x86_64 emulator, DPR 2.625, Impeller OpenGLES. All 84 images pass R40: 84 changed pixels total versus 52e1e11, maximum 3 per image, all reference edge pixels; geometry identical (r40.json/r40.log). Exact comparison with the previously accepted Stage 2 images: zero changed pixels (exact.json/exact.log). Capture images and metadata: ../2026-10-24-perf-after/parity/review-fixes/ (ignored). Only lib/grouped_ink.dart's unused classifier changed in production sources.

Proof data: the parity capture lists every generated device/action/word identifier in its capture.json records; the dedicated perf-parity-proof.db and all those records were deleted at teardown. Unit tests use in-memory stores only. No accounts or tokens created. Fonts and private glyph images remain uncommitted.

Not run: new performance/memory sweep (no active rendering path changed); physical arm64 proof (no phone connected); separate-process restart proof this turn (the existing proof was unchanged). Owner edits in .claude files and pre-existing logs remain untouched.
