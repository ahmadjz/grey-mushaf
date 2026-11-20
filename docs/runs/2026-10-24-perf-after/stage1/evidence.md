# Stage 1 exact-pixel gate failure

Stage 0 commit: dda9f8a. Base production: 52e1e11. Candidate production changes remain uncommitted; no fonts converted or modified.

Medium_Phone 4096 MB, x86_64, API37, Impeller OpenGLES, DPR 2.625, profile. Reference captured before production changes. 84 combinations, with both reference and candidate repeat captures identical (zero RGBA differences). Candidate vs reference: 84 differing pixels across 44 images, maximum channel delta 50. No threshold, masks or registration.

| Page / spread | Changed pixels across all modes/states | Conservative ink-rect overlap pairs |
|---|---:|---:|
| 1 | 0 | 54 |
| 2 | 12 | 50 |
| 50 | 0 | 2 |
| 187 | 12 | 0 |
| 604 | 0 | 1 |
| 63 | 36 | 0 |
| 49 | 24 | 4 |

Twelve differing pixels lie inside the audited overlapping bounds; 72 do not. Those bounds use prepared horizontal ink extents and conservative page-font vertical bounds. Overlap is therefore a risk, but not established as the sole cause. Changes also occur on overlap-free page 187. Example: page 187 dark128 at physical pixel (153,1540), reference RGBA [0,0,0,255], candidate [24,24,24,255]. Full pixel coordinates, values and candidate word locations: stage1/pixel-locations.json. Some changes fall outside the conservative word boxes, pointing to per-word versus grouped paint/filter bounds as another hypothesis, not a proven cause.

The candidate keeps per-word layout and semantics unchanged, defers their painting to two colour groups per page, preserves render-tree transforms and headings, and reuses the exact two matrices. No painter migration or glyph warming was started. Three tests now inspect the grouped word colour property instead of the former FlatInk widget; colour, geometry and behaviour assertions are unchanged.

Checks: red grouped test observed missing implementation; translated nonoverlapping grouped paint and original matrix tests green. Analyzer clean. Full suite: all 60 tests passed (stage1/tests-final.log); initial widget-type finder failures were corrected without changing their assertions. Candidate device capture passed persisted SQLite close/reopen checks and cleaned perf-parity-proof.db. All temporary identifiers are listed in the ignored parity/stage1/capture.json records array; no accounts or tokens. The normal reveals.db was not deleted.

Not run: Stage 1 performance/cold/PSS acceptance (exact-pixel gate failed); Stages 2 and 3; process-restart persistence integration (the existing test deletes normal reveals.db; the isolated capture instead verifies store close/reopen and Reader recreation); physical arm64 device. No Stage 1 commit: failed candidate retained for review. Stage 0 profile/release timings and full-session PSS are in numbers.md, with a bounded FrameTiming timeline at stage0/timeline.json.

NEEDS_DECISION: Continue investigating grouped filter paint bounds/order while retaining exact pixels (recommended), or retain per-word filtering and pursue the painter optimisation first. Neither option permits a pixel tolerance or font conversion.
