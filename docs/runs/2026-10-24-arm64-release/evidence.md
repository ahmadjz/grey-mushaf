# Arm64 release

Head: `4e648bdc1659b48c820652beb69fad15d3d7fc58`. Grep found the removed renderer referenced only by its own test; no remaining GroupedInkPage/GroupedInkWord/grouped_ink references in app/lib, test, integration_test or tool. Deleted app/lib/grouped_ink.dart and app/test/grouped_ink_test.dart.

Analyze clean; all 69 Flutter tests pass (gates.log). Build succeeded on its first attempt. `:app:verifyMushafBundle` executed at build.log:224; BUILD SUCCESSFUL at :1780. APK inspection independently verifies all 604 page JSONs, 604 page fonts and 1212 asset hashes against embedded metrics. Only arm64-v8a native libraries are packaged, all with AArch64 ELF machine type. The regenerated Android plugin registrant excludes the dev-only integration-test plugin.

Command, from app/:

```sh
heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter build apk --release --split-per-abi --target-platform android-arm64 --target=lib/main.dart --verbose
```

Normal release plugin preparation was retained (no --no-pub) to avoid the stale dev-only registrant issue. No dependency or SDK changes.

Copied verified output to repo-root grey-mushaf.apk. Size: 88,076,901 bytes (84.00 MiB). SHA-256: `c3c0325406f7ef3bce4a28ab92ba21050b2fe07a4de4ff7f7dd855ad7047b4ac`. Ignored by .gitignore:3 (`*.apk`); no APK/font/assets committed.

Not run: physical arm64 execution (no connected phone). No accounts, tokens or database records created. Existing owner edits and untracked diagnostics untouched.
