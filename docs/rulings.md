# Rulings

The owner's decisions. Code follows these. A new ruling gets the next number and a date, and a
changed ruling is edited in place with a note of what it replaced.

## Purpose

A fast recap of about 50 pages where the eye catches only the words the owner fails to remember.
Revealed words are weak spots and stay black, so over time the owner remembers where they sit.

## R1–R9 (2026-10-21)

1. **Handwriting** comes in a later phase. Writing over the grey text stays in the exported PDF on
   the Boox for now.
2. **A revealed word stays black** until the owner turns it grey again. The state is saved locally
   and synced between devices.
3. **Gestures.** A long-press reveals one word. Long-press then drag reveals every word the finger
   passes over, and the page swipe is off until the finger lifts. A short tap on a black word turns
   it grey.
4. **Orientation.** Portrait shows one page. Landscape shows a two-page spread like an open mushaf:
   the odd page on the right and the even page on the left (page 1 right, page 2 left). This is the
   same on phone and Boox.
5. **Layout fidelity.** The 1441 Madinah Hafs layout must be exact: ayah positions, where each line
   starts and ends, and the line count per page, including the special opening pages 1–2. Borders and
   decoration may differ. The 1421 (V2) layout is rejected.
6. **Turning a word grey again is manual only.** The app keeps a reveal count per word, for a later
   "weakest pages" view. The count goes up only when a word turns grey→black, and a drag counts each
   word once.
7. **Export:** the grey mushaf with the weak words in black, plus a plain grey option. It is built
   server-side on the VPS, in phase 2 after sync.
8. **Devices:** an Android phone and a Boox. Distribution is replaced by R13. The phone uses natural
   colours. A black-and-white e-ink mode turns on automatically on a Boox
   (`Build.MANUFACTURER == ONYX`) and can be toggled.
9. **No audio or tafsir** for now.

## R10 (2026-10-21, owner)

10. **Offline first, sync optional.** The app works fully offline with no account. In Settings the
    user can sign in and enable sync, and then every signed-in device shares the same weak words,
    bookmarks and last page. Signing out keeps the local data.

## R11 (2026-10-21, owner)

11. **Backend and accounts:** a dedicated PocketBase instance on the VPS behind the existing Caddy,
    with no Firebase. Anyone can sign up, with Google sign-in or email and password. Verification
    and password-reset emails go out through a free Gmail app password over SMTP. The devices keep
    local SQLite as the source of truth while offline. Each user can read and write only their own
    records.

## R12 (2026-10-21, Claude's default, the owner may overrule)

12. **Conflicts:** each word's state is the last action by server receive order. Actions carry a UUID
    and a device id, so retries are idempotent and there are no clock-skew ties. Reveal counts are
    stored as append-only events and summed, never overwritten.

## R13–R15 (2026-10-21, owner)

13. *(Replaced by R16: no Play release.)* **Google Play release.** This replaced R8's "sideloaded APK, no store". The package id is
    `tech.ahmadjz.greymushaf` and can never change. Play requires:
    - in-app and web account deletion;
    - a privacy policy and the Data safety form;
    - an AAB signed with an upload key that is never in git;
    - the current target API level;
    - a closed test with 12+ testers for 14 days before production, because this is a new personal
      developer account.
14. **Free, donations only.** The owner's ShamCash QR goes on the app's website and the README. It is
    not shown in the app unless Google Play's payments policy is confirmed to allow it.
15. **Licences gate phase 0.** Whichever mushaf source phase 0 picks (KFGQPC .ai outlines, or the QUL
    V4 data and fonts) must have terms that allow free redistribution in a public app. Assets never
    go in the public repo: they are fetched at build time or on first launch.

## R16–R18 (2026-10-21, owner)

16. **Personal use only, no public release.** This replaces R13 and R15's public-app clause. The
    1441 word fonts (QUL V4, from the King Fahad Complex) say "charitable only, publishing not
    permitted without prior permission", so the app is not published on Google Play or anywhere
    else. It is for the owner and friends who test it. The repo stays public, and the assets still
    never go in it.
17. **Revealed words are plain black,** like the printed 1441 mushaf. Grey words are plain grey. The
    tajweed colours in the fonts are never shown.
18. **The mushaf ships inside the APK.** The build takes the fonts and word data from the owner's
    own machine (downloaded from QUL with the owner's sign-in) and packs them into the APK, so it
    reads offline from the first launch. Nothing is downloaded on first open.

## R19 (2026-10-21, owner)

19. **The page fills the screen.** Words must be as large as the screen allows, above all on a
    phone. Margins, borders and empty space around the page stay as thin as possible, and the
    text block scales to the available width and height in portrait and in the landscape spread.
    The special pages 1–2 keep their short centred layout (R5) at the same text size as other
    pages.

## R20 (2026-10-21, owner)

20. **Surah names and the basmallah headings are always black.** They are not words: they are never
    grey, never revealed and never counted. The basmallah that is ayah 1:1 on page 1 is a word like
    any other.
21. **A surah heading reads "سورة" plus the name,** in the mushaf calligraphy. The size and spacing of
    the heading and the basmallah match the printed 1441 pages (the owner's .ai pages).
22. **The basmallah heading has two forms, as printed.** Page 2 shows the compact basmallah. Every
    other page shows the wide, stretched basmallah traced from the owner's page-50 .ai file. The
    traced artwork stays on the owner's machine and is packed into the APK, never into the repo.

## Phases

0. **Feasibility spike:** get the 1441 word data (QUL V4 layout plus words, and fonts if they can be
   used), or segment the owner's .ai outlines into words. Prove tapping and colouring on a sample of
   pages, including 1, 2 and one dense page. Check the asset licences.
1. **Offline reader:** grey pages, reveal and re-grey, navigation by page, surah and juz, bookmarks,
   last page, B/W mode.
2. **Sync and export,** plus accounts and the web page for privacy, account deletion and donations.
3. ~~**Play release**~~: dropped by R16. Friends install the APK directly.
4. **Handwriting, stats, search by text.**
