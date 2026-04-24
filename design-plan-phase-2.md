# MediaMio Design Plan — Phase 2: Streaming Flow Repair

**Started:** 2026-04-23
**Status:** Items A + B + C.1 + D shipped 2026-04-23. Item C.2 (actual trailer playback) deferred — blocked on YouTube URL resolution / Jellyfin local-trailers integration. Items E–H pending.
**Scope:** tvOS streaming-app conventions, focus-engine correctness, real perf bugs, and the three "judge moments" (hero, shelf, detail → player). Picks up where `design-plan.md` left off after 7 chrome/palette items shipped 2026-04-22 / 2026-04-23.

**Explicitly NOT in scope:** business logic, API client, authentication flow, settings business wiring, transcode policy (already fixed in `fix-unnecessary-transcode.md`).

---

## Why a phase 2

Phase 1 (the 7 items) was a **chrome & palette refresh**: tokens, focus tiers, nav shell, surface ramp. It did not touch:

1. **Streaming vocabulary** — poster aspect ratios per shelf, hero auto-trailer, Continue Watching as episodes not movie posters, title-treatment logos on hero.
2. **Player HUD conventions** — `contextualActions`, `transportBarCustomMenuItems`, `MPNowPlayingInfoCenter`.
3. **Focus-engine correctness** — `.focusSection()` wrappers, `prefersDefaultFocus` on entry, zoom transition from poster → detail.
4. **Real perf bombs** — `.blur(radius: 80)` on full-screen detail header, production `print()` on every `HeroBanner` render, all four tabs mounted simultaneously.

Phase 2 is everything a tvOS user *feels* but that chrome-level work can't reach.

---

## Ground truth — things wrong right now

### Real bugs visible in the diff

1. **`HeroBanner.hasProgress` spams `print()` every render** — `HeroBanner.swift:281` and `:287`. Three lines per rotation, every 8s, forever. Hide behind `#if DEBUG` or a `DebugLog` helper.
2. **`EpisodeCard` still has the `.white.opacity(0.3)` AI glow** — `ItemDetailView.swift:706-708`. Phase-1 item 3 claimed to kill every instance; this one was missed. Migrate to `.contentFocus(isFocused:)`.
3. **`DetailHeaderView` uses `.blur(radius: 80)` full-screen fallback** — `ItemDetailView.swift:201`. This is a frame killer on Apple TV HD (A8). Replace with a solid `surface1` + gradient, or use `MetalPetal` / a pre-blurred cached variant if the mood is critical.
4. **`.onTapGesture` on `PosterCard` instead of a `Button`** — `PosterCard.swift:97`. Loses the free tvOS `.card` parallax + specular glare. The single biggest AI-slop tell left in the app.
5. **`SkipButton` is a SwiftUI overlay instead of `AVPlayerViewController.contextualActions`** — `VideoPlayerView.swift:201-261`. Apple expects the tvOS-15+ contextual action contract for Skip Intro. Custom overlays live above native scrubbing UI and fight focus when the transport bar is up.
6. **`MPNowPlayingInfoCenter` is not populated** — searched entire project. System TV app's Continue Watching row has nothing to show.
7. **Four tabs mounted simultaneously** — `MainTabView` keeps Home/Search/Library/Settings alive via `.opacity(0).disabled(true)`. Fine on A12+, painful on A8. Downgrade to eager-mount for the *current* tab only on Apple TV HD, keep full eager-mount on 4K.
8. **`Color.black` + `Color.black.opacity(0.8)` gradient stops on hero** — `HeroBanner.swift:188-197`. The pure-black bottom stop produces a hard line against `Constants.Colors.background` (`#0d0f15`). Blend to `background` not to pure black.

### Streaming vocabulary misses

9. **All shelves use 2:3 `PosterCard`, including Continue Watching** — `ContentRow.swift:73`. Streaming convention is 16:9 landscape for resume/episode thumbs; 2:3 is reserved for movie/show keyart shelves.
10. **No title-treatment logo on hero** — `HeroBanner.swift:205` renders the title as `.system(size: 60)` text. Jellyfin returns a `logo` ImageTag for most items; using it is the difference between "streaming app" and "library browser."
11. **No auto-trailer on hero focus dwell** — the convention across Netflix, Apple TV+, Disney+ is "mute trailer starts after 2s dwell." Currently the hero is a static backdrop only.
12. **No long-press context menu on posters** — convention: "Mark as watched", "Add to favorites", "Go to series", "Remove from Continue Watching". Missing everywhere.
13. **No hero → detail zoom transition** — tvOS 18+ `matchedTransitionSource` + `.navigationTransition(.zoom(sourceID:in:))` is the modern idiom. Current push is a crossfade (acceptable) but the zoom is a free upgrade.

### Focus-engine gaps

14. **No `.focusSection()` around the shelves block** — horizontal swipe from hero CTA into the first row may skip to a distant row on wide layouts.
15. **No `prefersDefaultFocus(_:in:)` on Home** — relies on the focus engine's default heuristic (usually the hero) but not guaranteed.
16. **`HomeContentView.focusedField: String?`** is declared but only used for one-shot assignments — no `.onChange(of:)` restoration when tab switches back.

### Detail view pattern inconsistency

17. **Hybrid layout**: `DetailHeaderView` uses a "poster on the left, metadata on the right" compositio with a 900pt header. That's a *library* pattern (Stremio / Jellyfin Web). Streaming convention (Netflix / Apple TV / Disney+) is full-bleed backdrop + title treatment + CTAs stacked lower-left inside safe area, *below* the backdrop. Pick one.
18. **Chapters section on non-Series items** — `ItemDetailView.swift:60-66`. On most movies this prints a long thumbnail strip that steals focus from Play. Move under a "More" disclosure or demote below cast/crew.

---

## Item A — Production log hygiene + focus bugs (P0 — ship first, smallest)

**Why first:** bugs with zero visual design decision attached. No tone, no tokens, just corrections.

**What:**
- Extract a `DebugLog.swift` helper: `DebugLog.verbose(_:)` / `DebugLog.playback(_:)` / `DebugLog.focus(_:)`, each a `@inlinable` no-op in release builds.
- Replace every raw `print(` in `HeroBanner.swift`, `VideoPlayerView.swift`, `ItemDetailView.swift`, `HomeViewModel.swift` with the appropriate channel.
- Migrate `EpisodeCard` (`ItemDetailView.swift:705-710`) to `.contentFocus(isFocused:)` and delete the `.white.opacity(0.3)` shadow.
- Add `.focusSection()` around the shelves `VStack` in `HomeContentView.swift:203-221`.
- Wrap the `HStack` of `DetailActionButton`s in `ItemDetailView.swift:281-303` in `.focusSection()`.
- Replace `Color.black` gradient terminal stop in `HeroBanner.swift:193` with `Constants.Colors.background`.
- Drop `.blur(radius: 80)` poster fallback in `DetailHeaderView.backdropLayer` → substitute `Constants.Colors.surface1` + existing gradient.

**Files touched:**
- `MediaMio/Utilities/DebugLog.swift` (new)
- `MediaMio/Views/Components/HeroBanner.swift`
- `MediaMio/Views/Detail/ItemDetailView.swift`
- `MediaMio/Views/Player/VideoPlayerView.swift`
- `MediaMio/ViewModels/HomeViewModel.swift`
- `MediaMio/Views/Home/HomeView.swift`

**Risk:** low — all reversible, zero visual-decision surface.
**Build gate:** `xcodebuild -destination 'platform=tvOS Simulator,OS=26.0,name=Apple TV'` green, no new warnings.

---

## Item B — Continue Watching becomes 16:9 episode thumbs (P1) — SHIPPED 2026-04-23

### What landed

- `MediaItem` gained two helpers:
  - `landscapeImageURL(baseURL:maxWidth:quality:)` — picks the right 16:9 source per Jellyfin semantics: for Episodes, `Primary` IS the 16:9 still; for Movies/Series, prefers `Thumb` → `Backdrop`, falling back to `Primary` (2:3) only when nothing landscape is available.
  - `remainingText` — `"23m left"` / `"1h 5m left"`, nil when progress is missing or within 1 minute of the end.
- New `MediaMio/Views/Components/EpisodeThumbCard.swift`:
  - 400×225pt landscape still with a 48pt bottom-gradient scrim and a 4pt `ProgressBar` flush to the bottom edge (reused from PosterCard).
  - Three-line label stack: series name (headline semibold), `S1E1 · Lost / Found` (subheadline white-0.65), `29m left` (caption, `Constants.Colors.accent`).
  - Focus model intentionally mirrors PosterCard: `.focusable() + .onTapGesture` + `.contentFocus(isFocused:)`. The first build tried `Button(.plain)` but tvOS's `PlainButtonStyle` applied its own white-surface focus highlight *on top of* our content-focus tier — two treatments layered. Reverted to the PosterCard idiom; Item F will revisit both with `.buttonStyle(.card)`.
- `ContentRow` now branches on `section.type`:
  - `.continueWatching` → `EpisodeThumbCard` with row frame `thumbHeight + 180pt`
  - everything else → `PosterCard` with row frame `posterHeight + 180pt`
  - All other behavior (focus memory, navigation/focus manager updates, see-all) unchanged.
- Build green `tvOS Simulator,OS=26.0,name=Apple TV`. Verified on sim — Continue Watching shows 16:9 tiles (Versa / The Acolyte / Parent Trap / Merry Little Ex-Mas) with accent-colored "m left" labels; Nextflix row below still renders 2:3 posters.

### Known trade-offs carried into Item F

- Focus model is the same `.focusable() + .onTapGesture` pattern PosterCard uses — works, but foregoes tvOS's free card parallax + specular shine. Item F's whole purpose is to move both cards onto `Button(_) { ... }.buttonStyle(.card)` and reconcile the focus tiers; do not re-litigate here.
- Recently Added stays on `PosterCard` for every item regardless of type. The plan floated per-item branching (`PosterCard` for movies, `EpisodeThumbCard` for episodes inside the same row) — skipped because mixed-height rows break `LazyHStack` layout stability and the shelf is healthier as one consistent 2:3 discovery rail anyway.

---

## Item B — original plan (historical)

**Why:** biggest "didn't test on Apple TV" tell. Anyone who has used Apple TV once immediately sees the mismatch.

**What:**
- New `MediaMio/Views/Components/EpisodeThumbCard.swift` — 16:9 thumbnail, 400×225pt, 4pt progress bar across the bottom (red accent or `Constants.Colors.accent`), `S2 E4 · 23m left` overlay in caption type.
- `ContentRow.swift` branches on `section.type`:
  - `.resume` → `EpisodeThumbCard`
  - `.latest` (Recently Added) → stays on `PosterCard` (2:3) for movies, `EpisodeThumbCard` for shows/episodes.
  - `.library` → `PosterCard`.
- Progress-bar layout moves from `PosterCard:42-47` to `EpisodeThumbCard`. `PosterCard` keeps the progress bar only if the underlying item is a movie with progress (rare but possible).

**Risk:** medium — touches the core row rendering logic.
**Acceptance:** Home shelf ordering unchanged; Continue Watching row is visibly wider per tile and 50% shorter; Recently Added retains tall posters.

---

## Item C.1 — Hero title treatment + vignette + settings scaffold — SHIPPED 2026-04-23

### What landed

- `MediaItem` + `JellyfinAPIClient` co-evolved so the server actually sends us logo data:
  - Added `parentLogoItemId` / `parentLogoImageTag` to `MediaItem` — for Episodes, Jellyfin puts the logo on the parent series, not the episode itself. Without these two fields, every episode featured in the hero falls back to text.
  - Four API endpoints (`getContinueWatching`, `getRecentlyAdded`, `getLibraryItems`, plus the search variant at 511) had `EnableImageTypes=Primary,Backdrop,Thumb` — explicitly excluding Logo. Added Logo to all four.
  - New `MediaItem.logoImageURL(baseURL:maxWidth:quality:)` tries direct logo first, falls back to parent-logo URL for episodes.
  - Updated the 6 `MediaItem(...)` preview callsites with the two new nil fields.
- New private `HeroTitle` view inside `HeroBanner.swift`:
  - Uses a private `ImageLoader` directly (not `AsyncImageView`) so the failure case is a silent fall-through to typographic text, not a "Failed to load" placeholder card.
  - Renders the logo `contentMode: .fit` within a 600×180pt box so wordmarks stay readable and square logos don't letterbox.
  - Shadow `.black.opacity(0.5)` radius 12pt y=4 for legibility against any backdrop.
  - Preserves the previous `.system(size: 60, weight: .bold)` Text as the fallback — zero regression when no logo exists.
- `HeroBannerContent` backdrop composition:
  - Added a centered `RadialGradient` vignette (clear → `.black.opacity(0.35)` at 60% of screen width) layered between the linear gradient and the content overlay. Corner dim, center clear, `.allowsHitTesting(false)` so it never intercepts remote input.
  - Replaced the inline title Text with `HeroTitle(item:baseURL:)` — rest of the content stack (metadata line / overview / action buttons) unchanged.
  - Terminal gradient stop was *already* blending to `Constants.Colors.background` from Item A's work — no change needed there.
- `SettingsManager` gained `@AppStorage("autoPlayTrailers") var autoPlayTrailers = true` (opt-out, default on).
- `PlaybackSettingsView`'s Auto-Play section gets a new "Auto-Play Hero Trailers" toggle and updated footer copy ("Hero trailers start muted on focus dwell.").

### Verified on sim

Demo server featured-items rotation produced title treatments for:
- The Parent Trap (branded yellow/teal decorative wordmark)
- Books of Blood (stylized "BLOOD" serif)
- Versa (Disney banner + serif VERSA wordmark)
- THE ACOLYTE — **episode** pulling through `ParentLogoItemId` (this is the one that proves the fallback works; without it episodes render text)

Falls back cleanly for items with no logo (e.g. Sid and Nancy).

### Known trade-offs / C.2 follow-up

- **Trailer playback deferred.** The plan called for a 2s-dwell muted trailer over the backdrop. Blocked because Jellyfin's `RemoteTrailers` entries are YouTube URLs, and AVPlayer can't play YouTube directly. Three viable paths for C.2:
  1. Integrate Jellyfin's local-trailer API — `/Users/{userId}/Items/{itemId}/LocalTrailers` returns actual playable Jellyfin items. Works only on servers where the admin enabled local-trailer scraping.
  2. Add a YouTube extractor dependency (XCDYouTubeKit or similar) to resolve a direct stream URL from the `youtube.com/watch?v=…` link. Adds a third-party dep + fragile against YouTube changes.
  3. Skip trailer playback entirely and close the ticket.
  - Default direction: path 1 (local trailers), fall back to showing nothing. Gate on `autoPlayTrailers == true && localTrailers.first != nil`.
- Vignette is intentionally subtle (α=0.35 outer). If it reads as invisible on the TV at 10ft, raise to 0.5 in a follow-up tweak — do not go past 0.6 or the backdrop photo starts to feel artificially boxed.
- Logo size (600×180pt) is a fixed upper bound. Square logos (series-style circle marks) will render much smaller inside that box; if that becomes a visual issue, pass a per-item aspect hint from Jellyfin's `LogoImageTags` metadata (not currently decoded).

---

## Item C — original plan (historical)

**Why:** the first 2 seconds of the app. Biggest cinematic upgrade per line of code.

**What — title treatment:**
- Extend `MediaItem` / `ImageTags` decoding to surface `logo` tag (already present in spec; verify decoder).
- `HeroBanner.swift`: if `item.logoImageURL` resolves, render `AsyncImageView` at max-width 600pt, height 180pt, lower-left inside safe area. Fall back to `.system(size: 60)` title text.
- Shadow: `.black.opacity(0.5)` radius 12 so logo reads over any backdrop.

**What — auto-trailer:**
- On hero focus dwell ≥ 2s, if `remoteTrailers.first` resolves to a YouTube URL, mount a muted looping `AVPlayer` over the backdrop.
- On focus loss (user swipes down into a shelf) → fade out the trailer, cross-fade back to the still backdrop.
- Gate behind a new `SettingsManager.autoPlayTrailers: Bool` (default true).

**What — gradient refinement:**
- Increase bottom stop to `Constants.Colors.background` (not `Color.black`) so the hero terminates flush with the scrolling content below.
- Add a subtle radial vignette at the corners (`α=0.35` edges → `α=0` at 30% radius).

**Risk:** medium. Trailer playback on a view that already rotates needs careful state machine — focus in → stop rotation *and* start trailer; focus out → start rotation *and* stop trailer; disappear → stop both.
**Acceptance:** focus Play on hero, count "one-mississippi, two-" and a muted trailer begins; focus down, it cross-fades back to the still.

---

## Item D — Player HUD aligns to Apple's tvOS contract (P1) — SHIPPED 2026-04-23

### What landed

- `SimpleVideoPlayerRepresentable` now drives `AVPlayerViewController.contextualActions` directly from `viewModel.showSkipIntroButton` / `showSkipCreditsButton`. Skip Intro appears as a native `UIAction` chip with Apple's transport-bar animation; the SwiftUI overlay is gone. When the VM state flips false the array goes empty and Apple animates the chip out — no custom transition code.
- New `syncContextualActions(on:)` helper is called from both `makeUIViewController` and `updateUIViewController`. The SwiftUI parent observes `viewModel.showSkipIntroButton` via `@StateObject`, which forces an invalidation each time the controller's intro-skipper window opens or closes → `updateUIViewController` re-runs → contextual actions refresh.
- New `syncPlaybackRateMenu(on:)` publishes a `UIMenu` with 0.5× / 1× / 1.25× / 1.5× / 2× children as the sole `transportBarCustomMenuItems` entry. Check-state comes from `player.defaultRate` (tvOS 16+) not `player.rate` — `rate` goes to 0 while paused, which would otherwise flip the checkmark back to 1× incorrectly whenever the user paused. Selecting a speed writes both `defaultRate` (persists across pause/seek) and `rate` (applies live, but only if currently playing so selecting a speed doesn't unpause).
- `VideoPlayerView` parent now passes `showSkipIntro` / `showSkipCredits` / `onSkipIntro` / `onSkipCredits` into the representable. Closures capture `viewModel` — safe because they're replaced on every SwiftUI invalidation and `UIAction` holds them only until the array is replaced.
- Deleted `SkipMarkerOverlay` and `SkipButton` structs entirely — ~60 lines of SwiftUI + `@FocusState` that existed only because we weren't using Apple's contract. Grep for `SkipMarkerOverlay` / `SkipButton` returns nothing. 
- **`MPNowPlayingInfoCenter` was already wired** by `NowPlayingPublisher` (added since the plan was written) — it already publishes title/series/artwork/elapsed/duration/rate, wires `playCommand`/`pauseCommand`/`togglePlayPauseCommand`/skip ±10s/`changePlaybackPositionCommand`, and clears on deinit. Re-verified; nothing to add.
- Build green on `tvOS Simulator,OS=26.0,name=Apple TV`, no new warnings.

### Trade-offs / things to watch

- Skip Intro "Auto-skip with countdown" visual: the previous custom overlay showed the button for N seconds then seeked. The contextual-action contract doesn't render a countdown — it's just a chip that's present or not. If the countdown UX matters, we'd need an extra label on the chip (not supported) or fall back to a non-native CTA. Current behavior: the chip appears during the intro window and auto-skip fires after the configured countdown — same VM state, same controller behavior, just a different visual idiom. If a user pref for "show countdown" becomes a requirement, revisit.
- `UIMenu` for playback rate has no check-mark animation when the selection changes — the menu rebuilds on the next `updateUIViewController` and the new state appears instantly on reopen. This is the same behavior AVKit ships for its native subtitle/audio menus, so it matches platform expectations.
- `IntroCreditsController.hasSkippedIntro` / `hasSkippedCredits` still latch to `true` after a skip — so if the user seeks *backwards* past the intro marker a second time, the chip won't re-appear. Pre-existing behavior, not in this item's scope.

---

## Item D — original plan (historical)

**Why:** today, Skip Intro is a SwiftUI overlay that ignores the AVKit transport-bar contract; `MPNowPlayingInfoCenter` is silent. Apple convention exists for free; we're not using it.

**What:**
- Replace `SkipMarkerOverlay` with `AVPlayerViewController.contextualActions`:
  - On `viewModel.showSkipIntroButton == true`, set `controller.contextualActions = [UIAction(title: "Skip Intro", image: UIImage(systemName: "forward.fill")) { _ in vm.skipIntro() }]`.
  - On `false`, set `[]`. Apple animates it in/out using the native "Up Next" chrome.
  - Same treatment for Skip Credits (driven off `showSkipCreditsButton`).
- Wire `MPNowPlayingInfoCenter`:
  - On `viewModel.didBeginPlayback`, publish `title`, `artist` (seriesName), `artwork`, `duration`, `elapsedTime`, `playbackRate`.
  - On pause/seek/scrub → update `elapsedTime`.
  - On teardown → `setNowPlaying(nil)`.
- Add `controller.transportBarCustomMenuItems = [playbackRateMenu]` driving 0.5× / 1× / 1.25× / 1.5× / 2×.
- Delete `SkipMarkerOverlay` + `SkipButton` once `contextualActions` path is live (keep commented hook in case we ever need a non-native CTA).

**Files touched:**
- `MediaMio/Views/Player/VideoPlayerView.swift`
- `MediaMio/Views/Player/CustomInfoViewControllers.swift`
- `MediaMio/ViewModels/VideoPlayerViewModel.swift`

**Risk:** medium-high. Lifecycle ordering is the common trap — `contextualActions` must be cleared on dismiss.
**Acceptance:** Skip Intro appears as a native "contextual action" pill lower-right with the Apple animation, not as our overlay. System TV app Continue Watching row receives the in-flight episode.

---

## Item E — Detail view pattern decision + layout (P1)

**Why:** the current header is a hybrid. Commit to one idiom.

**Recommended idiom:** **Full-bleed cinematic** (Apple TV / Netflix). Reasons:
- Backdrop tags are well-populated from TMDb-backed Jellyfin instances.
- Premium-cinematic tone (locked in Phase 1 Q1) points here.
- The poster-beside-metadata pattern is a *library* idiom, better fit for Sonarr/Radarr than a playback client.

**What:**
- `DetailHeaderView`:
  - Height: `900pt` → `720pt` (66% of 1080, matches skill spec).
  - Remove `HStack { poster / info }` composition — single `VStack` lower-left anchored at the bottom of the backdrop.
  - Poster drops off the header entirely; for items lacking a backdrop, render a centered title-treatment logo over a vertical gradient on `surface1` (no blur-poster fallback).
  - Metadata line stays.
  - Play / Favorite CTA row shifts lower-left, ~80pt from bottom, inside the 80pt horizontal safe area.
- `ChaptersSection`: demote below Cast & Crew on Movie detail; hide entirely on Series detail (already hidden per current code — keep).
- Wrap the entire scrollable content VStack in a `.focusScope(namespace)` and mark the Play button with `.prefersDefaultFocus(true, in: namespace)`.
- Use tvOS 18+ `matchedTransitionSource(id: item.id, in: namespace)` on `PosterCard` + `.navigationTransition(.zoom(sourceID: item.id, in: namespace))` on `ItemDetailView` for poster → detail zoom. Guard with `#available(tvOS 18, *)` since the minimum deployment target may be lower.

**Risk:** medium. Layout shift; needs a design eyeball at 10ft.
**Acceptance:** Apple-TV-app-like cinematic detail with backdrop filling 2/3 viewport, metadata + CTAs stacked lower-left, Play auto-focused on entry, poster-to-backdrop zoom transition.

---

## Item F — `PosterCard` becomes a real tvOS `Button` with `.card` style (P2)

**Why:** the free tvOS card parallax + specular glare is the single cheapest upgrade to premium feel. Currently we have `.onTapGesture` bypassing this.

**What:**
- Rewrite `PosterCard` body:
  ```
  Button(action: onSelect) {
      VStack(...) { image · title · metadata }
  }
  .buttonStyle(.card)
  ```
- Drop `@FocusState private var isFocused` — the system card style drives its own focus visual.
- Keep `.contentFocus(isFocused:)` *only* if `buttonStyle(.card)`'s free lift + parallax needs custom shadow stacking. Run it on-device first; if the system treatment is good enough, delete our custom tier here (keep `.contentFocus` for hero CTAs where we *don't* want parallax).
- Add long-press context menu:
  ```
  .contextMenu {
      if isResumable { Button("Play from Beginning", action: ...) }
      if canMarkWatched { Button(isPlayed ? "Mark Unwatched" : "Mark Watched", action: ...) }
      Button(isFavorite ? "Remove from Favorites" : "Add to Favorites", action: ...)
      if item.type == "Episode" { Button("Go to Series", action: ...) }
      if isInResumeRow { Button("Remove from Continue Watching", role: .destructive, action: ...) }
  }
  ```
- These actions route through existing `HomeViewModel` / `ItemDetailViewModel` mutation methods where available; plumb new VM actions where not.

**Risk:** medium. Moving to `.card` style may visually diverge from Hero button (which still needs `.contentFocus`). Test side-by-side.
**Acceptance:** focused posters tilt + specular-shine on remote movement; long-press on any poster brings up the context menu.

---

## Item G — Split focus strategy for Apple TV HD (P3 — defer if no users)

**Why:** Apple TV HD (A8) is Apple's minimum-spec device. Mounting all 4 tabs eagerly + 4K image decodes + full-screen blurs chokes.

**What (investigate first — verify device share matters before doing the work):**
- Gate `MainTabView`'s eager-mount to the current tab + one prefetched neighbor on A8; full eager-mount on A10+.
- Guard `AsyncImage` max-size decode at `UIScreen.main.nativeScale` — already done via `ImageSizing.pixelSize`, verify no regressions.
- Add a `.device.isLowPower` env flag that disables: auto-trailer, radial vignette, zoom transition, hero rotation animation.
- Skip Item G entirely if nobody on A8 is using the app — check telemetry first.

**Risk:** low (code) but potentially wasted if no A8 users. Check first.

---

## Item H — Final polish pass (P2)

**Why:** runs after all structural work, same convention as Phase 1 item 7.

**What:**
- Tokenize remaining inline `.system(size:)` calls in `HeroBanner.swift:206` and `ItemDetailView.swift:255` → `Font.system(.largeTitle, weight: .bold)` with a custom scale modifier where 60pt/72pt is desired, so Dynamic Type and accessibility scale still apply.
- Sweep any remaining `Color.white.opacity(0.1/0.2/0.3)` in non-text contexts → surface tokens. (Phase 1 item 7 mostly cleared these; final audit.)
- Add skeleton state to `ItemDetailView` — use `SkeletonView` while `viewModel.isLoading` is true and no `detailedItem` is available yet.
- Run `/critique` again and compare to Phase 1 baseline (Nielsen 32/40, AI Slop Test pass).
- Screenshot pass at 4K: Home, Library, Detail (movie), Detail (series), Player (playing), Player (paused w/ info).

**Risk:** near-zero.

---

## Decisions locked in (2026-04-23 — Brandon approved)

**Q1. Hero auto-trailer — opt-out, default ON.**
- Item C wires a new `SettingsManager.autoPlayTrailers: Bool` AppStorage default `true`.
- Surface a toggle in `PlaybackSettingsView` so motion-sensitive / metered-network users can disable it.
- On hero focus dwell ≥ 2s and `autoPlayTrailers == true` and `item.remoteTrailers.first` resolves → start muted looping playback.

**Q2. Detail view — commit to full-bleed cinematic.**
- Item E executes the full pattern (no scope reduction): drop the `HStack { poster · info }` composition, header height 900pt → 720pt, single lower-left `VStack` over backdrop + scrim, no blur-poster fallback.
- For items lacking a backdrop: centered title-treatment logo (or text fallback) over `surface1` + gradient — *not* a blurred poster.

**Q3. Deployment target — tvOS 26.0 (main app), 18.6 (tests).**
- Both ≥ 18, so `matchedTransitionSource` + `.navigationTransition(.zoom(sourceID:in:))` work unconditionally.
- **No `#available(tvOS 18, *)` guard needed in Item E.** Use the modern API directly.
- Same green light for any other tvOS-18+ APIs: `customInfoViewControllers` extensions, contextual-action animations, etc.

---

## Sequencing — recommended order

1. **Item A** (bugs / hygiene) — one session. Ship before anything else. Low risk, unblocks the rest.
2. **Item B** (Continue Watching 16:9) — one session. Biggest visual delta per hour.
3. **Item C** (hero title treatment + auto-trailer) — one session. The cinematic upgrade.
4. **Item D** (player HUD Apple contract) — one session. Invisible but eliminates the worst technical debt.
5. **Item E** (detail pattern commit) — one session. Largest user-visible structural change.
6. **Item F** (PosterCard → `.card` + context menu) — one session. Biggest "tvOS native feel" upgrade.
7. **Item H** (polish) — one session.
8. **Item G** (A8 gating) — skip unless telemetry says users are on A8.

**Total estimated effort:** 6–7 focused sessions. Each item is independently shippable; each ends in a green build on `tvOS Simulator,OS=26.0,name=Apple TV`.

---

## What Phase 2 does NOT do

- Does not change the business logic or API surface.
- Does not refactor the view model layer.
- Does not touch Splash screen or Video Player color (both explicitly preserved).
- Does not re-open subtitles / playback / bitrate decisions.
- Does not introduce a sidebar — current 4-tab top bar is correct for this app's destination count.
- Does not build custom player UI. AVKit owns the HUD.

---

## Baseline scores to re-measure after Phase 2

Phase 1 shipped at **~32/40 Nielsen, AI Slop Test passes** (target).

Phase 2 target:
- **Nielsen**: 34+/40. Lift comes from Consistency & Standards (+1 if all shelves commit to aspect-ratio convention) and Aesthetic/Minimalist (+1 if detail view commits to one idiom).
- **AI Slop Test**: still passes — stricter because EpisodeCard's remaining glow is the last obvious tell.
- **tvOS convention compliance**: 4 additional conformance points — `contextualActions`, `MPNowPlayingInfoCenter`, 16:9 resume thumbs, `.buttonStyle(.card)` on posters.

---

## Quick index — files Phase 2 will touch

| File | Items |
|---|---|
| `MediaMio/Utilities/DebugLog.swift` (new) | A |
| `MediaMio/Views/Components/EpisodeThumbCard.swift` (new) | B |
| `MediaMio/Views/Components/HeroBanner.swift` | A, C |
| `MediaMio/Views/Components/PosterCard.swift` | F |
| `MediaMio/Views/Components/ContentRow.swift` | A, B |
| `MediaMio/Views/Detail/ItemDetailView.swift` | A, E |
| `MediaMio/Views/Player/VideoPlayerView.swift` | A, D |
| `MediaMio/Views/Player/CustomInfoViewControllers.swift` | D |
| `MediaMio/Views/Home/HomeView.swift` | A, E |
| `MediaMio/ViewModels/HomeViewModel.swift` | A, F |
| `MediaMio/ViewModels/ItemDetailViewModel.swift` | F |
| `MediaMio/ViewModels/VideoPlayerViewModel.swift` | D |
| `MediaMio/Services/SettingsManager.swift` | C |
| `MediaMio/Navigation/MainTabView.swift` | G (optional) |

---

## Resume checklist for the next session

1. Read this file (`design-plan-phase-2.md`) and the Phase-1 doc (`design-plan.md`).
2. Q1/Q2/Q3 are already locked above — do NOT re-ask. Proceed straight to Item A.
3. Run Item A (bugs + hygiene) in isolation, commit, build-green.
4. Confirm with Brandon whether to continue sequential (A → B → C …) or fan out — default to sequential.
5. After each item, re-run the build gate (`tvOS Simulator,OS=26.0,name=Apple TV`) and check for new warnings.
6. After Item H, re-run `/critique` to measure delta against Phase 1 baseline (target: Nielsen 34+/40).
