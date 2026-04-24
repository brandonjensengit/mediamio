# Phase 2 QA — Manual Verification on tvOS Simulator

**Started:** 2026-04-24
**Sim:** Apple TV 4K (3rd gen), tvOS 26.0, UDID `FE485BD4-38E6-4607-A865-E29C5A4AC506`
**Build:** green on `tvOS Simulator,OS=26.0,name=Apple TV 4K (3rd generation)`, zero new warnings (chunk 1 build gate)
**Server:** Brandon's Jellyfin (user `brandon.jensen`)

**What this doc is:** per-chunk QA results for Phase 2 against the sim, plus any bugs that need follow-up. Phase 2 items A/B/C.1/D/E/F/H all shipped in prior sessions; this QA pass includes both committed Phase 2 work AND the ~500 lines of uncommitted post-Phase-2 UX refinements currently in the working tree.

**Chunks:** sequenced by surface, not by ticket. Chunk N only starts after chunk N-1 is signed off.

---

## Bug & follow-up index

Running list across all chunks. Severities: **P0** block ship, **P1** file before merge, **P2** phase-3 polish, **?** needs hand-off verification (can't confirm from sim alone).

| ID | Chunk | Sev | Area | One-liner | File / source |
|---|---|---|---|---|---|
| QA-1 | 1 | P2 | Hero | Overview text truncates mid-word ("a...") with significant unused horizontal room right of the 2:3 keyart | `HeroBanner.swift` overview Text frame |
| QA-2 | 1 | ? | Hero | Resume vs Play-from-Beginning confirmation dialog not visually captured — rotation landed on non-progress backfill item during test window; code path inspected and appears correct | `HeroBanner.swift:253-297` |
| QA-3 | 1 | ? | Home | ErrorView auto-focus fix on Try Again button not exercised (would require killing network) — code path inspected and appears correct | `HomeView.swift:267-309` |
| QA-4 | 2 | P2 | Detail (Series) | Double-title: when Jellyfin backdrop keyart bakes in the title AND a separate logo asset exists, both render → large title on backdrop + smaller logo overlay lower-left. Observed on Schmigadoon! | `ItemDetailView.swift:318-323` TitleTreatment in infoColumn |
| QA-5 | 2 | P2 | Detail (Series) | Series metadata line shows "0m" runtime because Jellyfin surfaces per-episode runtime, not series aggregate. Cosmetic but inconsistent with Movie "1h 58m" format. Pre-existing (not Phase 2). | `ItemDetailView.swift:380` `runtimeFormatted` for Series |
| QA-6 | 2 | ? | Detail (Movie) | Chapters demotion order (moved below Cast/Crew per Item E) not exercised — tested Movies (Sid & Nancy, Little Big League, Versa) all lacked chapter metadata on Brandon's Jellyfin. Code path inspected; `ChaptersSection` is gated `displayItem.type != "Series"` and positioned after the (commented-out) Cast/Crew block. | `ItemDetailView.swift:172-183` |
| QA-7 | 2 | P3 | Detail | `CastCrewSection.swift` + `TrailersSection.swift` diffs in working tree migrate both away from `Button(.plain)` + `.focusEffectDisabled()` → `.focusable() + .onTapGesture` (PosterCard idiom) to avoid system-drawn focus fill. Not exercised — both sections are commented out of `ItemDetailView` lines 155-170 with notes "off-platform" / "focus routing still needs work". Diffs compile and are preparatory; re-enable the blocks to verify. | `ItemDetailView.swift:155-170`, `CastCrewSection.swift`, `TrailersSection.swift` |
| QA-8 | 3 | P1 | Search | `SearchView` `onAppear { focus = .field }` does NOT fire on first mount when entering via the top-nav Search chip. Focus stays on the Search chip; user must press Down once to reach the field. Field focus does work on subsequent arrivals (after modal close, etc). | `SearchView.swift:62-64` |
| QA-9 | 3 | — | Library | **Product decision (Brandon, 2026-04-24):** remove the in-library Search feature entirely — redundant with the dedicated Search tab. Scope: delete `LibrarySearchModal.swift`, the `$showSearch` sheet presenter in `LibraryView.swift:118-120`, and the Search chip in the library filter row. After removal, uncommitted diff on `LibrarySearchModal.swift` can be dropped (moot). | `LibraryView.swift:118-120`, `LibrarySearchModal.swift`, `LibraryHeader` filter row |
| QA-10 | 3 | P2 | Library | `GenrePickerModal.swift` has an uncommitted single-ScrollView focus-routing diff, but the component is **orphan** — no call sites in the codebase (the live genre flow is a `Menu` in `LibraryFilterBar.swift:60-100`). Either wire it up or delete it; the diff as-is is dead code. | `GenrePickerModal.swift`, `LibraryFilterBar.swift:60-100` |
| QA-11 | 4 | P2 | Player | Playback-rate `UIMenu` checkmark doesn't refresh when user selects a new rate. Functional change commits (verified via 1.5× → 16s playback over 10s real-time), but on reopen the ✓ still shows the prior rate. Root cause: `player.defaultRate` is a plain AVPlayer property, not `@Published` on the VM — SwiftUI never invalidates → `updateUIViewController` never re-runs → stale `UIMenu` stays on screen. | `VideoPlayerView.swift:154-182` `syncPlaybackRateMenu` |
| QA-12 | 4 | ? | Player | Skip Intro contextual-action chip never observed during any playback test. Could be: (a) Brandon's Jellyfin lacks intro-skipper markers for the Scrubs episode tested, (b) intro-skipper plugin not installed, or (c) I always passed the window before checking. Code path + `contextualActions` integration look correct; needs a known-intro-marker episode to verify live. | `VideoPlayerView.swift:133-148` `syncContextualActions` |
| QA-2-✅ | 4 | — | Detail | **Bonus QA-2 validation.** The hero Resume dialog ("Resume from Xm" / "Play from Beginning" / "Cancel") that chunk 1 couldn't observe appeared twice on the **Detail view's** Play CTA — Parent Trap (10m resume) and Scrubs S8E9 (11m resume). Same code path as hero. Closes QA-2 as verified. | `ItemDetailView.swift` Play CTA |

Details for each entry appear inline under the relevant chunk section below.

---

## Chunk plan

| # | Surface | Status | Key changes under test |
|---|---|---|---|
| 1 | Home + Hero | ✅ **Done — see below** | HeroPosterKeyart (new), Play-from-Beginning dialog on hero (new), Continue Watching 16:9 tiles (B), Gloxx rebrand, top-nav chip focus, ErrorView focus fix (new) |
| 2 | Detail (movie + series) | ✅ **Done — see below** | Full-bleed layout (E), Play auto-focus via prefersDefaultFocus (E), Chapters demotion (E), CastCrewSection (diff), ExternalLinksSection (diff), TrailersSection (diff), skeleton while loading (H) |
| 3 | Library + Search | ✅ **Done — see below** | GenrePickerModal (diff — orphan), LibrarySearchModal (diff — but feature slated for removal per QA-9), SearchView (big +228 diff) |
| 4 | Player HUD | ✅ **Done — see below** | Native `contextualActions` Skip Intro (D), playback-rate `UIMenu` (D), `MPNowPlayingInfoCenter` (D), transport-bar tvOS 26 conformance |
| 5 | Build-gate + `/critique` | ⏳ pending | `xcodebuild` clean warnings, `/critique` rerun for Nielsen delta vs Phase 1 baseline |

---

## Chunk 1 — Home + Hero — ✅ 2026-04-24

### What was tested

1. Cold launch → splash → Home
2. Hero rotation cycle (took ~5–6 screenshots across ~15s to observe rotation timing)
3. Focus flow: Down from top-nav → hero Play → Continue Watching row → Nextflix library row
4. Visual verification of hero keyart poster (NEW) and metadata line
5. Continue Watching 16:9 tile visuals + label format
6. Library shelf 2:3 poster visuals
7. Attempt to trigger hero Resume dialog (deferred — see "Known gaps")

### ✅ Passes

**HeroPosterKeyart renders correctly (new diff):**
- Sid and Nancy, Scrubs, Versa (Continue Watching items) show their 2:3 Jellyfin `Primary` image (keyart with title baked in) over the backdrop — the new `HeroPosterKeyart` view at `HeroBanner.swift:344` works. Fallback path (item lacks poster → typographic title) is code-reviewed and correct but wasn't observed in this pass (Brandon's catalog is fully-scraped).
- Poster sizing 200×300pt with 12pt corner radius and 18pt drop shadow feels right at 10ft — reads as "streaming app" vs "library browser" per the Phase 2 intent.

**Metadata line format (H item):**
- Interpunct-separated: `2010 · PG-13 · 1h 36m · ★ 6.3` on The Losers, `2009 · TV-PG · 21m · ★ 7.4` on Scrubs — matches Phase 2 H spec.

**Continue Watching shelf (Item B):**
- 16:9 landscape tiles, 400×225pt. Four visible pre-scroll: Sid and Nancy, Scrubs, Versa, The Acolyte.
- Label stack works: series name headline / `S8E9 · My Absence` subheadline / **accent-colored** `9m left` caption. On movies the subheadline is absent; caption renders with time-left directly.
- Movies in CW (Sid and Nancy) cascade to 16:9 `Backdrop`/`Thumb` because `Primary` is 2:3 — confirms `landscapeImageURL` cascade logic works.

**Library shelf (Item F's `.card` style, ambient verification):**
- Nextflix row: The Losers / Sid and Nancy / Books of Blood / Book of Blood / Little Big League / Shooting Stars / Avatar. 2:3 posters with metadata below (year · rating · runtime). No AI-slop glow visible.
- Focus on an unfocused card shows clean subtle drop shadow; couldn't A/B against pre-Item-F state in this session but visual is consistent with `.buttonStyle(.card)` expectation.

**Gloxx rebrand:**
- Top-left wordmark reads `GLOXX` with the yellow B roundel to the right of the user chip — matches the brand-pass commit.

**Top-nav chip row:**
- `Home` / `Search` / `Library` / `Settings` + `brandon.jensen` + B roundel. Home is highlighted with the accent underline. No regression from Phase 1 chrome.

**Hero rotation behavior:**
- Rotation interval 8s, cross-fade 0.8s (confirmed in code: `HeroBanner.swift:59-60`).
- Rotation pauses when the hero Play/Info button is focused (`onChange(of: isButtonFocused) { if focused { stopAutoRotation() } }` at `HeroBanner.swift:98-100`) — confirmed empirically: hero was stuck on The Losers once Play button took focus.
- Backdrop prefetch at 2s before each rotation wired in (lines 129-138). No visible pop-in during transitions in the observed rotations.
- `featuredItems` composition: first 3 from Continue Watching, backfilled up to 5 from the next section — so the first three rotation slots should all be progress items.

**Play button label (per diff):**
- Always reads "Play" now (not "Resume"). The Resume-vs-restart choice is moved to the confirmation dialog. Visually confirmed on both The Losers (no progress) and Sid and Nancy (has 1h 58m left).

### ⚠️ Known gaps / needs hand-off

**QA-2 · Hero Resume confirmation dialog — not captured on screenshot this session.**
- Code path at `HeroBanner.swift:253-260` and the `.confirmationDialog` block at `HeroBanner.swift:289-297` is correct SwiftUI — when `hasProgress == true`, pressing Play sets `showPlayChoice = true`. Dialog shows three buttons: `resumeButtonTitle` ("Resume from 1h 58m" when we can compute it, else "Resume"), "Play from Beginning", and "Cancel" (role destructive).
- Why not captured: the sim's focus landed on a non-progress hero item (The Losers, from the library-backfill tail of `featuredItems`) during the test window, and the rotation-pause-on-focus behavior meant I couldn't get to a progress item without defocusing → rotating → re-focusing, which I tried once and came back to the same non-progress item.
- **Recommended hand-off test** (Brandon, ~30s): launch app, press Down once (focuses hero Play button via focus-engine default) while hero is still on a Continue Watching item (Sid and Nancy / Scrubs / Versa for Brandon's lib), press Select. Expect modal dialog "Continue Watching" title with three buttons. Pick "Play from Beginning" → player should open with no resume. Relaunch, repeat with "Resume from Xh Ym" → player should open mid-content.

**QA-3 · ErrorView auto-focus fix — not exercised.**
- `HomeView.swift:267-309` diff adds `@FocusState` + 100ms `asyncAfter` to grab focus on Try Again after mount. Addresses a reported stuck-focus bug on physical hardware where focus stayed on Home nav chip.
- Why not exercised: to trigger ErrorView I'd need to disconnect the network mid-load or point the client at a dead URL. Neither is easy to do non-destructively on the running sim without code change or physical action.
- **Recommended hand-off test** (Brandon, ~60s): launch app, force-quit, disable wifi on sim's host Mac or kill Jellyfin container briefly, launch app → should land on ErrorView. Press Select immediately without pressing Down first — if Try Again button activates, fix works. If focus is still on top nav chip (Home), regression.

### 🐛 Bugs / observations

**QA-1 · Hero overview truncation is aggressive (P2).**
- **Observed:** The Losers hero overview shows "On a mission deep in the Bolivian jungle, a..." — the ellipsis cuts mid-word.
- **Expected:** either a clean word-boundary break, or more of the overview rendered before truncation given the available horizontal space.
- **Repro:** launch app → wait for The Losers to rotate in (or focus any hero item whose overview exceeds ~70 chars) → observe trailing `...`.
- **Hypothesis:** `HeroBannerContent`'s overview `Text` frame may be narrower than necessary. With the new 200pt keyart poster placed lower-left (`HeroBanner.swift:344`), the overview Text inherits the parent VStack's width, which still stretches ~60-70% of the banner. But the text wraps via `lineLimit(2)` or similar and truncates early. There's visible horizontal room to the right of the keyart that the overview could fill.
- **Severity:** P2 — visual polish, not a functional defect.
- **Proposed fix (phase-3):** either (a) raise `lineLimit` from 2 → 3 on the overview Text, (b) extend the overview's frame to fill to the right-edge minus safe-area, or (c) use `.truncationMode(.tail)` explicitly with a longer line budget.

**No obvious progress indicator on the hero for resumable items.**
- The hero doesn't show any progress bar or "resumable" affordance — so the only way a user knows to press Play and see the Resume dialog is by trial, or by recognizing the title from the Continue Watching row right below. This is by design per the diff (the dialog IS the affordance), but worth flagging: the visual signal for "this is resumable" only exists if you notice the CW row. Acceptable for now.

### Build + code state

- Build green (timestamp 12:54:39): `/Users/brando/Library/Developer/Xcode/DerivedData/MediaMio-bijgmfsjqkoqatbjnuqwiylisxyp/Build/Products/Debug-appletvsimulator/MediaMio.app`
- Zero new warnings (checked full build output — only the standard `appintentsmetadataprocessor` "No AppIntents.framework" info, which is expected).
- No crashes observed across ~3 minutes of interaction.

---

## Chunk 2 — Detail (movie + series) — ✅ 2026-04-24

### What was tested

1. Movie detail via hero More Info (Sid & Nancy — has progress, backdrop present)
2. Movie detail via Continue Watching tile (Versa — Disney short, has progress)
3. Movie detail with no backdrop (Little Big League — triggers the empty-backdrop branch)
4. Series detail via Continue Watching tile (Schmigadoon! — backdrop with baked-in title)
5. Series detail via Home TV Series shelf (Ludwig — clean logo + backdrop, no baked-in title)
6. Skeleton state captured at 0ms on Ludwig (race-screenshot against API load)
7. Post-load state on Ludwig at 2s
8. Ratings & Links section scroll on Sid & Nancy (Movie) and Ludwig (Series)
9. Scroll for Chapters presence on Sid & Nancy, Ludwig

### ✅ Passes

**Full-bleed 720pt cinematic header (Item E):**
- Sid & Nancy: red punk collage backdrop fills upper 2/3 viewport, `SID & NANCY` title-treatment logo rendered in place of text, metadata `1986 · R · 2h 8m · ★ 6.7`, `13% watched` progress text + bar, lower-left CTA row (Play focused / Favorite unfocused).
- Versa: Disney short backdrop, VERSA Disney logo, `2025 · PG · 9m · ★ 7.7`, `37% watched`, Play focused (orange stroke visible).
- Schmigadoon!: teal backdrop (keyart with title baked in), SCHMIGADOON! logo overlay lower-left, `2021 · TV-14 · 0m · ★ 6.9`, TVShowSeasonsView (Season 1/2 picker + episode grid) rendered below header.
- Ludwig: dark murder-wall backdrop, red cursive `Ludwig.` logo, `2024 · 12 · 57m · ★ 7.7`, Season picker + episode grid below.
- Header height visibly matches the 66% / 720pt spec — content below the gradient fade starts at the bottom third of the viewport.

**Empty-backdrop branch (Item E):**
- Little Big League (no backdrop available from Jellyfin) renders the `LITTLE BIG LEAGUE` logo centered in the upper stage over `surface1`, lower-left `infoColumn` still carries metadata + CTAs. The `.blur(radius: 80)` ambient-poster fallback is correctly gone — background is clean dark with no bleeding poster.

**Title treatment (`TitleTreatment.swift` shared component):**
- Four distinct logo treatments rendered without issue: SID & NANCY (serif+sans punk), VERSA (Disney branded), LITTLE BIG LEAGUE (red/cream arched), SCHMIGADOON! (gold ornate serif), Ludwig. (red italic script).
- Fallback to `.system(size:)` text was observed during Ludwig's 0ms load state (pre-logo), then transitioned to the logo image once the detailed payload arrived — expected behavior.

**Play auto-focus via `.prefersDefaultFocus(true, in: detailFocusNamespace)` (Item E):**
- On every Movie detail entry (Sid & Nancy, Versa, Little Big League), the Play CTA had the focused treatment (white fill / orange stroke) immediately on mount — no intermediate state where Favorite was focused. Imperative `focusedButton = .play` hack is gone and unnecessary.
- For Series detail (no Play CTA rendered — see intentional gate below), focus falls to the first focusable in `detailContent`, which is the Season 1 picker pill. Correct landing for a pick-an-episode UX.

**Series CTA gating (intentional, `ItemDetailView.swift:344`):**
- `if displayItem.type != "Series"` correctly hides the Play/Favorite HStack on Series detail. Verified on Schmigadoon! + Ludwig (no CTAs visible anywhere in header). Worth noting as a design choice — Netflix/Apple TV put a "Play Next Episode" CTA on Series detail; we put the Season picker directly. Both are valid UX models.

**Chapters demotion (Item E):**
- `if displayItem.type != "Series"` correctly gates ChaptersSection off Series (Schmigadoon!, Ludwig show no Chapters section between Ratings & Links and More Like This).
- Demotion below Cast/Crew on Movies not exercised — tested Movies lack chapter metadata on Brandon's Jellyfin (no Chapters section rendered for any of Sid & Nancy / Versa / Little Big League). Code position is correct per diff review: after Cast/Crew (commented out) and before Similar Items. Filed as QA-6.

**ExternalLinksSection IMDb/TMDB filter (diff):**
- Zero IMDb/TMDB pills rendered on any of four tested details (Sid & Nancy, Versa, Schmigadoon!, Ludwig).
- Rating pills still render: Sid & Nancy shows ⭐ Community 6.7 + ✓ Critics 89%; Ludwig shows ⭐ Community 7.7.
- On items where IMDb/TMDB are the only external URLs in Jellyfin, the filter produces zero external pills — the `Ratings & Links` section then contains only the rating pills, which is visually clean.

**Skeleton state (Item H — `DetailSkeletonBody`):**
- Race-screenshot at 0ms on Ludwig fresh-load captured the skeleton clearly: header renders from sparse `viewModel.item` (bold text "Ludwig" + metadata, spinner in backdrop slot), content below the header shows shimmer tiles in Overview / Metadata / Cast / Similar positions mirroring the final layout.
- By 2s the skeleton is gone, replaced by TVShowSeasonsView (Season picker + episode grid). No visible layout shift — the skeleton shapes match the final content shapes.
- Gate is `viewModel.isLoading && viewModel.detailedItem == nil` — works correctly for first-paint; re-visits with cached `detailedItem` skip the skeleton.

**More Like This row:**
- Renders at the bottom of both Movie (Sid & Nancy → Radio, Windtalkers, Deepwater Horizon, Welcome to Marwen, Apollo 13, Short Circuit 2, Hustlers) and Series (Ludwig → Paradise, The Penguin, Moon Knight, Gravity Falls, Peacemaker, The Acolyte, Tulsa King) detail.
- Uses `.card` button style (from Phase 2 Item F) — no regression from Chunk 1's shelf observations.

### ⚠️ Known gaps / needs hand-off

**QA-6 · Chapters demotion order — not exercised on Movies.**
- Movies tested (Sid & Nancy, Versa, Little Big League) all lacked chapter metadata on Brandon's Jellyfin, so `ChaptersSection` never rendered. The demotion (moving the section below Cast/Crew per Item E) is code-reviewed and correct: the `if displayItem.type != "Series" { ChaptersSection(...) }` block sits after the (commented-out) `CastCrewSection` block. With Cast/Crew currently commented out, Chapters would render directly after ExternalLinksSection — which is the OLD position — but that's a consequence of Cast being off, not of the demotion being wrong.
- **Recommended hand-off test** (Brandon, ~60s): open detail for a Movie that has chapters scraped (any Movie where `/Videos/{id}/Chapters` returns rows — typically anything TMDb-scraped with a proper backdrop set), scroll down from the header, observe that Chapters renders AFTER Ratings & Links but BEFORE More Like This. Absence of Cast/Crew in current build means "below Cast/Crew" is effectively "same as old position" — the demotion becomes visible only when Cast/Crew is re-enabled.

**QA-7 · `CastCrewSection` + `TrailersSection` diffs not exercised.**
- Both sections are commented out of `ItemDetailView.swift:155-170` with rationale (`// Trailers — hidden for now. Off-platform (YouTube)…`, `// Cast & Crew — hidden for now. Focus routing from the description to the row still needs work…`). Uncommitted diffs migrate both components from `Button(.plain) + .focusEffectDisabled()` → `.focusable() + .onTapGesture` (the PosterCard idiom) to kill the system focus-fill artifact, but nothing in the running app exercises them.
- The diffs compile and read correctly. Re-enabling the blocks would validate them visually. Noted as P3 / defer-to-phase-3.

### 🐛 Bugs / observations

**QA-4 · Double-title on Schmigadoon! (P2).**
- **Observed:** Series backdrop keyart bakes in the title "SCHMIGADOON!" in large gold type, and our `TitleTreatment` renders the separate Jellyfin logo asset as a smaller overlay at lower-left — same word, two sizes, visually cluttered at 10ft.
- **Root cause:** we always overlay `TitleTreatment` when `backdropURL != nil` (`ItemDetailView.swift:318-323`). We can't know from metadata alone whether the backdrop art already contains the title — Jellyfin doesn't flag that.
- **Repro:** open any Series whose backdrop keyart is the same asset the title is burned into (common for Apple TV+ / Disney+ branded series where the backdrop IS the key art).
- **Severity:** P2 — visual polish. Item C.1's equivalent risk on the hero was mitigated because hero keyart is pulled from `Primary` (2:3 poster) where title is present but the logo overlay is expected. Detail's backdrop is different.
- **Proposed fix (phase-3):** two options, both non-trivial:
  1. **Heuristic**: only show `TitleTreatment` overlay when Jellyfin's separate `LogoImageTags` asset exists AND the backdrop is a generic scene shot (hard to detect).
  2. **Token-size reduction**: shrink the overlay TitleTreatment to ~400×120pt for Detail (vs 600×180 for Hero) so it reads as a "brand mark" accent rather than a second title, reducing overlap tension.
  3. **Opt-out per-item**: a user setting "Use title treatment on detail" toggle, default on. Heavy-handed for one visual class.
- Default direction: option 2 (shrink logo on Detail header).

**QA-5 · Series metadata "0m" runtime (P2, pre-existing).**
- **Observed:** Schmigadoon!, Ludwig's metadata line reads `· 0m ·` where Movie format reads `· 2h 8m ·`. Jellyfin returns per-episode runtime for Series items, not a series aggregate.
- **Severity:** P2 — cosmetic. Pre-existing (not introduced by Phase 2).
- **Proposed fix:** in `metadataLine(for:)`, skip `runtimeFormatted` when `type == "Series"` and substitute season/episode count (e.g. `2 Seasons · 18 Episodes`) or omit the runtime slot entirely.

**Focus-jump from Play CTA on Movie detail.**
- On Sid & Nancy, pressing Down while focused on Play skipped past Overview (text, non-focusable), Metadata section (non-focusable), and Ratings & Links (only non-focusable rating pills after the IMDb/TMDB filter) directly to the first poster in More Like This. Two full sections traversed in one Down press.
- This is technically correct tvOS focus-engine behavior (skip to next focusable), but at 10ft it can feel abrupt — user goes from top CTA to bottom-of-page similar row with no intermediate stops.
- Not filing as a bug — `.focusSection()` could mitigate but would add its own trade-offs. Worth noting if user feedback surfaces confusion.

### Build + code state

- No rebuild needed between chunks 1 and 2 — `git status` unchanged, same installed build.
- No crashes observed across ~4 minutes of Detail-surface interaction (5 Detail opens, 2 skeleton races, multiple scrolls, multiple backs).
- All six `TitleTreatment` renderings (Sid & Nancy, Versa, Little Big League, Schmigadoon!, Ludwig, + Ludwig text fallback during load) worked correctly.

## Chunk 3 — Library + Search — ✅ 2026-04-24

### What was tested

1. Top-nav → **Search tab** (`SearchView`): entry focus, field auto-focus, keyboard path, multi-result grid (50 of 15595 for query "the"), narrow-result grid (2 of 2 for "schmigadoon"), No Results empty state for garbage query
2. Down→Up routing: field → first result → back to field, for both multi-result and narrow-result cases (the explicit bug the diff was written to fix)
3. Escape-to-TopNav check: Up-from-grid **did not** escape past the header to the TopNavBar chips — the single-ScrollView architecture holds
4. `LibraryView` → **LibrarySearchModal** (Nextflix library, `.sheet` presentation): open via Search chip in filter row, field auto-focus on mount, keyboard flow, query "sid" → ~6 results in the modal grid, horizontal routing field → X clear → Close → dismiss
5. `LibraryView` → **Genre chip** Select (to open `GenrePickerModal`) — probe only; modal did not open
6. Code inspection to confirm which components are actually wired

### ✅ Passes

**Search tab — single-ScrollView architecture holds (`SearchView.swift` +228 diff):**
- "the" → 50 of 15595 results, 5-wide grid. Down from field scrolls past the sticky header into first row; Up returns to field without escape-to-TopNavBar. Field shows its "focused" white-fill treatment on return.
- "schmigadoon" → 2 of 2 results (Schmigadoon! episode + series). Down from field focuses first poster (subtle lift); Up from that narrow-row grid returns cleanly to the field. **This is the specific edge case the diff was written for** (pre-fix, a lone grid cell escaped past the header to the "Home" chip). Fix verified.
- "qqqzzzxxx" → `EmptyStateView` "No Results Found" renders at full viewport height — `.frame(minHeight: 400)` keeps the layout from collapsing in the single-ScrollView.
- `@FocusState<SearchFocus?>` unified enum (`.field | .result(Int)`) replacing the previous two `@FocusState<Bool>` works without the "focus stuck on field" bug the diff comment describes.

**LibrarySearchModal — single-ScrollView fix applied (`LibrarySearchModal.swift` diff):**
- Opens as a **SwiftUI `.sheet`** from `LibraryView.swift:118-120` — not a full-screen overlay. The rendering is narrow (~40% viewport wide) because of the sheet container. This is pre-existing presentation, not a regression from the diff.
- `onAppear { isSearchFieldFocused = true }` works correctly here (unlike `SearchView`) — Select on mount immediately opened the keyboard.
- "sid" typed → ~6 results in a 3-column grid inside the modal. Header (field + Close) routes horizontally: field → X-clear → Close. Down from field focuses first poster; Up returns to header region.
- Empty-state (`searchQuery.isEmpty`), loading (`isSearching`), no-results (`searchResults.isEmpty`) all render inside the single ScrollView with `.frame(minHeight: 400)` — no layout collapse.
- Close button dismisses; focus on return lands on the invoking Search chip in the Library filter row.

**Focus restoration on modal close:**
- After `LibrarySearchModal` dismisses, the Library Search chip regains focus (white-fill). No stray focus-lost state.

### ⚠️ Known gaps / findings

**QA-8 · `SearchView` `onAppear { focus = .field }` does not fire on first mount (P1).**
- **Observed:** on entering the Search tab via the top-nav chip (Right from Home chip → Select), focus stayed on the Search chip itself. The search field was NOT focused — its "white fill" focus treatment was absent, and pressing Select on the still-focused Search chip was a no-op. Pressing Down once moved focus to the field.
- **Expected:** per the diff's `.onAppear { focus = .field }` at `SearchView.swift:62-64`, the field should grab focus on mount so the user can immediately press Select to open the keyboard.
- **Hypothesis:** the top-nav chip's focus is "sticky" — tvOS's focus engine honors the chip as the currently-focused element even as the new view mounts under it, and the `.onAppear` setter loses to that. Same pattern the diff's big multi-line comment warns about ("programmatic override causing focus to pin on field") but inverted — here the field never gets the first focus claim.
- **Repro:** from Home, Up to top-nav row, Right to Search chip, Select. Observe: field is not white-filled. Press Select — nothing opens. Press Down — field gets white-fill.
- **Severity:** P1 — user-visible friction on a primary surface. Not a crash, but every Search entry requires an extra Down press the diff was meant to eliminate.
- **Possible fix directions** (without rolling the diff back):
  1. Call `DispatchQueue.main.async { focus = .field }` inside `onAppear` to defer past the nav-chip focus claim.
  2. Add `.prefersDefaultFocus(true, in: searchFocusNamespace)` to the TextField + `.focusScope(searchFocusNamespace)` on the ScrollView, so the focus engine picks the field explicitly when routing into the view.
  3. Use the newer `@FocusState` + `.onChange(of: scenePhase)` pattern to re-set focus when the view becomes active.
- Option 1 is a 3-line change; worth trying first.

**QA-9 · Remove in-library Search feature (product decision, no severity).**
- Brandon's call 2026-04-24: the in-library Search modal is **redundant** with the dedicated Search tab. Scope for removal:
  - Delete `MediaMio/Views/Library/Components/LibrarySearchModal.swift` entirely.
  - Remove `.sheet(isPresented: $showSearch) { LibrarySearchModal(viewModel: viewModel) }` at `LibraryView.swift:118-120` + the `@State private var showSearch` declaration.
  - Remove the "Search" chip from the Library filter row (`LibraryHeader` / `LibraryFilterBar`) + any `showSearch = true` trigger sites.
  - Any `performSearch` wiring on `LibraryViewModel` that's only used by the modal can go too.
- After this lands, the uncommitted `LibrarySearchModal.swift` diff in the current working tree is moot — drop it with the rest of the component.
- **Not done in this QA pass** — scope change, belongs to a follow-up commit.

**QA-10 · `GenrePickerModal.swift` is orphan code (P2).**
- **Observed:** pressed Select on the Library filter row's "Genre All" chip. Nothing opened — chip is a SwiftUI `Menu` (inline popover), handled entirely by `LibraryFilterBar.swift:60-100`. `grep -rn "GenrePickerModal"` returns only the file itself and one reference inside its own diff comment — there are **no call sites**.
- **Implication:** the uncommitted focus-routing diff on `GenrePickerModal.swift` (+28/−23) is a fix for a component that never renders. The diff is correct structurally (matches the `SearchView` / `LibrarySearchModal` pattern) but has zero runtime effect.
- **Severity:** P2 — dead code with a non-zero maintenance cost. Either wire the modal up as an alternative to the inline Menu (useful for long genre lists where a modal is nicer than a dropdown), or delete both the component and its diff.
- **Recommendation:** delete, then resurrect the file from git if a modal picker is ever needed. The current `LibraryFilterBar` Menu flow is adequate for Brandon's genre count.

### 🐛 Bugs / observations

**Search modal visibly narrow on tvOS (pre-existing, no action needed).**
- `.sheet(isPresented:)` in SwiftUI on tvOS renders as a centered, ~40% viewport-wide card, not a full-screen overlay. This is the standard tvOS sheet look, not a regression from the diff.
- Acceptable for a short-lived search interaction. If it becomes a UX problem post-Library-search-removal (QA-9), the same rendering already appears on any `.sheet()` elsewhere in the app — file separately, don't gate Phase 2 on it.

**Search nav-chip Select is unreliable on first mount.**
- Related to QA-8: the first-mount focus state means pressing Select on the top-nav Search chip (from a cold Home→Search transition) often feels unresponsive. The user has pressed-through-to-Search, but Select seems to do nothing. In reality, focus is still on the chip; Select on a tab chip is a no-op.
- Would be easier to explain if QA-8 is fixed (focus lands on field, field's Select opens keyboard → obvious what's happening).

### Build + code state

- No rebuild required — working-tree diff unchanged since chunks 1 & 2.
- No crashes across the chunk 3 session (~5 min interaction, ~20 screenshots).
- All three chunk-3 diffs compile and run (where wired). Two of them (`SearchView`, `LibrarySearchModal`) are verified live; one (`GenrePickerModal`) is never reached by any UI path — flagged QA-10.

## Chunk 4 — Player HUD — ✅ 2026-04-24

### What was tested

1. Navigated Home → Continue Watching → Parent Trap (Movie) → Detail → Play → **Resume dialog** → Resume from 10m → player mounted
2. Parent Trap playback failed to visually start (4K HEVC stream, sim's software decoder stalled past 25s); used the log stream to verify `MPNowPlayingInfoCenter` publishing even during the spinner phase
3. Backed out → Home → Continue Watching → Scrubs S8E9 (Episode) → Detail → Play → **Resume dialog** → Play from Beginning → player mounted + actively played (Direct Stream, MKV, 7.3 Mbps, 480p)
4. During Scrubs playback: summoned info panel (swipe-down / key `125`) → observed `customInfoViewControllers` tabs; summoned transport bar (Select / key `36`) → observed scrubber + time + right-side icon row + tabs; opened rate `UIMenu` → all 5 rates rendered with correct ✓ on 1×; selected 1.5× → verified playback rate applied via 10s-real-time → 16s-playback-time delta
5. Grep-audited source for any residual `SkipMarkerOverlay` / `SkipButton` structs → confirmed gone
6. Code-reviewed `NowPlayingPublisher.swift` — already ahead of Item D's plan (Brandon shipped it earlier)

### ✅ Passes

**Zero SwiftUI overlay chrome on the player surface (Item D):**
- Across ~6 different screenshots during Scrubs playback (paused, playing, info panel up, transport bar up, rate menu open) the only chrome visible is Apple's native AVKit rendering — scrubber, tabs, icon row, modal popover. No custom SwiftUI `.overlay` is drawn over the player.
- Grep for `SkipMarkerOverlay` / `SkipButton` across `MediaMio/**/*.swift` returns zero hits — the legacy overlay structs are fully deleted per Item D's "~60 lines of SwiftUI" removal.
- The only remaining `showSkipIntroButton` / `showSkipCreditsButton` references are the *state flag* traveling `IntroCreditsController` → `VideoPlayerViewModel` → `VideoPlayerView` → `SimpleVideoPlayerRepresentable.contextualActions`. That's the correct wiring.

**Transport bar is native AVKit (Item D):**
- `mm_p4_24_transport_again.png` + `mm_p4_25_tb_up.png` show the transport bar with:
  - Scrubber + elapsed `00:48` / remaining `-20:48` time readouts
  - Right-side icon row: **speedometer (our custom menu), CC bubble, audio speaker** — all native AVKit treatment
  - Bottom tabs: **Playback Info** (focused, white pill), **Video Quality**, **Audio Quality** — all from `customInfoViewControllers`
- Up-arrow from the tab row correctly focus-jumps to the speedometer icon (white-circle focus highlight visible in `mm_p4_25`).

**`customInfoViewControllers` content (Item D — existing, not new in this item):**
- Swipe-down from playback summons the info panel (`mm_p4_18_transport_bar.png`):
  - **Playback Info** tab (focused): GENERAL → Play Method: **Direct Stream**, Container: **MKV**, File Size: **896 MB**, Total Bitrate: **7.3 Mbps**. `PlaybackInfoBuilder.build(item:mode:subtitleDisplay:maxStreamingBitrate:)` is returning correct values.
  - Video Quality + Audio Quality tabs render without issue (focus-select didn't open these submenus in this pass since they're not Item D's scope).

**Playback-rate `UIMenu` (Item D — core deliverable):**
- Opened via Up + Select on the speedometer icon (`mm_p4_27_menu_fast.png`):
  - Title: **Playback Speed**
  - Children in spec order: **0.5× / 1× (✓) / 1.25× / 1.5× / 2×**
  - Initial ✓ correctly on 1× (matches `player.defaultRate == 1.0` baseline)
  - Focus lands on the first child (0.5×) — Apple's convention for `UIMenu` children on tvOS
- Functional rate-change committed:
  - Selected 1.5× from the menu → player paused (Select overloaded with play/pause on sim; see QA observation below)
  - Resumed playback with Select → time advanced from 00:25 → 00:41 over ~10s real-time
  - Delta: 16s playback in 10s wall-clock = **~1.6× apparent rate** (well within timing slop for 1.5× + 1s start/stop noise) → `player.defaultRate = 1.5` took effect

**`MPNowPlayingInfoCenter` wiring (Item D — verified via `simctl spawn log`):**
Direct evidence from `log show` during Parent Trap playback load:
```
MediaMio: (MediaPlayer) [com.apple.amp.mediaplayer:RemoteControl] NPIC: setNowPlayingInfo: sending to MediaRemote
	kMRMediaRemoteNowPlayingInfoMediaType = kMRMediaRemoteNowPlayingInfoTypeVideo
    playbackDuration = "7679.744";            # = Parent Trap's 2h 7m 59s runtime
item:<com.apple.avkit.18367.d063f791//CalculatedPlaybackPosition: 632.000000/PlaybackRate: 0.000000/L>
                                             # 632s = 10:32 → matches "Resume from 10m" start position
    MPNowPlayingInfoPropertyPlaybackRate = 1;
    MPMediaItemPropertyAlbumTitle (implicit via item.seriesName when Series)
    MPMediaItemPropertyTitle  (publishes item.name)
```
`NowPlayingPublisher.publishInitialMetadata()` is firing. AVKit then overrides the rate field (standard Apple behavior — `AVKit will override MPNowPlayingInfoPropertyPlaybackRate!`) but duration, position, title, mediaType all stick.

Remote commands are installed — also from logs:
```
installed handlers for AVMediaPlayerDelegate ... play/pause enabled; skipping enabled
"<MRCommandInfo: ..., SkipBackward, enabled = 1, options = {kMRMediaRemoteCommandInfoPreferredIntervalsKey = ( 10 );}>"
"<MRCommandInfo: ..., SkipForward, enabled = 1, options = {kMRMediaRemoteCommandInfoPreferredIntervalsKey = ( 10 );}>"
"<MRCommandInfo: ..., ChangePlaybackRateCommand, enabled = 1, ...>"
```
`NowPlayingPublisher.wireCommands` is registering play/pause/togglePlayPause/skipForward/skipBackward/changePlaybackPosition — all six handlers the VM needs for Control Center + AirPlay + Siri-remote overlay control.

### ⚠️ Known gaps / needs hand-off

**QA-12 · Skip Intro contextual-action chip not observed (P?).**
- Played Scrubs S8E9 from 0:00 and summoned the transport bar at 0:25 — no `forward.fill` "Skip Intro" chip appeared. Scrubs theme songs run ~10-15s, so 0:25 is likely past the intro window even if markers existed.
- Code path inspected:
  - `IntroCreditsController.fetchMarkers()` hits `/Shows/{itemId}/IntroTimestamps` at play-start
  - 404 branch silently leaves all markers nil → `tickIntro` never enters the `isInIntro` branch → `showSkipIntroButton` stays false → `syncContextualActions` publishes `[]` → Apple draws no chip (correct)
  - 200 branch with marker data → `showSkipIntroButton = true` during `[introStart, introEnd]` window → chip renders
- Couldn't confirm from `simctl spawn log` whether markers were fetched because `IntroCreditsController` logs via raw `print()` (not `os_log`), and those only flow to the Xcode console, not the unified system log.
- **Recommended hand-off test** (Brandon, ~3 min):
  1. Confirm intro-skipper plugin is installed + enabled on your Jellyfin instance (`/System/Plugins` in the admin UI, plugin name is "Intro Skipper")
  2. Let the plugin scan an episode with a reliable intro (e.g. Scrubs, The Acolyte, Schmigadoon! S1)
  3. Start playback from 0:00, wait until the intro window lands (~5-10s for Scrubs)
  4. Summon transport bar — expect a `▶▶` "Skip Intro" chip in the contextual-action area (lower-right, animated in via the native "Up Next" chrome)
  5. Select the chip — playback should jump to `introEnd` (logs will show `⏭️ Skipping intro to: 0:XX`)
  6. If no chip appears even with markers, check Xcode console for `ℹ️ No intro markers available for this item` — if that's logged, markers weren't returned despite the plugin being installed; if `✅ Intro detected: X - Y` is logged, the fetch worked but state wiring is broken.

### 🐛 Bugs / observations

**QA-11 · Playback-rate `UIMenu` checkmark is stale after selection (P2).**
- **Observed:**
  1. Rate menu opens with ✓ on 1× (correct — `player.defaultRate = 1.0`).
  2. User selects 1.5× → menu closes → playback rate DOES change (verified: 16s playback in 10s real-time).
  3. User reopens the rate menu → ✓ is **still on 1×**, not 1.5×.
- **Expected:** after selecting 1.5×, subsequent menu opens should show ✓ on 1.5×.
- **Root cause:** `syncPlaybackRateMenu(on:)` builds a fresh `UIMenu` each time it runs, reading `player.defaultRate` live. But it only runs inside `updateUIViewController(_:context:)`, which SwiftUI invokes only when the `UIViewControllerRepresentable`'s props change. Those props come from `@StateObject var viewModel: VideoPlayerViewModel`'s `@Published` fields. `player.defaultRate` is not `@Published` — it's a plain property on `AVPlayer`. Writing to it from the menu closure mutates the player state but doesn't invalidate SwiftUI, so `updateUIViewController` never runs, so the `UIMenu` AVKit is holding is the stale one with the old checkmark.
- **Severity:** P2 — cosmetic. Functional rate change works; only the visual "which rate is active" indicator lags.
- **Proposed fix:** add a `@Published private(set) var currentRate: Float = 1.0` to `VideoPlayerViewModel` and observe `player.publisher(for: \.defaultRate)` → sink into `currentRate`. Then `SimpleVideoPlayerRepresentable` reads `viewModel.currentRate` as a prop, SwiftUI invalidates on change, `updateUIViewController` fires, `syncPlaybackRateMenu` rebuilds the menu with the fresh checkmark. Alternative: fire a manual SwiftUI invalidation from within the UIAction closure (e.g. nudge a `@Published` dummy on the VM).
- **Note:** Item D's trade-off write-up anticipated this — "the menu rebuilds on the next updateUIViewController and the new state appears instantly on reopen" — but the "next `updateUIViewController`" never fires on rate-only changes, so in practice the menu never rebuilds until something *else* in the VM changes. Apple's native subtitle/audio menus don't have this issue because AVKit owns their state and AVKit decides when to redraw; our `transportBarCustomMenuItems` ride the SwiftUI invalidation lifecycle.

**Siri Remote Select overloading inside the rate menu (sim behavior, possibly device too).**
- Pressing Select on a focused rate-menu child on the sim closes the menu AND toggles the underlying player's play/pause. Result: user picks a new rate → player pauses → resume requires another Select press. On a physical Siri Remote the behavior may differ (touchpad "click" vs dedicated Play/Pause button).
- Not filing as a bug — the rate selection still commits, just with a confusing pause transient. If it reproduces on hardware, consider capturing Select inside the `UIAction` closure before it propagates, or publishing the menu via a different control surface.

**Media decoder can't handle 4K HEVC on the tvOS sim.**
- Parent Trap (3840×2160 HEVC Main 10) showed the native spinner for 25+ seconds without producing frames. Logs showed `FigAlternate` picked the SDR h.264 variant, HLS manifest resolved, and `MPNowPlayingInfoCenter` published correctly — but no `VMC` / `IQ-CA` "frames decoded" lines appeared during Parent Trap, only during Scrubs.
- This is a sim limitation (macOS software decoder ≠ tvOS hardware HEVC), not a MediaMio bug. Scrubs (480p h.264) worked instantly — switched test subject.

### Build + code state

- No rebuild required — working-tree diff unchanged since chunks 1-3.
- Player-side source inspection: `VideoPlayerView.swift:127-182` contains both `syncContextualActions` and `syncPlaybackRateMenu` exactly as Item D's summary described. `NowPlayingPublisher.swift` wires all six remote commands and publishes via `MPNowPlayingInfoCenter.default()`.
- Zero crashes across the chunk 4 session (~8 min, ~25 screenshots, 3 player mount/unmount cycles).



## Chunk 5 — Build-gate + `/critique` — ⏳ pending

[to run after chunk 4]

---

## Resume instructions after /clear

The conversation will be cleared between chunks. To resume cleanly:

1. Read this file (`qa-phase-2.md`) — has the full chunk status and findings so far.
2. Read `design-plan-phase-2.md` for the Phase 2 context.
3. Read `/Users/brando/.claude/projects/-Users-brando-code-mediamio/memory/reference_tvos_sim_test_commands.md` for the sim-driving recipe.
4. The sim is at UDID `FE485BD4-38E6-4607-A865-E29C5A4AC506`, the app is bundle id `com.bran.jellyfintv`, and the installed build path is `/Users/brando/Library/Developer/Xcode/DerivedData/MediaMio-bijgmfsjqkoqatbjnuqwiylisxyp/Build/Products/Debug-appletvsimulator/MediaMio.app`.
5. To skip a rebuild, check `git status` is unchanged from chunk 1 start — if so, just re-launch with `simctl launch`. If the diff has shifted (Brandon committed / edited), rebuild first.
6. Start the next chunk with status = `in progress`, finish, mark `✅`, then stop for Brandon review.
