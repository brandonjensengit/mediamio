# MediaMio Design Plan — Navigation & Menu Refresh

**Started:** 2026-04-22
**Status:** All 7 items shipped. 2026-04-22: Item 1 (`/colorize`). 2026-04-23: Items 2 (`/bolder`), 3 (`/normalize`), 4 (`/arrange`), 5 (`/extract`), 6 (`/distill`), 7 (`/polish`).
**Scope:** Navigation chrome + menu styling across the app. Not touching business logic, not touching video player pipeline.

## Decisions locked in

- **Q1 tone:** Premium cinematic (default — Brandon didn't override)
- **Q2 brand color:** Warm amber `#e8a13b` (`oklch(0.78 0.15 75)`) — projector-tungsten
- **Background:** `#0d0f15` (`oklch(0.15 0.015 260)`) — cool dark blue-black
- **Surface ramp:** `surface1 #161922` → `surface2 #1f2330` → `surface3 #2c303f`
- **Off-limits this pass:** Splash screen + Video Player (true-black intentional)

## Item 1 — what landed

- New palette tokens in `MediaMio/Utilities/Constants.swift` (Constants.Colors)
- All 28+ `Color(hex: "667eea")` references → `Constants.Colors.accent`
- All `Color.black.ignoresSafeArea()` (except Splash + Player) → `Constants.Colors.background.ignoresSafeArea()`
- All `.listRowBackground(Color.black.opacity(0.3))` → `.listRowBackground(Constants.Colors.surface1)`
- Five surface fills (SidebarView focused chip, PosterCard progress bar, HeroBanner secondary button, LibraryToolbar sort/search pills) → surface tokens
- `SettingsManager.accentColor` AppStorage default flipped from `"667eea"` → `"e8a13b"`
- 26 source files touched, build green for `tvOS Simulator,name=Apple TV` (Apple TV, OS 26.0)

## Item 2 — what landed

- New `MediaMio/Views/Components/TopNavBar.swift` component:
  - Leading: `AppLogo` (60pt) + `LogoText` (140pt wide) — promoted from orphaned SidebarView
  - Center: 4 tab chips (Home/Search/Library/Settings) with `matchedGeometryEffect` amber underline — same animated pattern Library's CategorySelector uses
  - Trailing: user name + first-initial avatar circle (amber on dark bg), pulls from `AuthenticationService.currentSession`
  - `.focusSection()` wrapper so tvOS remote treats the bar as one sticky focus container
- `MediaMio/Navigation/MainTabView.swift` — replaced stock `TabView { .tabItem { ... } }` with custom `ZStack` + `VStack`:
  - `TopNavBar` at top
  - Inner `ZStack` keeps all 4 tab subtrees mounted (same lifecycle contract as native TabView) so scroll position, focus memory, and in-flight loads survive tab switches
  - Hidden tabs get `.opacity(0)` + `.disabled(true)` — removes them from focus engine
- Build green for `tvOS Simulator,name=Apple TV,OS=26.0`. `TopNavBar.o` compiled (Xcode synced-folder inclusion confirmed)

### Known trade-offs carried into Item 3+

- ~~Tab chips use an inline `scaleEffect(1.06)` on focus~~ — resolved in Item 3.
- No scroll-reactive background on the nav bar yet (plan called for transparent → `.ultraThinMaterial` when scrolled). Deferred because it needs scroll-offset plumbing from each tab. Tackle in Item 4 (`/arrange`) or a dedicated follow-up.
- Nav bar sits in a `VStack` above content (not overlaid). Hero banners lose the "image extends under the bar" effect. If Brandon wants that cinematic edge-to-edge feel, switch to `.safeAreaInset(edge: .top)` or `.overlay(alignment: .top)` — easy to revisit.
- `SidebarView.swift` is now doubly-orphaned (logo assets moved out of it). Item 5 (`/extract`) should delete it.

## Item 3 — what landed

- New `MediaMio/Utilities/FocusModifiers.swift`:
  - `.chromeFocus()` / `.chromeFocus(isFocused:)` — subtle lift (scale 1.03, -4pt rise, soft dark shadow). For nav chips, settings rows, toolbar pills, sidebar rows.
  - `.contentFocus()` / `.contentFocus(isFocused:)` — bigger lift (scale 1.10, -8pt rise, deeper dark shadow, spring animation). For posters, hero CTAs, detail cards.
  - Both tiers have Environment-reading and explicit-Bool overloads so callers inside a `Button(.plain)` label and callers with a local `@FocusState` can both use the same API.
- Tokens live in `Constants.UI.ChromeFocus` / `Constants.UI.ContentFocus` (scale, yOffset, shadowColor, shadowRadius, shadowY, animation).
- Chrome surfaces routed to `.chromeFocus()`:
  - `TopNavBar.TopNavTabChip` (replaces the inline `scaleEffect(1.06)` Item 2 flagged).
  - `FocusableButton` (dropped the `.white.opacity(0.4)` glow — the biggest AI-slop tell in the button set; also removed the unused `@FocusState`/`@Environment` pair).
  - `SettingsView.SettingsRow` and the sibling `SettingsRowWithFocus`.
  - `SidebarView.SidebarMenuButton`.
  - `LibraryToolbar` sort + search pills (switched from `.buttonStyle(.card)` to `.buttonStyle(.plain)` so our chrome lift isn't layered on top of tvOS's native card parallax — one treatment, not two).
- Content surfaces routed to `.contentFocus()`:
  - `PosterCard` — same dark-shadow direction, now via tokens; `zIndex(999)` preserved so a focused poster still overlays row siblings.
  - `HeroBannerButton` (dropped `.white.opacity(0.3)` glow).
  - Four Detail cards that also had `.white.opacity(0.3)` glows: `ExternalLinksSection.ExternalLinkCard`, `CastCrewSection` person card, `ChaptersSection` chapter card, `TrailersSection` trailer card.
- Legacy `Constants.UI.focusScale` / `focusShadowRadius` kept for the two auth-screen callers in `ServerEntryView.swift` that weren't in Item 3's explicit scope; they can migrate in a later pass.
- Build green for `tvOS Simulator,name=Apple TV,OS=26.0`. No new warnings.

### Known trade-offs carried into Item 4+

- ~~`ExternalLinksSection.ExternalLinkCard` still uses `Color.white.opacity(0.25 / 0.1)`~~ — resolved in Item 6.
- ~~Auth views (`ServerEntryView.swift:320,364`) still call legacy `Constants.UI.focusScale` / `focusShadowRadius`~~ — resolved in Item 7; legacy tokens deleted from `Constants.UI`.
- ~~`ItemDetailView` season picker still uses scale-only focus~~ — resolved in Item 7; routed through `.chromeFocus(isFocused:)`, selected chip re-tokened to `accent` on `background`.

## Item 4 — what landed

- `MediaMio/Views/Settings/SettingsView.swift`:
  - Dropped `.grouped` List + per-row `.listRowBackground` bookkeeping for `ScrollView { VStack(spacing: 32) { sectionStack · Rectangle divider · sectionStack } }`.
  - `SettingsRow` is now the row chrome (surface1 fill by default, surface3 when focused, 24pt H / 20pt V padding, minHeight 120pt, corner `cardCornerRadius`). Focus lift still owned by `.chromeFocus()` from Item 3.
  - Icon frame 64×64 (was 60×60), label stack spacing bumped 4→6, subtitle color standardized to `.white.opacity(0.6)` (was `.secondary`), chevron `.white.opacity(0.4)` (was `.secondary`) — predictable delta on focus instead of system-managed color.
  - Section divider: `Rectangle().fill(Constants.Colors.divider).frame(height: 1)` between the media and account stacks.
- `MediaMio/Views/Components/HeroBanner.swift`:
  - Replaced the `HStack { 4× MetadataBadge }` chip row with a single `.title3` `.medium` typographic line `"2025 · PG-13 · 1h 55m · ★ 6.1"` in `.white.opacity(0.85)` with a soft drop shadow for legibility over the backdrop.
  - Composed via new `HeroBannerContent.metadataLine` computed helper — returns nil when every field is missing so the line collapses gracefully.
  - `MetadataBadge` struct retained because `ItemDetailView` still uses it; ItemDetailView deliberately stays chip-styled since the Detail surface has more horizontal room.

## Item 5 — what landed

- New `MediaMio/Views/Components/MenuChip.swift`:
  - Optional leading icon · text · optional trailing icon, surface1 fill, `chromeFocus` tier. Single shared pill for toolbar actions.
- New `MediaMio/Views/Components/CTAButton.swift`:
  - Canonical full-width button with primary/secondary/destructive styles; primary fills `accent`, destructive uses muted cinematic red (`#a33a2e`) instead of the shouty `.red.opacity(0.8)` previous destructive path. Chrome focus tier.
- `FocusableButton` collapsed to a thin wrapper over `CTAButton` — the 9 existing callers stay untouched; all future code should use `CTAButton` directly.
- `LibraryToolbar` search pill now uses `MenuChip`; sort pill keeps its inline HStack only because `Menu.label` requires a View (not a Button) so the chip can't be nested inside the menu trigger directly. Visuals match.
- Dead-code removal:
  - Deleted `MediaMio/Views/Components/SidebarView.swift` entirely (SidebarView + MenuItem enum).
  - Removed orphaned `struct HomeView` (pre-MainTabView root) + its `#Preview` from `HomeView.swift`. `HomeContentView`, `NavigationCoordinator`, `ErrorView`, and the detail/library/search wrappers remain — they're still used by `MainTabView`.
  - Removed the now-useless `isSidebarVisible: Binding<Bool>` parameter from `HomeContentView` and the `.constant(false)` pass-through at `MainTabView.HomeTabView`.

## Item 6 — what landed

- `SettingsManager.subtitleSummary`: dropped the `"Default:"` prefix AND upgraded from `defaultSubtitleLanguage.uppercased()` (`"ENG"`) to `Locale.current.localizedString(forLanguageCode:)?.capitalized` (`"English"`) with a code-uppercased fallback.
- `ExternalLinksSection`:
  - `ExternalLinkRow` background `Color.white.opacity(0.08)` → `Constants.Colors.surface1`.
  - `ExternalLinkPill` focus background `Color.white.opacity(0.25/0.1)` → `surface3` focused / `surface2` resting.

## Item 7 — what landed

- New `MediaMio/Extensions/Color+Hex.swift`:
  - Promoted the `Color(hex:)` initializer out of the bottom of `MainTabView.swift`. One home for the extension alongside any future `Color+*` / `View+*` helpers.
- `white.opacity` → surface-token sweep (backgrounds only; text/shadow uses left alone):
  - `SearchView` — field `0.1` → `surface1`, filter menu `0.15` → `surface2`, recent-search row focus `0.18/0.08` → `surface3/surface1` + inline scale/animation replaced by `.chromeFocus(isFocused:)`.
  - `LibraryView` toolbar picker `0.15` → `surface2`.
  - `QuickConnectView` code card `0.1` → `surface1`.
  - `ItemDetailView.SeasonButton`: `0.2` unselected → `surface2`; selected chip re-palette `.white/.black` → `accent/background`, inline `scaleEffect + .white.opacity(0.3)` glow replaced with `.chromeFocus(isFocused:)`.
- Auth rows (`ServerEntryView` saved & discovered rows): migrated off legacy `Constants.UI.focusScale` / `focusShadowRadius` / `animationDuration` → `.chromeFocus(isFocused: envFocused)`. `.white.opacity(0.4)` shadow glow removed.
- Deleted now-unreferenced legacy tokens `focusScale` / `normalScale` / `focusShadowRadius` / `animationDuration` from `Constants.UI`.
- Build green `tvOS Simulator,name=Apple TV,OS=26.0` after each item.

### Leftover notes (optional future sweep)

- `YearRangePickerModal`, `BitratePickerModal`, `LibrarySearchModal`: still use `Color.white.opacity(0.05–0.18)` for picker cells. Low visibility on 10-foot UI; fold into a modal-surface pass if ever needed.
- `CastCrewSection` person-fallback Circle stroke/fill still uses white-opacity. Borderline acceptable on the Detail surface but would tighten with `surface2` + `accent` focus stroke if fully normalized.
- `Constants.Colors.primary` / `cardBackground` / `secondary` aliases still have callers across auth + PosterCard progress fill. Kept as-is; rename in a dedicated refactor pass.

---

## Context for fresh session

- This plan was produced by running `/critique` on the nav/menu surfaces against frontend-design anti-patterns.
- The app is **MediaMio**, a Jellyfin client for Apple TV (tvOS 26). Bundle id `com.bran.jellyfintv`. Competitors: Apple TV app, Netflix, Plex, Infuse.
- Just before this critique, the `fix-unnecessary-transcode.md` work was completed and verified: default `streamingMode` flipped from `.transcode` → `.auto` and `SubtitleMethod` changed from `Encode` → `Hls` for non-transcode URLs. Do NOT re-open that ticket.
- No design-context file exists yet (`.impeccable.md` and `CLAUDE.md` both absent at repo root). If you want proper framing, run `/teach-impeccable` once before starting item 1 — it writes the context file and dramatically improves the downstream `/colorize` and `/bolder` output.

---

## Baseline scores (re-run `/critique` after work to compare)

- **AI Slop Test**: FAILS — the design reads as AI-generated at first glance.
- **Nielsen 10 Heuristics**: 24/40 (mid-range).
  - Consistency and Standards: 1/4 (four different nav patterns across the app)
  - Aesthetic and Minimalist: 2/4 (hero badges cluttered)
  - User Control and Freedom: 2/4
  - Error Prevention: 2/4
  - Help and Documentation: 2/4

Target after all 7 items: **~32/40**, AI Slop Test passes.

## The 7 AI-slop tells currently in the codebase

| Tell | Files |
|---|---|
| `#667eea` periwinkle accent | `MainTabView.swift:68`, `SettingsView.swift:143,167`, `Constants.Colors.primary` |
| `Color.white.opacity(0.1/0.2/0.3)` grays everywhere | `LibraryToolbar.swift:60,76`, `SidebarView.swift:103`, `HeroBanner.swift:307`, `PosterCard.swift:148` |
| Pure `Color.black` backgrounds | `LibraryTabView.swift:27`, `SettingsView.swift:27`, `HomeView.swift:21,38` |
| Generic white focus glow | `FocusableButton.swift:62-63`, `HeroBanner.swift:339-342` |
| Uniform `RoundedRectangle(cornerRadius: 8/10)` | `SettingsView.swift:166`, `LibraryToolbar.swift:61,77`, `SidebarView.swift:102`, `HeroBanner.swift:333` |
| Stock `TabView { .tabItem { Label } }` with zero customization | `MainTabView.swift:42-66` |
| "Dark mode with glowing accents" overall feel | System-wide |

## What's working — don't touch

1. Library tab's `CategorySelector` with `matchedGeometryEffect` animated underline — `LibraryTabView.swift:77-109`. Use this pattern as reference when rebuilding top nav.
2. Hero banner layout (`HeroBanner.swift:201-271`) — content structure is 80% there; needs styling, not restructuring.
3. Settings rows showing live `...Summary` state — `SettingsView.swift:36-106`. Recognition-over-recall win.
4. Progress bar overlay on resume posters — `PosterCard.swift:42-47`.

---

## Open questions — decide BEFORE item 1

These were asked but not yet answered. Item 1 (`/colorize`) needs Q1 + Q2 to produce non-generic output.

**Q1. Tone direction:**
- A. Premium cinematic (Apple TV / Infuse vibe)
- B. Warm editorial (Letterboxd / Criterion Channel)
- C. Retro / neon-synth (old Plex, '80s VHS)
- D. Brutalist / raw (Radarr-style server admin, cleaned up)
- E. Something else

**Q2. Brand color:**
- A. Media/cinema (amber, theater-red, gold)
- B. Jellyfin-adjacent but distinct (teal/emerald shift)
- C. Custom bold color
- D. "Just not periwinkle" — pick based on Q1

**Q3. Off-limits / already-done surfaces** — likely leave as-is:
- Library CategorySelector underline (flagged as the good pattern)
- Hero banner layout (restyle, don't restructure)
- Settings sub-screens (Playback/Streaming/Subtitles sub-pages)
- Video player HUD (out of nav/menu scope)

---

## The 7 items — sequence and detail

Run in this order. Each is independently shippable.

### 1. `/colorize` — Replace the palette
**Why first:** biggest AI-slop kill per hour. Every subsequent command pulls from the new palette.
**What:**
- Replace `#667eea` (periwinkle) with a brand color per Q2 answer.
- Define shades in OKLCH so dark/light variants stay perceptually even.
- Tint neutrals toward the brand hue — kill pure `Color.black` (`LibraryTabView.swift:27`, `SettingsView.swift:27`, `HomeView.swift:21,38`). Define `Constants.Colors.background` e.g. `Color(hex: "0a0a0e")` or OKLCH-derived.
- Kill the `.white.opacity(0.1/0.2/0.3)` formula — replace with a tinted neutral scale (e.g. `Constants.Colors.surface1/2/3`).
**Risk:** low — single-file find/replace for `#667eea`; scale change for neutrals. No layout impact.

### 2. `/bolder` — Rebuild top navigation bar
**Why second:** the single most-visible chrome element. Sets the identity that Apple TV / Netflix nail and MediaMio currently has zero of.
**What:**
- Stop using stock `TabView { .tabItem { Label } }`. In `MainTabView.swift:42-66`, wrap the TabView with `.toolbar(.hidden, for: .tabBar)` and add a custom top bar overlay.
- Custom bar = `HStack`: `AppLogo` + `LogoText` at leading edge (assets already exist but are orphaned in `SidebarView.swift:20-28`), `HStack` of custom tab chips in the center, profile/user avatar at trailing edge.
- Use the Library tab's `matchedGeometryEffect` underline pattern (`LibraryTabView.swift:88-99`) for selected-state indication.
- Background that responds to scroll: transparent at hero, `.ultraThinMaterial` once scrolled.
- Sizing: logo ~80pt tall, tab text `.title2` weight `.semibold`, 10-foot UI scale.
**Risk:** medium — touches the focus engine wiring. Test that tab selection still drives `navigationManager.selectedTab`.

### 3. `/normalize` — Unify focus treatments
**Why third:** removes the "random scale + random shadow" feel. After this, every focusable surface looks intentional.
**What:**
- Define in `Constants.swift`:
  - `ChromeFocus`: scale 1.03, subtle inner material highlight, 6pt y-offset, no glow. For nav chips / settings rows / toolbar buttons.
  - `ContentFocus`: scale 1.10, soft dark shadow `.black.opacity(0.5)` 24pt blur 12pt y-offset, no glow. For posters / hero buttons.
- Apply everywhere:
  - `FocusableButton.swift:60-65` → `ChromeFocus`
  - `HeroBanner.swift:338-342` (HeroBannerButton) → `ContentFocus`
  - `PosterCard.swift:92-100` → `ContentFocus` (keep current direction of black shadow, lower opacity)
  - `SettingsView.swift:167-170` (SettingsRow) → `ChromeFocus`
  - `SidebarView.swift:103-106` (if still exists after item 5) → `ChromeFocus`
  - `LibraryToolbar.swift` sort/search pills → `ChromeFocus`
- Remove every `.white.opacity(0.4)` shadow. That's the AI-glow signal.
**Risk:** low — cosmetic-only changes.

### 4. `/arrange` — Reflow Settings + Hero metadata
**Why:** the `.grouped` List is wrong for 10-foot UI; the hero badge row is cluttered.
**What:**
- `SettingsView.swift:29-113`: replace `List { Section { NavigationLink(...) } }` with `ScrollView { LazyVStack }`. Each row 120-140pt tall, 24pt horizontal / 20pt vertical padding, 12pt inter-row spacing, subtle 1px divider.
- `HeroBanner.swift:211-228`: remove the chip chrome. Render metadata as a single line — `"2025 · PG-13 · 1h 55m · ★ 6.1"` in `.title3` medium weight, `.white.opacity(0.85)`.
**Risk:** low-medium — Settings layout change needs focus re-verification.

### 5. `/extract` — Consolidate button/chip components
**Why:** four different button treatments across the app is chaos. One `MenuChip` + one `CTAButton` component, used everywhere.
**What:**
- New `Components/MenuChip.swift` — single pill used by `LibraryToolbar` sort/search, top-nav chips, future `HeroBannerButton.secondary`.
- New `Components/CTAButton.swift` — primary white-filled variant for Hero's Play/Resume, destructive variant for sign-out / reset.
- Delete `SidebarView.swift` entirely if not wired (check `HomeView.swift:24-36` — current theory is it's legacy from before `MainTabView` and can be removed). OR promote it and delete the top TabView. Pick one. Don't leave both.
- `FocusableButton.swift` — keep, but route through `CTAButton` so styles converge.
**Risk:** medium — touching shared components. Build and smoke-test after.

### 6. `/distill` — Trim visual noise
**Why:** Hero is busy after items 1-5; pass through and remove redundant chrome.
**What:**
- Remove the "Default:" prefix in `SettingsManager.swift:91-94` subtitle summary — show `"English"` not `"Default: ENG"`.
- If any items 1-5 left behind redundant surrounding chrome, strip it.
**Risk:** low.

### 7. `/polish` — Final cleanup
**Why:** runs last per critique skill convention.
**What:**
- Move `Color(hex:)` extension out of `MainTabView.swift:209-234` into `MediaMio/Extensions/Color+Hex.swift`.
- Audit for any remaining `.white.opacity(...)` grays; replace with the new tinted neutrals.
- Run a 4K screenshot pass of Home / Library / Settings / Detail / Player and eyeball at actual TV viewing distance.
- Re-run `/critique` to confirm scores moved. Target: Nielsen 32+/40, AI Slop Test passes.
**Risk:** near-zero.

---

## If Q1/Q2 come back as "I don't know, you pick"

Default direction: **Premium cinematic (Q1=A), media/cinema warm amber accent (Q2=A)**.
- Accent: warm amber like projector-bulb tungsten — `oklch(0.78 0.15 75)` or similar.
- Background: `oklch(0.15 0.02 260)` — very dark with cool blue undertone.
- Neutrals: derive via `color-mix` between accent and background.

This matches the Apple TV / Infuse benchmark competitors and is the safest high-upside default for a Jellyfin client.

---

## Files the next session will touch (quick index)

- `MediaMio/Navigation/MainTabView.swift` (items 2, 7)
- `MediaMio/Views/Home/HomeView.swift` (items 1, 5)
- `MediaMio/Views/Components/SidebarView.swift` (item 5 — likely delete)
- `MediaMio/Views/Components/HeroBanner.swift` (items 1, 3, 4)
- `MediaMio/Views/Components/FocusableButton.swift` (items 1, 3, 5)
- `MediaMio/Views/Components/PosterCard.swift` (items 1, 3)
- `MediaMio/Views/Components/ContentRow.swift` (item 1)
- `MediaMio/Views/Settings/SettingsView.swift` (items 1, 3, 4, 6)
- `MediaMio/Views/Library/LibraryTabView.swift` (items 1, 3 — mostly keep)
- `MediaMio/Views/Library/Components/LibraryToolbar.swift` (items 1, 3, 5)
- `MediaMio/Constants.swift` (items 1, 3)
- `MediaMio/Services/SettingsManager.swift` (item 6 — subtitle summary wording)
- `MediaMio/Extensions/Color+Hex.swift` (new file, item 7)

## Resume checklist for the next session

1. Read this file (`design-plan.md`).
2. If no `.impeccable.md` exists, either run `/teach-impeccable` or confirm with Brandon that defaults are fine.
3. Get Brandon's answers to Q1 + Q2 (tone + brand color).
4. Get Brandon's scope preference: top 3 only (items 1-3), all 7, or start with item 1 and re-evaluate.
5. Run item 1 (`/colorize`). After it completes, check in before continuing.
6. After all chosen items, re-run `/critique` to measure the delta.
