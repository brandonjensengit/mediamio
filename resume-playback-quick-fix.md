# Quick Fix: Resume Playback

## TL;DR - Copy This to Claude Code

```
Implement resume playback functionality so videos start from where users left off.

Current issue: Resume buttons start videos from the beginning instead of saved position.

Required implementation:

1. FETCH USER DATA FROM JELLYFIN
   - Add userData field to MediaItem model
   - userData contains playbackPositionTicks (position in ticks)
   - Convert ticks to seconds: ticks / 10_000_000.0

2. SEEK TO SAVED POSITION
   - In VideoPlayerManager, add resume(item:url:) method
   - Get start position from item.userData.playbackPositionSeconds
   - Seek player to that position BEFORE playing
   - Code: player.seek(to: CMTime(seconds: startPosition)) { player.play() }

3. REPORT PROGRESS TO JELLYFIN
   - Create PlaybackReporter class
   - reportPlaybackStart() when video starts
   - reportPlaybackProgress() every 10 seconds during playback
   - reportPlaybackStopped() when video exits
   - Use Jellyfin endpoints: /Sessions/Playing, /Sessions/Playing/Progress, /Sessions/Playing/Stopped

4. UPDATE UI
   - Show "Resume" button if item has progress (not "Play")
   - Show progress bar on content cards
   - Add "Continue Watching" row on home screen

5. MARK AS WATCHED
   - When video reaches 90%+, mark as watched
   - Use endpoint: POST /Users/{userId}/PlayedItems/{id}

Test by:
- Watch video for 2 minutes, exit
- Return to detail - should show Resume button
- Click Resume - should start at 2 minute mark
- Progress should save every 10 seconds

Read fix-resume-playback.md for complete implementation.
```

---

## The Problem

**Current behavior:**
- User watches video partially
- User exits video
- Returns later
- Clicks "Resume"
- ❌ Video starts from beginning

**Expected behavior:**
- User watches video partially (e.g., 30 minutes)
- User exits video
- Position saved to Jellyfin (30:00)
- Returns later
- Clicks "Resume"
- ✅ Video starts at 30:00

---

## Three Key Components

### 1. Fetch Saved Position from Jellyfin

```swift
struct JellyfinUserData: Codable {
    let playbackPositionTicks: Int64  // Position in ticks
    let played: Bool  // Marked as watched
    
    var playbackPositionSeconds: Double {
        Double(playbackPositionTicks) / 10_000_000.0  // Convert to seconds
    }
}

struct MediaItem: Codable {
    let id: String
    let name: String
    let runTimeTicks: Int64?
    let userData: JellyfinUserData?  // ← Add this!
    
    var shouldShowResume: Bool {
        guard let userData = userData else { return false }
        return userData.playbackPositionSeconds > 0 && !userData.played
    }
    
    var progressPercentage: Double {
        guard let userData = userData,
              let runtime = runTimeTicks else { return 0 }
        
        let position = userData.playbackPositionSeconds
        let total = Double(runtime) / 10_000_000.0
        return (position / total) * 100.0
    }
}
```

### 2. Seek to Saved Position

```swift
class VideoPlayerManager: ObservableObject {
    @Published var player = AVPlayer()
    
    func resume(item: MediaItem, url: URL) {
        let startPosition = item.userData?.playbackPositionSeconds ?? 0
        
        print("📍 Resuming from \(startPosition) seconds")
        
        // Create player item
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        
        // Wait for ready, then seek
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let seekTime = CMTime(seconds: startPosition, preferredTimescale: 1)
            
            self.player.seek(to: seekTime) { finished in
                guard finished else {
                    print("❌ Seek failed")
                    return
                }
                
                print("✅ Seeked to \(startPosition)s, starting playback")
                self.player.play()
            }
        }
    }
    
    func playFromBeginning(item: MediaItem, url: URL) {
        print("📍 Playing from beginning")
        
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
    }
}
```

### 3. Report Progress Back to Jellyfin

```swift
class PlaybackReporter {
    func reportPlaybackStart(itemId: String, positionSeconds: Double) async {
        let url = "\(serverURL)/Sessions/Playing"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "ItemId": itemId,
            "PlaySessionId": UUID().uuidString,
            "PositionTicks": Int64(positionSeconds * 10_000_000),
            "IsPaused": false
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (_, _) = try? await URLSession.shared.data(for: request)
        print("✅ Reported playback start at \(positionSeconds)s")
    }
    
    func reportPlaybackProgress(itemId: String, positionSeconds: Double) async {
        let url = "\(serverURL)/Sessions/Playing/Progress"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        
        let body: [String: Any] = [
            "ItemId": itemId,
            "PositionTicks": Int64(positionSeconds * 10_000_000)
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (_, _) = try? await URLSession.shared.data(for: request)
        print("📊 Reported progress: \(positionSeconds)s")
    }
    
    func reportPlaybackStopped(itemId: String, positionSeconds: Double) async {
        let url = "\(serverURL)/Sessions/Playing/Stopped"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        
        let body: [String: Any] = [
            "ItemId": itemId,
            "PositionTicks": Int64(positionSeconds * 10_000_000)
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (_, _) = try? await URLSession.shared.data(for: request)
        print("✅ Reported playback stop at \(positionSeconds)s")
    }
}
```

---

## UI Updates

### Resume Button in Detail View

```swift
struct DetailView: View {
    let item: MediaItem
    
    var body: some View {
        VStack {
            // ... backdrop, title, etc ...
            
            // Resume or Play button
            if item.shouldShowResume {
                Button {
                    resumeVideo()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Resume")
                    }
                }
            } else {
                Button {
                    playVideo()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Play")
                    }
                }
            }
            
            // Show progress if partially watched
            if let progress = item.progressPercentage, progress > 0 {
                ProgressView(value: progress, total: 100)
                Text("\(Int(progress))% watched")
            }
        }
    }
    
    func resumeVideo() {
        playerManager.resume(item: item, url: streamURL)
    }
    
    func playVideo() {
        playerManager.playFromBeginning(item: item, url: streamURL)
    }
}
```

### Progress Bar on Content Cards

```swift
struct ContentCard: View {
    let item: MediaItem
    
    var body: some View {
        VStack {
            ZStack(alignment: .bottom) {
                // Poster image
                AsyncImage(url: item.posterURL) { ... }
                
                // Progress bar overlay
                if let progress = item.progressPercentage, progress > 0 {
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            ZStack(alignment: .leading) {
                                // Background
                                Rectangle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(height: 4)
                                
                                // Progress
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(
                                        width: geo.size.width * (progress / 100),
                                        height: 4
                                    )
                            }
                        }
                    }
                }
            }
            
            Text(item.name)
        }
    }
}
```

---

## Complete Flow

### 1. User Starts Watching
```
User clicks Play
↓
Video starts at 0:00
↓
reportPlaybackStart(itemId, position: 0)
↓
Start timer: report progress every 10 seconds
```

### 2. User Watches Partially
```
Timer fires every 10 seconds
↓
reportPlaybackProgress(itemId, currentPosition)
↓
Jellyfin saves position
```

### 3. User Exits
```
User presses Menu
↓
Stop timer
↓
reportPlaybackStopped(itemId, finalPosition)
↓
Position saved to Jellyfin
```

### 4. User Returns
```
Fetch item with userData
↓
Check userData.playbackPositionSeconds
↓
If > 0: Show "Resume" button
↓
User clicks Resume
↓
player.seek(to: savedPosition)
↓
player.play()
↓
Video starts at saved position! ✅
```

---

## Testing

### Quick Test
```
1. Play any video
2. Watch for ~2 minutes
3. Exit (press Menu)
4. Wait 5 seconds
5. Go back to detail view
6. ✅ Should show "Resume" button
7. ✅ Should show progress bar (~2 min / total)
8. Click Resume
9. ✅ Should start at ~2 minute mark
```

### Check Console Logs
```
✅ "Resuming from X seconds"
✅ "Seeked to Xs, starting playback"
✅ "Reported playback start at Xs"
✅ "Reported progress: Xs" (every 10s)
✅ "Reported playback stop at Xs"
```

---

## Common Issues

### Issue 1: Video Starts at Beginning
**Check:**
- Is seek completing? Add log in completion handler
- Is seek being called? Add log before seek
- Is position > 0? Print startPosition

**Fix:**
```swift
player.seek(to: seekTime) { finished in
    print("Seek finished: \(finished)")  // ← Should be true
    if finished {
        player.play()
    }
}
```

### Issue 2: Position Not Saving
**Check:**
- Is reportPlaybackProgress being called?
- Is timer running?
- Are API requests succeeding?

**Fix:**
```swift
Timer.scheduledTimer(withTimeInterval: 10) { _ in
    print("⏰ Timer fired")  // ← Should print every 10s
    reportProgress()
}
```

### Issue 3: Resume Button Doesn't Show
**Check:**
- Is userData being fetched?
- Is playbackPositionTicks > 0?
- Is shouldShowResume calculated correctly?

**Fix:**
```swift
print("User data: \(item.userData)")
print("Position: \(item.userData?.playbackPositionSeconds)")
print("Should show resume: \(item.shouldShowResume)")
```

---

## Key Jellyfin Endpoints

```
GET /Users/{userId}/Items/{id}
→ Fetch item with userData (includes playbackPositionTicks)

POST /Sessions/Playing
→ Report playback start
Body: { ItemId, PlaySessionId, PositionTicks }

POST /Sessions/Playing/Progress
→ Report progress (call every 10 seconds)
Body: { ItemId, PositionTicks }

POST /Sessions/Playing/Stopped
→ Report playback stopped
Body: { ItemId, PositionTicks }

POST /Users/{userId}/PlayedItems/{id}
→ Mark as watched (at 90%+ completion)

GET /Users/{userId}/Items/Resume
→ Get "Continue Watching" items
```

---

## Essential Code Snippet

Copy this minimal implementation:

```swift
// 1. Add to MediaItem
struct MediaItem: Codable {
    let userData: JellyfinUserData?
    
    var resumePosition: Double {
        userData?.playbackPositionSeconds ?? 0
    }
    
    var shouldResume: Bool {
        resumePosition > 0
    }
}

// 2. Add to VideoPlayerManager
func resume(item: MediaItem, url: URL) {
    let position = item.resumePosition
    let playerItem = AVPlayerItem(url: url)
    player.replaceCurrentItem(with: playerItem)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.player.seek(to: CMTime(seconds: position)) { _ in
            self.player.play()
        }
    }
}

// 3. Add to DetailView
if item.shouldResume {
    Button("Resume") {
        playerManager.resume(item: item, url: streamURL)
    }
} else {
    Button("Play") {
        playerManager.playFromBeginning(item: item, url: streamURL)
    }
}
```

That's the minimum needed to get resume working! Add progress reporting next for persistence.

---

## Resources

**Complete Guide:** [fix-resume-playback.md](fix-resume-playback.md)
- Full PlaybackReporter implementation
- Complete API integration
- UI components
- Testing procedures

**Quick Reference:** This document
- Essential code only
- Fast implementation
- Common issues

---

**Bottom Line:** Fetch userData from Jellyfin, seek to playbackPositionSeconds, report progress back. That's resume! 🎬
