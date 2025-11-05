# Quick Fix: Content Card Focus - Remove Frame, Add Depth

## The Problem (Your Screenshot)

First card has **white border/frame** when focused - looks like a selection box, not modern.

**Want:** Card should scale up and "pull out" with shadow, like Netflix.

## Copy to Claude Code

```
Fix content card focus effect throughout app.

Problem (screenshot): Cards show white border/frame when focused. 
Want: Cards should scale up and "pull out" with depth instead.

FIX ALL CONTENT CARDS:

1. REMOVE all border/frame code:
   - Search for .border(...) - DELETE
   - Search for .overlay(RoundedRectangle(...).stroke(...)) - DELETE
   - Search for .background(Color.white) on focus - DELETE
   - Remove ANY white frame/border modifiers

2. ADD Netflix-style focus effect:

struct ContentCard: View {
    let item: MediaItem
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack {
            AsyncImage(url: item.posterURL) { ... }
                .cornerRadius(8)
            
            Text(item.name)
                .foregroundColor(.white)
        }
        .frame(width: 250)
        // ✅ ADD THESE EFFECTS:
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .shadow(
            color: Color.black.opacity(isFocused ? 0.6 : 0),
            radius: isFocused ? 20 : 0,
            y: isFocused ? 10 : 0
        )
        .zIndex(isFocused ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .focusable()
        .focused($isFocused)
        // ❌ NO .border, NO .overlay stroke, NO white background
    }
}

3. INCREASE spacing to prevent overlap:
   LazyHStack(spacing: 30) {  // Increase from 20
       ForEach(items) { ... }
   }
   .padding(.vertical, 20)  // Room for shadow

4. Apply to ALL content displays:
   - Recently Added (screenshot)
   - Continue Watching
   - All genre rows
   - Search results
   - Library grids

TESTING:
Navigate cards → should scale smoothly with shadow, NO white frame.

Read fix-content-card-focus-effect.md for details.
```

---

## The Fix (Visual)

### Before (Bad - Your Screenshot)
```
┌─────────────┐
│ [Poster]    │ ← White frame around it
│ Title       │
└─────────────┘
```

### After (Good - Netflix Style)
```
    [Poster]      ← Scales up 1.1x
    Title         ← Shadow below creates depth
                  ← No frame!
```

---

## Code Changes

### ❌ REMOVE These (Bad):
```swift
.border(Color.white, width: 4)  // ❌ DELETE
.overlay(
    RoundedRectangle(cornerRadius: 8)
        .stroke(Color.white, lineWidth: 4)  // ❌ DELETE
)
.background(isFocused ? Color.white : .clear)  // ❌ DELETE
```

### ✅ ADD These (Good):
```swift
.scaleEffect(isFocused ? 1.1 : 1.0)  // Enlarge 10%
.shadow(
    color: .black.opacity(isFocused ? 0.6 : 0),
    radius: isFocused ? 20 : 0,
    y: isFocused ? 10 : 0
)
.zIndex(isFocused ? 1 : 0)  // Bring to front
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
```

---

## Complete Working Example

```swift
struct ContentCard: View {
    let item: MediaItem
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster
            AsyncImage(url: item.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(ProgressView())
            }
            .cornerRadius(8)
            
            // Title
            Text(item.name)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .frame(width: 250)
        // ✅ Focus effects (NO borders!)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .shadow(
            color: .black.opacity(isFocused ? 0.6 : 0),
            radius: isFocused ? 20 : 0,
            y: isFocused ? 10 : 0
        )
        .zIndex(isFocused ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .focusable()
        .focused($isFocused)
    }
}
```

---

## Where to Apply

Fix ALL these places:

- ✅ Recently Added row (your screenshot)
- ✅ Continue Watching row
- ✅ Movies section
- ✅ TV Shows section
- ✅ All genre rows (Action, Comedy, etc.)
- ✅ Search results grid
- ✅ Library grid views
- ✅ ANY content card display

---

## Important: Spacing

When cards scale up, they need room:

```swift
// BEFORE
LazyHStack(spacing: 20) { ... }

// AFTER
LazyHStack(spacing: 30) { ... }  // Wider spacing
    .padding(.vertical, 20)      // Room for shadow
```

---

## Testing Checklist

```
Test each content section:

[ ] Recently Added → Focus card → Scales up with shadow ✅
[ ] Continue Watching → Focus card → Scales up with shadow ✅
[ ] Movies → Focus card → Scales up with shadow ✅
[ ] TV Shows → Focus card → Scales up with shadow ✅
[ ] Search results → Focus card → Scales up with shadow ✅

Verify NO white borders/frames anywhere! ❌
```

---

## Customization Options

### Scale Amount
```swift
.scaleEffect(isFocused ? 1.1 : 1.0)   // Subtle
.scaleEffect(isFocused ? 1.15 : 1.0)  // Medium ← Recommended
.scaleEffect(isFocused ? 1.2 : 1.0)   // Dramatic
```

### Shadow Intensity
```swift
color: .black.opacity(0.4)  // Light
color: .black.opacity(0.6)  // Medium ← Recommended
color: .black.opacity(0.8)  // Heavy
```

### Animation Style
```swift
.animation(.easeInOut(duration: 0.2), value: isFocused)  // Quick
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)  // Bouncy ← Recommended
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFocused)  // Smooth
```

---

## Optional: Add Info on Focus

Show extra info when focused:

```swift
ZStack(alignment: .bottom) {
    // Poster
    AsyncImage(url: item.posterURL) { ... }
    
    // Info overlay when focused
    if isFocused {
        LinearGradient(
            colors: [.clear, .black.opacity(0.8)],
            startPoint: .center,
            endPoint: .bottom
        )
        .frame(height: 100)
        .overlay(
            VStack(alignment: .leading) {
                Text(item.name)
                HStack {
                    Text(item.year)
                    Image(systemName: "star.fill")
                    Text(item.rating)
                }
            }
            .padding()
        )
    }
}
```

---

## The Formula

**Remove:** White borders, frames, backgrounds
**Add:** Scale (1.1x) + Shadow + Z-index
**Result:** Cards "pull out" like Netflix ✅

---

## Summary

**Current:** White frame/border on focus (looks old)
**Fixed:** Scale up with shadow (looks modern)

Apply to EVERY content card in the app for consistent Netflix-style focus effects!
