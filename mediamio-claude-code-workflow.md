# Claude Code Workflow: Implementing Netflix-Level Navigation

## How to Use Claude Code for This Refactor

### Step 1: Initial Setup
Open your terminal and start Claude Code in your MediaMio project:

```bash
cd /path/to/MediaMio
claude-code
```

### Step 2: Prime Claude Code
Send this initial message:

```
I'm refactoring the navigation in my MediaMio tvOS app to match 
Netflix's premium quality. I have two detailed guides:

1. mediamio-navigation-refactor-prompt.md (comprehensive navigation spec)
2. mediamio-navigation-quickref.md (patterns and examples)

Please read both files, then help me implement Phase 1: Core Navigation 
Structure. Start by analyzing the current codebase and proposing the 
navigation architecture we'll build.
```

### Step 3: Phase-by-Phase Implementation

#### Phase 1: Core Navigation Structure (Day 1)
**Goal**: Get tab-based navigation working with proper state management

**Tell Claude Code:**
```
Phase 1 Focus: Core Navigation Structure

Tasks:
1. Create NavigationManager.swift as a centralized state manager
2. Refactor main app to use TabView with 4 tabs (Home, Search, Library, Settings)
3. Set up focus management infrastructure
4. Implement tab state preservation
5. Test tab switching smoothness

Use the NavigationManager example from the prompt as a starting point.
Ensure all tabs are created but can show placeholder content for now.
Priority: Get smooth 60fps tab switching working first.
```

**Verify before moving on:**
- [ ] Tab switching is instant (<100ms)
- [ ] Tab icons and labels look good
- [ ] Focus moves correctly between tabs
- [ ] Selected tab has accent color
- [ ] Dark mode is applied throughout

---

#### Phase 2: Home View Hero Banner (Day 1-2)
**Goal**: Implement the Netflix-style featured content banner

**Tell Claude Code:**
```
Phase 2 Focus: Hero Banner

Tasks:
1. Create HeroBannerView.swift with large backdrop image
2. Implement gradient overlay (transparent → black)
3. Add title, description, and CTA buttons (Play, More Info)
4. Implement auto-rotation every 8-10 seconds
5. Add smooth crossfade transition between featured items
6. Implement focus effects on buttons (scale + shadow)
7. Make it respond to Jellyfin "Continue Watching" or "Featured" items

Requirements:
- Hero should take up ~55% of screen height
- Smooth 800ms fade transitions
- Proper focus order: Play button (default) → More Info
- Pause auto-rotation when buttons are focused
- Use AsyncImage with caching for backdrop

Test with 3-5 featured items to verify smooth rotation.
```

**Verify before moving on:**
- [ ] Hero banner looks cinematic
- [ ] Auto-rotation is smooth (no flashing)
- [ ] Focus on buttons feels premium (scale + shadow)
- [ ] Gradient overlay makes text readable
- [ ] Images load progressively (no blank states)

---

#### Phase 3: Content Rows (Day 2-3)
**Goal**: Horizontal scrolling rows with Netflix-level focus behavior

**Tell Claude Code:**
```
Phase 3 Focus: Content Rows

This is the most critical phase for feel. Tasks:

1. Create ContentRowView.swift with LazyHStack
2. Create PosterCard.swift component with focus effects
3. Implement focus animations:
   - Scale: 1.0 → 1.1 (200ms ease-in-out)
   - Shadow: 0 → 20pt blur (same timing)
4. Implement focus memory per row in NavigationManager
5. Add multiple rows to HomeView:
   - Continue Watching (if applicable)
   - Recently Added
   - Movies
   - TV Shows
   - Collections
6. Implement vertical navigation between rows
7. Ensure horizontal position is maintained when navigating up/down

CRITICAL REQUIREMENTS:
- Use LazyHStack (NOT HStack)
- Load images for visible + 2 adjacent items only
- Implement proper image caching
- Focus should feel immediate (no lag)
- Smooth scrolling with momentum
- 60pt horizontal padding for edge breathing room

Integration points:
- Hook up to Jellyfin API for real content
- Use ImageLoader.swift for cached image loading
- Test with 20+ items per row to verify performance
```

**Verify before moving on:**
- [ ] Focus moves smoothly between items
- [ ] Scale animation is 200ms (feels instant)
- [ ] Shadow appears on focused item
- [ ] Vertical navigation maintains horizontal position
- [ ] Returning to a row focuses last item (focus memory)
- [ ] No stuttering with 20+ items per row
- [ ] Images load without causing frame drops

---

#### Phase 4: Detail View (Day 3-4)
**Goal**: Beautiful detail sheets that slide up smoothly

**Tell Claude Code:**
```
Phase 4 Focus: Detail View

Tasks:
1. Create DetailView.swift presented as a sheet
2. Implement layout:
   - Large backdrop with gradient
   - Poster thumbnail
   - Title, year, rating, duration
   - Description (3-4 lines)
   - Cast & crew info
   - Action buttons (Play, My List, Info)
3. Add sheet presentation with:
   - .sheet() modifier (NOT .fullScreenCover)
   - 85% screen height
   - Blurred background (.ultraThinMaterial)
   - Spring animation for slide-up
4. Implement focus order (Play button gets default focus)
5. For TV shows: Add season selector + episode list
6. Add "Similar Content" row at bottom
7. Handle back navigation (swipe down to dismiss)

Sheet should have rounded top corners (30pt radius) and blur the 
previous view for context. When opening detail view, remember the 
focused item in the home row so we can return to it.

Integration:
- Connect to Jellyfin API for full metadata
- Handle both Movie and TVShow types
- Load episode thumbnails for TV shows
```

**Verify before moving on:**
- [ ] Sheet slides up smoothly (400ms spring)
- [ ] Background is blurred (can still see previous view)
- [ ] Play button has default focus
- [ ] All metadata displays correctly
- [ ] TV show season/episode navigation works
- [ ] Swipe down dismisses sheet
- [ ] Returning to home maintains focus on opened item

---

#### Phase 5: Video Player (Day 4-5)
**Goal**: Full-screen player with custom controls

**Tell Claude Code:**
```
Phase 5 Focus: Video Player

Tasks:
1. Create VideoPlayerView.swift with AVPlayer
2. Implement custom PlayerControlsView:
   - Play/Pause (center)
   - -10s / +10s buttons
   - Progress bar with scrubbing
   - Time remaining display
   - Subtitle selector
   - Quality selector
3. Add auto-hide controls (3 seconds of inactivity)
4. Implement gestures:
   - Swipe left: -10s
   - Swipe right: +10s
   - Any remote movement: Show controls
5. Present as fullScreenCover
6. Implement playback reporting to Jellyfin:
   - Start
   - Progress (every 10s)
   - Stop/Complete
7. Add resume functionality (continue from last position)

Controls should fade in/out smoothly (300ms). Focus order should be:
Center (Play/Pause) → Left (-10s) → Right (+10s) → Bottom controls

Integration:
- Use Jellyfin streaming URL with token
- Support direct play when possible
- Handle transcoding when needed
- Save playback position to Jellyfin
- Mark as watched when >90% complete
```

**Verify before moving on:**
- [ ] Video plays smoothly
- [ ] Controls auto-hide after 3 seconds
- [ ] Seek gestures work (±10s)
- [ ] Progress bar updates in real-time
- [ ] Playback position syncs to Jellyfin
- [ ] Resume works correctly
- [ ] Subtitles can be selected and display
- [ ] Menu button shows player menu (doesn't dismiss)

---

#### Phase 6: Search Implementation (Day 5)
**Goal**: Fast, responsive search with on-screen keyboard

**Tell Claude Code:**
```
Phase 6 Focus: Search

Tasks:
1. Create SearchView.swift
2. Implement search interface:
   - Large search field at top (default focus)
   - On-screen keyboard (tvOS optimized)
   - Real-time search as user types
   - Recent searches (store in UserDefaults)
   - Clear button
3. Add filter buttons (All, Movies, TV Shows)
4. Display results in grid format (2-3 columns)
5. Debounce search queries (300ms after last keystroke)
6. Show loading skeleton while searching
7. Handle empty states gracefully

Focus flow:
Search field → Recent searches → Filter buttons → Results grid

Integration:
- Use Jellyfin search endpoint
- Display results with posters
- Tap result opens DetailView
- Limit results to 50 items initially
```

**Verify before moving on:**
- [ ] Search is instant (debounced)
- [ ] Keyboard is easy to use on TV
- [ ] Results appear smoothly
- [ ] Filter buttons work correctly
- [ ] Recent searches are saved
- [ ] Tapping result opens detail view
- [ ] Empty state shows helpful message

---

#### Phase 7: Polish & Optimization (Day 6-7)
**Goal**: Make everything feel premium

**Tell Claude Code:**
```
Phase 7 Focus: Polish & Optimization

Tasks:
1. Add loading skeletons to all views
2. Implement progressive image loading (blur → sharp)
3. Optimize image caching:
   - Set max cache size (500MB)
   - Implement LRU eviction
   - Preload adjacent items
4. Add proper error handling everywhere:
   - Network errors
   - Missing images
   - API failures
5. Implement empty states for:
   - No content in library
   - No search results
   - No continue watching items
6. Test memory usage with Instruments:
   - Target: <500MB typical usage
   - No memory leaks
   - Proper resource cleanup
7. Animation timing audit:
   - All focus changes: 200ms
   - Sheet presentations: 400ms spring
   - Fades: 300ms
   - Hero rotation: 800ms
8. Add subtle haptic feedback (if supported)
9. Test all navigation paths thoroughly
10. Performance testing with large library (1000+ items)

Run the app through Instruments and profile:
- Time Profiler (find slow code)
- Allocations (find memory leaks)
- Leaks (verify no retain cycles)
- Network (optimize API calls)
```

**Final Verification Checklist:**
- [ ] All navigation is smooth (60fps)
- [ ] Focus behavior is predictable
- [ ] Focus memory works everywhere
- [ ] Loading states are smooth (no blanks)
- [ ] Images load progressively
- [ ] Memory usage is reasonable
- [ ] No crashes or errors
- [ ] All animations have correct timing
- [ ] Search is fast
- [ ] Video playback is smooth
- [ ] Resume functionality works
- [ ] App feels like Netflix

---

## Pro Tips for Working with Claude Code

### 1. Be Specific About What to Test
After each phase, tell Claude Code:
```
Please build and run the app. Test the following scenarios:
1. [Specific test case]
2. [Specific test case]
3. [Specific test case]

Report any issues you find.
```

### 2. Use Iterative Refinement
If something doesn't feel right:
```
The focus animation feels too slow. Let's change it from 300ms to 200ms.
Also, the shadow is too strong - reduce the radius from 30 to 20.
Test both changes and let me know how it feels.
```

### 3. Request Performance Analysis
```
Run the app in Instruments with Time Profiler. 
Are there any slow methods? Anything taking >16ms (causing frame drops)?
Show me the top 5 time consumers.
```

### 4. Ask for Code Reviews
```
Review the NavigationManager class. Are there any potential memory 
leaks? Any @Published properties that should be private? Any 
unnecessary state updates that could cause re-renders?
```

### 5. Incremental Integration with Jellyfin
```
Phase 2a: Use mock data to build the UI
Phase 2b: Integrate with Jellyfin API
Phase 2c: Add error handling

Let's do Phase 2a first with mock data so we can focus on the UI/UX.
```

### 6. Visual Polish Iterations
```
The hero banner looks good but could be more premium. Can we:
1. Make the gradient more pronounced (darker at bottom)
2. Add a subtle vignette effect
3. Make the title text slightly larger (10% bigger)
Test these changes and show me a screenshot.
```

## Common Issues & Solutions

### Issue: Focus Not Moving Correctly
**Tell Claude Code:**
```
The focus isn't moving between rows correctly. When I swipe down from 
row 1, it should go to row 2, but it's not focusing any item. Let's 
add .focusScope() to each row and debug the focus navigation.
```

### Issue: Images Not Loading
**Tell Claude Code:**
```
Images aren't loading in the content rows. Let's add logging to 
ImageLoader to see what URLs are being requested. Also verify that 
the Jellyfin image URLs are being constructed correctly with the 
authentication token.
```

### Issue: Animation Stuttering
**Tell Claude Code:**
```
The focus animation is stuttering. This usually means the animation 
is being applied to too many properties. Let's optimize:
1. Use .scaleEffect() only (remove .frame() animation)
2. Add .drawingGroup() to the card
3. Verify we're using LazyHStack (not HStack)
```

### Issue: Memory Growing
**Tell Claude Code:**
```
Memory is growing past 1GB. Let's investigate:
1. Check if images are being released when scrolling
2. Verify LazyHStack is being used (not HStack)
3. Add memory limit to image cache
4. Print memory usage every 5 seconds during scrolling
Profile with Instruments and show me what's holding memory.
```

## Timeline Expectations

**Realistic Timeline:**
- **Day 1**: Phases 1-2 (Core navigation + Hero banner)
- **Day 2-3**: Phase 3 (Content rows - this is the hardest)
- **Day 3-4**: Phase 4 (Detail view)
- **Day 4-5**: Phase 5 (Video player)
- **Day 5**: Phase 6 (Search)
- **Day 6-7**: Phase 7 (Polish)

**Total: ~1 week of focused development**

## Success Metrics

You'll know the navigation is Netflix-level when:

1. **Feel Test**: Close your eyes, navigate around, open your eyes. You should always be exactly where you expect.

2. **Performance Test**: Scroll through 100 items rapidly. Should be smooth 60fps throughout.

3. **Memory Test**: Navigate entire app for 10 minutes. Memory should stay <500MB.

4. **Polish Test**: Show app to someone unfamiliar. They should say "This feels professional."

5. **Focus Test**: Navigate to deep content (row 5, item 10), go to detail, come back. Focus should return to row 5, item 10.

## Final Claude Code Command

When you're ready to start:

```bash
claude-code
```

Then paste:
```
I'm building MediaMio, a premium Jellyfin client for tvOS. I need to 
implement Netflix-level navigation quality.

Please read these files:
1. mediamio-navigation-refactor-prompt.md
2. mediamio-navigation-quickref.md

Then analyze the current codebase and let's start with Phase 1: 
Core Navigation Structure. Create the NavigationManager and set up 
the TabView with proper state management.

Focus on making tab switching feel instant and smooth (60fps). 
We'll build up the complexity from there.
```

---

**Remember**: Navigation IS the experience on TV. Take time to get it perfect!
