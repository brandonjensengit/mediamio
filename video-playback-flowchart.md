# Video Playback Troubleshooting Flowchart

## Quick Diagnostic: Answer These Questions

### Q1: Can you see the video player controls?
- **YES** → Controls visible but video doesn't play → Go to Q2
- **NO** → Player not showing at all → Check if VideoPlayerView is being presented

### Q2: What does the console say when you try to play?
Run this code to get detailed output:

```swift
// Add this observer to your player setup
playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)

override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == "status", let item = object as? AVPlayerItem {
        print("🎬 Player Status: \(item.status.rawValue)")
        // 0 = unknown, 1 = readyToPlay, 2 = failed
        
        if item.status == .failed, let error = item.error {
            print("❌ ERROR: \(error.localizedDescription)")
            print("❌ Full error: \(error)")
        }
    }
}
```

**Console shows "readyToPlay" (status: 1)**
→ Player is ready but not playing → Did you call `player.play()`?

**Console shows "failed" (status: 2)**
→ See error message:
- "Cannot decode" → Wrong video format, need transcoding
- "Network error" → See Q3
- "Unauthorized" → See Q4
- Other error → Go to Q5

**Console shows "unknown" (status: 0)**
→ Player never initialized → Check URL construction

### Q3: Network Error - Is the URL reachable?

Test the stream URL directly:
```swift
print("Testing URL: \(streamURL)")

// Try to access it
URLSession.shared.dataTask(with: streamURL) { data, response, error in
    if let error = error {
        print("❌ Network error: \(error.localizedDescription)")
        // Can't reach server - check network/URL
        return
    }
    
    if let response = response as? HTTPURLResponse {
        print("✅ Server responded with status: \(response.statusCode)")
        if response.statusCode == 200 {
            print("✅ URL is valid and accessible!")
        } else if response.statusCode == 401 {
            print("❌ Authentication failed - check API key")
        }
    }
}.resume()
```

**URL test fails:**
- Check server URL is correct (e.g., `http://192.168.1.100:8096`)
- Check Apple TV and Jellyfin server are on same network
- Check Jellyfin server is running
- For HTTP, check Info.plist has NSAllowsArbitraryLoads

**URL test succeeds but player fails:**
→ AVPlayer doesn't like the format → Go to Q6

### Q4: Is Authentication Working?

Test your API key:
```swift
let testURL = "\(serverURL)/System/Info?api_key=\(apiKey)"

URLSession.shared.dataTask(with: URL(string: testURL)!) { data, response, error in
    if let response = response as? HTTPURLResponse {
        if response.statusCode == 200 {
            print("✅ Authentication works!")
        } else {
            print("❌ Auth failed: Status \(response.statusCode)")
        }
    }
}.resume()
```

**Auth test fails:**
- API key is wrong → Re-authenticate with Jellyfin
- Token expired → Get new token
- Using wrong header → Try both `api_key` query param AND `X-Emby-Token` header

### Q5: What URL Format Are You Using?

Print your complete stream URL:
```swift
print("🔗 Full Stream URL:")
print(streamURL.absoluteString)
```

Common formats and when to use them:

**Format 1: Direct Stream (Simple)**
```
http://server:8096/Videos/{itemId}/stream?api_key={key}&Static=true
```
- Use when: Video format is supported by Apple TV (h264, hevc)
- Pros: Simple, no transcoding needed
- Cons: Won't work if format not supported

**Format 2: HLS Streaming (Recommended)**
```
http://server:8096/Videos/{itemId}/master.m3u8?api_key={key}&[params]
```
- Use when: Want adaptive streaming
- Pros: Best quality, handles network changes
- Cons: Requires proper params

**Format 3: Download (Rarely needed)**
```
http://server:8096/Items/{itemId}/Download?api_key={key}
```
- Use when: Want to download entire file
- Pros: Works with any format
- Cons: Must download entire file first

**Which should you use?**
Start with Format 1 (simplest). If that doesn't work, try Format 2 with full params.

### Q6: Does the URL Work Outside Your App?

Copy the stream URL from console and test in:

1. **VLC Media Player**
   - Open VLC → File → Open Network
   - Paste URL
   - Does it play?

2. **Safari on Mac/iPhone**
   - Open Safari
   - Paste URL in address bar
   - Does it download/play?

**URL works in VLC but not in app:**
→ AVPlayer setup issue or missing parameters

**URL doesn't work anywhere:**
→ URL construction is wrong

## Common Issues & Quick Fixes

### Issue 1: "I see controls but black screen"

**Quick Fix:**
```swift
// Make sure you're calling play() after player is ready
case .readyToPlay:
    DispatchQueue.main.async {
        self.player.play() // ← Don't forget this!
        print("▶️ Started playback")
    }
```

### Issue 2: "Player status stays at 'unknown'"

**Quick Fix:**
URL is probably malformed. Print and verify:
```swift
print("URL: \(url.absoluteString)")
// Should look like: http://192.168.1.100:8096/Videos/12345/stream?api_key=abc123
```

### Issue 3: "Player status goes to 'failed' immediately"

**Quick Fix:**
Check the error:
```swift
if let error = playerItem.error {
    print("Error domain: \(error._domain)")
    print("Error code: \(error._code)")
    print("Error description: \(error.localizedDescription)")
}
```

Common errors:
- **NSURLErrorDomain -1022**: App Transport Security blocking HTTP
  - Fix: Add NSAllowsArbitraryLoads to Info.plist
- **NSURLErrorDomain -1003**: Can't reach server
  - Fix: Check server URL and network
- **AVFoundationErrorDomain -11800**: Format not supported
  - Fix: Use transcoding or different URL format

### Issue 4: "HTTP server not working (only HTTPS)"

**Quick Fix:**
Add to Info.plist:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Issue 5: "401 Unauthorized error"

**Quick Fix:**
Check your API key is being sent:
```swift
// Try adding token as header too
let headers = [
    "X-Emby-Token": apiKey,
    "X-MediaBrowser-Token": apiKey
]

let asset = AVURLAsset(url: streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
let playerItem = AVPlayerItem(asset: asset)
```

### Issue 6: "Transcoding not starting"

**Check Jellyfin server:**
1. Dashboard → Playback
2. Check "Enable video transcoding"
3. Check FFmpeg path is set correctly
4. Look at server logs for transcoding errors

## The "Nuclear Option" - Simplest Possible Test

If nothing else works, try this minimal test:

```swift
class MinimalPlayerTest {
    let player = AVPlayer()
    
    func testPlayback() {
        // Hardcode EVERYTHING to test
        let serverURL = "http://192.168.1.100:8096" // ← Your actual server URL
        let apiKey = "your-actual-api-key-here"     // ← Your actual API key
        let itemId = "actual-video-item-id"          // ← An actual video item ID
        
        // Simplest possible URL
        let urlString = "\(serverURL)/Videos/\(itemId)/stream?api_key=\(apiKey)&Static=true"
        let url = URL(string: urlString)!
        
        print("Testing with URL: \(url)")
        
        let playerItem = AVPlayerItem(url: url)
        
        // Check status
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("Status after 2 seconds: \(playerItem.status.rawValue)")
            if playerItem.status == .readyToPlay {
                print("✅ IT WORKS! Now integrate properly.")
                self.player.replaceCurrentItem(with: playerItem)
                self.player.play()
            } else if playerItem.status == .failed {
                print("❌ Failed: \(playerItem.error?.localizedDescription ?? "unknown")")
            }
        }
    }
}
```

If this works → Your authentication/URL construction is fine, issue is in your main code
If this doesn't work → Problem is with server setup or network

## Step-by-Step Debug Process

Follow this exact order:

### Step 1: Verify Server Connection
```bash
# From terminal or use network tools
curl http://your-server:8096/System/Info?api_key=your-key
```
Should return JSON with server info.

### Step 2: Add Logging
Add the comprehensive logging from the main prompt file.

### Step 3: Test Stream URL
Print the URL and test it in VLC.

### Step 4: Check Player Status
Add status observer and print the status.

### Step 5: Check Error
If status is failed, print the full error.

### Step 6: Fix Based on Error
Use the error message to determine next steps.

### Step 7: Test Again
After each fix, test again immediately.

## Success Criteria

You'll know it's working when:
1. ✅ Console shows "readyToPlay" status
2. ✅ Console shows "Started playback"
3. ✅ Video appears on screen
4. ✅ Progress bar moves
5. ✅ Audio plays

## Still Stuck?

Provide Claude Code with:
1. Complete console logs from app launch to play attempt
2. The exact stream URL being used (with sensitive parts redacted)
3. AVPlayerItem status
4. Any error messages
5. Whether URL works in VLC
6. Your Jellyfin server version
7. Video file format (h264? hevc? av1?)

This will allow precise diagnosis!

---

## TL;DR - Most Common Fixes

**90% of issues are:**

1. **Forgot to call play()** → Add `player.play()` in .readyToPlay case
2. **HTTP blocked by ATS** → Add NSAllowsArbitraryLoads to Info.plist
3. **Wrong URL format** → Use `/Videos/{id}/stream?api_key={key}&Static=true`
4. **Bad API key** → Re-authenticate and get fresh token
5. **Network not reachable** → Verify server URL and network connection

Try these five things first before deep debugging!
