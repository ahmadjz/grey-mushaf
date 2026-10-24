# Reject neighbour glyph warming

Medium_Phone profile, 4096 MB, x86_64, API37, DPR2.625, Impeller OpenGLES. Both runs were isolated from other heavy jobs. No physical phone measurement.

A bounded queue scheduled one offscreen page after each frame, at the real font size/DPR, with at most four incoming neighbour pages and replaceable stale work. Temporary paragraphs, images and pictures were disposed. Queue cancellation/disposal test went red before implementation, then passed; analyzer passed. The candidate is removed, with its one-off patch retained locally only.

| Medium_Phone profile raster workload | Stage 2 avg / p90 / worst ms; jank | Warming avg / p90 / worst ms; jank |
|---|---|---|
| First cold swipe | 2.627 / 4.605 / 7.700; 0 | 12.551 / 16.784 / 16.993; 11 |
| Portrait 20 swipes | 16.797 / 16.910 / 119.824; 315 | 16.153 / 16.962 / 79.428; 310 |
| Page 450 jump | 24.059 / 38.385 / 38.385; 1 | 17.415 / 17.012 / 131.073; 28 |
| Landscape 20 swipes | 10.804 / 16.837 / 41.500; 209 | 12.784 / 16.832 / 51.410; 250 |

Jank threshold >16.7 ms. Warming did not meet the keep criterion: first-swipe and landscape regressions. Sample counts differ because the capture includes settling and warming frames. No statistical significance claim from one run. No warming parity/PSS run was needed after rejecting it; final Stage 2 build receives full memory and cold-start measurement. Existing bounded font/data preloading remains.
