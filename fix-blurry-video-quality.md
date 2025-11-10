# Fix Blurry Video Quality in MediaMio

## The Problem

Some movies/TV shows are blurry while others are crystal clear. This is almost always caused by:

1. **Transcoding** - Jellyfin is re-encoding video on-the-fly (reduces quality)
2. **Low Bitrate** - MaxStreamingBitrate is too low
3. **Wrong Codec** - H.265/HEVC forcing transcoding to H.264
4. **Network Detection** - App thinks connection is slow

## Quick Diagnosis

### Check if Content is Transcoding

Add this logging to your video player:

```swift
func checkTranscodingStatus(url: URL) {
    if url.absoluteString.contains("master.m3u8") {
        print("⚠️ TRANSCODING - Quality may be reduced")
        print("🔗 URL: \(url.absoluteString)")
        
        // Check for bitrate limit
        if url.absoluteString.contains("MaxStreamingBitrate") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let bitrate = components?.queryItems?.first(where: { $0.name == "MaxStreamingBitrate" })?.value {
                print("📊 Max Bitrate: \(bitrate) bps")
                let mbps = Double(bitrate)! / 1_000_000.0
                print("📊 That's: \(String(format: "%.1f", mbps)) Mbps")
                
                if mbps < 40 {
                    print("⚠️ WARNING: Bitrate too low for HD content!")
                }
            }
        }
    } else if url.absoluteString.contains("/Download") {
        print("✅ DIRECT PLAY - Maximum quality")
        print("🔗 URL: \(url.absoluteString)")
    }
}
```

## Solution 1: Force Direct Play (Best Quality)

Direct Play means the video is sent as-is without transcoding. This gives maximum quality.

### Update Stream URL Builder

```swift
class JellyfinStreamBuilder {
    let settings: SettingsManager
    let apiClient: JellyfinAPIClient
    
    func buildStreamURL(for item: MediaItem) -> URL {
        // Check if user wants to force Direct Play
        if settings.streamingMode == "directPlay" {
            return buildDirectPlayURL(for: item)
        }
        
        // Check if content can be direct played
        if canDirectPlay(item: item) {
            print("✅ Content compatible - using Direct Play")
            return buildDirectPlayURL(for: item)
        }
        
        print("⚠️ Content needs transcoding")
        return buildTranscodeURL(for: item)
    }
    
    private func canDirectPlay(item: MediaItem) -> Bool {
        // Check if video codec is supported by Apple TV
        guard let videoCodec = item.mediaStreams?.first(where: { $0.type == "Video" })?.codec else {
            return false
        }
        
        let supportedCodecs = ["h264", "hevc", "h265"]
        
        if supportedCodecs.contains(videoCodec.lowercased()) {
            print("✅ Video codec supported: \(videoCodec)")
            return true
        } else {
            print("⚠️ Video codec NOT supported: \(videoCodec)")
            return false
        }
    }
    
    private func buildDirectPlayURL(for item: MediaItem) -> URL {
        // Direct Play URL - no transcoding!
        var components = URLComponents(string: "\(apiClient.serverURL)/Items/\(item.id)/Download")!
        
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiClient.apiKey)
        ]
        
        let url = components.url!
        print("🎬 Direct Play URL: \(url.absoluteString)")
        return url
    }
    
    private func buildTranscodeURL(for item: MediaItem) -> URL {
        var components = URLComponents(string: "\(apiClient.serverURL)/Videos/\(item.id)/master.m3u8")!
        
        var queryItems = [
            URLQueryItem(name: "api_key", value: apiClient.apiKey),
            URLQueryItem(name: "DeviceId", value: apiClient.deviceId),
            URLQueryItem(name: "MediaSourceId", value: item.id),
        ]
        
        // CRITICAL: Set very high bitrate
        let maxBitrate = settings.maxBitrate > 0 ? settings.maxBitrate : 120_000_000 // 120 Mbps default
        queryItems.append(URLQueryItem(name: "MaxStreamingBitrate", value: "\(maxBitrate)"))
        
        print("📊 Transcoding with bitrate: \(maxBitrate / 1_000_000) Mbps")
        
        // Don't limit video resolution
        // Remove or comment out MaxHeight to allow 4K
        // queryItems.append(URLQueryItem(name: "MaxHeight", value: "1080"))
        
        // Request high quality video codec
        queryItems.append(URLQueryItem(name: "VideoCodec", value: "h264,hevc"))
        
        // Request high quality audio
        queryItems.append(URLQueryItem(name: "AudioCodec", value: "aac,mp3,ac3,eac3"))
        
        components.queryItems = queryItems
        
        let url = components.url!
        print("🎬 Transcode URL: \(url.absoluteString)")
        return url
    }
}
```

## Solution 2: Increase Maximum Bitrate

Low bitrate = blurry video. Increase it!

### Update Settings

```swift
struct StreamingSettingsView: View {
    @AppStorage("maxBitrate") private var maxBitrate: Double = 120.0 // Default 120 Mbps
    @AppStorage("streamingMode") private var streamingMode = "auto"
    
    var body: some View {
        Form {
            Section("QUALITY") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Maximum Bitrate")
                        .font(.headline)
                    
                    HStack {
                        Text("1 Mbps")
                            .font(.caption)
                        Slider(value: $maxBitrate, in: 1...200, step: 1)
                        Text("200 Mbps")
                            .font(.caption)
                    }
                    
                    Text("Current: \(Int(maxBitrate)) Mbps")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(bitrateDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
            }
            
            Section("STREAMING MODE") {
                Picker("Mode", selection: $streamingMode) {
                    Text("Auto").tag("auto")
                    Text("Direct Play (Maximum Quality)").tag("directPlay")
                    Text("Transcode if Needed").tag("transcode")
                }
                .pickerStyle(.inline)
                
                Text(streamingModeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("Video Quality")
    }
    
    private var bitrateDescription: String {
        switch maxBitrate {
        case 0..<10:
            return "⚠️ Very Low - Only for slow connections. Will be blurry."
        case 10..<20:
            return "⚠️ Low - For mobile/slow WiFi. May be blurry on TV."
        case 20..<40:
            return "📱 Good - Fine for 720p, may be blurry for 1080p"
        case 40..<80:
            return "✅ High - Good for 1080p HD content"
        case 80..<120:
            return "✅ Very High - Excellent for 1080p, good for 4K"
        default:
            return "🎬 Maximum - Best quality for 4K and remux files"
        }
    }
    
    private var streamingModeDescription: String {
        switch streamingMode {
        case "directPlay":
            return "✅ Always use original file without transcoding. Best quality, but may not work for all content."
        case "transcode":
            return "⚙️ Always transcode. Lower quality but more compatible."
        default:
            return "🔄 Automatically choose based on compatibility."
        }
    }
}
```

### Recommended Bitrate Settings

```
Content Type          | Recommended Bitrate
─────────────────────────────────────────
DVD Quality          | 5-10 Mbps
720p HD              | 10-20 Mbps
1080p HD (Good)      | 20-40 Mbps
1080p HD (Excellent) | 40-80 Mbps
4K UHD               | 80-120 Mbps
4K Remux/Blu-ray     | 120-200 Mbps
```

## Solution 3: Check Jellyfin Server Settings

Sometimes the server is limiting quality.

### Server-Side Checks

1. **Open Jellyfin Admin Dashboard**
2. **Go to Playback → Transcoding**
3. **Check these settings:**
   - Hardware acceleration: Enabled (if available)
   - H264 encoding preset: `medium` or `slow` (not `ultrafast`)
   - Throttle transcoding: Disabled
   - Max simultaneous streams: Reasonable number

### Check Server Logs

In Jellyfin, check if transcoding is happening:
- Dashboard → Playback Activity
- Look for "Transcoding" status
- If transcoding, check why (codec, bitrate, etc.)

## Solution 4: Detect and Display Quality Info

Show users what quality they're getting:

```swift
struct VideoQualityIndicator: View {
    let url: URL
    @State private var isTranscoding = false
    @State private var bitrate: String = "Unknown"
    @State private var resolution: String = "Unknown"
    
    var body: some View {
        HStack(spacing: 12) {
            // Quality badge
            if isTranscoding {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                    Text("Transcoding")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.3))
                .cornerRadius(4)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                    Text("Direct Play")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.3))
                .cornerRadius(4)
            }
            
            // Bitrate
            Text(bitrate)
                .font(.caption)
                .foregroundColor(.white)
            
            // Resolution
            Text(resolution)
                .font(.caption)
                .foregroundColor(.white)
        }
        .onAppear {
            analyzeURL()
        }
    }
    
    private func analyzeURL() {
        let urlString = url.absoluteString
        
        // Check if transcoding
        isTranscoding = urlString.contains("master.m3u8")
        
        // Extract bitrate
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let bitrateItem = components.queryItems?.first(where: { $0.name == "MaxStreamingBitrate" }),
           let bitrateValue = bitrateItem.value,
           let bitrateLong = Int(bitrateValue) {
            let mbps = Double(bitrateLong) / 1_000_000.0
            bitrate = String(format: "%.0f Mbps", mbps)
        } else if !isTranscoding {
            bitrate = "Original"
        }
        
        // Extract resolution
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let heightItem = components.queryItems?.first(where: { $0.name == "MaxHeight" }),
           let height = heightItem.value {
            resolution = "\(height)p"
        } else if !isTranscoding {
            resolution = "Original"
        }
    }
}

// Add to video player overlay
struct VideoPlayerOverlay: View {
    let item: MediaItem
    let streamURL: URL
    
    var body: some View {
        VStack {
            HStack {
                Text(item.name)
                Spacer()
                VideoQualityIndicator(url: streamURL)
            }
            .padding()
            
            Spacer()
        }
    }
}
```

## Solution 5: Network-Based Quality Selection

Detect actual network speed and adjust:

```swift
class NetworkSpeedDetector {
    static let shared = NetworkSpeedDetector()
    
    func detectSpeed() async -> Double {
        // Download test file from Jellyfin
        guard let testURL = URL(string: "\(jellyfinURL)/test.bin") else {
            return 40.0 // Default 40 Mbps
        }
        
        let startTime = Date()
        
        do {
            let (data, _) = try await URLSession.shared.data(from: testURL)
            let duration = Date().timeIntervalSince(startTime)
            let bytes = Double(data.count)
            let bits = bytes * 8
            let mbps = (bits / duration) / 1_000_000.0
            
            print("📊 Detected speed: \(String(format: "%.1f", mbps)) Mbps")
            return mbps
        } catch {
            print("❌ Speed test failed: \(error)")
            return 40.0 // Default
        }
    }
    
    func recommendedBitrate(speed: Double) -> Int {
        // Use 80% of detected speed to be safe
        let safeBitrate = speed * 0.8
        
        let bitrate: Int
        if safeBitrate >= 100 {
            bitrate = 120_000_000 // 120 Mbps - 4K
        } else if safeBitrate >= 60 {
            bitrate = 80_000_000  // 80 Mbps - 1080p remux
        } else if safeBitrate >= 30 {
            bitrate = 40_000_000  // 40 Mbps - 1080p
        } else if safeBitrate >= 15 {
            bitrate = 20_000_000  // 20 Mbps - 720p
        } else {
            bitrate = 10_000_000  // 10 Mbps - SD
        }
        
        print("📊 Recommended bitrate: \(bitrate / 1_000_000) Mbps")
        return bitrate
    }
}
```

## Solution 6: Disable All Quality Limitations

For maximum quality, remove all restrictions:

```swift
func buildMaxQualityURL(for item: MediaItem) -> URL {
    // Try Direct Play first
    if canDirectPlay(item: item) {
        return buildDirectPlayURL(for: item)
    }
    
    // If must transcode, use maximum settings
    var components = URLComponents(string: "\(apiClient.serverURL)/Videos/\(item.id)/master.m3u8")!
    
    var queryItems = [
        URLQueryItem(name: "api_key", value: apiClient.apiKey),
        URLQueryItem(name: "DeviceId", value: apiClient.deviceId),
        URLQueryItem(name: "MediaSourceId", value: item.id),
        
        // MAXIMUM bitrate
        URLQueryItem(name: "MaxStreamingBitrate", value: "200000000"), // 200 Mbps
        
        // NO resolution limit (allow 4K)
        // Remove MaxHeight entirely
        
        // High quality codecs
        URLQueryItem(name: "VideoCodec", value: "h264,hevc"),
        URLQueryItem(name: "AudioCodec", value: "aac,mp3,ac3,eac3,truehd,dts"),
        
        // High quality audio
        URLQueryItem(name: "AudioBitrate", value: "320000"), // 320 kbps
        
        // No transcoding if possible
        URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),
    ]
    
    components.queryItems = queryItems
    
    let url = components.url!
    print("🎬 MAX QUALITY URL: \(url.absoluteString)")
    return url
}
```

## Diagnostic Tool

Add this to help debug quality issues:

```swift
struct VideoQualityDiagnostic: View {
    let item: MediaItem
    @State private var diagnosticInfo: DiagnosticInfo?
    
    struct DiagnosticInfo {
        let isTranscoding: Bool
        let bitrate: String
        let videoCodec: String
        let audioCodec: String
        let resolution: String
        let fileSize: String
        let directPlayAvailable: Bool
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Video Quality Diagnostic")
                .font(.title2)
                .fontWeight(.bold)
            
            if let info = diagnosticInfo {
                Group {
                    DiagnosticRow(label: "Status", value: info.isTranscoding ? "⚠️ Transcoding" : "✅ Direct Play")
                    DiagnosticRow(label: "Bitrate", value: info.bitrate)
                    DiagnosticRow(label: "Video Codec", value: info.videoCodec)
                    DiagnosticRow(label: "Audio Codec", value: info.audioCodec)
                    DiagnosticRow(label: "Resolution", value: info.resolution)
                    DiagnosticRow(label: "File Size", value: info.fileSize)
                    DiagnosticRow(label: "Direct Play", value: info.directPlayAvailable ? "✅ Available" : "❌ Not Available")
                }
                
                if info.isTranscoding {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why is this transcoding?")
                            .font(.headline)
                            .padding(.top)
                        
                        if !info.directPlayAvailable {
                            Text("• Video codec not supported by Apple TV")
                        }
                        
                        Text("Recommendation:")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("• Enable Direct Play in Settings")
                        Text("• Increase Max Bitrate to 120+ Mbps")
                        Text("• Check Jellyfin server transcoding settings")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                ProgressView()
            }
        }
        .padding()
        .onAppear {
            loadDiagnosticInfo()
        }
    }
    
    private func loadDiagnosticInfo() {
        Task {
            // Gather diagnostic information
            let mediaSource = item.mediaSources?.first
            let videoStream = mediaSource?.mediaStreams?.first(where: { $0.type == "Video" })
            let audioStream = mediaSource?.mediaStreams?.first(where: { $0.type == "Audio" })
            
            diagnosticInfo = DiagnosticInfo(
                isTranscoding: !(item.canDirectPlay ?? false),
                bitrate: formatBitrate(videoStream?.bitRate),
                videoCodec: videoStream?.codec ?? "Unknown",
                audioCodec: audioStream?.codec ?? "Unknown",
                resolution: "\(videoStream?.width ?? 0)x\(videoStream?.height ?? 0)",
                fileSize: formatFileSize(mediaSource?.size),
                directPlayAvailable: canDirectPlay(item: item)
            )
        }
    }
}

struct DiagnosticRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}
```

## Claude Code Prompt

```
Fix blurry video quality in MediaMio - some content is blurry while others are crystal clear.

Problem: Jellyfin is transcoding some content (reducing quality) or bitrate is too low.

SOLUTIONS:

1. FORCE DIRECT PLAY (Best Quality)
   Create buildDirectPlayURL() method:
   - Use /Items/{id}/Download endpoint (no transcoding)
   - Only use when video codec is h264/hevc (Apple TV compatible)
   - Check item.mediaStreams for codec compatibility
   - Log: "✅ Direct Play - Maximum quality"

2. INCREASE MAX BITRATE
   Update stream URL builder:
   - Default MaxStreamingBitrate to 120_000_000 (120 Mbps)
   - Don't limit MaxHeight (allow 4K)
   - Settings: Let user choose 1-200 Mbps with slider
   - Show bitrate description (Low/Good/Excellent/Maximum)

3. ADD QUALITY INDICATOR
   Create VideoQualityIndicator component:
   - Show "Direct Play" (green) or "Transcoding" (orange) badge
   - Display current bitrate (e.g., "120 Mbps")
   - Display resolution (e.g., "1080p" or "Original")
   - Add to video player overlay

4. STREAMING MODE SETTING
   Add setting with options:
   - Auto: Try Direct Play, transcode if needed
   - Direct Play: Force Direct Play (may fail for some content)
   - Transcode: Always transcode (lower quality but compatible)

5. DIAGNOSTIC LOGGING
   Add to video player initialization:
   - Log if URL contains "master.m3u8" (transcoding)
   - Log if URL contains "/Download" (direct play)
   - Log MaxStreamingBitrate value
   - Warn if bitrate < 40 Mbps for HD content

KEY POINTS:
- Direct Play = Original file = Maximum quality
- Transcode = Re-encoded = Lower quality
- Higher bitrate = Better quality (but needs fast network)
- h264/hevc codecs work on Apple TV without transcoding

RECOMMENDED DEFAULTS:
- MaxStreamingBitrate: 120000000 (120 Mbps)
- StreamingMode: "auto" (try Direct Play first)
- Remove MaxHeight restriction (allow 4K)

TESTING:
1. Play movie that was blurry
2. Check logs: Should show bitrate and play mode
3. If transcoding, try increasing bitrate
4. If still blurry, try forcing Direct Play
5. Compare quality before/after changes

Read fix-blurry-video-quality.md for complete implementation.
```

## Quick Fixes Summary

### Fix 1: Increase Bitrate (Easiest)
```swift
// Change from:
URLQueryItem(name: "MaxStreamingBitrate", value: "40000000") // 40 Mbps

// To:
URLQueryItem(name: "MaxStreamingBitrate", value: "120000000") // 120 Mbps
```

### Fix 2: Remove Resolution Limit
```swift
// Remove or comment out:
// URLQueryItem(name: "MaxHeight", value: "1080")

// This allows 4K playback
```

### Fix 3: Force Direct Play
```swift
// Use this URL instead of transcode URL:
let url = "\(serverURL)/Items/\(item.id)/Download?api_key=\(apiKey)"
```

## Common Causes & Solutions

| Symptom | Cause | Solution |
|---------|-------|----------|
| All content blurry | Low max bitrate | Increase to 120+ Mbps |
| Some blurry, some clear | Mixed Direct Play/Transcode | Force Direct Play where possible |
| 4K content blurry | MaxHeight=1080 limit | Remove MaxHeight parameter |
| Stuttering + blurry | Network too slow | Reduce bitrate or upgrade network |
| Server CPU high | Hardware accel off | Enable hardware transcoding on server |

## Expected Results

After fixes:
- ✅ 1080p content should be sharp and clear
- ✅ 4K content should show full 4K quality
- ✅ No visible compression artifacts
- ✅ Colors should be vibrant
- ✅ Text/credits should be readable

Before fixes:
- ❌ Blocky compression artifacts
- ❌ Blurry faces and details
- ❌ Washed out colors
- ❌ Unreadable text

## Testing Procedure

1. **Find a blurry video**
2. **Check current settings**:
   - What's the MaxStreamingBitrate?
   - Is it transcoding or direct playing?
3. **Apply fixes**:
   - Increase bitrate to 120 Mbps
   - Enable Direct Play
4. **Replay same video**
5. **Compare quality** - should be dramatically better!

The key is to avoid transcoding whenever possible and use high bitrates when transcoding is necessary.
