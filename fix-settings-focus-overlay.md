# Fix Settings, Focus Styling, and Overlay Issues

## Issue 1: Settings Don't Actually Apply

### The Problem
Settings are visible in the menu but don't affect playback:
- Subtitles don't appear when set to "Always On"
- Default subtitle language isn't applied
- Video quality settings don't change stream quality
- Other settings are ignored

### Why This Happens
Settings are stored in `@AppStorage` but never actually used when building stream URLs or configuring the player. They're "write-only" - saved but not read.

### Solution: Apply Settings to Playback

#### Step 1: Apply Subtitle Settings

**Create Subtitle Manager:**
```swift
import AVFoundation

class SubtitleManager {
    let settings: SettingsManager
    
    init(settings: SettingsManager) {
        self.settings = settings
    }
    
    func applySubtitleSettings(to player: AVPlayer) {
        guard let currentItem = player.currentItem else {
            print("⚠️ No current item to apply subtitles")
            return
        }
        
        // Get subtitle preferences
        let subtitleMode = settings.subtitleMode  // "off", "on", "foreign", "smart"
        let preferredLanguage = settings.defaultSubtitleLanguage  // "eng", "spa", etc.
        
        print("🎬 Applying subtitle settings:")
        print("  Mode: \(subtitleMode)")
        print("  Language: \(preferredLanguage)")
        
        // Get the legible media selection group (subtitles)
        guard let subtitleGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            print("⚠️ No subtitle tracks available")
            return
        }
        
        print("📝 Available subtitle tracks:")
        for option in subtitleGroup.options {
            print("  - \(option.displayName) [\(option.extendedLanguageTag ?? "unknown")]")
        }
        
        // Apply based on mode
        switch subtitleMode {
        case "off":
            // Turn off subtitles
            currentItem.select(nil, in: subtitleGroup)
            print("✅ Subtitles disabled")
            
        case "on":
            // Always enable subtitles in preferred language
            if let preferredOption = findSubtitleTrack(in: subtitleGroup, language: preferredLanguage) {
                currentItem.select(preferredOption, in: subtitleGroup)
                print("✅ Enabled subtitles: \(preferredOption.displayName)")
            } else {
                // Fallback to first available
                if let firstOption = subtitleGroup.options.first {
                    currentItem.select(firstOption, in: subtitleGroup)
                    print("⚠️ Preferred language not found, using: \(firstOption.displayName)")
                }
            }
            
        case "foreign":
            // Only enable if audio is foreign language
            // This requires checking audio track language
            let audioLanguage = getCurrentAudioLanguage(player: player)
            if audioLanguage != preferredLanguage {
                if let preferredOption = findSubtitleTrack(in: subtitleGroup, language: preferredLanguage) {
                    currentItem.select(preferredOption, in: subtitleGroup)
                    print("✅ Foreign audio detected, enabled subtitles")
                }
            } else {
                currentItem.select(nil, in: subtitleGroup)
                print("✅ Audio matches preference, subtitles off")
            }
            
        case "smart":
            // Smart mode: enable if audio doesn't match preferred language
            let audioLanguage = getCurrentAudioLanguage(player: player)
            if audioLanguage != preferredLanguage {
                if let preferredOption = findSubtitleTrack(in: subtitleGroup, language: preferredLanguage) {
                    currentItem.select(preferredOption, in: subtitleGroup)
                    print("✅ Smart mode: enabled subtitles")
                }
            }
            
        default:
            break
        }
        
        // Apply subtitle styling
        applySubtitleStyle(to: currentItem)
    }
    
    private func findSubtitleTrack(in group: AVMediaSelectionGroup, language: String) -> AVMediaSelectionOption? {
        return group.options.first { option in
            option.extendedLanguageTag?.hasPrefix(language) ?? false
        }
    }
    
    private func getCurrentAudioLanguage(player: AVPlayer) -> String? {
        guard let currentItem = player.currentItem,
              let audioGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
              let selectedAudio = currentItem.selectedMediaOption(in: audioGroup) else {
            return nil
        }
        
        return selectedAudio.extendedLanguageTag
    }
    
    private func applySubtitleStyle(to playerItem: AVPlayerItem) {
        // Apply custom subtitle styling from settings
        var attributes: [String: Any] = [:]
        
        // Font size
        let fontSize = settings.subtitleSize  // "small", "medium", "large", "extraLarge"
        let fontScale: CGFloat
        switch fontSize {
        case "small": fontScale = 0.8
        case "medium": fontScale = 1.0
        case "large": fontScale = 1.2
        case "extraLarge": fontScale = 1.5
        default: fontScale = 1.0
        }
        
        // Note: AVPlayer has limited subtitle styling support on tvOS
        // Most styling needs to be done via AVPlayerViewController
        print("📝 Subtitle style applied: \(fontSize)")
    }
}
```

**Apply in VideoPlayerManager:**
```swift
class VideoPlayerManager: ObservableObject {
    @Published var player = AVPlayer()
    private let subtitleManager: SubtitleManager
    
    init(settings: SettingsManager) {
        self.subtitleManager = SubtitleManager(settings: settings)
    }
    
    func play(item: MediaItem, url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        
        // Wait for player to be ready, then apply subtitles
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new], context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            if let item = object as? AVPlayerItem, item.status == .readyToPlay {
                // Apply subtitle settings NOW
                subtitleManager.applySubtitleSettings(to: player)
                
                // Start playback
                player.play()
            }
        }
    }
}
```

#### Step 2: Apply Video Quality Settings

**Update Stream URL Builder:**
```swift
class JellyfinStreamBuilder {
    let settings: SettingsManager
    
    func buildStreamURL(for item: MediaItem) -> URL {
        var components = URLComponents(string: "\(serverURL)/Videos/\(item.id)/master.m3u8")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "DeviceId", value: deviceId),
            URLQueryItem(name: "MediaSourceId", value: item.id)
        ]
        
        // Apply max bitrate from settings
        queryItems.append(URLQueryItem(name: "MaxStreamingBitrate", value: "\(settings.maxBitrate)"))
        print("🎬 Max bitrate: \(settings.maxBitrate)")
        
        // Apply video quality setting
        let quality = settings.videoQuality  // "Auto", "4K", "1080p", "720p", "480p"
        if quality != "Auto" {
            let maxHeight: Int
            switch quality {
            case "4K": maxHeight = 2160
            case "1080p": maxHeight = 1080
            case "720p": maxHeight = 720
            case "480p": maxHeight = 480
            default: maxHeight = 0
            }
            
            if maxHeight > 0 {
                queryItems.append(URLQueryItem(name: "MaxHeight", value: "\(maxHeight)"))
                print("🎬 Max height: \(maxHeight)p")
            }
        }
        
        // Apply audio quality
        let audioQuality = settings.audioQuality  // "lossless", "high", "standard"
        let audioCodecs: String
        switch audioQuality {
        case "lossless":
            audioCodecs = "aac,mp3,ac3,eac3,truehd,dts"
        case "high":
            audioCodecs = "aac,mp3,ac3,eac3"
        case "standard":
            audioCodecs = "aac,mp3"
        default:
            audioCodecs = "aac,mp3"
        }
        queryItems.append(URLQueryItem(name: "AudioCodec", value: audioCodecs))
        
        // Apply streaming mode
        let streamingMode = settings.streamingMode  // "directPlay", "directStream", "transcode", "auto"
        if streamingMode == "directPlay" {
            // Use direct play URL instead
            return buildDirectPlayURL(for: item)
        }
        
        components.queryItems = queryItems
        
        let finalURL = components.url!
        print("🔗 Stream URL: \(finalURL.absoluteString)")
        
        return finalURL
    }
    
    private func buildDirectPlayURL(for item: MediaItem) -> URL {
        // Direct play bypasses transcoding
        let urlString = "\(serverURL)/Items/\(item.id)/Download?api_key=\(apiKey)"
        return URL(string: urlString)!
    }
}
```

#### Step 3: Apply Auto-Skip Settings

**Integrate with Player:**
```swift
class SkipManager {
    let settings: SettingsManager
    private var skipMarkers: SkipMarkers?
    
    func checkForSkips(currentTime: Double, player: AVPlayer) {
        guard let markers = skipMarkers else { return }
        
        // Check intro skip
        if settings.autoSkipIntros &&
           currentTime >= markers.introStart &&
           currentTime < markers.introEnd {
            
            if settings.skipIntroCountdown == 0 {
                // Skip immediately
                skipToTime(markers.introEnd, player: player)
                print("⏩ Skipped intro")
            } else {
                // Show countdown and skip
                showSkipCountdown(seconds: settings.skipIntroCountdown) {
                    self.skipToTime(markers.introEnd, player: player)
                }
            }
        }
        
        // Check credits skip
        if settings.autoSkipCredits,
           let creditsStart = markers.creditsStart,
           currentTime >= creditsStart {
            // Show next episode overlay
            showNextEpisodeOverlay(countdown: settings.skipCreditsCountdown)
        }
    }
    
    private func skipToTime(_ time: Double, player: AVPlayer) {
        let seekTime = CMTime(seconds: time, preferredTimescale: 1)
        player.seek(to: seekTime)
    }
}
```

---

## Issue 2: White Background on Focus

### The Problem
When hovering/focusing on content cards, a white background appears that looks bad and doesn't match the Netflix aesthetic.

### Solution: Remove Background, Use Scale & Shadow

**Before (Bad):**
```swift
// ❌ Don't do this
.background(isFocused ? Color.white : Color.clear)
```

**After (Good):**
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
            }
            .cornerRadius(8)
            .shadow(
                color: isFocused ? Color.black.opacity(0.6) : Color.clear,
                radius: isFocused ? 20 : 0,
                x: 0,
                y: isFocused ? 10 : 0
            )
            
            // Title
            Text(item.name)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .scaleEffect(isFocused ? 1.1 : 1.0)  // ✅ Scale up when focused
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .focusable()
        .focused($isFocused)
        // ❌ No background!
    }
}
```

**Netflix-Style Focus Effect:**
```swift
struct NetflixStyleCard: View {
    let item: MediaItem
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Poster image
            AsyncImage(url: item.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.3))
            }
            .cornerRadius(8)
            
            // Gradient overlay at bottom (for title)
            if isFocused {
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .cornerRadius(8)
                
                // Title on gradient
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if let year = item.year {
                        Text(year)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 250)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .shadow(
            color: Color.black.opacity(isFocused ? 0.6 : 0),
            radius: isFocused ? 20 : 0,
            x: 0,
            y: isFocused ? 10 : 0
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .focusable()
        .focused($isFocused)
    }
}
```

---

## Issue 3: White Text on White Background

### The Problem
When a card with white text gets focused and has a white/light background, the text becomes invisible.

### Solution: Dynamic Text Color Based on Background

**Approach 1: Always Use Dark Text on Light Backgrounds**
```swift
struct SmartTextCard: View {
    let item: MediaItem
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: item.posterURL) { image in
                image.resizable().aspectRatio(2/3, contentMode: .fill)
            }
            .cornerRadius(8)
            
            Text(item.name)
                .font(.headline)
                // ✅ Dynamic text color
                .foregroundColor(textColor)
                .lineLimit(2)
        }
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .focusable()
        .focused($isFocused)
    }
    
    private var textColor: Color {
        // Always use white text on dark backgrounds
        // If your background is light/white, use dark text
        return .white  // Since MediaMio has dark theme
    }
}
```

**Approach 2: Use Text Shadow for Contrast**
```swift
Text(item.name)
    .font(.headline)
    .foregroundColor(.white)
    .shadow(
        color: .black.opacity(0.8),
        radius: isFocused ? 4 : 2,
        x: 0,
        y: 0
    )
    .lineLimit(2)
```

**Approach 3: Always Show Text on Gradient Background**
```swift
struct TextOnGradientCard: View {
    let item: MediaItem
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Poster
            AsyncImage(url: item.posterURL) { image in
                image.resizable().aspectRatio(2/3, contentMode: .fill)
            }
            .cornerRadius(8)
            
            // Always show gradient at bottom for text
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(isFocused ? 0.9 : 0.7)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 80)
            
            // Text always on dark gradient
            Text(item.name)
                .font(.headline)
                .foregroundColor(.white)  // Always white on dark gradient
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 250)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .shadow(color: .black.opacity(isFocused ? 0.6 : 0), radius: isFocused ? 20 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .focusable()
        .focused($isFocused)
    }
}
```

---

## Issue 4: Overlay Needs More Information

### The Problem
Video player overlay is too basic. Should show title, rating, description, etc., like Netflix.

### Solution: Rich Information Overlay

```swift
import SwiftUI
import AVKit

struct RichVideoPlayerView: View {
    let item: MediaItem
    @ObservedObject var playerManager: VideoPlayerManager
    @State private var showOverlay = true
    @State private var hideOverlayTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Video player
            VideoPlayer(player: playerManager.player) {
                // Empty - we'll use our own overlay
            }
            .ignoresSafeArea()
            
            // Custom overlay
            if showOverlay {
                ZStack {
                    // Gradient backgrounds for top and bottom
                    VStack(spacing: 0) {
                        // Top gradient
                        LinearGradient(
                            colors: [Color.black.opacity(0.8), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                        
                        Spacer()
                        
                        // Bottom gradient
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                    }
                    .ignoresSafeArea()
                    
                    // Content
                    VStack {
                        // Top bar - Title and metadata
                        HStack(alignment: .top, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                // Title
                                Text(item.name)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                // Metadata row
                                HStack(spacing: 12) {
                                    // Rating (if available)
                                    if let rating = item.officialRating {
                                        Text(rating)
                                            .font(.headline)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                    
                                    // Year
                                    if let year = item.year {
                                        Text(year)
                                            .font(.headline)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    // Duration
                                    if let runtime = item.runtimeMinutes {
                                        Text("•")
                                            .foregroundColor(.white.opacity(0.6))
                                        Text("\(runtime) min")
                                            .font(.headline)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    // Quality badge
                                    if let videoCodec = item.videoCodec {
                                        Text("•")
                                            .foregroundColor(.white.opacity(0.6))
                                        Text(videoCodec.uppercased())
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.3))
                                            .cornerRadius(3)
                                    }
                                }
                                
                                // Season/Episode info for TV shows
                                if item.type == "Episode" {
                                    HStack(spacing: 8) {
                                        if let season = item.seasonNumber,
                                           let episode = item.episodeNumber {
                                            Text("S\(season):E\(episode)")
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        }
                                        
                                        if let episodeTitle = item.episodeTitle {
                                            Text("•")
                                                .foregroundColor(.white.opacity(0.6))
                                            Text(episodeTitle)
                                                .font(.title3)
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Close button
                            Button {
                                // Dismiss player
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 60)
                        .padding(.top, 60)
                        
                        Spacer()
                        
                        // Bottom bar - Playback controls and progress
                        VStack(spacing: 20) {
                            // Progress bar
                            PlaybackProgressBar(
                                currentTime: playerManager.currentTime,
                                duration: playerManager.duration
                            )
                            
                            // Control buttons
                            HStack(spacing: 40) {
                                // Rewind
                                Button {
                                    playerManager.seek(by: -10)
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "gobackward.10")
                                            .font(.system(size: 40))
                                        Text("10s")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                // Play/Pause
                                Button {
                                    playerManager.togglePlayPause()
                                } label: {
                                    Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 50))
                                }
                                .buttonStyle(.plain)
                                
                                // Forward
                                Button {
                                    playerManager.seek(by: 10)
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "goforward.10")
                                            .font(.system(size: 40))
                                        Text("10s")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                // Subtitles
                                Button {
                                    // Show subtitle menu
                                } label: {
                                    Image(systemName: "captions.bubble")
                                        .font(.system(size: 30))
                                }
                                .buttonStyle(.plain)
                                
                                // Audio
                                Button {
                                    // Show audio menu
                                } label: {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.system(size: 30))
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 60)
                        }
                        .padding(.bottom, 60)
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            resetHideOverlayTimer()
        }
        .onMoveCommand { _ in
            showOverlay = true
            resetHideOverlayTimer()
        }
        .onPlayPauseCommand {
            showOverlay = true
            playerManager.togglePlayPause()
            resetHideOverlayTimer()
        }
    }
    
    private func resetHideOverlayTimer() {
        hideOverlayTask?.cancel()
        hideOverlayTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.3)) {
                    showOverlay = false
                }
            }
        }
    }
}

struct PlaybackProgressBar: View {
    let currentTime: Double
    let duration: Double
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)
                    
                    // Progress
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: progressWidth(in: geometry.size.width), height: 4)
                }
            }
            .frame(height: 4)
            
            // Time labels
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("-\(formatTime(duration - currentTime))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 60)
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return totalWidth * CGFloat(currentTime / duration)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
```

**Add Content Rating and Extra Info:**
```swift
extension MediaItem {
    var officialRating: String? {
        // From Jellyfin: "TV-MA", "PG-13", "R", etc.
        return self.communityRating
    }
    
    var runtimeMinutes: Int? {
        guard let ticks = runTimeTicks else { return nil }
        let seconds = Double(ticks) / 10_000_000.0
        return Int(seconds / 60)
    }
    
    var videoCodec: String? {
        // From media info: "h264", "hevc", etc.
        return self.mediaStreams?.first(where: { $0.type == "Video" })?.codec
    }
    
    var episodeTitle: String? {
        // For TV episodes
        return self.name
    }
    
    var seasonNumber: Int? {
        return self.parentIndexNumber
    }
    
    var episodeNumber: Int? {
        return self.indexNumber
    }
}
```

---

## Claude Code Prompt

```
Fix four major issues in MediaMio:

1. SETTINGS NOT APPLYING
Problem: Settings save but don't affect playback.

Fix:
- Create SubtitleManager class that reads settings and applies to AVPlayer
- In VideoPlayerManager, after player is ready, call subtitleManager.applySubtitleSettings()
- Update stream URL builder to include settings (maxBitrate, videoQuality, audioCodecs)
- Apply settings when building URLs, not just storing them
- Add logging: "Applied subtitle settings: mode=X, language=Y"

Test: Set subtitles to "Always On" + English, play video, verify subtitles appear

2. WHITE BACKGROUND ON FOCUS
Problem: Cards have ugly white background when focused.

Fix:
- Remove any .background() modifiers on focused state
- Use ONLY .scaleEffect(isFocused ? 1.1 : 1.0) for focus
- Add shadow: .shadow(color: .black.opacity(0.6), radius: 20) when focused
- Use .animation(.spring(response: 0.3), value: isFocused)
- Optional: Add gradient overlay at bottom for text readability

Test: Navigate cards, should scale+shadow only (no white background)

3. WHITE TEXT ON WHITE BACKGROUND
Problem: Text becomes invisible when background is light.

Fix:
- Always use gradient overlay at bottom of cards for text
- LinearGradient from clear to black.opacity(0.8)
- Text always sits on this dark gradient
- Alternatively: Add text shadow: .shadow(color: .black, radius: 4)

Test: Navigate cards, text should always be readable

4. BASIC VIDEO OVERLAY
Problem: Overlay lacks information (title, rating, duration, etc.)

Fix:
- Create RichVideoPlayerView with custom overlay
- Top section: Title, rating badge, year, duration, quality badge
- For episodes: Show S1:E2 format and episode title
- Bottom section: Progress bar, playback controls, time remaining
- Add subtitle/audio buttons
- Auto-hide after 3 seconds, show on any remote movement

Test: Play video, overlay should show all metadata and auto-hide

TESTING:
1. Settings: Enable subtitles, play video, verify they appear
2. Focus: Navigate content, should scale smoothly without white background
3. Text: Text should be readable on all cards
4. Overlay: Shows title, rating, year, duration, progress bar

Read fix-settings-focus-overlay.md for complete implementation details.
Add comprehensive logging for each fix.
```

## Summary

**Issue 1: Settings Don't Apply**
→ Create managers that READ settings and apply them to player/URLs

**Issue 2: White Background on Focus**
→ Remove backgrounds, use scale (1.1x) + shadow only

**Issue 3: White Text Invisible**
→ Use dark gradient overlay at bottom of cards for text

**Issue 4: Basic Overlay**
→ Rich overlay with title, rating, year, duration, progress, controls

These fixes will make MediaMio look and feel like Netflix! 🎬
