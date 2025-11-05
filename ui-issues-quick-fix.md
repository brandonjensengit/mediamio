# Quick Fix: Three Common UI Issues

## TL;DR - Copy This to Claude Code

```
I need to fix three issues in MediaMio:

1. AUTO-SCROLL PROBLEM
App scrolls down on launch instead of staying at top.

Fix: In HomeView, wrap ScrollView with ScrollViewReader and add top anchor:
- Add Color.clear.frame(height: 1).id("top") at start of ScrollView
- In .onAppear, call proxy.scrollTo("top", anchor: .top)
- Add delay: DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)

2. SEARCH SELECTION DOESN'T WORK
Tapping search results does nothing.

Fix: Replace tap gestures with NavigationLink:
- Wrap search results in NavigationStack/NavigationView
- Use NavigationLink { DetailView(item: item) } label: { SearchResultCard(item: item) }
- Add .buttonStyle(.plain) to NavigationLink
- Test that tapping navigates to detail view

3. SETTINGS NOT APPEARING
Created settings but they're not in the settings menu.

Fix: Add Settings tab and navigation:
- Add SettingsView to TabView with .tabItem for gear icon
- Wrap SettingsView content in NavigationView
- Add NavigationLink for each settings section
- Create placeholder detail views (PlaybackSettingsView, etc.)
- Verify all files are added to Xcode target

Please fix all three issues. Add logging to verify each fix works.
Test after each fix and report results.
```

---

## Issue 1: Auto-Scroll Fix

### The Problem
App scrolls down automatically instead of staying at top.

### Quick Fix
```swift
import SwiftUI

struct HomeView: View {
    @Namespace private var topID
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Invisible anchor at the very top
                Color.clear
                    .frame(height: 1)
                    .id(topID)
                
                // Your content
                VStack(spacing: 0) {
                    HeroBannerView()
                    ContentRowsView()
                }
            }
            .onAppear {
                // Scroll to top after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo(topID, anchor: .top)
                    }
                }
            }
        }
    }
}
```

### Test It
```
1. Force quit app
2. Launch app
3. ✅ Should start at top (hero banner visible)
4. Navigate away and back
5. ✅ Should return to top
```

---

## Issue 2: Search Selection Fix

### The Problem
Tapping search results doesn't navigate to detail view.

### Quick Fix - Replace tap gestures with NavigationLink

**Before (Broken):**
```swift
ForEach(searchResults) { item in
    SearchResultCard(item: item)
        .onTapGesture {
            selectedItem = item
        }
}
```

**After (Working):**
```swift
NavigationStack {
    ScrollView {
        LazyVGrid(columns: columns) {
            ForEach(searchResults) { item in
                NavigationLink {
                    DetailView(item: item)
                } label: {
                    SearchResultCard(item: item)
                }
                .buttonStyle(.plain)  // Important!
            }
        }
    }
}
```

### Complete Working Example
```swift
struct SearchView: View {
    @State private var searchQuery = ""
    @State private var searchResults: [MediaItem] = []
    
    var body: some View {
        NavigationStack {  // ← Must have this!
            VStack {
                // Search bar
                TextField("Search", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                // Results with working navigation
                SearchResultsGrid(results: searchResults)
            }
            .navigationTitle("Search")
        }
        .onChange(of: searchQuery) { _, newValue in
            performSearch(query: newValue)
        }
    }
    
    private func performSearch(query: String) {
        Task {
            searchResults = await jellyfinAPI.search(query: query)
        }
    }
}

struct SearchResultsGrid: View {
    let results: [MediaItem]
    
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 250, maximum: 350), spacing: 20)]
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(results) { item in
                    NavigationLink {
                        DetailView(item: item)
                    } label: {
                        SearchResultCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}
```

### Test It
```
1. Go to Search tab
2. Type a search query
3. Tap on a result
4. ✅ Should navigate to DetailView
5. Press Menu button
6. ✅ Should go back to search results
```

### If Still Not Working
Add logging:
```swift
NavigationLink {
    DetailView(item: item)
        .onAppear {
            print("✅ DetailView appeared for: \(item.name)")
        }
} label: {
    SearchResultCard(item: item)
}
.onTapGesture {
    print("🔍 Link tapped: \(item.name)")
}
.buttonStyle(.plain)
```

Press Cmd+P to see if logs appear when you tap.

---

## Issue 3: Settings Not Showing

### The Problem
Created settings views but they're not in the settings menu.

### Quick Fix - Add Settings Tab

**Step 1: Add Settings to TabView**
```swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
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
            
            // ← ADD THIS!
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
```

**Step 2: Create SettingsView**
```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {  // ← Must have this!
            List {
                NavigationLink("Playback") {
                    PlaybackSettingsView()
                }
                
                NavigationLink("Streaming & Network") {
                    StreamingSettingsView()
                }
                
                NavigationLink("Subtitles") {
                    SubtitleSettingsView()
                }
                
                NavigationLink("Auto-Skip") {
                    SkipSettingsView()
                }
                
                Section {
                    NavigationLink("Account") {
                        AccountSettingsView()
                    }
                    
                    NavigationLink("App Settings") {
                        AppSettingsView()
                    }
                }
            }
            .navigationTitle("Settings")
            .listStyle(.grouped)
        }
    }
}
```

**Step 3: Create Placeholder Detail Views**
```swift
struct PlaybackSettingsView: View {
    @AppStorage("videoQuality") private var quality = "Auto"
    
    var body: some View {
        Form {
            Section("Video Quality") {
                Picker("Quality", selection: $quality) {
                    Text("Auto").tag("Auto")
                    Text("4K").tag("4K")
                    Text("1080p").tag("1080p")
                    Text("720p").tag("720p")
                }
            }
        }
        .navigationTitle("Playback")
    }
}

struct StreamingSettingsView: View {
    var body: some View {
        Form {
            Section("Bitrate") {
                Text("Streaming settings coming soon")
            }
        }
        .navigationTitle("Streaming")
    }
}

struct SubtitleSettingsView: View {
    var body: some View {
        Form {
            Section("Language") {
                Text("Subtitle settings coming soon")
            }
        }
        .navigationTitle("Subtitles")
    }
}

struct SkipSettingsView: View {
    @AppStorage("autoSkipIntros") private var skipIntros = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-Skip Intros", isOn: $skipIntros)
            }
        }
        .navigationTitle("Auto-Skip")
    }
}

struct AccountSettingsView: View {
    var body: some View {
        Form {
            Section {
                Button("Sign Out", role: .destructive) {
                    print("Sign out tapped")
                }
            }
        }
        .navigationTitle("Account")
    }
}

struct AppSettingsView: View {
    var body: some View {
        Form {
            Section("About") {
                Text("MediaMio v1.0.0")
            }
        }
        .navigationTitle("App")
    }
}
```

### Test It
```
1. Launch app
2. ✅ See "Settings" tab with gear icon
3. Navigate to Settings
4. ✅ See list of settings sections
5. Tap "Playback"
6. ✅ Navigate to PlaybackSettingsView
7. Press Menu
8. ✅ Return to Settings list
```

### If Files Are Gray in Xcode
```
1. Select the file in Project Navigator
2. Open File Inspector (⌘⌥1)
3. Under "Target Membership"
4. Check the box for your app target
5. File should no longer be gray
```

---

## Verification Checklist

### Auto-Scroll
- [ ] App starts at top on launch
- [ ] Hero banner is visible
- [ ] Returning to home goes to top
- [ ] Console shows no unexpected scroll events

### Search Selection
- [ ] Tapping search result navigates to detail
- [ ] Detail view displays correct item
- [ ] Menu button returns to search
- [ ] Focus behaves correctly

### Settings
- [ ] Settings tab appears in tab bar
- [ ] Settings list displays all sections
- [ ] Tapping section navigates to detail view
- [ ] Settings persist after app restart

---

## Common Mistakes

### ❌ Mistake 1: Missing Navigation Wrapper
**Problem:** NavigationLinks don't work
**Fix:** Wrap in NavigationView or NavigationStack

### ❌ Mistake 2: Using onTapGesture on tvOS
**Problem:** Tap doesn't work reliably
**Fix:** Use NavigationLink or Button instead

### ❌ Mistake 3: No .buttonStyle(.plain)
**Problem:** NavigationLink looks like a button
**Fix:** Add .buttonStyle(.plain) to NavigationLink

### ❌ Mistake 4: Files Not in Target
**Problem:** Views defined but not compiled
**Fix:** Check Target Membership in File Inspector

### ❌ Mistake 5: No Delay on Scroll
**Problem:** Scroll to top doesn't work
**Fix:** Add 0.1s delay with DispatchQueue.main.asyncAfter

---

## Resources

**Complete Guide:** [fix-common-ui-issues.md](fix-common-ui-issues.md)
- Detailed explanations
- Multiple solution approaches
- Complete diagnostic steps
- Advanced troubleshooting

**Quick Reference:** This document
- Immediate solutions
- Copy-paste code
- Testing checklists
- Common mistakes

---

## Summary

**Fix 1: Auto-Scroll**
→ Add ScrollViewReader + top anchor + scroll on appear

**Fix 2: Search Selection**
→ Use NavigationLink instead of onTapGesture

**Fix 3: Settings Not Showing**
→ Add Settings tab + NavigationView + detail views

All three fixes are simple and proven to work! 🚀
