# R40 full grouping

Full per-page colour grouping replaces the ineffective hybrid. Reference is 52e1e11. Medium_Phone profile, 4096 MB, x86_64, API37, DPR2.625, Impeller OpenGLES. Fresh 84-case capture passes R40: 84 changed pixels total, at most 3 per image, all at reference 8-neighbour colour edges; captured word identities and ink rectangles identical. Repeat captures pass exact mode. Private screenshots remain ignored under ../parity/r40-grouped/.

The reusable diff defaults to exact mode. Set PARITY_MODE=r40 for a per-image limit of 5 with no non-edge changes; R40 also requires matching capture.json word geometry (paths can be overridden with PARITY_REFERENCE_GEOMETRY / PARITY_CANDIDATE_GEOMETRY). It never thresholds, aligns or masks pixels. Tests cover count overflow, flat fields, row wrapping and geometry/identity changes. Initial red test is recorded in red.log.

Analyzer, full Flutter suite and pytest passed (analyze.log, tests.log, pytest.log); live capture and both diff logs are adjacent. The dedicated perf-parity-proof.db was deleted at capture teardown. Created identifiers are recorded in ../parity/r40-grouped/capture.json records; no accounts/tokens. Existing normal reveals.db was untouched.

Prior isolated performance of this renderer is in ../full-grouping/numbers.md; final-head performance will be measured after the remaining stages. No fonts or private images committed. The owner edits to .claude files remain untouched.
