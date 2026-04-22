# MediaMio — Architecture + Feature Review

> Senior tvOS engineer + streaming-platform architect perspective
> Comparing against Netflix, Apple TV+, Disney+, Swiftfin, Infuse, Plex
> Reviewed: `main` branch, 68 Swift files, 13,857 lines

---

## TL;DR

The app is **well-layered and buildable** — clean MVVM split, centralized services, Keychain auth, a sensible Jellyfin wire model, and thoughtful codec decision logic. You are *much* closer to shippable than most first-time tvOS apps.

The gap to "Netflix-class" is **not** architectural rewrite territory — it's three concrete things:

1. **VideoPlayerViewModel at 1,830 lines is a god-object** that must be decomposed before you add any more features (DRM, adaptive bitrate, PiP, AirPlay).
2. **The focus system is the #1 user-visible problem**: you have parallel focus tracking (SwiftUI `@FocusState` + your own `FocusManager` + a `UIFocusGuide` bridge) that are not synchronized. This causes the brute-force `scrollTo` loops, lost focus after detail dismissal, and tab-state reset. This is fixable without rewriting views.
3. **Feature parity gaps with top clients** (cast/crew, trailers, watchlist, quick-connect, server discovery, offline, letter-jump library) — these are mostly server-driven additions, not app-architecture changes.

No security or data-loss ship-blockers. Two real medium-severity bugs (image-loader race, keychain silent delete). Tests are effectively zero.

Ship-blocking priority: **P0 player decomposition → P0 focus consolidation → P1 feature gaps → P2 polish**.

---

## Scorecard

| Area | Grade | Notes |
|------|-------|-------|
| Layering / MVVM | **B+** | Clean split, some view bloat, wrapper factory duplication |
| Services & API client | **B** | Good structure, missing retries/backoff/pagination/cancellation |
| Video player | **C** | Works, but god-object, hidden control flow, no bitrate switching |
| Focus & navigation | **C** | Ambitious, but three parallel systems fighting each other |
| Feature completeness | **C** | Good scaffold; missing ~40% of what Netflix/Infuse users expect |
| Settings | **B** | Well-organized, but no device mgmt / parental controls / offline |
| Auth | **B-** | Keychain used correctly for token; no Quick Connect / mDNS / multi-user |
| Models | **A-** | Clean Codable, good `MediaStream` / `MediaSource` handling |
| Tests | **F** | Three stub files, zero real assertions |
| Docs / planning | **A** | 28 markdown planning files — almost overkill |

Overall: **B-** with clear path to B+/A-.

---

## Top 10 findings (ranked by user-facing impact)

| # | Finding | Files | Priority |
|---|---------|-------|----------|
| 1 | `VideoPlayerViewModel` is 1,830 lines — 6 concerns bolted together | `ViewModels/VideoPlayerViewModel.swift` | **P0** |
| 2 | Three parallel focus systems (`@FocusState` + `FocusManager` + `UIFocusGuide`) drift out of sync | `Navigation/FocusManager.swift`, `Navigation/FocusGuideViewController.swift`, feature views | **P0** |
| 3 | Tab switching tears down view trees and loses scroll/focus position | `Navigation/MainTabView.swift:17` | **P0** |
| 4 | Home screen loads sections **sequentially**, not in parallel | `Services/ContentService.swift:34–65` | **P0** |
| 5 | No retry/backoff on transient network errors | `Services/JellyfinAPIClient.swift:31–34, 166–185` | **P1** |
| 6 | Play button on detail is a stub (`"will be implemented in Phase 5"`) | `ViewModels/ItemDetailViewModel.swift:150–152` | **P1** |
| 7 | Bitrate picker is UI-only — selection is ignored by player | `Views/Player/CustomInfoViewControllers.swift:132,259`, `VideoPlayerViewModel` | **P1** |
| 8 | Cast/crew, trailers, similar-items-View-All, external ratings missing from detail | `Views/Detail/ItemDetailView.swift` | **P1** |
| 9 | Image loader has a deduplication race + no downsampling for 4K backdrops | `Services/ImageLoader.swift:69–114`, `Services/ImageCache.swift` | **P2** |
| 10 | Zero real tests (three Xcode-template stub files) | `MediaMioTests/`, `MediaMioUITests/` | **P1** |

---

## Architecture audit

### Layering map

```
MediaMioApp (@main)
    ├── AuthenticationService (env)   ← Keychain, login/logout
    ├── AppState (env)                 ← isLaunching, jellyfinConnected
    │
    ├── ServerEntryView → LoginView    (unauth branch)
    │
    └── MainTabView                    (auth branch)
        ├── Tab: Home → HomeView → HomeViewModel
        ├── Tab: Library → LibraryTabView → LibraryViewModel
        ├── Tab: Search → SearchView → SearchViewModel
        └── Tab: Settings → SettingsView → SettingsManager (singleton)

   Services layer (shared):
     JellyfinAPIClient — HTTP + decode
     ContentService — domain convenience (what counts as "home row")
     AuthenticationService — session + Keychain
     ImageCache / ImageLoader — memory + disk cache
     SettingsManager — @AppStorage wrapper
     KeychainHelper — Security-framework wrapper
     AppleTVCodecSupport — codec detection (great module)
     AudioManager — intro sound FX

   Navigation:
     NavigationManager — published state for detail/sheet
     NavigationCoordinator — (duplicate, lives inside HomeView)
     FocusManager — published focus shadow
     FocusGuideViewController — UIKit bridge (unwired)
```

### What's right

- **Clean MVVM split.** Every view has a VM; VMs don't import `SwiftUI.View`. Dependencies flow Route → VM → Service → API → server, with the one exception called out below.
- **`AppleTVCodecSupport`** is a highlight — a proper decision tree for DirectPlay → Remux → DirectStream → Transcode, keyed to actual Apple TV hardware capabilities. Better than most open-source Jellyfin clients.
- **Keychain is used correctly for tokens** (`KeychainHelper.swift`, used by `AuthenticationService:saveSession`). The agent's "credentials in UserDefaults" finding only applies to the `rememberMe` flag + last-typed username (`LoginView.swift:19–20, 171`), which is fine.
- **Models are clean.** `MediaItem`, `MediaStream`, `MediaSource`, `UserData` — proper `Codable`, well-named computed helpers (`runtimeFormatted`, `episodeText`, `subtitleDisplayName`), no enum-string stringly-typing spread into views.

### What needs work

#### 1. Dependency injection is ad-hoc

`HomeView.swift:140–239` defines `ItemDetailViewWrapper`, `LibraryViewWrapper`, `SearchViewWrapper` — each one manually instantiates `JellyfinAPIClient`, `ContentService`, `HomeViewModel`, etc. That pattern repeats in 3 places with drift.

**Fix:** An `AppEnvironment` object (or EnvironmentKey) holding `apiClient`, `contentService`, `authService`, injected once at `MediaMioApp` and read via `@Environment(\.mediaEnv)`. Eliminates the wrapper factories.

#### 2. Two navigation systems

You have both `NavigationManager` and `NavigationCoordinator` (the latter embedded inside `HomeView.swift:248–270`) with fallback logic in `ItemDetailViewModel.swift:145–152`:
```swift
if let navManager = navManager {
    navManager.playItem(displayItem)
} else {
    coordinator?.playItem(displayItem) // fallback
}
```
This is a smell. Pick one. `NavigationManager` is the cleaner abstraction.

#### 3. `ContentView.swift` is a dead Xcode template

Literal "Hello, world!" globe. It's not in the view tree (`MediaMioApp` routes to `MainTabView` or `ServerEntryView`) — just delete it.

#### 4. Cross-feature duplication

Pagination logic is identical in `LibraryViewModel.swift:186–240` and `SearchViewModel.swift:156–166` — `currentStartIndex`, `pageSize`, `hasMoreContent`, onAppear-of-last-item trigger. Five separate empty-state views (`EmptyHomeView`, `EmptyLibraryView`, `SearchEmptyState`, `NoResultsView`, `LibrarySearchModal.emptySearchView`). Extract both to shared components.

---

## Video player audit — the big one

### The 1,830-line god-object

`VideoPlayerViewModel.swift` bundles **six distinct responsibilities**:

| # | Concern | Approx lines |
|---|---------|--------------|
| 1 | **Stream URL building** (DirectPlay / DirectStream / Remux / Transcode URL construction, codec selection, bitrate params) | ~320 (257–432, 487–700) |
| 2 | **Subtitle track management** (AVMediaSelectionGroup binding, track enumeration, selection persistence) | ~150 (931–1095) |
| 3 | **Intro/credits skip** (Jellyfin intro-skipper plugin integration, marker fetch, skip button show/hide) | ~80 (846–930) |
| 4 | **Playback fallback controller** (Direct Play → Transcode degradation on failure) | ~100 (1362–1440) |
| 5 | **Playback session reporting** (`/Sessions/Playing`, `/Playing/Progress`, `/Playing/Stopped` POSTs) | ~150 (1640–1760) |
| 6 | **Core lifecycle** (AVPlayer create/teardown, play/pause/seek, status observation) | ~350 |

**Recommended split** — keep the outer VM as a thin orchestrator, extract five services:

```
VideoPlayerViewModel (~350 lines, orchestrator only)
   ├── PlaybackStreamURLBuilder          // pure functions, unit-testable
   ├── PlaybackSessionReporter           // Jellyfin /Sessions/* POSTs
   ├── SubtitleTrackManager              // AVMediaSelectionGroup wrapper
   ├── IntroCreditsController            // marker fetch + skip logic
   └── PlaybackFailoverController        // DirectPlay→Transcode retry
```

This buys you:
- Unit tests on `PlaybackStreamURLBuilder` (no AVPlayer needed)
- Ability to mock `PlaybackSessionReporter` for offline/testing
- Safe place to add **DRM** (`PlaybackStreamURLBuilder` gets a `DRMHandler` dependency)
- Safe place to add **AirPlay / external display** (orchestrator manages, others don't care)
- Safe place to add **PiP** (orchestrator owns AVPlayerViewController lifecycle)

### Correctness issues (verified)

- **`VideoPlayerViewModel.swift:1262–1263`** — `player.play()` called inside a Combine sink on status change. Hidden control flow; view cannot decide not to auto-play. Emit an event, let the view drive.
- **`VideoPlayerViewModel.swift:1374–1437`** — 3-second hardcoded delay before fallback kicks in. Network jitter causes false fallbacks (user gets transcoded stream when Direct Play would have succeeded). Observe `playable` or buffer-fill threshold instead.
- **`VideoPlayerViewModel.swift:1659`** — `reportPlaybackStart()` always sends `"PlayMethod": "DirectPlay"` regardless of actual mode. Jellyfin's server-side stats and "Now Playing" display are wrong because of this. Send `currentPlaybackMode.rawValue`.
- **`VideoPlayerView.swift:166–172`** — Pause on `willResignActive` is correct, but no resume on `didBecomeActive`. Background → foreground leaves playback paused. Also no handler for `AVAudioSession.interruptionNotification` (incoming call, Siri).
- **No `preferredMaximumResolution`** set on `AVURLAsset`. tvOS will auto-select the highest HLS variant even on 1080p displays, wasting bandwidth. Set based on `UIScreen.main.nativeBounds`.
- **Bitrate picker UI is a lie.** `CustomInfoViewControllers.swift:132,259` posts bitrate-change notifications that the VM ignores. Either (a) restart playback with new URL on change (Infuse does this), or (b) remove the picker until it works. Lying UI is worse than no UI.
- **No `MPNowPlayingInfoCenter` integration** — AirPlay / lock-screen / Siri remote don't show artwork or metadata. For tvOS this matters less than iOS but is still expected polish. ~30 lines to add.

### Gaps vs top players

| Capability | MediaMio | Netflix | Infuse | Swiftfin |
|------------|----------|---------|--------|----------|
| Direct Play / DirectStream / Transcode fallback chain | ✅ | ✅ | ✅ | ✅ |
| Auto-pick bitrate from bandwidth | ❌ | ✅ | ✅ | partial |
| Live bitrate/FPS overlay | ❌ | debug | ✅ | ✅ |
| Skip intro | partial (intro only) | ✅ | ✅ | ✅ |
| Skip outro/credits | ❌ | ✅ | ✅ | ✅ |
| Chapter navigation | ❌ | — | ✅ | ✅ |
| Subtitle burn-in option | ❌ | — | ✅ | ✅ |
| Dolby Vision / HDR10+ passthrough signaled | unclear | ✅ | ✅ | partial |
| AirPlay to other device | untested | ✅ | ✅ | ✅ |
| Picture-in-Picture | ❌ | ✅ | ✅ | ✅ |
| Token-refresh mid-playback | ❌ | ✅ | ✅ | ✅ |
| Now Playing metadata | ❌ | ✅ | ✅ | ✅ |

---

## Navigation & focus audit

### The core problem: three focus systems

You have **three parallel representations of "who has focus"**:

1. **SwiftUI `@FocusState`** in `PosterCard.swift:16`, `ContentRow.swift:20`, `HeroBannerButton.swift:264` — this is the *actual* focus, managed by the OS.
2. **`FocusManager`** (`Navigation/FocusManager.swift:19–180`) — a `@Published` shadow updated only through callbacks like `focusedOnRow(_:)`. **It's always at best one frame behind reality.**
3. **`FocusGuideViewController`** (`Navigation/FocusGuideViewController.swift`) — a UIKit `UIFocusGuide` bridge with *hardcoded* frame estimates (lines 160–178: `hero height = 900pt`, `first row at 940pt`, `row spacing 260pt`). These are never updated when layout changes. Worse, the comment at line 146 admits "the guide doesn't directly set preferred focus environments… we'll handle preferred focus through SwiftUI's @FocusState" — meaning it's structurally orphan code.

**The user-visible consequence of this:** `HomeView.swift:393–403` has a brute-force `scrollTo` loop calling `proxy.scrollTo(...)` six times with escalating delays (0.1s → 1.8s) "to fight the focus system." That is the symptom. The *cause* is that three systems are racing.

**Recommended fix:**
- Delete `FocusGuideViewController` unless there's a specific focus-island problem it's solving (there doesn't appear to be one in the code).
- Demote `FocusManager` to just `lastFocusedItemInRow: [RowID: ItemID]` — a pure memo, no per-card state.
- Let `@FocusState` be the source of truth. On detail dismissal, `ContentRow.onAppear` reads `FocusManager.lastFocused(row)` and writes to `@FocusState focusedItemId`. That's it.

### Additional correctness issues

- **`MainTabView.swift:17`** — Each tab has its own `NavigationStack`. SwiftUI's default `TabView` tears down non-visible tabs. That's why tab switching loses state. Two options:
  - `.tabViewStyle(.sidebarAdaptable)` with explicit `@StateObject` VMs held at `MainTabView` level (survive tab switch).
  - Or a custom "tab as a z-stacked hidden view" pattern that `.opacity(selected ? 1 : 0)` plus `.allowsHitTesting(selected)`. Less idiomatic but guarantees state preservation.
- **`NavigationManager.swift:32–34`** — `homeScrollPosition`, `searchScrollPosition`, `libraryScrollPosition` are declared `@Published` but **nothing reads or writes them anywhere in the codebase**. Either wire them up or delete them.
- **`ContentRow.swift:79–86`** — Row tracks which card was last focused via `FocusManager.focusedOnRow()` — but on re-entry (returning from detail), never restores to that card. Add `.onAppear { focusedItemId = navigationManager.lastFocusedItem(for: rowID) }`.
- **Detail sheet dismissal doesn't restore focus** (`MainTabView.swift:50–54`). When `.sheet` dismisses, focus goes to the tab bar. Netflix pattern: focus returns to the originating card. Requires storing `restoredFocus` target at the originating row before presenting.
- **`PosterCard.swift:92,100`** — `scaleEffect` with `.animation(.spring(...), value: isFocused)` — but the spring starts after focus moves. You see the scale lag behind the focus ring. Use `.animation(nil, ...)` to remove the spring, or use `withAnimation` in an `onChange(of: isFocused)` with a tighter duration.
- **Hero banner doesn't prefetch next slide's backdrop** (`HeroBanner.swift:112–127`) — image pops in during crossfade. Prefetch `currentIndex+1` backdrop 2s before transition.
- **`SidebarView.swift:35–61`** — No `.focusSection()` around sidebar. When open, focus can leak into content or back, triggering the 0.1s delayed hide with a race. Wrap sidebar buttons in `.focusSection()` so the focus engine treats them as a group.

### Strengths
- LazyHStack in content rows (right call — would be catastrophic as HStack).
- Hero banner pauses rotation when a CTA button is focused (`HeroBanner.swift:91`).
- 200ms `.easeInOut` focus animation on most buttons matches the claim in `README.md`.

---

## Feature-by-feature

### Home
**Works:** Rotating hero, content rows with lazy loading, pull-to-refresh, sidebar.
**Gaps:**
- `ContentService.swift:34–65` — home sections loaded **sequentially**. Convert to `TaskGroup` for 3–5× faster first paint.
- No skeleton loaders — blank black during initial load.
- No "Continue Watching" distinct from "Recently Added" — `HomeViewModel.swift:66–88` populates both from the same call.

### Library
**Works:** Genre/year/rating/status filters, 8 sort options, persisted filter state, in-library search.
**Gaps:**
- No letter-jump / alphabetical scrubber (every top client has this).
- No list-view variant (grid-only).
- Filter bar shows active-filter *text* but no count badge.
- Grid item width hardcoded 250–350pt adaptive — fine for 4K, sparse on 1080p TVs.

### Search
**Works:** 500ms debounce (Combine), type filter (All/Movies/TV), pagination.
**Gaps:**
- No recent searches. No suggestions. No trending searches.
- No faceted results (by actor, director, genre).
- Two empty-state views that look similar but aren't the same component.

### Detail
**Works:** Backdrop, progress bar, resume-vs-play logic, season/episode browser.
**Gaps (biggest feature-parity deficit in the app):**
- **Play button is a stub.** `ItemDetailViewModel.swift:150–152` — comment explicitly says "will be implemented in Phase 5." This is the most important button in the app.
- **Favorite toggle is a print statement.** `ItemDetailViewModel.swift:155–158`.
- **No cast/crew** — `DetailMetadataView:243–276` only shows genres/studios/release date. `MediaItem.people` is already decoded (`MediaItem.swift:35`) — just render it.
- **No trailers** — Jellyfin serves `RemoteTrailers` in `/Users/{UserId}/Items/{ItemId}`. Not surfaced.
- **No external ratings** (IMDb, TMDB, RT). Jellyfin has these in `ExternalUrls`.
- **No chapters** — `MediaSource.chapters` exists in Jellyfin's API schema but isn't modeled.
- **Episodes presented horizontally** — vertical list is standard for tvOS and easier to navigate.
- **ItemDetailView is 572 lines** — above your 300-line guideline. Extract `DetailHeaderView`, `DetailMetadataView`, `SeasonEpisodesView`, `SimilarItemsView` to files.

### Settings
**Works:** Clean tab split — Playback / Streaming / Subtitles / Skip / Account / App. Subtitle live preview.
**Gaps:**
- No device management (sign out all devices).
- No parental controls / PIN.
- No offline download management (Infuse flagship feature).
- Auto-switch bitrate on network type not implemented.
- Cache clearing is binary — no per-library breakdown.

### Authentication
**Works:** URL validation, Keychain storage, connection test before login, "Remember Me" for username (not password, correctly).
**Gaps:**
- **No mDNS / Bonjour server discovery.** Swiftfin has this — on the same network, you shouldn't need to type a URL.
- **No Quick Connect.** Jellyfin's flagship feature: "enter this 6-digit code on the web to log in this TV." Removes password entry entirely on tvOS. High ROI (~100 lines) and users will notice immediately.
- **No multi-user** — server may have multiple profiles; only first-user-to-log-in is supported.
- **No saved-servers list** — last URL is stored but UI shows nothing on return.
- **`LoginViewModel` is redundant** — `LoginView.swift:148–177` reimplements the same logic. Delete the VM or move logic into it.

---

## Services layer audit

### Verified issues

- **`Services/ContentService.swift:34–65`** — Home loads sections sequentially. `TaskGroup` fix:
  ```swift
  async let cw = loadContinueWatching()
  async let ra = loadRecentlyAdded()
  async let libs = loadLibrarySections()
  self.sections = try await [cw, ra] + libs
  ```
- **`Services/JellyfinAPIClient.swift:31–34`** — Only timeouts set on `URLSession.configuration`. No retry policy for 5xx, no exponential backoff on `-1009`/`-1001`, no single 401-triggered refresh. Add a wrapping `performRequestWithRetry` that retries on `URLError.networkConnectionLost/.timedOut` with backoff (e.g., 500ms → 1500ms → 4000ms), and on 401 triggers `AuthenticationService.refreshToken()` before retrying once.
- **`Services/JellyfinAPIClient.swift:166–185`** — All `URLError` codes treated identically. At minimum, distinguish transient (retry) from permanent (surface).
- **`Services/JellyfinAPIClient.swift:21–28`** — Device ID in `UserDefaults` regenerates on reinstall. Use `UIDevice.current.identifierForVendor` (stable per-app across installs) or `ASIdentifierManager` (not allowed for non-advertising). `identifierForVendor` is the right call.
- **`Services/JellyfinAPIClient.swift:83,88`** — Line 83 sets a partial `X-Emby-Authorization` header, line 88 overwrites it with the full `buildAuthorizationHeader()` which *does* include the token. Line 83 is **dead code**, not a bug. Delete it.
- **`Services/ImageLoader.swift:69–114`** — Dedup with `NSLock` around a `[URL: Task]` dict. Subtle: the lock is released before awaiting `existingTask.value`, and cleanup (remove-from-dict) happens *after* the await. If two callers hit simultaneously, both may try to remove on completion — `NSLock` guards the dict so that's safe, but in the failure path the second caller gets a zombie `nil` from a completed-then-removed task. Small correctness risk, not critical. Simpler rewrite: use an `actor ImageRequestCoordinator` and let Swift handle the serialization.
- **`Services/ImageCache.swift`** — No image downsampling. A 6000×3375 backdrop is decoded full-res, occupying ~80MB of GPU-side memory per tile. Use `ImageIO` with `kCGImageSourceThumbnailMaxPixelSize` = the display size in pixels. This is often a single-digit-X memory reduction. `MediaItem.backdropImageURL` already accepts `maxWidth` so the server can do it — you just need the call site (`HeroBanner`, `DetailHeaderView`) to pass the actual pixel size of the screen region, not 1920.
- **`Services/ImageCache.swift:50–57`** — URL as cache key yields 300-char filenames. Hash with `SHA256` → base32 → fixed 32-char filenames.
- **`Services/ImageCache.swift`** — No response to `UIApplication.didReceiveMemoryWarningNotification`. Register in `init` and call `clearMemoryCache()`.
- **`Services/AuthenticationService.swift` (logout)** — Clears Keychain but doesn't call `POST /Sessions/Logout` on the server, so the access token remains valid server-side. Minor privacy issue, fix is one HTTP call.
- **`Utilities/KeychainHelper.swift:137–142`** — `clearCredentials()` uses `try?`, so keychain-delete failures are silent. Low risk in practice (keychain delete rarely fails), but log on failure.

### Strengths
- `AppleTVCodecSupport` — already called out, the best module in the app.
- `KeychainHelper` — textbook `Security.framework` usage, proper error enum.
- `Constants.swift` — centralized endpoints, UI metrics, Keychain keys.
- Authentication URL normalization (`AuthenticationService:81–94`).

---

## Tests

Three files, all Xcode template stubs:
- `MediaMioTests/MediaMioTests.swift` (17 lines) — one empty `@Test` function.
- `MediaMioUITests/MediaMioUITests.swift` (41 lines) — `testExample()` + `testLaunchPerformance()`, both empty bodies.
- `MediaMioUITestsLaunchTests.swift` (33 lines) — empty.

**Effectively no test coverage.** Top priorities for a test baseline:

1. **`PlaybackStreamURLBuilder` unit tests** (after player decomposition). Feed in sample `MediaItem` + settings, assert the generated URL. This is the highest-ROI test surface — it catches Jellyfin API drift instantly.
2. **Decoding tests** on `MediaItem`, `ItemsResponse` with saved JSON fixtures. If Jellyfin changes the wire format, you want to find out in CI.
3. **`AuthenticationService` integration test** with a stubbed `URLSession` — verify Keychain persists + `restoreSession` round-trips.
4. **A single UI test that launches the app** and asserts the server-entry field appears. Smoke test only.

Don't aim for percentage coverage yet — the god-object VM is untestable in its current shape, and testing untestable code first wastes effort. Decompose, then test.

---

## Prioritized remediation plan

### Phase A — P0 blockers (1 week)
1. **Decompose `VideoPlayerViewModel`** into 5 services + thin orchestrator. No behavior changes. Add unit tests on `PlaybackStreamURLBuilder` as you extract it.
2. **Consolidate focus**. Delete `FocusGuideViewController`. Demote `FocusManager` to a last-focus memo only. Rip out the `scrollTo` loops in `HomeView:393–403`.
3. **Fix tab-state preservation.** Hoist tab VMs to `MainTabView`-level `@StateObject`s so they survive tab switch.
4. **Parallelize home section loads.**
5. **Implement the Play button on Detail.** (This is the most embarrassing bug.)

### Phase B — P1 feature gaps (1–2 weeks)
6. Add cast/crew, trailers, chapters, external ratings to detail.
7. Fix bitrate picker (restart player with new URL on change, Infuse-style) or remove it.
8. Add intro *and* outro skip (`IntroCreditsController` once extracted).
9. Add `MPNowPlayingInfoCenter` metadata + artwork.
10. Build `AppEnvironment` DI container, remove three `*Wrapper` factories.
11. Shared `Pagination` and `EmptyState` components.
12. Seed unit tests on URL builder + model decoding.

### Phase C — P2 polish (1 week)
13. Retry/backoff on transient errors.
14. Image downsampling via `ImageIO`.
15. Memory-warning response in `ImageCache`.
16. Replace device ID with `identifierForVendor`.
17. Skeleton loaders during initial load.
18. Hero backdrop prefetch.
19. Delete `ContentView.swift` (Hello World template).

### Phase D — P3 feature parity (ongoing)
20. Quick Connect (high-ROI auth UX win).
21. mDNS / Bonjour server discovery.
22. Multi-user per server + saved-servers list.
23. Letter-jump in Library.
24. Search suggestions + recent searches.
25. Watchlist / favorites (backend already supports it — detail favorite button is a stub).
26. Offline download (Infuse's flagship).
27. Parental controls.

---

## What I'd *not* change

- Your **MVVM + Services layering** is clean. Don't rearrange it.
- **`AppleTVCodecSupport`** — leave alone, it's the strongest module.
- **Keychain implementation** — correct, don't touch.
- **`Codable` models** — mostly good, only add to them.
- **Hero-banner rotation-pause-on-focus** — this is exactly right.
- **LazyHStack in rows** — correct.
- **`.sheet` for detail** — correct (not `.fullScreenCover`).

---

## References

- [tvOS Human Interface Guidelines — Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection)
- [Jellyfin API docs](https://api.jellyfin.org/)
- [Swiftfin (reference open-source client)](https://github.com/jellyfin/Swiftfin)
- [Apple — AVFoundation Programming Guide](https://developer.apple.com/av-foundation/)
- [WWDC 2018 — "A Tour of UICollectionView" (tile reuse on tvOS)](https://developer.apple.com/videos/play/wwdc2018/225/)
