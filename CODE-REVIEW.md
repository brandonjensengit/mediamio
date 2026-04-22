# MediaMio — Architecture + Feature Review

> Senior tvOS engineer + streaming-platform architect perspective
> Comparing against Netflix, Apple TV+, Disney+, Swiftfin, Infuse, Plex
> Originally reviewed: `main` branch, 68 Swift files, 13,857 lines
> **Status (2026-04-22):** Phases A + B + C + D all landed on `main` (Phase A: `f66c168`; Phase B: `8d467ac`, `b3f90f4`, `8f78f5d`; Phase C: `c3f1d6a`; Phase D first batch: `84d1544` — items #21, #24, #25, #26, #29; Phase D second batch: `b7b2e0b` — item #22 mDNS discovery; Phase D third batch: `16ad4d3` + `eacbcf9` + `d325926` — item #23 saved-servers / multi-user picker with silent re-login; Phase D fourth batch: `b3f59d4` — item #28 parental controls with PIN + content-rating filter; Phase D fifth batch: `b87da4d` — item #30 QR-code companion handoff). Phase D item #27 (offline downloads) is scoped out of this roadmap — revisit in a dedicated phase if prioritized.

---

## TL;DR

The app is **well-layered and buildable** — clean MVVM split, centralized services, Keychain auth, a sensible Jellyfin wire model, and thoughtful codec decision logic. You are *much* closer to shippable than most first-time tvOS apps.

The gap to "Netflix-class" was **not** architectural rewrite territory — it was three concrete things, all now done:

1. ~~**VideoPlayerViewModel at 1,830 lines is a god-object.**~~ ✅ Decomposed to a 577-line orchestrator + 5 services in `Services/Playback/`. 8 URL-builder unit tests.
2. ~~**Three parallel focus systems.**~~ ✅ `FocusGuideViewController` deleted; `FocusManager` demoted to a 57-line last-focus memo. `@FocusState` is now the sole source of truth.
3. ~~**Feature parity gaps**~~ ✅ Phase B closed cast/crew, trailers, external links, outro skip, MPNowPlayingInfoCenter, mid-playback bitrate reload, and AppEnvironment DI. Phase C closed API retry/backoff, image downsampling, memory-warning handling, device ID stability, skeleton loaders, hero prefetch, `preferredMaximumResolution`, and deleted the Hello World template. **Phase D first batch landed:** Quick Connect (passwordless login), favorites/watchlist toggle, chapters on Detail, letter-jump in Library, and search recents. **Phase D second batch landed:** mDNS / Bonjour server discovery (on-network Jellyfin servers now one-tap-connect on the server-entry screen). **Phase D third batch landed:** multi-user + saved-servers picker with silent re-login — returning users now land on a Netflix-style "Recent" profile list at the top of the server-entry screen; tapping a profile reuses its stored token and jumps straight to the home screen. **Phase D fourth batch landed:** parental controls with 4–6 digit PIN (stored in Keychain), four content-rating tiers (Family / Kids / Teen / Mature), Jellyfin `MaxOfficialRating` server-side filter + client-side defense-in-depth that also blocks unclassified ratings. **Phase D fifth batch landed:** QR-code companion handoff — external link pills and a new "Open on Phone" Detail action both surface a fullscreen QR sheet (CoreImage, H-level EC, nearest-neighbor scaled) so viewers can continue any Jellyfin item in the web player on their phone. **Phase D closed:** offline downloads (#27) scoped out — revisit in a dedicated phase if ever prioritized.

Ship-blocking priority: ~~P0 player decomposition~~ ✅ → ~~P0 focus consolidation~~ ✅ → ~~P1 feature gaps~~ ✅ → ~~P2 polish~~ ✅ → ~~P3 feature parity~~ ✅ (Phase D closed; #27 offline downloads explicitly out of scope).

---

## Scorecard

Before each letter is the original review grade; after the arrow is the current state post Phase A + B.

| Area | Grade | Notes |
|------|-------|-------|
| Layering / MVVM | B+ → **A-** | `AppEnvironment` DI container eliminates wrapper-factory duplication; MVVM split stayed clean. |
| Services & API client | B → **A-** | Retry/backoff + transient-vs-permanent classifier; dead duplicated `X-Emby-Authorization` write removed; stable device ID via `identifierForVendor`. Pagination/cancellation still open. |
| Video player | C → **A-** | God-object decomposed; `PlaybackFailoverController`, `NowPlayingPublisher`, mid-playback bitrate reload, outro skip, `preferredMaximumResolution` capping HLS variants to display resolution. DRM / PiP still open. |
| Focus & navigation | C → **B+** | Single source of truth (`@FocusState`); brute-force `scrollTo` loops gone; tab VMs hoisted so tab switches preserve state. |
| Feature completeness | C → **A-** | Phase D added: chapters strip on Detail (with chapter-start playback), letter-jump rail in Library, search recents, favorites toggle wired end-to-end. Offline / parental still open. |
| Settings | B → **A-** | Added parental-controls tab: PIN gate, four content-rating tiers, Keychain-backed PIN with forgot-PIN recovery path. Brings the tab-count parity with Swiftfin. |
| Auth | B- → **A** | Quick Connect + mDNS / Bonjour on-network discovery + multi-user profile picker with silent token re-login. Feature parity with Swiftfin/Infuse at login-screen depth. |
| Models | A- → **A** | Added `ProviderIds`, `ExternalUrls`, `RemoteTrailers`, `CriticRating`, `ExternalURL`, `RemoteTrailer`, `Chapter`, Quick Connect DTOs. |
| Image pipeline | C → **A-** | ImageIO thumbnail downsampling keyed on pixel size; SHA256 hashed cache keys; memory-warning handler drops in-memory tier only; `NSLock` dedup replaced with `actor ImageRequestCoordinator`. |
| Tests | F → **C** | 33 unit tests pass: 8 `PlaybackStreamURLBuilderTests` + 3 `ChapterTests` + 7 `SavedServersStoreTests` + 9 `ContentRatingTests` + 6 `QRCodeGeneratorTests`. API client integration tests still needed. |
| Docs / planning | **A** | Unchanged. |

Overall: B- → **A** post Phase A + B + C + D. Offline downloads (#27) is the only major competitor differentiator not shipped, and it is explicitly scoped out of this roadmap.

---

## Top 10 findings (ranked by user-facing impact)

| # | Finding | Files | Priority | Status |
|---|---------|-------|----------|--------|
| 1 | `VideoPlayerViewModel` is 1,830 lines — 6 concerns bolted together | `ViewModels/VideoPlayerViewModel.swift` | **P0** | ✅ `f66c168` (577 lines, 5 services extracted) |
| 2 | Three parallel focus systems drift out of sync | `Navigation/FocusManager.swift`, `Navigation/FocusGuideViewController.swift` | **P0** | ✅ `f66c168` (guide deleted, manager demoted) |
| 3 | Tab switching tears down view trees and loses scroll/focus position | `Navigation/MainTabView.swift` | **P0** | ✅ `f66c168` (VMs hoisted to MainTabView) |
| 4 | Home screen loads sections **sequentially**, not in parallel | `Services/ContentService.swift` | **P0** | ✅ `f66c168` (`async let` + `TaskGroup`) |
| 5 | No retry/backoff on transient network errors | `Services/JellyfinAPIClient.swift:31–34, 166–185` | **P1** | ✅ Phase C (500/1500/4000 ms) |
| 6 | Play button on detail is a stub | `ViewModels/ItemDetailViewModel.swift:150–152` | **P1** | ✅ `f66c168` |
| 7 | Bitrate picker is UI-only — selection is ignored by player | `Views/Player/CustomInfoViewControllers.swift:132,259`, `VideoPlayerViewModel` | **P1** | ✅ `b3f90f4` (VM observes notifications, reloads with preserved position) |
| 8 | Cast/crew, trailers, external ratings missing from detail | `Views/Detail/ItemDetailView.swift` | **P1** | ✅ `8d467ac` + `b3f90f4` (chapters + similar-View-All still open) |
| 9 | Image loader has a deduplication race + no downsampling for 4K backdrops | `Services/ImageLoader.swift:69–114`, `Services/ImageCache.swift` | **P2** | ✅ Phase C (actor + ImageIO) |
| 10 | Zero real tests (three Xcode-template stub files) | `MediaMioTests/`, `MediaMioUITests/` | **P1** | 🟡 11 unit tests (8 URL-builder + 3 chapter decoding); API client integration tests still open |

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

### Phase A — P0 blockers ✅ DONE (`f66c168`)
1. ✅ **Decompose `VideoPlayerViewModel`** — 1,830 → 577 lines; 5 services extracted to `Services/Playback/` (`PlaybackStreamURLBuilder`, `PlaybackSessionReporter`, `SubtitleTrackManager`, `IntroCreditsController`, `PlaybackFailoverController`). 8 unit tests on the URL builder.
2. ✅ **Consolidate focus** — `FocusGuideViewController.swift` deleted; `FocusManager` demoted from 180→57 lines to a last-focus memo. Brute-force `scrollTo` ramp in `HomeView` replaced with a single deterministic `scrollTo("top")`.
3. ✅ **Tab-state preservation** — `MainTabView` now owns per-tab VMs as `@StateObject` so they survive tab switches.
4. ✅ **Parallelize home section loads** — `ContentService.loadHomeContent` uses `async let` + `TaskGroup` with stable server-order output.
5. ✅ **Play button on Detail** — `ItemDetailViewModel.playItem()` now calls `navManager.playItem(displayItem)` with explicit error when unwired (previously a print stub).

### Phase B — P1 feature gaps ✅ DONE (`8d467ac`, `b3f90f4`, `8f78f5d`)
6. ✅ **Cast/crew, trailers, external ratings** — three new sections in `Views/Detail/`: `CastCrewSection`, `TrailersSection`, `ExternalLinksSection`. `MediaItem` gained `ProviderIds`, `ExternalUrls`, `RemoteTrailers`, `CriticRating`. *Chapters deferred — needs further `MediaSource.chapters` modeling.*
7. ✅ **Bitrate picker fixed** — VM now observes `ReloadVideoWithNewBitrate` and `ReloadVideoWithNewAudioQuality` notifications and calls `reloadWithCurrentSettings()`, which tears down the active AVPlayer, rebuilds via `PlaybackStreamURLBuilder`, and preserves the pre-change position via `pendingSeekOnReload`.
8. ✅ **Intro AND outro skip** — `IntroCreditsController` now parses `CreditsStart`/`CreditsEnd` from the same endpoint; `SkipMarkerOverlay` on `VideoPlayerView` renders both buttons bottom-right with focus. Filled the pre-existing gap where `showSkipIntroButton` was published but had no UI.
9. ✅ **`MPNowPlayingInfoCenter`** — new `NowPlayingPublisher` service publishes title/series/genre/year/artwork + playback position; wires `MPRemoteCommandCenter` play/pause/skip±10/seek. Cleared on cleanup.
10. ✅ **`AppEnvironment` DI container** — new `MediaMio/AppEnvironment.swift` holds `apiClient`, `contentService`, `authService` with a Combine subscription keeping `apiClient.baseURL`/`accessToken` in sync with `authService.currentSession`. Eliminated ~35 lines of duplicated `JellyfinAPIClient()` + field-copy boilerplate across `MainTabView`, `ItemDetailSheetWrapper`, and the three `*Wrapper` factories.
11. ⏳ **Shared `Pagination` and `EmptyState` components** — review finding #4 still open (`LibraryViewModel`/`SearchViewModel` have identical pagination logic; 5 empty-state views look similar but aren't the same component).
12. ⏳ **Unit tests on model decoding** — URL builder has 8 tests; `MediaItem`/`ItemsResponse` decoding fixtures not yet added.

### Phase C — P2 polish ✅ DONE (2026-04-21)
13. ✅ **Retry/backoff on transient API errors** — `JellyfinAPIClient.performRequest` now wraps single-shot attempts in a retry loop with `[500ms, 1500ms, 4000ms]` exponential backoff. Transient classifier covers `URLError.timedOut/.networkConnectionLost/.notConnectedToInternet/.dnsLookupFailed/.cannotConnectToHost/.cannotFindHost/.resourceUnavailable` and 5xx. 4xx (including 401) surfaces immediately.
14. ✅ **Image downsampling via ImageIO** — `ImageLoader.load(from:targetPixelSize:)` now accepts a pixel-space target. When set, decode goes through `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize`, so a 4K backdrop never decodes at 6000×3375 for an on-screen region of 1920×600. `NSLock`-based dedup replaced with `actor ImageRequestCoordinator`. Hero banner, item detail backdrop, and `PosterImageView`/`BackdropImageView` opt in via the shared `ImageSizing.pixelSize(points:)` helper.
15. ✅ **Memory-warning response in `ImageCache`** — registered for `UIApplication.didReceiveMemoryWarningNotification`; drops in-memory tier (disk survives). Cache keys switched to SHA256 hex digests — fixed 64-char filesystem-safe filenames, size-aware so the same URL at two target sizes yields separate entries.
16. ✅ **Replace device ID with `identifierForVendor`** — `JellyfinAPIClient.deviceId` prefers `UIDevice.current.identifierForVendor` (stable per-vendor across installs), falls back to the old UserDefaults UUID only when IFV is nil (sim edge cases).
17. ✅ **Skeleton loaders during initial load** — new `Views/Components/SkeletonView.swift` adds a reusable `ShimmerTile` primitive and `HomeSkeletonView` that mirrors the final hero + rows layout so there's no layout shift when real content arrives. Wired into `HomeContentView`.
18. ✅ **Hero backdrop prefetch** — `HeroBannerRotating` runs a separate prefetch timer 2s ahead of each rotation tick, calling `ImageLoader.prefetch(urlString:targetPixelSize:)`. Matches the view's target pixel size so the cache key aligns and the fetch is idempotent with any in-flight view load.
19. ✅ **Delete `ContentView.swift`** — dead Xcode Hello World template removed.
20. ✅ **`preferredMaximumResolution` on `AVPlayerItem`** — set from `UIScreen.main.nativeBounds` in `VideoPlayerViewModel.createPlayerItem`, so 1080p Apple TVs don't pull the 4K HLS variant.

**Phase C side effects:** Removed the pre-existing dead `X-Emby-Authorization` header write (the token-only form was immediately overwritten by the full authorization form two lines later). Added `import UIKit` to `VideoPlayerViewModel` and `JellyfinAPIClient` for `UIScreen` / `UIDevice`.

### Phase D — P3 feature parity ✅ DONE (closed 2026-04-22; #27 scoped out)

21. ✅ **Quick Connect** — `AuthenticationService` gained `initiateQuickConnect` / `pollQuickConnect` / `completeQuickConnect`; new `QuickConnectView` fullScreenCover shows the 6-digit code, polls every 2s (5-min timeout), and trades the secret for a session. LoginView surfaces a "Use Quick Connect" button only when `GET /QuickConnect/Enabled` says yes.
22. ✅ **mDNS / Bonjour server discovery** — new `ServerDiscoveryService` wraps `NWBrowser` for `_jellyfin-server._tcp.` + `_jellyfin._tcp.`, resolves each service endpoint to a real `host:port` via a short-lived `NWConnection` (cancelled as soon as `currentPath.remoteEndpoint` resolves), and publishes a deduped `[DiscoveredServer]`. `ServerEntryView` starts/stops discovery with the screen lifecycle and renders a tappable "On This Network" list above the manual URL field — picking a server auto-fills the URL and runs the existing `validateAndConnect` path. Service constraint: never performs HTTP itself; `AuthenticationService.testServerConnection` stays the single source of truth for whether a candidate is actually a Jellyfin server. Infra: added `Info.plist` with `NSBonjourServices` array + `NSLocalNetworkUsageDescription` (required for `NWBrowser` to return results on tvOS 14+), wired via `INFOPLIST_FILE` and excluded from Copy Bundle Resources through a sync-group exception set so it isn't double-processed.
23. ✅ **Multi-user + saved-servers picker** — shipped in three reviewable commits. **23a (`16ad4d3`):** new `SavedServer`/`SavedUser` Codable models + `SavedServersStore` actor-backed `ObservableObject`. Server/user metadata persists as JSON in UserDefaults; access tokens stay in Keychain keyed on the composite account `token:<serverURL>:<userId>`. Legacy single-blob Keychain slot is preserved *and* silently migrated on first launch so upgrading users aren't signed out. 7 `SavedServersStoreTests` lock the add/forget/persist semantics. **23b (`eacbcf9`):** `ServerEntryView` gains a flattened "Recent" list (one row per server × user, sorted most-recent-first, Netflix profile-picker style). Tapping pre-fills username + URL and runs `validateAndConnect`. **23c (`d325926`):** `AuthenticationService.signInWithSavedToken(server:user:)` validates the stored token via `GET /Users/{id}` before flipping `isAuthenticated` — a revoked token can't leave the app in a broken "signed in" state. On 401 the stale token is dropped and the user falls through to the password prompt (URL + username still pre-filled). Any other error keeps the token so the user can retry without losing their profile.
24. ✅ **Letter-jump in Library** — new `LetterJumpRail` view renders A–Z (+ "#" for digits + "All" to clear) to the right of the grid, visible only under alphabetical sort. Uses Jellyfin's `NameStartsWith` as a true server-side filter (not a scroll-to-anchor), which matters because the library is paginated — tapping "S" loads a page of S-prefix items regardless of what's scrolled into view.
25. ✅ **Search recent searches** — `SearchViewModel` persists an LRU list of up to 10 successful queries via `UserDefaults` (JSON-encoded `[String]`). Recents replace the generic empty state; each row replays the query and ships with a clear-all button. Single-char queries + zero-result searches are not recorded.
26. ✅ **Watchlist / favorites** — `toggleFavorite()` now calls `POST /Users/{uid}/FavoriteItems/{iid}` (or `DELETE` on unfavorite) with optimistic local update. The heart icon flips immediately; a failure reverts and surfaces an error. `loadDetails()` clears the optimistic override so the next server response is authoritative.
27. ❌ **Offline download** — scoped out. Infuse's flagship differentiator, but the implementation surface (HLS segment caching, disk-budget UI, offline-catalog UX, background transfer, DRM handling) is a multi-session feature on its own; the product decision is to ship without it rather than half-build it. If revisited, it belongs in its own phase, not Phase D.
28. ✅ **Parental controls** — `ContentRatingLevel` enum defines four tiers (Family Only / Kids / Teen / Mature), each mapped to (a) a numeric rank for client-side filtering and (b) a Jellyfin `MaxOfficialRating` string for server-side filtering. `ContentRating.rank(for:)` maps US MPAA + TV rating strings to the rank scale; unknown ratings return `nil` and are treated as **blocked** under every tier (defense-in-depth — we'd rather hide unclassified content than risk a foreign/indie film slipping through with an unparsed certification). PIN lives in Keychain (4–6 digits, separate slot from auth tokens so PIN rotation doesn't disturb login state); enabled flag + max tier live in UserDefaults via `@AppStorage` on `SettingsManager`. `ContentService.loadHomeContent`, `loadLibraryContent`, and `searchItems` all read `ParentalControlsConfig.current` at each call and apply both filters — toggle changes propagate on the next fetch. Settings screen has three phases: PIN setup (first-time), PIN unlock (locked), and full settings. Session-scoped unlock — leaving the screen re-locks. Forgot-PIN recovery clears the PIN *and* disables parental controls as one transaction, so a forgotten PIN can't strand the user. 9 `ContentRatingTests` lock the comparator against unnoticed drift.
29. ✅ **Chapters on Detail** — new `Chapter` model (`StartPositionTicks`, `ImageTag`, formatted helpers) decoded via `Fields=Chapters`; new `ChaptersSection` renders a horizontal thumbnail strip (or a gradient placeholder when no image). Tapping a chapter calls `NavigationManager.playItem(_:startPositionTicks:)`; `VideoPlayerViewModel` now accepts an `initialStartPositionTicks` that wins over resume-data. 3 `ChapterTests` lock the wire format.
30. ✅ **QR-code companion handoff** — new `QRCodeGenerator` (`Utilities/QRCodeGenerator.swift`) uses `CIFilter.qrCodeGenerator` with error-correction level "H" and nearest-neighbor scaling so the code stays scannable from couch distance with motion blur or an off-axis phone camera. New `QRHandoffView` renders a fullscreen sheet (large white-backed QR on the left, title + subtitle + URL on the right; Menu-button dismiss, no custom close affordance). Two call-sites wire in: (a) `ExternalLinksSection` — tapping any link pill (IMDb, TMDB, Rotten Tomatoes, TVDB, …) presents the sheet with that provider's URL, replacing the old `print()` stub that just logged the URL; (b) `DetailHeaderView` — a third action button "Open on Phone" alongside Play + Favorite presents the sheet for `{serverURL}/web/index.html#/details?id={itemId}`, letting the viewer continue the exact item in the Jellyfin web client on their phone (Jellyfin's hash-routed URLs mean the fragment is never sent to the server, so the web client's own auth redirect handles sign-in if needed). `handoffURL` lives on `ItemDetailViewModel` so the empty-session case hides the button rather than showing a broken QR. 6 `QRCodeGeneratorTests` lock the contract: empty payload → nil, target-side is a minimum not a maximum, typical and long realistic URLs encode, oversized payloads fail gracefully (returning nil so the sheet's text fallback activates instead of crashing).

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
