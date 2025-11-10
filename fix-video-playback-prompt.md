# Claude Code Prompt: Fix Jellyfin Video Playback

## Problem
Video player shows overlay controls but video never starts playing. The AVPlayer appears to be initialized but no video content is streaming from the Jellyfin server.

## Debugging Strategy

### Step 1: Add Comprehensive Logging
First, we need to see what's happening. Add detailed logging to understand the issue:

```swift
// Add this to your VideoPlayerView or PlayerViewModel

func setupPlayer(for item: MediaItem) {
    print("🎬 === VIDEO PLAYBACK DEBUG ===")
    print("📦 Item ID: \(item.id)")
    print("📦 Item Name: \(item.name)")
    print("📦 Item Type: \(item.type)")
    
    let streamURL = buildStreamURL(for: item)
    print("🔗 Stream URL: \(streamURL)")
    
    let playerItem = AVPlayerItem(url: streamURL)
    
    // Add status observer BEFORE setting player item
    playerItem.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
    
    player.replaceCurrentItem(with: playerItem)
    
    print("▶️ Player initialized, waiting for status...")
}

override func observeValue(forKeyPath keyPath: String?, 
                          of object: Any?, 
                          change: [NSKeyValueChangeKey : Any]?, 
                          context: UnsafeMutableRawPointer?) {
    
    if keyPath == "status" {
        if let playerItem = object as? AVPlayerItem {
            switch playerItem.status {
            case .readyToPlay:
                print("✅ PlayerItem status: READY TO PLAY")
                print("⏱️ Duration: \(playerItem.duration)")
                player.play()
                
            case .failed:
                print("❌ PlayerItem status: FAILED")
                if let error = playerItem.error {
                    print("❌ Error: \(error.localizedDescription)")
                    print("❌ Error details: \(error)")
                }
                
            case .unknown:
                print("⚠️ PlayerItem status: UNKNOWN")
                
            @unknown default:
                print("⚠️ PlayerItem status: UNEXPECTED")
            }
        }
    }
}
```

### Step 2: Verify Stream URL Construction

The Jellyfin streaming URL must be constructed correctly. Here are the common patterns:

**For Direct Play (when client supports the format):**
```swift
func buildDirectPlayURL(for item: MediaItem) -> URL {
    // Format: http://server:port/Items/{itemId}/Download?api_key={apiKey}
    let baseURL = jellyfinAPI.serverURL // e.g., "http://192.168.1.100:8096"
    let apiKey = jellyfinAPI.authToken
    
    let urlString = "\(baseURL)/Items/\(item.id)/Download?api_key=\(apiKey)"
    
    print("🔗 Direct Play URL: \(urlString)")
    return URL(string: urlString)!
}
```

**For HLS Streaming (recommended for tvOS):**
```swift
func buildHLSStreamURL(for item: MediaItem) -> URL {
    // Format: http://server:port/Videos/{itemId}/master.m3u8?params
    let baseURL = jellyfinAPI.serverURL
    let apiKey = jellyfinAPI.authToken
    let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "tvos-device"
    
    var components = URLComponents(string: "\(baseURL)/Videos/\(item.id)/master.m3u8")!
    components.queryItems = [
        URLQueryItem(name: "api_key", value: apiKey),
        URLQueryItem(name: "DeviceId", value: deviceId),
        URLQueryItem(name: "MediaSourceId", value: item.id),
        URLQueryItem(name: "VideoCodec", value: "h264,hevc"),
        URLQueryItem(name: "AudioCodec", value: "aac,mp3"),
        URLQueryItem(name: "MaxStreamingBitrate", value: "20000000"), // 20 Mbps
        URLQueryItem(name: "TranscodingProtocol", value: "hls"),
        URLQueryItem(name: "TranscodingContainer", value: "ts"),
        URLQueryItem(name: "EnableRedirection", value: "true"),
        URLQueryItem(name: "EnableRemoteMedia", value: "true")
    ]
    
    let url = components.url!
    print("🔗 HLS Stream URL: \(url.absoluteString)")
    return url
}
```

**For Transcoded Streaming:**
```swift
func buildTranscodeURL(for item: MediaItem) -> URL {
    let baseURL = jellyfinAPI.serverURL
    let apiKey = jellyfinAPI.authToken
    
    var components = URLComponents(string: "\(baseURL)/Videos/\(item.id)/stream")!
    components.queryItems = [
        URLQueryItem(name: "api_key", value: apiKey),
        URLQueryItem(name: "Container", value: "ts"),
        URLQueryItem(name: "VideoCodec", value: "h264"),
        URLQueryItem(name: "AudioCodec", value: "aac"),
        URLQueryItem(name: "MaxStreamingBitrate", value: "20000000"),
        URLQueryItem(name: "TranscodeReasons", value: "VideoCodecNotSupported")
    ]
    
    return components.url!
}
```

### Step 3: Check Authentication

The API key/token must be valid. Test it:

```swift
func verifyAuthentication() {
    print("🔐 Testing authentication...")
    print("🔐 Server URL: \(serverURL)")
    print("🔐 API Key: \(apiKey.prefix(10))...") // Don't print full key
    
    // Test with a simple API call
    let testURL = "\(serverURL)/System/Info?api_key=\(apiKey)"
    
    URLSession.shared.dataTask(with: URL(string: testURL)!) { data, response, error in
        if let error = error {
            print("❌ Auth test failed: \(error)")
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("✅ Auth test status: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 200 {
                print("✅ Authentication is working!")
            } else {
                print("❌ Authentication failed with status \(httpResponse.statusCode)")
            }
        }
    }.resume()
}
```

### Step 4: Test Different Streaming Methods

Try these approaches in order:

#### Approach 1: Simple Direct Stream (Test First)
```swift
func testSimpleStream(itemId: String) {
    // Simplest possible URL
    let url = URL(string: "\(serverURL)/Videos/\(itemId)/stream?api_key=\(apiKey)&Static=true")!
    
    print("🧪 Testing simple stream: \(url)")
    
    let playerItem = AVPlayerItem(url: url)
    player.replaceCurrentItem(with: playerItem)
    
    // Add observer and wait for result
}
```

#### Approach 2: HLS with Proper Headers
```swift
func setupHLSStream(itemId: String) {
    let url = buildHLSStreamURL(for: item)
    
    // Create asset with proper headers
    let headers = [
        "X-Emby-Token": apiKey, // Jellyfin also accepts Emby headers
        "X-MediaBrowser-Token": apiKey // Alternative header
    ]
    
    let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
    let playerItem = AVPlayerItem(asset: asset)
    
    player.replaceCurrentItem(with: playerItem)
}
```

#### Approach 3: Manual MediaSource Selection
```swift
func getMediaSources(for itemId: String, completion: @escaping ([MediaSource]) -> Void) {
    let url = URL(string: "\(serverURL)/Items/\(itemId)/PlaybackInfo?api_key=\(apiKey)")!
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Request body with device profile
    let body: [String: Any] = [
        "DeviceProfile": [
            "MaxStreamingBitrate": 20000000,
            "DirectPlayProfiles": [
                ["Type": "Video", "Container": "m4v,mp4,mov", "VideoCodec": "h264,hevc", "AudioCodec": "aac,mp3"]
            ]
        ]
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        // Parse response and get optimal stream URL
        if let data = data {
            print("📦 PlaybackInfo response: \(String(data: data, encoding: .utf8) ?? "none")")
            // Parse and use the URL from the response
        }
    }.resume()
}
```

### Step 5: Check Network Permissions

Ensure Info.plist has the right settings:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <!-- Or be more specific: -->
    <key>NSExceptionDomains</key>
    <dict>
        <key>your-jellyfin-server.local</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### Step 6: Common Issues and Fixes

#### Issue: CORS or SSL Certificate Problems
**Fix:** Use HTTP instead of HTTPS for local testing, or configure proper SSL certs

#### Issue: Wrong Content-Type
**Fix:** Jellyfin needs specific headers for streaming
```swift
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue("MediaBrowser Client=\"MediaMio\", Device=\"AppleTV\", DeviceId=\"\(deviceId)\", Version=\"1.0.0\"", 
                 forHTTPHeaderField: "X-Emby-Authorization")
```

#### Issue: Transcoding Not Starting
**Fix:** Check Jellyfin server logs. May need to install FFmpeg or configure transcoding paths

#### Issue: Network Unreachable
**Fix:** Verify server URL is reachable from Apple TV (same network for local server)

## Complete Working Implementation

Here's a complete, working video player setup:

```swift
import AVFoundation
import AVKit
import SwiftUI

class VideoPlayerManager: NSObject, ObservableObject {
    @Published var player = AVPlayer()
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var errorMessage: String?
    
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    
    private let serverURL: String
    private let apiKey: String
    private let deviceId: String
    
    init(serverURL: String, apiKey: String) {
        self.serverURL = serverURL
        self.apiKey = apiKey
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "mediamio-tvos"
        super.init()
    }
    
    func playVideo(itemId: String, itemName: String) {
        print("🎬 === STARTING PLAYBACK ===")
        print("📦 Item ID: \(itemId)")
        print("📦 Item Name: \(itemName)")
        
        // Clean up previous player
        cleanup()
        
        // Build stream URL
        let streamURL = buildStreamURL(itemId: itemId)
        print("🔗 Stream URL: \(streamURL.absoluteString)")
        
        // Create player item
        let asset = AVURLAsset(url: streamURL)
        playerItem = AVPlayerItem(asset: asset)
        
        guard let playerItem = playerItem else { return }
        
        // Observe status
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new, .initial], context: nil)
        
        // Set player item
        player.replaceCurrentItem(with: playerItem)
        
        // Add time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
        
        print("✅ Player setup complete, waiting for ready state...")
    }
    
    private func buildStreamURL(itemId: String) -> URL {
        // Try HLS streaming first (best for tvOS)
        var components = URLComponents(string: "\(serverURL)/Videos/\(itemId)/master.m3u8")!
        
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "DeviceId", value: deviceId),
            URLQueryItem(name: "MediaSourceId", value: itemId),
            URLQueryItem(name: "VideoCodec", value: "h264,hevc,vp9"),
            URLQueryItem(name: "AudioCodec", value: "aac,mp3,opus"),
            URLQueryItem(name: "MaxStreamingBitrate", value: "20000000"),
            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "TranscodingProtocol", value: "hls"),
            URLQueryItem(name: "TranscodingContainer", value: "ts"),
            URLQueryItem(name: "EnableRedirection", value: "true"),
            URLQueryItem(name: "EnableRemoteMedia", value: "true")
        ]
        
        return components.url!
    }
    
    override func observeValue(forKeyPath keyPath: String?, 
                              of object: Any?, 
                              change: [NSKeyValueChangeKey : Any]?, 
                              context: UnsafeMutableRawPointer?) {
        
        guard keyPath == #keyPath(AVPlayerItem.status) else { return }
        
        if let playerItem = object as? AVPlayerItem {
            switch playerItem.status {
            case .readyToPlay:
                print("✅ Player ready to play!")
                DispatchQueue.main.async {
                    self.duration = playerItem.duration.seconds
                    self.player.play()
                    self.isPlaying = true
                    print("▶️ Playback started!")
                }
                
            case .failed:
                print("❌ Player failed!")
                if let error = playerItem.error {
                    print("❌ Error: \(error.localizedDescription)")
                    print("❌ Full error: \(error)")
                    
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                }
                
            case .unknown:
                print("⚠️ Player status unknown")
                
            @unknown default:
                print("⚠️ Unexpected player status")
            }
        }
    }
    
    func cleanup() {
        print("🧹 Cleaning up player...")
        player.pause()
        
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        
        if let item = playerItem {
            item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        }
        
        player.replaceCurrentItem(with: nil)
        playerItem = nil
    }
    
    deinit {
        cleanup()
    }
}

// SwiftUI View
struct VideoPlayerView: View {
    @StateObject private var playerManager: VideoPlayerManager
    let itemId: String
    let itemName: String
    
    init(itemId: String, itemName: String, serverURL: String, apiKey: String) {
        self.itemId = itemId
        self.itemName = itemName
        _playerManager = StateObject(wrappedValue: VideoPlayerManager(serverURL: serverURL, apiKey: apiKey))
    }
    
    var body: some View {
        ZStack {
            // AVPlayer view
            VideoPlayer(player: playerManager.player)
                .ignoresSafeArea()
            
            // Error overlay
            if let error = playerManager.errorMessage {
                VStack {
                    Text("Playback Error")
                        .font(.title)
                    Text(error)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.8))
            }
        }
        .onAppear {
            playerManager.playVideo(itemId: itemId, itemName: itemName)
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }
}
```

## Testing Checklist

Run through these tests in order:

1. **Test Authentication**
   ```
   - [ ] Call verifyAuthentication()
   - [ ] Verify 200 status code
   - [ ] Check console logs
   ```

2. **Test Stream URL Construction**
   ```
   - [ ] Print the complete URL
   - [ ] Copy URL and test in VLC or browser
   - [ ] Verify it returns video data
   ```

3. **Test Player Status**
   ```
   - [ ] Add status observer
   - [ ] Check if status becomes .readyToPlay
   - [ ] If .failed, print the error details
   ```

4. **Test Network**
   ```
   - [ ] Verify Apple TV and server on same network
   - [ ] Test server URL in Safari on Apple TV
   - [ ] Check Info.plist for network permissions
   ```

5. **Check Jellyfin Server Logs**
   ```
   - [ ] Open Jellyfin Dashboard → Logs
   - [ ] Look for playback start requests
   - [ ] Check for transcoding errors
   - [ ] Verify FFmpeg is installed
   ```

## Quick Diagnostic Questions

Ask these to narrow down the issue:

1. **Does the stream URL work in VLC?**
   - If YES: Problem is in AVPlayer setup
   - If NO: Problem is URL construction or auth

2. **What's the AVPlayerItem status?**
   - .unknown: Player not initialized properly
   - .failed: Check error message (network, format, auth)
   - .readyToPlay: Should work, check if play() is called

3. **Are you using HTTP or HTTPS?**
   - HTTP: Need NSAllowsArbitraryLoads in Info.plist
   - HTTPS: Need valid SSL certificate

4. **Is this a local or remote Jellyfin server?**
   - Local: Easier, should work with direct URLs
   - Remote: May have firewall/port issues

## Most Common Solutions

### Solution 1: Use the Simplest Possible URL
```swift
let url = URL(string: "\(serverURL)/Videos/\(itemId)/stream?api_key=\(apiKey)&Static=true")!
```
This bypasses transcoding and just streams the file directly.

### Solution 2: Add Required Info.plist Permissions
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Solution 3: Actually Call play()
Make sure you're calling `player.play()` after the item is ready:
```swift
case .readyToPlay:
    DispatchQueue.main.async {
        self.player.play() // Don't forget this!
    }
```

## Next Steps for Claude Code

1. **Add comprehensive logging** using the code above
2. **Check console output** when trying to play
3. **Test the stream URL** manually (in VLC or browser)
4. **Verify authentication** is working
5. **Try the simplest URL first** (direct stream with Static=true)
6. **Check Info.plist** for network permissions
7. **Look at Jellyfin server logs** for errors

Report back with:
- Console logs when attempting playback
- AVPlayerItem status
- Any error messages
- The exact stream URL being used
- Whether URL works in VLC

This will help us identify the exact issue!
