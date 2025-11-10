# MediaMio - Complete Project Guide

## 🎯 Your Mission
Build the best Jellyfin client for Apple TV. Make it so good that people choose it over the official app. Make it feel like Netflix, but better.

## 📦 What You Have

### 1. Branding Assets
- **Logo**: `mediamio-logo.png`
- **App Icons**: Multiple sizes (1024, 512, 256, 180, 120, 80)
- **Interactive Gallery**: `mediamio-branding.html`
- **Setup Guide**: `BRANDING-GUIDE.md`

**Status**: ✅ Complete - Ready to add to Xcode

### 2. Development Guides

#### Main Project Prompt
📄 **`jellyfin-appletv-prompt.md`**
- Complete technical specification
- All features and requirements
- Jellyfin API integration guide
- 5-phase development roadmap
- Testing and performance criteria

**Use this for**: Overall project direction and feature reference

#### Navigation Refactor Prompt
📄 **`mediamio-navigation-refactor-prompt.md`**
- Detailed Netflix-level navigation spec
- Focus behavior patterns
- Animation timing and effects
- State management architecture
- Complete implementation checklist

**Use this for**: Core navigation implementation with Claude Code

#### Navigation Quick Reference
📄 **`mediamio-navigation-quickref.md`**
- Side-by-side comparisons (Basic vs Netflix-level)
- Code examples for each pattern
- Quick wins checklist
- Testing methodology

**Use this for**: Understanding what makes navigation "premium"

#### Claude Code Workflow
📄 **`mediamio-claude-code-workflow.md`**
- Step-by-step implementation guide
- Phase-by-phase breakdown
- Specific prompts to give Claude Code
- Troubleshooting common issues
- Timeline expectations

**Use this for**: Daily development workflow with Claude Code

## 🚀 Getting Started (Right Now)

### Step 1: Fix Xcode Signing (5 minutes)
You saw this error in the screenshot. Here's the fix:

1. Open your Xcode project
2. Click project name in left sidebar
3. Select your target under "TARGETS"
4. Go to "Signing & Capabilities" tab
5. Change **Bundle Identifier** to: `com.yourname.mediamio`
6. Enable "**Automatically manage signing**"
7. Select your **Team** (your Apple ID)
8. Choose **Apple TV simulator** from device dropdown
9. Press **⌘R** to build and run

✅ **Verify**: App launches in simulator without errors

### Step 2: Add App Icon (2 minutes)
1. In Xcode, open `Assets.xcassets`
2. Click `AppIcon`
3. Drag `mediamio-icon-1024.png` into any tvOS slot
4. Xcode auto-generates all other sizes

✅ **Verify**: Beautiful gradient icon appears in Xcode

### Step 3: Start Development (The Fun Part)

Open terminal:
```bash
cd /path/to/your/MediaMio/project
claude-code
```

Tell Claude Code:
```
I'm building MediaMio, a premium Jellyfin client for tvOS.

I have comprehensive guides:
1. jellyfin-appletv-prompt.md (complete project spec)
2. mediamio-navigation-refactor-prompt.md (navigation patterns)
3. mediamio-navigation-quickref.md (code examples)
4. mediamio-claude-code-workflow.md (implementation workflow)

Please read all four files, then analyze the current codebase.

Let's start with Phase 1: Core Navigation Structure from the workflow 
guide. Create the NavigationManager and set up the TabView with proper 
state management.

Focus: Make tab switching feel instant and smooth (60fps). We'll build 
up complexity from there.
```

## 📅 Development Timeline

### Week 1: Core Navigation (THIS WEEK)
**Day 1**: 
- ✅ Fix Xcode signing issues
- ✅ Add app icon
- 🎯 Phase 1: Core Navigation Structure
- 🎯 Phase 2: Hero Banner

**Day 2-3**: 
- 🎯 Phase 3: Content Rows (most important!)
  - Horizontal scrolling
  - Focus animations
  - Focus memory
  - Performance optimization

**Day 4**: 
- 🎯 Phase 4: Detail View
  - Sheet presentation
  - Metadata display
  - TV show support

**Day 5**: 
- 🎯 Phase 5: Video Player
  - Custom controls
  - Playback reporting
  - Resume functionality

**Day 6**: 
- 🎯 Phase 6: Search
  - On-screen keyboard
  - Real-time results
  - Filter options

**Day 7**: 
- 🎯 Phase 7: Polish & Optimization
  - Loading states
  - Error handling
  - Performance testing

### Week 2: Jellyfin Integration
- Connect all features to real Jellyfin API
- Handle authentication properly
- Implement proper error handling
- Add all content types (Movies, TV, Music?)
- Test with real Jellyfin server

### Week 3: Polish & Testing
- UI/UX refinements
- Performance optimization
- Memory leak hunting
- Test on actual Apple TV hardware
- User testing and feedback

### Week 4: Launch Prep
- App Store assets (screenshots, descriptions)
- Privacy policy
- TestFlight beta testing
- Final bug fixes
- Submit to App Store

## 🎯 Critical Success Factors

### 1. Navigation Quality (Most Important!)
The navigation IS the experience on TV. If it doesn't feel smooth and natural, nothing else matters.

**Must Have:**
- 60fps everywhere
- 200ms focus animations
- Focus memory per row
- Predictable focus movement

**Read**: `mediamio-navigation-refactor-prompt.md` thoroughly

### 2. Performance
Memory and smoothness are non-negotiable.

**Targets:**
- Memory: <500MB typical usage
- Launch time: <2 seconds
- Content load: <1 second
- Video start: <2 seconds

**Tools**: Xcode Instruments (Time Profiler, Allocations, Leaks)

### 3. Visual Polish
First impressions matter.

**Requirements:**
- Beautiful app icon ✅ (done!)
- Smooth animations everywhere
- Skeleton loading screens
- Progressive image loading
- Proper empty states

### 4. Jellyfin Integration
It needs to work flawlessly with Jellyfin.

**Must Work:**
- Authentication (secure token storage)
- All content types (Movies, TV Shows, Collections)
- Playback reporting (resume, watch status)
- Image loading (posters, backdrops, thumbs)
- Search functionality
- Multiple user profiles

## 📚 Reference Guide

### When Working on Navigation
Read: `mediamio-navigation-refactor-prompt.md`
Reference: `mediamio-navigation-quickref.md`
Follow: `mediamio-claude-code-workflow.md`

### When Working on Features
Read: `jellyfin-appletv-prompt.md`
Section: Find relevant feature section
Implement: Follow implementation notes

### When Stuck
1. Check `mediamio-claude-code-workflow.md` "Common Issues"
2. Ask Claude Code to analyze the specific issue
3. Use Instruments to profile (memory, performance)
4. Test on actual Apple TV if possible

### When Polishing
Reference: Both navigation guides for animation timing
Check: All success criteria in main prompt
Test: With real users for feedback

## 🎨 Design System

### Colors
```
Primary Gradient: #667eea → #764ba2
Primary Blue: #667eea
Primary Purple: #764ba2
Background: #0a0a0a
Surface: #1a1a1a
Text Primary: #ffffff
Text Secondary: #888888
```

### Typography
```
Hero Title: 72pt, Bold
Section Title: 32pt, Bold
Card Title: 18pt, Semibold
Body: 14pt, Regular
Caption: 12pt, Regular
```

### Spacing
```
Edge Padding: 60pt
Row Spacing: 40pt
Card Spacing: 20pt
Element Spacing: 16pt
```

### Animations
```
Focus Change: 200ms ease-in-out
View Transition: 400ms spring
Fade: 300ms ease-in-out
Hero Rotation: 800ms ease-in-out
```

## 🔧 Development Tools

### Required
- Xcode 15+ (with tvOS SDK)
- macOS Ventura or later
- Apple ID (free tier OK for simulator)
- Claude Code (for AI-assisted development)

### Recommended
- Actual Apple TV (for final testing)
- Jellyfin test server (for real data)
- Git (for version control)
- TestFlight (for beta testing)

### Helpful
- SF Symbols app (for icons)
- Figma/Sketch (for mockups)
- Charles Proxy (for API debugging)
- Reveal/Lookin (for UI debugging)

## 🚨 Common Pitfalls to Avoid

### 1. Using HStack Instead of LazyHStack
❌ Loads all items at once → Memory explosion
✅ Use LazyHStack → Loads only visible items

### 2. Not Managing Focus State
❌ Default focus behavior → Unpredictable
✅ Explicit focus management → Netflix-smooth

### 3. Ignoring Animation Timing
❌ Default animations → Feels sluggish
✅ 200ms for focus, 400ms for views → Feels premium

### 4. Loading All Images Upfront
❌ All images loaded → Slow, crashes
✅ Progressive loading + caching → Fast, smooth

### 5. Forgetting State Preservation
❌ Lost position on navigation → Frustrating
✅ Focus memory + scroll position → Natural feel

### 6. Using fullScreenCover for Details
❌ Takes entire screen → Loss of context
✅ Use .sheet() → Maintains context

## 📊 Quality Checklist

### Navigation
- [ ] 60fps during all navigation
- [ ] Focus moves where expected
- [ ] Focus memory works correctly
- [ ] Tab switching is instant
- [ ] Animations feel purposeful

### Performance
- [ ] Memory stays under 500MB
- [ ] No memory leaks (tested in Instruments)
- [ ] Images load progressively
- [ ] No frame drops during scrolling
- [ ] App launches in <2 seconds

### Visual Quality
- [ ] App icon looks great
- [ ] All images have proper aspect ratios
- [ ] Text is readable from couch
- [ ] Colors match design system
- [ ] Animations are smooth
- [ ] Loading states are polished

### Functionality
- [ ] Can connect to Jellyfin server
- [ ] Can browse all content types
- [ ] Can search effectively
- [ ] Can play videos with subtitles
- [ ] Can resume from last position
- [ ] Can switch between profiles

### User Experience
- [ ] Navigation is intuitive
- [ ] No confusing states
- [ ] Error messages are helpful
- [ ] Empty states are clear
- [ ] Settings are accessible
- [ ] Help/support is available

## 🎓 Learning Resources

### Apple Documentation
- [Human Interface Guidelines - tvOS](https://developer.apple.com/design/human-interface-guidelines/tvos)
- [AVFoundation Programming Guide](https://developer.apple.com/av-foundation/)
- [Focus Navigation on tvOS](https://developer.apple.com/documentation/swiftui/focus-navigation)

### Jellyfin Documentation
- [Jellyfin API Documentation](https://api.jellyfin.org/)
- [Client Development Guide](https://jellyfin.org/docs/general/clients/index.html)

### Study These Apps
- Netflix (navigation patterns)
- Apple TV+ (design language)
- Plex (features)
- Infuse (polish)

## 🎬 Next Steps

**Right now:**
1. ✅ Read this document completely
2. 🎯 Fix Xcode signing (5 min)
3. 🎯 Add app icon (2 min)
4. 🎯 Start claude-code (1 min)
5. 🎯 Begin Phase 1 (rest of day)

**This week:**
- Complete all 7 phases of navigation
- Get smooth 60fps throughout
- Basic Jellyfin integration working
- Video playback functional

**Next week:**
- Full Jellyfin integration
- All content types working
- Search and filtering complete
- Polish and optimization

**Week 3:**
- Final polish
- Real user testing
- Performance optimization
- TestFlight beta

**Week 4:**
- App Store submission
- Launch! 🚀

## 💡 Pro Tips

1. **Test on simulator early and often** - Don't wait for hardware
2. **Use Instruments regularly** - Catch memory issues early
3. **Get real user feedback** - Your perspective isn't enough
4. **Study Netflix on Apple TV** - Use it for 10 minutes before coding
5. **Focus on feel** - 60fps and smooth animations matter more than features
6. **Iterate on navigation** - Get it perfect before adding complexity
7. **Use Claude Code effectively** - Be specific, test often, iterate
8. **Don't skip polish** - Loading states and empty states matter

## 🎉 You've Got This!

You have:
✅ Beautiful branding (logo + icons)
✅ Comprehensive technical specifications
✅ Detailed navigation patterns
✅ Step-by-step implementation guide
✅ Code examples and references
✅ Timeline and checklist
✅ Claude Code to help build it

Everything you need to build the best Jellyfin client for Apple TV.

**Now go build something amazing!** 🚀

---

## Quick Links

📄 **Main Guides:**
- [Complete Project Spec](jellyfin-appletv-prompt.md)
- [Navigation Refactor](mediamio-navigation-refactor-prompt.md)
- [Navigation Quick Ref](mediamio-navigation-quickref.md)
- [Claude Code Workflow](mediamio-claude-code-workflow.md)

🎨 **Branding:**
- [Branding Gallery](mediamio-branding.html)
- [Setup Guide](BRANDING-GUIDE.md)

📦 **Assets:**
- All icon files (1024, 512, 256, 180, 120, 80)
- High-res logo

---

**Questions? Issues? Stuck?**
Just ask! I'm here to help you build MediaMio into the best Jellyfin client ever made.

Let's make something people love. 💜
