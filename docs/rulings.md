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
3. **Gestures.** A long-press reveals one word. ~~Long-press then drag reveals every word the finger
   passes over~~ (dropped by R43), and the page swipe is off until the finger lifts. A short tap on a
   black word turns it grey.
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
    marks and bookmarks. Signing out keeps the local data. *(The last page no longer syncs: R76.)*

## R11 (2026-10-21, owner)

11. **Backend and accounts:** a dedicated PocketBase instance on the VPS behind the existing Caddy,
    with no Firebase. Anyone can sign up, with Google sign-in or email and password. Verification
    and password-reset emails go out through a free Gmail app password over SMTP. The devices keep
    local SQLite as the source of truth while offline. Each user can read and write only their own
    records.

## R12 (2026-10-21, Claude's default, the owner may overrule)

12. *(Conflict order replaced by R77; idempotent UUIDs and summed counts still hold.)* **Conflicts:** each word's state is the last action by server receive order. Actions carry a UUID
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
23. **Every line fits on screen in full.** On the upright phone a full page shrinks slightly so no
    word is cut by the screen edge, with the printed line breaks and one text size across pages.

## R24 (2026-10-21, owner)

24. **A word shows black only once it is saved.** If saving a reveal or a re-grey fails, the word
    keeps its last saved colour and a short "Couldn't save" message offers a retry.

## R25–R28 (2026-10-22, owner)

25. **The reader is full screen.** The phone's status bar and navigation bar are hidden so the page
    gets all the space.
26. **A single page keeps a small side margin.** In portrait the text no longer touches the screen
    edges, so it reads clearly. This narrows R19's "as thin as possible" for the portrait page.
27. **The page number is shown small, for information only.** It is not a button and takes as little
    room as possible. The page list behind it goes away. Navigation comes later as a surah list with
    the juz marked inside it, like the owner's reference app.
28. **Settings has a slider for how light the grey text is.** The owner prefers it lighter, but
    others may not, so it is adjustable.

## R29 (2026-10-22, owner)

29. **Tapping empty space shows the bars,** like the owner's reference Quran app. The reader opens
    full screen (R25). A tap on a spot with no word brings back the phone's bars and a thin top bar
    in the app, which holds Settings (and later the surah list). Another tap on empty space hides
    them. Taps and long-presses on words work as before.

## R30–R32 (2026-10-22, Claude's defaults, the owner may overrule)

30. **Page number style:** small, at the bottom centre of each page, in Arabic-Indic digits (١٠٩), as
    in the reference app. It sits in the page's own blank space; a thin strip is reserved only where
    a page has no room under its last line.
31. **Portrait side margin:** 2% of the screen width on each side.
32. **Grey slider range:** from mid grey (`#808080`) to very light (`#E0E0E0`), starting at today's
    grey (`#B0B0B0`). The setting belongs to each device and is not synced.

## R33–R35 (2026-10-22, owner)

33. **Dark mode,** like the owner's reference Quran app: a black page, unrevealed words dim, revealed
    words bright white. Surah names and the basmallah headings are white in dark mode (R20's "always
    black" means full contrast in the current mode).
34. **Dark mode has its own dimness slider.** It remembers its own level separately from the light
    mode's grey (R28), per device.
35. **Dark mode turns on only by a switch in Settings.** The app starts in light mode and does not
    follow the phone's dark mode.

## R36–R38 (2026-10-22, owner)

36. **Every launch opens in light mode,** even if dark mode was on when the app was closed. Going to
    the background and back keeps the current mode. The dark dimness level (R34) is remembered.
37. **The dark slider runs from very dim to medium grey:** from `#202020` to `#808080`, starting at
    `#505050`. Unrevealed words stay visible and never match the white of revealed words.
38. **Dark mode darkens the whole screen.** The top bar and Settings panel are dark, the page number
    is a soft light grey, and "Couldn't save" is a dark grey box with white text. Ayah-number circles
    are black inside, and their outline and number follow the word (dim, then white once revealed).
    Settings shows one slider, for the mode that is on; each mode keeps its own level.

## R39 (2026-10-23, Claude's default, the owner may overrule)

39. **The app opens fast with all 604 pages inside.** On the Medium_Phone emulator a cold start
    shows the first page within 2 seconds and stays under 300 MiB of memory (PSS as Android reports
    it), even after reading all 604 pages in one session. If loading every page
    up front misses that, pages and their fonts load as the reader nears them, with no visible
    change to text size or layout.

## R40 (2026-10-24, owner)

40. **Speed over invisible pixel parity.** A rendering speed-up may change a handful of edge pixels
    (a few per screen, at letter tips) as long as nothing a reader can see changes: same words, line
    breaks, positions, sizes and colours. Screenshot diffs stay the check, and any change beyond
    stray edge pixels goes back to the owner.

## R41 (2026-11-01, Claude's default, the owner may overrule)

41. **Page turns settle like a native Android app.** After a swipe the page snaps into place about as
    fast as Android's own page swiping, instead of the slower springy finish. Where the finger lets
    go, which page it lands on and the swipe lock during a drag (R3) don't change.

## R42 (2026-11-18, Claude's default, the owner may overrule)

42. **Memory on a real phone is judged by growth, not by the emulator's total.** Reading all 604
    pages in one session may add at most 230 MiB of PSS above the app's own launch figure on the
    same device (R39's 300 MiB total stays the emulator check). The page fonts cannot be unloaded
    once shown, so a long session grows by about their size; restarting the app frees it.

## R43 (2026-11-18, owner)

43. **Long-press reveals one word only.** No drag-to-reveal and no multi-select: after the long-press
    turns the word black, moving the finger reveals nothing else and does not turn the page until it
    lifts (Claude's default). Supersedes the drag part of R3 and R6.

## R44 (2026-11-18, owner)

44. **The next screen is ready before you swipe.** While the owner reads, the app prepares the
    previous and next screen: one page each side in portrait, a whole two-page spread each side in
    landscape. Further pages load after a swipe finishes, not during it. Showing the bars, a reveal
    or a slider move only redraws what changed. Nothing on the page looks different (R40).

## R45–R57 (2026-11-18, owner)

45. **Page-turn arrows.** Two faint round chevron buttons sit at the bottom corners, always shown,
    with an on/off switch in Settings. The left arrow goes to the next page, the right to the
    previous one; in landscape they move a whole spread. A long-press on an arrow lets the owner
    drag it anywhere, and the spot is remembered per orientation. A tap on an arrow never reveals a
    word or toggles the bars.
46. **Marks.** A word carries up to three marks at once: visible (black, R2), a line under it
    (single or double) and a shape around it (rectangle or circle). The line and the shape each
    keep their own colour. Only "visible" counts toward the reveal count (R6).
47. **Tools.** The toolbar's five tools are on/off switches sharing one active colour, and one
    long-press applies every active tool. A mark the word already has is left as it is, even in
    another colour (to change it, remove it and apply again). A single line on a double-lined word,
    or a circle on a boxed word, replaces the old one (Claude's default).
48. **Tap on a marked word.** A word that is only visible turns grey at once (R3). A word with a
    line or shape shows a small box with a checkbox per mark and "Clear all".
49. **Colours:** six fixed ones: red, blue, green, orange, purple, and black (white in dark mode).
50. **The PDF export (R7) shows every mark.**
51. **Floating toolbar,** like Xiaomi's quick ball: a faint circle showing the active tool in the
    active colour. It can be dragged anywhere, tucks half away at a screen edge, and can be pinned
    so it stays fixed. A tap opens a strip with the five tools, the colour, show/hide the top bar
    and hide the toolbar; once hidden it comes back from the top bar menu. A tap on empty space
    still toggles the bars (R29).
52. **Top bar,** like the reference app: a back arrow to the surah list; the surah name with
    "صفحة ٢١٦، جزء ١١" under it; a bookmark icon; and a ⋮ menu with search, the dark mode switch,
    quick jump and Settings. It covers the status bar and the full width. No translation or audio
    (R9).
53. **Bookmarks:** the icon saves or removes the current page, any number of pages, listed on their
    own bookmarks screen.
54. **Quick jump:** a dialog that takes a page number, or a surah and ayah, like the reference app.
55. **Search:** surah name, page and juz, plus text search from the QUL word text the owner
    downloads (Claude's default; the owner had no preference).
56. **Web, not native desktop, for now.** A web build on the VPS, usable only by users signed in with
    a PocketBase account (R11). With a mouse, holding the button is a long-press, and the wheel or
    arrow keys turn pages.
57. **Order:** (1) top bar, borders and arrows; (2) marks and the floating toolbar; (3) surah list,
    bookmarks, quick jump and search; then the phase 1 and 2 work still open (B/W mode, accounts
    and sync, export), and the web build once sign-in exists.

## R58–R60 (2026-11-18, owner)

58. **Sync runs by itself.** Every change saves on the device first (R10). Once signed in, the app
    syncs on launch and whenever the connection returns. Settings has a "Sync now" button showing
    the last sync time and how many changes are waiting.
59. **Borders,** like the reference app: a thin double line down the page's outer edge. In portrait
    that is the right edge on odd pages and the left edge on even pages; in landscape both outer
    edges and the spine.
60. **Page header line:** a thin line at the top of each page with "الجزء ١١" on the right and the
    surah name on the left, in portrait and landscape. In landscape it shrinks the text by a few
    percent; this narrows R19 there.

## R61 (2026-11-19, Claude's defaults, the owner may overrule)

61. **Top bar and header details for run 1 of R57.** The surah name and juz shown in the top bar and
    the page header line are those of the page's first ayah. Pages 1–2 get the header line and border
    too. The dark mode switch leaves Settings for the ⋮ menu; until run 3 the menu holds only the dark
    mode switch and Settings, and the bar has no back arrow or bookmark icon. The arrows start at the
    bottom corners, and their Settings switch starts on. The arrows sit flush in the corners and can
    cover the last line's corner words; a tap there turns the page until the arrow is dragged away.
    On screens shorter than today's phones (16:9 phones, the Boox) the header line shrinks the
    portrait text by about 2% too; taller phones keep today's size.

## R62 (2026-11-19, Claude's defaults, the owner may overrule)

62. **Marks and floating toolbar details for run 2 of R57.** The tools are visible, single line,
    double line, rectangle and circle. Single and double line exclude each other, as do rectangle
    and circle, so turning one on turns its partner off. On first launch only "visible" is on and
    the colour is red, so a long-press works as before; with every tool off a long-press does
    nothing. The line sits just under the word and the shape around it, thin enough not to hide
    the letters. In the tap box, unticking a mark removes it at once (it can be ticked back while
    the box is open), "Clear all" removes every mark including visible and closes the box, and the
    box closes by itself once nothing is left. A grey word with no marks ignores a tap, as before.
    The quick ball sits on the right edge, half tucked, at first launch. It stays where it is
    dropped and tucks half away only when dropped near the left or right edge; pinned, it cannot
    be dragged. With several tools on, it shows the one turned on last, with a small count. The
    strip also holds the pin switch; while it is open, a tap outside it only closes it. The tools, colour, ball spot, pin and hidden state are
    remembered on the device and not synced. The five colours other than black stay the same in
    dark mode. "Couldn't save" and "Couldn't load page" messages sit between the bottom arrows,
    and a failed save of an arrow's spot offers Retry.

## R63–R65 (2026-11-20, owner)

63. **The app opens on the reader at the page last read.** The top bar's back arrow (R52) opens the
    surah list; picking a surah, juz or bookmark there takes the reader to its page.
64. **Bookmarks are a second tab on the surah list screen:** السور | العلامات.
65. **Search works like the reference app.** Typing shows up to five matching ayahs under the search
    field, each with its text and "سورة (٢) البقرة: ١٠٤ (صفحة ١٦)", plus a "full results" row. The
    full results screen shows the count ("٩٢ نتيجة في البحث عن ...") and every ayah with the searched
    words coloured. Opening a result goes to its page with the ayah shaded behind its words; the
    words keep their own grey or black.

## R66 (2026-11-20, Claude's defaults, the owner may overrule)

66. **Navigation details for run 3 of R57.** Each surah row shows its number, name, "مكية - N آيات"
    (or مدنية, as in the reference app) and its first page; a "الجزء N" row with its page sits where each juz begins in the list,
    and tapping it opens that juz. In a landscape spread the bookmark icon is filled when either
    page is saved; a tap removes the saved pages, or saves the right-hand page. The bookmarks tab
    lists the newest first, each with surah, page, juz and a remove button. Quick jump is one dialog
    with a page field and a surah picker with an ayah field. In search, a number also finds that page
    and juz, a surah name finds the surah, and text matching treats أ/إ/آ/ا, ى/ي and ة/ه as the same
    letter. A quick jump to a surah and ayah shades that ayah too. The search shading clears on the
    next tap or page turn. The last page read stays on
    the device and is not synced. A failed save while the mark box is open shows "Couldn't save"
    with Retry inside the box.

## R67–R72 (2026-11-20, owner)

67. **B/W grey words** use the same grey as light mode, and the grey slider still works.
68. **B/W marks are all drawn black** (white in dark mode) and the toolbar's colour row hides. Each
    mark keeps its stored colour, which shows again once B/W is off.
69. **B/W page and chrome.** Borders and the header line stay black, at least 1 px thick. The search
    shading is light grey instead of light blue. The top bar, Settings, switches and sliders are
    black, white and grey only, with no colour accents.
70. **Dark mode works in B/W:** a black page, dim words, white revealed words and white marks.
71. **The B/W switch is in Settings.** It starts on for a Boox (`Build.MANUFACTURER == ONYX`) and off
    elsewhere; once the owner flips it, the choice is remembered on that device across launches.
72. **In B/W the page changes instantly,** with no slide (arrows, quick jump, search results).

## R73 (2026-11-20, Claude's defaults, the owner may overrule)

73. **B/W details.** In search results the searched words are bold and underlined instead of
    coloured (R65). The mark box swatches, the toolbar's tool icons and error text are black, white
    or grey too. A swipe still follows the finger; only arrows, quick jump and search jump at once.
    The automatic Boox check can be faked on a debug build with
    `adb shell setprop debug.greymushaf.manufacturer ONYX`; release builds ignore it.

## R74 (2026-11-20, owner)

74. **Arrow turns are instant everywhere.** A tap on the left or right arrow shows the next or
    previous page (a whole spread in landscape) at once, with no slide, in colour on the phone as
    well as in B/W (extends R45 and R72). A finger swipe still follows the finger. Quick jump and
    search already jump.

## R75 (2026-11-20, owner; sizes are Claude's defaults)

75. **Bigger arrows on the Boox.** On large screens (the Boox and tablets) the arrows are 64 dp
    instead of 44, with a bigger chevron, and start 16 dp in from the bottom corners instead of
    flush (narrows R61). Phones keep today's arrows. A spot the owner dragged an arrow to is kept.

## R76–R80 (2026-11-20, owner)

76. **The last page is not synced.** Each device opens on its own last page (replaces R10's last page
    clause; confirms R66).
77. **Newest change wins.** When two devices changed the same word, mark or bookmark, the change made
    last (by when it was made) wins once both have synced. Every reveal from every device still adds
    to the reveal count (R6), even one a newer change later overrode.
78. **Sign-in has its own screen,** opened from an "Account" row in Settings: email, password, Sign in,
    Create account and Forgot password. Signed in, Settings shows the email, "Sync now", the last sync
    time, the number of changes waiting, and Sign out (R58).
79. **Email and password only for now.** Google sign-in (R11) comes in a later run.
80. **The server is `mushaf.ahmadjz.tech`:** a dedicated PocketBase container
    (`/opt/vps-infra/pocketbase-mushaf`, 127.0.0.1:8093) behind the shared Caddy, which gets one new
    site block and a reload.

## R81 (2026-11-20, Claude's defaults, the owner may overrule)

81. **Account details.** Signing in requires a verified email. Changes made while signed out upload at
    the next sign-in.

## R82 (2026-11-20, owner; the reset details are Claude's defaults)

82. **No sign-up in the app for now.** The owner creates his friends' accounts himself in the
    PocketBase admin page, already verified. The sign-in screen has only email, password and Sign in:
    "Create account" and "Forgot password" are left out (narrows R11 and R78), and the owner resets
    a forgotten password in the admin page. TODO later: self sign-up, verification and reset emails
    over Gmail SMTP.

## R83 (2026-11-20, Claude's default, the owner may overrule)

83. **One account per device.** Once a device has synced with an account, signing in there with a
    different account is refused with "This device holds another account's words. Sign in with that
    account." Nothing is deleted or mixed between accounts. Signing out and back in with the same
    account works as before. To hand a device to someone else, clear the app's data first.

## R84 (2026-11-20, owner)

84. **The PDF export (R7, R50) is on hold.** Nothing of it is built for now; the export rulings
    (start, delivery, page shape, mark colours, range, render source) stay open until it resumes.
    Finding kept for then: `ai-pages/` holds only 74 of 604 pages, so a 604-page export would draw
    from the QUL fonts and page data.

## Phases

0. **Feasibility spike:** get the 1441 word data (QUL V4 layout plus words, and fonts if they can be
   used), or segment the owner's .ai outlines into words. Prove tapping and colouring on a sample of
   pages, including 1, 2 and one dense page. Check the asset licences.
1. **Offline reader:** grey pages, reveal and re-grey, navigation by page, surah and juz, bookmarks,
   last page, B/W mode.
2. **Sync and export,** plus accounts and the web page for privacy, account deletion and donations.
3. ~~**Play release**~~: dropped by R16. Friends install the APK directly.
4. **Handwriting, stats, search by text.**
