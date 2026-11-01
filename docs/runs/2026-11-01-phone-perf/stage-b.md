# Stage B — quicker page settling

Redmi Note 9 Pro (2be3110f), arm64 profile, Impeller OpenGLES, 60 Hz. Identical 250 ms drags and sample harness before/after. Last controller-offset timestamp after injected release; this is not physical input-to-photon latency.

| Reader orientation | Original spring, cache enabled | Critically damped spring |
|---|---:|---:|
| Portrait | 630.7 ms | 157.1 ms |
| Landscape | 713.3 ms | 176.0 ms |

LoadedPagePhysics supplies an inherited spring with mass 0.5, stiffness 1500 and damping ratio 1. PageView retains its normal page-target calculation, fling threshold, loaded-page boundary clamps and gesture cancellation. The outer PageScrollPhysics uses this spring; replacing only the inner ballistic simulation would be bypassed.

Red-first test checks both fling directions and zero velocity at quarter-page release positions: exact initial offset, identical destination, and completion within 350 ms. Existing unloaded-page and pending-navigation cancellation tests remain unchanged. Analyzer and 73 tests pass. Phone 84-image R40 and exact-repeat gates pass; geometry is identical.

Raw evidence: `../shots/stage-b.log`, `../shots/phone-settle-perf/`, `../shots/settle-r40.json`, `../shots/settle-repeat.json`. Temporary proof database and all identifiers in `../shots/phone-settle-parity/capture.json` were removed by harness finally. No accounts/tokens. Release cold-start and all-604 memory acceptance remain separate.
