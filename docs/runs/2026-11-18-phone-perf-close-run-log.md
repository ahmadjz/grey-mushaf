# Run log: close reader performance on the owner's phone (2026-11-18)

base 931e22b (review range 931e22b..31d4e33) · dirty at start (not ours): .claude/codex-worker-rules.md, .claude/skills/quran-quick/SKILL.md
mode default · route routine (rendering cache + settle physics, no persistence/sync) · writer Opus medium (session) · reviewers Fable medium + fresh Sol medium

## Step 1 block

**Problem:** R39 fails on the phone (release PSS 347.93 MiB after 604 pages); review of the cache + settle commits not run.

**Memory attribution (phone, release, same harness, docs/runs/shots/memory-attribution/):**

| build | start | page 604 | settled | growth |
|---|---:|---:|---:|---:|
| a90f672 (no cache) | 142.3 | 348.5 | 345.6 | 206 MiB |
| 1f79eb7 (cache only) | 140.7 | 350.2 | 348.2 | 210 MiB |
| 31d4e33 (HEAD) | 140.9 | 347.9 | 346.9 | 207 MiB |

The page-image cache adds no measurable memory (within run noise). Breakdown HEAD start → 604
(docs/runs/shots/final-phone-release/pss-start.txt, pss-page-604.txt): Native 33.9 → 208.3, Graphics
71.4 → 88.7, Java 1.9 → 4.5, Code 14.3 → 14.0 MiB. Native growth ≈ the 161 MiB of page fonts:
engine copies each font into an SkMemoryStream (engine lib/ui/text/font_collection.cc:161) and offers
no unregister; mushaf_bundle.dart:72 registers each page font once. The emulator showed the same
~210 MiB growth from a 68 MiB launch (2026-10-23 run log); the phone launches at ~141 MiB.

**Rulings:** R42 Claude's default (growth limit on a real device). Stage C layout spikes: not fixed, no
safe cheap fix (numbers.md).

**Proof:** growth ≤230 MiB on the phone (met, 207 MiB); review findings handled; gates; release APK.

**Sessions:** writer Opus medium (session) · reviewers Fable medium (Agent), Sol gpt-6.1-sol medium thread 01a1ee20-6187-7671-89fe-df6daa1f4b09 (bridge accepts gpt-6.1-sol again)

## Steps
- 0 baseline: done · 1 investigate: done (memory A/B from 2026-11-01 artefacts) · 2 rulings: R42 default (b0c75a2)
- 5 review: done · r1 0/0/2 (C/H/M), 3 LOW
  - M both: two visible pages over the 24 MiB budget evict and re-capture each other forever (bigger screens, e.g. Boox) → fixed 6b86207: a page crowded out by the budget stays live-painted until it changes (page_image_cache.dart)
  - M Fable: Reader-level reveal/dark tests never proved an image was cached first → fixed: waitForCachedInk before reveal, re-grey and dark toggle; mutant without invalidation fails them
  - L Fable: new comments → removed
  - L Fable: every Reader rebuild re-captures; memory-pressure clear re-captures visible pages → kept as is (correct, bounded; 2 pages)
  - L Sol: no gesture-cancel test through Reader with LoadedPagePhysics → open, not done
  - r2 not needed (no C/H, routine, 2 fixes)
- 6 check: done (diff read, mutation check)
- 7 fix: done · gate: flutter analyze ok · flutter test 74 passed
- 8 exit:
  - R42 growth: 207 MiB on the phone (HEAD 31d4e33 release, 2026-11-01); 6b86207 changes no allocation, not re-measured
  - release arm64 APK grey-mushaf.apk sha256 b7fa3807…be93, installed on 2be3110f, process started; page on screen not observed (notification shade on top)
  - not done: Stage C layout spikes (35–65 ms on page change), R3 cancel test through Reader
- next action: Stage C incoming-line paragraph prewarm, if the owner still feels page-change hitches
