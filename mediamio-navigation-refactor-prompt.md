# Claude Code Prompt: Netflix-Level Navigation for MediaMio

## Mission
Refactor MediaMio's navigation system to match the premium, buttery-smooth experience of Netflix and Apple TV+ on tvOS. Every transition should feel intentional, every focus change should be smooth, and the entire navigation flow should be intuitive and delightful.

## Core Navigation Principles

### 1. Navigation Architecture
MediaMio should use a **tab-based root navigation** with seamless modal presentations:

```
TabView (Root)
├── Home Tab
│   ├── Featured Content (Hero Banner)
│   ├── Content Rows (Continue Watching, Movies, TV Shows, etc.)
│   └── DetailView (Sheet/Modal)
│       └── PlayerView (Full Screen)
├── Search Tab
│   ├── Search Interface
│   └── Results
├── Library Tab
│   └── Organized Collections
└── Settings Tab
    └── Account & Preferences
```

### 2. Tab Bar Implementation

**Requirements:**
- Fixed bottom tab bar that's ALWAYS visible (except during video playback)
- 4 primary tabs: Home, Search, Library, Settings
- Tab icons should be SF Symbols with custom tinting
- Selected tab: Full color with accent color (#667eea)
- Unselected tabs: White with 60% opacity
- Smooth tab switching with no lag
- Tab bar should blur the content behind it (frosted glass effect)

**SwiftUI Implementation Pattern:**
```swift
TabView {
    HomeView()
        .tabItem {
            Label("Home", systemImage: "house.fill")
        }
    
    SearchView()
        .tabItem {
            Label("Search", systemImage: "magnifyingglass")
        }
    
    LibraryView()
        .tabItem {
            Label("Library", systemImage: "square.stack.fill")
        }
    
    SettingsView()
        .tabItem {
            Label("Settings", systemImage: "gearshape.fill")
        }
}
.preferredColorScheme(.dark)
```

### 3. Hero Banner Navigation (Netflix-Style Featured Content)

**Behavior:**
- Large, cinematic hero section at top of Home view
- Takes up approximately 50-60% of screen height
- Displays featured content with:
  - Full-bleed backdrop image (with subtle parallax on focus)
  - Large title text
  - Brief description (2-3 lines max)
  - Primary CTA button: "Play" or "Resume" (with progress bar if applicable)
  - Secondary CTA button: "More Info"
  - Auto-rotates every 8-10 seconds (pauses on focus)

**Focus Behavior:**
- When focused on hero buttons, backdrop should zoom very slightly (1.02x scale)
- Smooth fade transition between featured items
- Focus on buttons should have subtle shadow and scale (1.05x)

**Implementation Notes:**
- Use `ZStack` with backdrop image as bottom layer
- Add linear gradient overlay (transparent → black) for text readability
- Use `AsyncImage` with caching for backdrop images
- Implement `Timer` for auto-rotation with proper cleanup
- Ensure smooth crossfade between images (no flashing)

### 4. Content Row Navigation (Horizontal Scrolling)

**Visual Design:**
- Multiple rows of content cards scrolling horizontally
- Row titles: Bold, 28-32pt font, white text
- Each row shows ~5-6 items on screen at once
- Generous padding between rows (40-50pt)
- Smooth momentum scrolling
- Items should scale up to 1.1x when focused
- Focused item should have a subtle shadow
- Rows should have a "See All >" option at the end

**Focus Behavior (CRITICAL):**
This is where Netflix shines - implement these exact behaviors:

1. **Horizontal Navigation:**
   - Swiping left/right moves focus between items in a row
   - Smooth focus animation (200ms ease-in-out)
   - Cards scale up when focused (1.0 → 1.1)
   - Add subtle drop shadow to focused card
   - Scroll row automatically to keep focused item in center

2. **Vertical Navigation:**
   - Swiping up/down moves focus between rows
   - Should "remember" horizontal position in each row
   - If returning to a row, focus returns to last focused item
   - Smooth vertical scrolling that feels natural

3. **Inertia & Momentum:**
   - Quick swipe should move focus by ~3 items with smooth deceleration
   - Long press + swipe should enable continuous scrolling
   - Implement proper edge resistance (can't scroll beyond bounds)

**SwiftUI Implementation Pattern:**
```swift
ScrollView(.horizontal, showsIndicators: false) {
    LazyHStack(spacing: 20) {
        ForEach(items) { item in
            PosterCard(item: item)
                .focusable()
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .shadow(radius: isFocused ? 20 : 0)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                .onTapGesture {
                    selectedItem = item
                    showDetail = true
                }
        }
    }
    .padding(.horizontal, 60)
}
```

**Performance Optimizations:**
- Use `LazyHStack` (NOT `HStack`) for memory efficiency
- Only load images for visible + adjacent items
- Implement proper image caching
- Release resources for off-screen items
- Monitor memory usage in Instruments

### 5. Detail View Navigation (Content Details)

**Presentation Style:**
- Present as a **sheet** that slides up from bottom
- Takes up ~85% of screen height
- Blurred background showing previous view
- Smooth spring animation on presentation/dismissal
- Back button returns to previous view with smooth transition

**Content Layout:**
```
┌─────────────────────────────────────┐
│ [Large Backdrop with Gradient]      │
│                                      │
│ [Poster]  Title (Large, Bold)      │
│           Year • Rating • Duration  │
│           ★★★★☆ 4.5/5              │
│                                      │
│ [▶ Play] [+ My List] [ℹ Info]      │
│                                      │
│ Description text (3-4 lines)        │
│                                      │
│ Cast: Actor names...                │
│ Genres: Action, Drama, Thriller     │
│                                      │
│ ─── Similar Content ─────────────  │
│ [Horizontal row of suggestions]     │
└─────────────────────────────────────┘
```

**For TV Shows - Add:**
- Season selector (pill-style buttons)
- Episode list with thumbnails
- "Next Episode" prominent button if user is mid-season

**Focus Order:**
1. Play/Resume button (default focus)
2. My List button
3. Info button (if applicable)
4. Season selector (TV shows)
5. Episode list
6. Similar content row

**Animations:**
- Fade in backdrop (300ms)
- Slide in content from bottom (400ms spring animation)
- Sequential fade-in of buttons (staggered by 50ms each)

### 6. Navigation Transitions

**Between Views:**
- Use `.sheet()` for detail views (NOT `.fullScreenCover()` unless it's video player)
- Smooth spring animation (`.spring(response: 0.4, dampingFraction: 0.8)`)
- Maintain context - user should always know where they are
- Blur previous view when showing modal (depth perception)

**Back Navigation:**
- Swipe down gesture to dismiss detail sheet
- Back button in top-left (use SF Symbol: `chevron.left`)
- Menu button press should go back
- Smooth reverse animation

**State Preservation:**
- Remember scroll position in Home view
- Remember last focused item in each row
- Restore focus when returning from detail view
- Maintain tab selection across app sessions

### 7. Focus Engine Optimization

**Custom Focus Behavior:**
```swift
// Implement custom focus movement for optimal UX
.focusScope(namespace)
.onMoveCommand { direction in
    switch direction {
    case .up:
        // Move to row above
        handleUpNavigation()
    case .down:
        // Move to row below
        handleDownNavigation()
    case .left, .right:
        // Default horizontal behavior
        break
    }
}
```

**Focus States to Track:**
- Current focused item ID
- Current row index
- Horizontal position in each row
- Tab selection state
- Detail view focus state

**Focus Visual Feedback:**
- Scale effect: 1.1x for focused items
- Shadow: 20pt blur radius with 50% opacity
- Border: Subtle 2pt white border (optional, for cards only)
- Smooth animation: 200ms ease-in-out
- Proper highlight color for buttons (use accent color)

### 8. Video Player Navigation

**Full-Screen Player:**
- Use `.fullScreenCover()` for video player ONLY
- Auto-hide controls after 3 seconds of inactivity
- Swipe down to minimize (picture-in-picture on supported devices)
- Menu button press shows player menu (not immediate dismiss)

**Player Controls Navigation:**
- Play/Pause: Center button (primary action)
- Seek -10s: Left swipe
- Seek +10s: Right swipe
- Show controls: Any remote movement
- Menu: Long press shows full menu (subtitle selection, quality, etc.)

**Focus Order in Player:**
1. Play/Pause button (center, default)
2. Progress bar (can scrub with left/right swipes)
3. -10s button (left)
4. +10s button (right)
5. Subtitle button (bottom-right)
6. Quality/Settings button (bottom-right)
7. Close/Back button (top-left)

### 9. Search Navigation

**Search Screen:**
- Large search bar at top (default focus)
- On-screen keyboard appears automatically
- Real-time results as user types
- Results displayed in grid format
- Filter buttons below search bar (Movies, TV Shows, All)

**Focus Flow:**
1. Search field (default focus on screen entry)
2. Recent searches (if any)
3. Filter buttons (horizontal row)
4. Results grid (vertical scrolling)

**Keyboard Navigation:**
- Keyboard should be optimized for TV (large keys)
- Quick access to common characters
- Voice search option (if available)
- Clear button always visible

### 10. Loading States & Placeholders

**During Navigation:**
- Show skeleton screens while loading
- Never show blank white screens
- Use shimmer effect for loading cards
- Maintain navigation responsiveness even while loading

**Skeleton Design:**
```
┌─────────────────┐
│   [Shimmer]     │ ← Animated gradient
│   [Shimmer]     │
│ [Shimmer]       │
└─────────────────┘
```

**Implementation:**
- Fade from skeleton to actual content (no jarring pops)
- Load images progressively (blur → sharp)
- Show cached content immediately, update in background

### 11. Gesture Handling

**Standard Gestures:**
- **Swipe Left/Right**: Navigate between items horizontally
- **Swipe Up/Down**: Navigate between rows vertically
- **Long Press**: Show context menu (Add to List, Remove, etc.)
- **Click/Select**: Primary action (play, open detail, etc.)
- **Menu Button**: Back/Dismiss (never exit app unless at root)
- **Play/Pause Button**: Direct video control (in player) or quick play (on content cards)

**Custom Gestures (Advanced):**
- Double-tap on card: Quick play (skip detail view)
- Swipe down from top: Refresh content
- Swipe up on video player: Show chapter markers (if available)

## Implementation Checklist

### Phase 1: Core Navigation Structure
- [ ] Implement TabView with 4 tabs
- [ ] Set up proper focus management
- [ ] Create navigation state management (ObservableObject)
- [ ] Implement back stack handling

### Phase 2: Home View Navigation
- [ ] Build hero banner with auto-rotation
- [ ] Implement horizontal content rows with LazyHStack
- [ ] Add proper focus animations (scale + shadow)
- [ ] Implement focus memory for rows
- [ ] Add smooth scrolling with momentum

### Phase 3: Detail View Navigation
- [ ] Create sheet presentation for detail view
- [ ] Implement backdrop with gradient overlay
- [ ] Add button focus states and animations
- [ ] Handle TV show season/episode navigation
- [ ] Add "Similar Content" row at bottom

### Phase 4: Player Navigation
- [ ] Full-screen video player with AVPlayer
- [ ] Auto-hiding controls with timer
- [ ] Proper control focus order
- [ ] Seek gestures and playback controls
- [ ] Back navigation from player

### Phase 5: Polish & Optimization
- [ ] Add loading skeletons everywhere
- [ ] Implement image caching strategy
- [ ] Optimize memory usage (test with Instruments)
- [ ] Add haptic feedback (if supported)
- [ ] Test all navigation paths thoroughly
- [ ] Verify focus behavior in all scenarios
- [ ] Add animation polish (timing, easing)

## Performance Requirements

**Navigation Speed:**
- Tab switch: <100ms
- Detail view open: <300ms
- Player open: <500ms (including video buffer)
- Back navigation: <200ms
- Focus change: <100ms

**Memory Management:**
- Release off-screen images
- Cancel pending image downloads when scrolling fast
- Implement proper cache size limits
- Monitor memory warnings and respond appropriately

**Smoothness:**
- Maintain 60fps during all navigation
- No dropped frames during scrolling
- No stuttering during tab switches
- Smooth animations everywhere

## Testing Checklist

- [ ] Test all navigation paths (forward and back)
- [ ] Verify focus moves correctly in all directions
- [ ] Test with slow network (loading states)
- [ ] Test with large libraries (performance)
- [ ] Verify focus memory works correctly
- [ ] Test gesture recognition (no conflicts)
- [ ] Verify keyboard navigation works
- [ ] Test on multiple Apple TV generations
- [ ] Verify memory usage is reasonable (<500MB typical)
- [ ] Test all edge cases (empty states, errors, etc.)

## Code Organization

```
Views/
├── Navigation/
│   ├── MainTabView.swift (Root tab view)
│   ├── NavigationManager.swift (State management)
│   └── FocusManager.swift (Focus state tracking)
├── Home/
│   ├── HomeView.swift
│   ├── HeroBannerView.swift
│   ├── ContentRowView.swift
│   └── Components/
│       ├── PosterCard.swift
│       └── FocusableCard.swift
├── Detail/
│   ├── DetailView.swift
│   ├── DetailHeaderView.swift
│   ├── EpisodeListView.swift
│   └── SimilarContentView.swift
└── Player/
    ├── VideoPlayerView.swift
    ├── PlayerControlsView.swift
    └── PlayerOverlayView.swift
```

## Navigation State Management

Create a centralized NavigationManager:

```swift
@MainActor
class NavigationManager: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var presentedItem: MediaItem?
    @Published var showingPlayer: Bool = false
    @Published var currentPlayerItem: MediaItem?
    
    // Focus state tracking
    @Published var homeScrollPosition: CGFloat = 0
    @Published var focusedRowIndex: Int = 0
    @Published var focusedItemIndices: [Int: Int] = [:] // Row index → Item index
    
    // Navigation methods
    func showDetail(for item: MediaItem) {
        presentedItem = item
    }
    
    func playItem(_ item: MediaItem) {
        currentPlayerItem = item
        showingPlayer = true
    }
    
    func dismissDetail() {
        presentedItem = nil
    }
    
    func closePlayer() {
        showingPlayer = false
        currentPlayerItem = nil
    }
    
    // Focus memory
    func rememberFocus(row: Int, itemIndex: Int) {
        focusedItemIndices[row] = itemIndex
    }
    
    func recallFocus(for row: Int) -> Int {
        return focusedItemIndices[row] ?? 0
    }
}
```

## Key Differences from Standard Navigation

**What Makes This Netflix-Level:**

1. **Focus Memory**: Always returns to last focused item in each row
2. **Smooth Animations**: 200ms transitions, spring physics for sheets
3. **Predictable Behavior**: Focus moves exactly where user expects
4. **Performance**: 60fps at all times, aggressive caching
5. **Polish**: Every detail considered - shadows, scales, timing
6. **Context Preservation**: Never lose user's place
7. **Gesture Support**: Natural, intuitive gestures throughout
8. **Loading States**: Never jarring, always smooth transitions

## Success Criteria

Your navigation is Netflix-quality when:

✓ User can navigate entire app without thinking about it
✓ Every focus movement feels natural and expected
✓ Animations are smooth and purposeful (never jarring)
✓ App maintains 60fps during all navigation
✓ Focus memory works perfectly - always returns to right place
✓ Loading states are smooth and non-intrusive
✓ Gestures feel natural and responsive
✓ No stuttering, lag, or frame drops
✓ Memory usage stays reasonable (<500MB)
✓ User never feels lost or confused about where they are

## Final Notes

- Study Netflix and Apple TV+ apps extensively before coding
- Test navigation flow on actual Apple TV hardware
- Pay attention to timing - animation speed matters immensely
- Use Instruments to verify performance continuously
- Get feedback from users about navigation feel
- Iterate on focus behavior until it's perfect
- Remember: Navigation IS the user experience on TV

---

**Start with Phase 1** and build up progressively. Get the core tab navigation working smoothly before adding complexity. Test each navigation pattern thoroughly before moving to the next.

The goal is to make users say: *"This feels just like Netflix, but better."*
