# Quick Fix: Apple TV Remote Play/Pause

## TL;DR - The Fix

Menu button works but play/pause doesn't? **Add this to your video player view:**

```swift
.onPlayPauseCommand {
    // Your toggle play/pause logic here
    if isPlaying {
        player.pause()
        isPlaying = false
    } else {
        player.play()
        isPlaying = true
    }
}
```

That's it! 90% of the time this solves the problem.

## Tell Claude Code (Copy This)

### Quick Fix Prompt:
```
The Apple TV remote's menu button works (goes back) but the play/pause 
button doesn't control video playback in the simulator.

Read fix-remote-controls.md and implement Solution 1: Add Play/Pause 
Command Handling.

Specifically:
1. Add .onPlayPauseCommand { } modifier to the video player view
2. Implement togglePlayPause() method that calls player.play() or player.pause()
3. Add logging: print("🎮 Play/Pause pressed") to verify it's working
4. Set focus on player: .focusable() and .focused($isPlayerFocused)

Test with Cmd+P in simulator - should see the log message.
```

### Complete Implementation Prompt:
```
Read fix-remote-controls.md completely and implement the "Complete 
Working Example" section.

This includes:
- .onPlayPauseCommand handler
- .onMoveCommand for seek (left/right swipes)
- .onExitCommand for menu button
- MPRemoteCommandCenter for system-level controls
- Proper focus management
- Control auto-hide functionality

Make sure all remote buttons work:
- Cmd+P for play/pause
- Arrow keys for navigation
- Escape for back/menu
- Arrow left/right for seek

Add console logging for each command to verify they're working.
```

## Testing in Simulator

### Keyboard Shortcuts:
- **Cmd + P** → Play/Pause button
- **Escape** → Menu button (back)
- **Arrow Keys** → Navigate/swipe
- **Space Bar** → Select/click
- **Cmd + Shift + R** → Show visual remote

### Show Visual Remote (Recommended):
1. **Window → Show Remote** (or Cmd+Shift+R)
2. Click buttons with mouse
3. More reliable than keyboard shortcuts

## The Problem Explained

**Why Menu Works But Play/Pause Doesn't:**
- Menu button (`.onExitCommand`) is a system navigation command - works automatically
- Play/Pause (`.onPlayPauseCommand`) is a media command - must be explicitly handled
- Without the handler, the command is ignored

**Common Mistake:**
```swift
// ❌ Missing play/pause handler
VideoPlayer(player: player)
    .onExitCommand { dismiss() }  // Menu works
    // No .onPlayPauseCommand!      // Play/Pause ignored!
```

**Correct:**
```swift
// ✅ With play/pause handler
VideoPlayer(player: player)
    .onExitCommand { dismiss() }
    .onPlayPauseCommand { togglePlayPause() }  // Now it works!
```

## Verify It's Working

Add logging and test:

```swift
.onPlayPauseCommand {
    print("🎮 Play/Pause command received!")  // Should print when you press Cmd+P
    togglePlayPause()
}
```

**Run the app, press Cmd+P:**
- ✅ If you see the log → Command received, check your play/pause logic
- ❌ If no log → Command not received, need to add the modifier

## Quick Diagnostic

### Test 1: Is the command being received?
```swift
.onPlayPauseCommand {
    print("TEST: Play/Pause pressed")
}
```
Press Cmd+P. If nothing prints → Need to add focus or check view hierarchy.

### Test 2: Is focus on the player?
```swift
@FocusState private var isPlayerFocused: Bool

var body: some View {
    VideoPlayer(player: player)
        .focusable()
        .focused($isPlayerFocused)
        .onAppear {
            isPlayerFocused = true
            print("Focus set to player")
        }
}
```

### Test 3: Are you calling the right methods?
```swift
func togglePlayPause() {
    print("togglePlayPause called")
    print("Current status: \(player.timeControlStatus)")
    
    if player.timeControlStatus == .playing {
        player.pause()
        print("Paused")
    } else {
        player.play()
        print("Playing")
    }
}
```

## Most Common Issues

### Issue 1: No `.onPlayPauseCommand` modifier
**Symptom:** Nothing happens when pressing Cmd+P
**Fix:** Add the modifier to your view

### Issue 2: Wrong view has focus
**Symptom:** Command received but nothing happens
**Fix:** Add `.focusable()` and `.focused($isPlayerFocused)`

### Issue 3: Using AVKit's VideoPlayer without custom handling
**Symptom:** Default controls don't respond to remote
**Fix:** Use `AVPlayerViewController` or add command handlers

### Issue 4: Simulator keyboard not working
**Symptom:** Keyboard shortcuts don't work
**Fix:** Use Window → Show Remote instead

### Issue 5: Logic error in toggle function
**Symptom:** Command received but playback doesn't change
**Fix:** Check your play/pause implementation

## Complete Minimal Example

Copy this into your project to test:

```swift
import SwiftUI
import AVKit

struct TestVideoPlayerView: View {
    @StateObject private var playerManager = TestPlayerManager()
    @FocusState private var isPlayerFocused: Bool
    
    var body: some View {
        VideoPlayer(player: playerManager.player)
            .ignoresSafeArea()
            .focusable()
            .focused($isPlayerFocused)
            .onAppear {
                isPlayerFocused = true
                playerManager.play(url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!)
            }
            .onPlayPauseCommand {
                print("🎮 Play/Pause pressed!")
                playerManager.togglePlayPause()
            }
            .onExitCommand {
                print("🎮 Menu pressed!")
            }
    }
}

class TestPlayerManager: ObservableObject {
    @Published var player = AVPlayer()
    @Published var isPlaying = false
    
    func play(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
        print("▶️ Started playing")
    }
    
    func togglePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
            print("⏸️ Paused")
        } else {
            player.play()
            isPlaying = true
            print("▶️ Playing")
        }
    }
}
```

**Test this:**
1. Build and run
2. Press **Cmd+P**
3. Should see "🎮 Play/Pause pressed!" in console
4. Video should pause/play

If this works, then integrate the same pattern into your main player view.

## Next Steps if Still Not Working

If the quick fix doesn't work, tell Claude Code:

```
I implemented the .onPlayPauseCommand handler but it's still not working.

Here's what I see in console when I press Cmd+P:
[paste console output]

Here's my video player view code:
[paste relevant code]

What's wrong?
```

## All Remote Commands Available

Once basic play/pause works, you can add:

```swift
.onPlayPauseCommand { /* Play/Pause button */ }
.onExitCommand { /* Menu button */ }
.onMoveCommand { direction in 
    /* Arrow keys / swipes */
    switch direction {
    case .left: seek(-10)
    case .right: seek(+10)
    case .up: /* volume or UI */
    case .down: /* volume or UI */
    }
}
```

## Resources

**Complete Guide:** [fix-remote-controls.md](fix-remote-controls.md)
- All solutions explained in detail
- Multiple implementation approaches
- Complete working examples
- Troubleshooting checklist

**Quick Start:**
1. Read this summary (2 min) ✓
2. Add `.onPlayPauseCommand` to your view (2 min)
3. Test with Cmd+P (30 sec)
4. If working, add other commands (5 min)
5. If not working, read full guide (10 min)

---

**Bottom Line:** Add `.onPlayPauseCommand { togglePlayPause() }` to your video player view and test with Cmd+P. That's the fix for 90% of cases!
