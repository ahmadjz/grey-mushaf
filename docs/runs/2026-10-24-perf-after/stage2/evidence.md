# Page painter evidence

Medium_Phone profile, 4096 MB, x86_64, API37, DPR2.625, Impeller OpenGLES. No physical phone.

Focused one-word and one-line device probes both matched exactly. The production mismatch was an extra inherited TextStyle merge above Scaffold. Removing it and refreshing collected paragraphs after child layout fixes the painter. A style-change run exposed stale disposed paragraphs before that correction; the full corrected Flutter suite passes 64 tests. One-off probe source/screenshots are ignored in baseline/parity/word-probe.

Final capture: baseline/parity/stage2-final-probe. R40 passes all 84 cases: 84 changed pixels total, maximum 3 per image, zero non-edge changes, identical geometry. Exact repeat and exact comparison with Stage 1 pass. Analyzer and pytest pass. Logs: final-probe-gate.log, final-repeat.log, vs-stage1.log, final-analyze.log, final-probe-tests.log, pytest.log.

Per-page painter keeps per-word shaping and the original baseline/RTL positioning. The page notifier repaints and updates semantics only after durable save. Loading refreshes only pages whose data identity changes. Page changes and drag samples no longer call reader setState. Long-press start/end still update paging physics. Existing gesture/save-failure tests retain their assertions through actual paragraph/semantics/geometry hooks.

Separate-process SQLite proof passes with --keep-app-running and explicit force-stop. Flutter drive otherwise uninstalls the app, erasing app data: earlier restart failure was a harness failure. No real phone was involved. Dedicated reader-restart-proof.db removed after read. Device identifier d8ad9745-0282-451d-b190-5d0370a38845; action identifier 72c6a990-47e5-4a30-bc90-ff07f07ef79d; word qul-v4-hafs:1:1:1. Earlier failed fixture IDs are in restart/write.json and were removed by teardown/app uninstall. Parity proof identifiers are in capture.json; perf-parity-proof.db removed at teardown. No accounts or tokens.
