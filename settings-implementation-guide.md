# MediaMio Settings Implementation Guide

## Overview
Create a premium, intuitive Settings interface for MediaMio that gives users full control over their streaming experience. Settings should be well-organized, easy to navigate with the Siri Remote, and include all of Jellyfin's powerful customization options.

## Design Philosophy

**tvOS Settings Principles:**
- Clear visual hierarchy
- Large, readable text (optimized for 10-foot viewing)
- Logical grouping of related settings
- Immediate visual feedback on changes
- Smart defaults for most users
- Advanced options available but not overwhelming
- Focus on most-used settings first

## Settings Architecture

### Main Settings Screen Structure

```
Settings (Root)
├── Playback
│   ├── Video Quality
│   ├── Audio Settings
│   └── Playback Behavior
├── Streaming
│   ├── Bitrate & Quality
│   ├── Network Settings
│   └── Transcoding Options
├── Subtitles
│   ├── Default Language
│   ├── Subtitle Style
│   └── Subtitle Behavior
├── Skip Settings
│   ├── Auto-Skip Intros
│   ├── Auto-Skip Credits
│   └── Skip Recaps
├── Account
│   ├── User Profile
│   ├── Server Settings
│   └── Sign Out
└── App Settings
    ├── Interface
    ├── Storage
    └── About
```

## Settings Categories

### 1. Playback Settings

#### Video Quality
**Options:**
- **Auto** (Default) - Let app choose best quality
- **4K/Ultra HD** - 2160p (if available)
- **Full HD** - 1080p
- **HD** - 720p
- **SD** - 480p

**Implementation:**
```swift
enum VideoQuality: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case uhd4K = "4K Ultra HD"
    case fullHD = "1080p Full HD"
    case hd = "720p HD"
    case sd = "480p SD"
    
    var id: String { rawValue }
    
    var maxHeight: Int? {
        switch self {
        case .auto: return nil
        case .uhd4K: return 2160
        case .fullHD: return 1080
        case .hd: return 720
        case .sd: return 480
        }
    }
    
    var description: String {
        switch self {
        case .auto: return "Automatically adjust quality based on connection"
        case .uhd4K: return "Best quality, requires fast connection (25+ Mbps)"
        case .fullHD: return "Excellent quality (5-8 Mbps)"
        case .hd: return "Good quality (2-5 Mbps)"
        case .sd: return "Lower quality, saves bandwidth (<2 Mbps)"
        }
    }
}
```

**Storage:**
```swift
@AppStorage("videoQuality") private var videoQuality: String = VideoQuality.auto.rawValue
```

#### Audio Settings
**Options:**
- **Default Audio Track** (Language preference)
- **Audio Quality**
  - Lossless (TrueHD, DTS-HD)
  - High Quality (AAC 5.1, AC3)
  - Standard (AAC Stereo)
- **Dolby Atmos** (On/Off)
- **Surround Sound** (5.1, 7.1, Stereo)
- **Audio Boost** (Normalize volume)
- **Audio Sync Adjustment** (-5s to +5s)

```swift
enum AudioQuality: String, CaseIterable {
    case lossless = "Lossless"
    case high = "High Quality"
    case standard = "Standard"
    
    var bitrate: Int {
        switch self {
        case .lossless: return 0 // No transcoding
        case .high: return 640000
        case .standard: return 192000
        }
    }
    
    var description: String {
        switch self {
        case .lossless: return "Preserve original audio (TrueHD, DTS-HD)"
        case .high: return "AAC 5.1 Surround (640 kbps)"
        case .standard: return "AAC Stereo (192 kbps)"
        }
    }
}

enum SurroundSound: String, CaseIterable {
    case dolbyAtmos = "Dolby Atmos"
    case surround71 = "7.1 Surround"
    case surround51 = "5.1 Surround"
    case stereo = "Stereo"
    
    var channels: Int {
        switch self {
        case .dolbyAtmos: return 0 // Passthrough
        case .surround71: return 8
        case .surround51: return 6
        case .stereo: return 2
        }
    }
}
```

#### Playback Behavior
**Options:**
- **Auto-Play Next Episode** (On/Off)
- **Auto-Play Countdown** (5s, 10s, 15s, Off)
- **Resume Playback** (Always ask, Always resume, Don't resume)
- **Mark as Played** (After 90%, After 95%, When finished)
- **Remember Audio Track** (Per show/movie)
- **Remember Subtitle Track** (Per show/movie)

```swift
struct PlaybackSettings {
    @AppStorage("autoPlayNext") var autoPlayNext = true
    @AppStorage("autoPlayCountdown") var autoPlayCountdown = 10
    @AppStorage("resumeBehavior") var resumeBehavior = ResumeBehavior.alwaysAsk.rawValue
    @AppStorage("markPlayedThreshold") var markPlayedThreshold = 90
    @AppStorage("rememberAudioTrack") var rememberAudioTrack = true
    @AppStorage("rememberSubtitleTrack") var rememberSubtitleTrack = true
}

enum ResumeBehavior: String, CaseIterable {
    case alwaysAsk = "Always Ask"
    case alwaysResume = "Always Resume"
    case neverResume = "Start from Beginning"
}
```

### 2. Streaming & Network Settings

#### Bitrate Settings
**Options:**
- **Maximum Bitrate** (Slider: 1-100 Mbps)
- **Wi-Fi Bitrate** (Separate from cellular if applicable)
- **Streaming Mode**
  - Direct Play (No transcoding, original quality)
  - Direct Stream (Remux container only)
  - Transcode (Full server transcoding)
  - Auto (Let server decide)

```swift
enum StreamingMode: String, CaseIterable {
    case directPlay = "Direct Play"
    case directStream = "Direct Stream"
    case transcode = "Transcode"
    case auto = "Auto"
    
    var description: String {
        switch self {
        case .directPlay: return "Play original file without any processing (best quality)"
        case .directStream: return "Change container format only (maintains quality)"
        case .transcode: return "Convert video on server (compatibility mode)"
        case .auto: return "Let MediaMio choose based on format support"
        }
    }
    
    var jellyfinValue: String {
        switch self {
        case .directPlay: return "DirectPlay"
        case .directStream: return "DirectStream"
        case .transcode: return "Transcode"
        case .auto: return "Auto"
        }
    }
}

struct BitrateSettings {
    @AppStorage("maxBitrate") var maxBitrate: Int = 20_000_000 // 20 Mbps default
    @AppStorage("streamingMode") var streamingMode = StreamingMode.auto.rawValue
    @AppStorage("allowTranscoding") var allowTranscoding = true
    
    var bitrateDisplay: String {
        let mbps = Double(maxBitrate) / 1_000_000
        return String(format: "%.1f Mbps", mbps)
    }
}
```

#### Transcoding Options
**Options:**
- **Allow Hardware Acceleration** (On/Off)
- **Video Codec Preference**
  - H.264 (Most compatible)
  - HEVC/H.265 (Better compression)
  - VP9 (Open source)
  - AV1 (Future-proof)
- **Maximum Transcoding Resolution**
- **Throttle Transcoding** (On/Off)

```swift
enum VideoCodec: String, CaseIterable {
    case h264 = "H.264/AVC"
    case hevc = "HEVC/H.265"
    case vp9 = "VP9"
    case av1 = "AV1"
    
    var jellyfinValue: String {
        switch self {
        case .h264: return "h264"
        case .hevc: return "hevc"
        case .vp9: return "vp9"
        case .av1: return "av1"
        }
    }
    
    var description: String {
        switch self {
        case .h264: return "Universal compatibility, larger file sizes"
        case .hevc: return "50% smaller files, newer devices only"
        case .vp9: return "Google's codec, good for web streaming"
        case .av1: return "Next-gen codec, best compression"
        }
    }
}
```

#### Network Settings
**Options:**
- **Pre-buffer Duration** (5s, 10s, 20s, 30s)
- **Cache Size** (100MB, 500MB, 1GB, 2GB)
- **Low Bandwidth Mode** (On/Off)
- **Prefer Local Network** (On/Off)
- **Connection Test** (Test current connection speed)

```swift
struct NetworkSettings {
    @AppStorage("preBufferDuration") var preBufferDuration = 10
    @AppStorage("cacheSize") var cacheSize = 500 // MB
    @AppStorage("lowBandwidthMode") var lowBandwidthMode = false
    @AppStorage("preferLocalNetwork") var preferLocalNetwork = true
    
    func estimatedBandwidth() async -> Double {
        // Implement bandwidth test
        // Return Mbps
    }
}
```

### 3. Subtitle Settings

#### Subtitle Preferences
**Options:**
- **Default Subtitle Language** (None, English, Spanish, etc.)
- **Subtitle Mode**
  - Off by default
  - On by default
  - Only for foreign language
  - Smart (based on audio track)
- **Burned-in Subtitles** (Prefer burned-in, Prefer separate, No preference)

```swift
enum SubtitleMode: String, CaseIterable {
    case off = "Off by Default"
    case on = "On by Default"
    case foreignOnly = "Foreign Language Only"
    case smart = "Smart (Match Audio)"
    
    var description: String {
        switch self {
        case .off: return "Subtitles off unless manually enabled"
        case .on: return "Subtitles always on in preferred language"
        case .foreignOnly: return "Only when audio is foreign language"
        case .smart: return "Auto-enable if audio doesn't match preferred language"
        }
    }
}

struct SubtitlePreferences {
    @AppStorage("defaultSubtitleLanguage") var defaultLanguage = "eng"
    @AppStorage("subtitleMode") var subtitleMode = SubtitleMode.off.rawValue
    @AppStorage("burnedInPreference") var burnedInPreference = "separate"
}
```

#### Subtitle Appearance
**Options:**
- **Font Size** (Small, Medium, Large, Extra Large)
- **Font** (System, Sans-Serif, Serif, Monospace)
- **Text Color** (White, Yellow, Cyan, etc.)
- **Background** (None, Black, Semi-transparent)
- **Edge Style** (None, Drop Shadow, Outline, Raised)
- **Position** (Bottom, Top, Custom)
- **Preview** (Live preview of settings)

```swift
struct SubtitleStyle {
    @AppStorage("subtitleSize") var size = SubtitleSize.medium.rawValue
    @AppStorage("subtitleFont") var font = "System"
    @AppStorage("subtitleColor") var color = "white"
    @AppStorage("subtitleBackground") var background = "semitransparent"
    @AppStorage("subtitleEdgeStyle") var edgeStyle = "dropShadow"
    @AppStorage("subtitlePosition") var position = 0.9 // 0-1, percentage from top
}

enum SubtitleSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"
    
    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.2
        case .extraLarge: return 1.5
        }
    }
}
```

### 4. Skip Settings (Auto-Skip Features)

#### Auto-Skip Options
**Options:**
- **Auto-Skip Intros** (On/Off)
  - Show "Skip Intro" button (5s before intro)
  - Auto-skip countdown (3s, 5s, instant)
  - Per-show preference
- **Auto-Skip Credits** (On/Off)
  - Start next episode automatically
  - Show "Next Episode" overlay
  - Countdown duration (5s, 10s, 15s)
- **Auto-Skip Recaps** (On/Off)
  - "Previously on..." segments
  - Automatic detection via Jellyfin markers
- **Skip Behavior**
  - Always skip
  - Show button and auto-skip after delay
  - Show button only (manual skip)

```swift
struct SkipSettings {
    // Intro Skipping
    @AppStorage("autoSkipIntros") var autoSkipIntros = false
    @AppStorage("showSkipIntroButton") var showSkipIntroButton = true
    @AppStorage("skipIntroCountdown") var skipIntroCountdown = 5
    @AppStorage("rememberSkipIntroPerShow") var rememberSkipIntroPerShow = true
    
    // Credits Skipping
    @AppStorage("autoSkipCredits") var autoSkipCredits = true
    @AppStorage("skipCreditsCountdown") var skipCreditsCountdown = 10
    @AppStorage("showNextEpisodeOverlay") var showNextEpisodeOverlay = true
    
    // Recap Skipping
    @AppStorage("autoSkipRecaps") var autoSkipRecaps = false
    @AppStorage("showSkipRecapButton") var showSkipRecapButton = true
    
    // General Skip Behavior
    @AppStorage("skipBehavior") var skipBehavior = SkipBehavior.buttonWithDelay.rawValue
}

enum SkipBehavior: String, CaseIterable {
    case alwaysSkip = "Always Skip"
    case buttonWithDelay = "Button + Auto-Skip"
    case buttonOnly = "Button Only"
    
    var description: String {
        switch self {
        case .alwaysSkip: return "Skip immediately without prompt"
        case .buttonWithDelay: return "Show button, auto-skip after countdown"
        case .buttonOnly: return "Show button, require manual skip"
        }
    }
}
```

#### Skip Markers
**Integration with Jellyfin:**
Jellyfin can provide intro/credits timestamps via the API:

```swift
struct SkipMarker: Codable {
    let itemId: String
    let seasonId: String?
    let introStart: Double
    let introEnd: Double
    let creditsStart: Double?
    
    var introDuration: Double {
        introEnd - introStart
    }
}

class SkipMarkerService {
    func fetchSkipMarkers(for itemId: String) async -> SkipMarker? {
        // GET /Items/{itemId}/IntroTimestamps
        // Jellyfin provides intro/outro timestamps
        // Parse and return markers
    }
    
    func shouldShowSkipButton(currentTime: Double, marker: SkipMarker, settings: SkipSettings) -> Bool {
        // Show button 5 seconds before intro
        let showThreshold = marker.introStart - 5
        let hideThreshold = marker.introEnd
        
        return currentTime >= showThreshold && currentTime < hideThreshold
    }
    
    func performAutoSkip(player: AVPlayer, to timestamp: Double, countdown: Int) {
        // Show countdown overlay
        // Skip after countdown expires
        let skipTime = CMTime(seconds: timestamp, preferredTimescale: 1)
        player.seek(to: skipTime)
    }
}
```

### 5. Account Settings

#### User Profile
**Options:**
- **Display Name** (Read-only from Jellyfin)
- **Profile Picture** (From Jellyfin)
- **Switch User** (Show all users on server)
- **User Preferences** (Sync from Jellyfin)

```swift
struct UserProfile {
    let id: String
    let name: String
    let imageURL: URL?
    let isAdmin: Bool
    let lastActive: Date
}

class AccountManager: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var availableUsers: [UserProfile] = []
    
    func switchUser(to user: UserProfile) async throws {
        // Authenticate as new user
        // Update current user
        // Reload content for new user
    }
    
    func signOut() {
        // Clear credentials from Keychain
        // Clear cached data
        // Return to login screen
    }
}
```

#### Server Settings
**Options:**
- **Server Address** (Current server URL)
- **Connection Status** (Active/Inactive)
- **Server Version** (Display Jellyfin version)
- **Change Server** (Switch to different server)
- **Test Connection** (Verify server is reachable)

```swift
struct ServerInfo {
    let url: String
    let version: String
    let name: String
    let isConnected: Bool
    
    func testConnection() async -> Bool {
        // Ping server
        // Return connectivity status
    }
}
```

#### Sign Out
**Options:**
- **Sign Out** (Clear credentials, return to login)
- **Sign Out All Devices** (Revoke token on server)
- **Delete Local Data** (Clear cache and preferences)

### 6. App Settings

#### Interface Settings
**Options:**
- **Theme** (Dark, Extra Dark, OLED Black)
- **Accent Color** (Purple, Blue, Red, Green, Custom)
- **Show Ratings** (Star ratings, Critic scores, Both, None)
- **Show Adult Content** (On/Off, PIN protected)
- **Spoiler Protection** (Hide episode thumbnails/titles)
- **Content Warnings** (Show content ratings/warnings)
- **Language** (App interface language)

```swift
enum AppTheme: String, CaseIterable {
    case dark = "Dark"
    case extraDark = "Extra Dark"
    case oledBlack = "OLED Black"
    
    var backgroundColor: Color {
        switch self {
        case .dark: return Color(hex: "0a0a0a")
        case .extraDark: return Color(hex: "000000")
        case .oledBlack: return Color.black
        }
    }
}

struct InterfaceSettings {
    @AppStorage("theme") var theme = AppTheme.dark.rawValue
    @AppStorage("accentColor") var accentColor = "667eea"
    @AppStorage("showRatings") var showRatings = true
    @AppStorage("showAdultContent") var showAdultContent = false
    @AppStorage("spoilerProtection") var spoilerProtection = false
}
```

#### Storage & Cache
**Options:**
- **Cache Size** (Current usage / Max)
- **Clear Cache** (Remove all cached images/data)
- **Download Quality** (For offline viewing if implemented)
- **Automatically Clear Cache** (After 7 days, 30 days, Never)

```swift
class CacheManager {
    func getCacheSize() -> Int64 {
        // Calculate total cache size in bytes
    }
    
    func clearCache() {
        // Clear image cache
        // Clear video buffer cache
        // Clear API response cache
    }
    
    var cacheSizeString: String {
        let bytes = getCacheSize()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
```

#### About
**Options:**
- **App Version** (e.g., "1.0.0 (123)")
- **Build Number**
- **Jellyfin Server Version**
- **Open Source Licenses**
- **Privacy Policy**
- **Terms of Service**
- **Support / Feedback** (Email, GitHub issues)
- **Check for Updates**

## Settings UI Implementation

### Main Settings View

```swift
import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager()
    @FocusState private var focusedField: SettingsField?
    
    enum SettingsField: Hashable {
        case playback
        case streaming
        case subtitles
        case skip
        case account
        case app
    }
    
    var body: some View {
        NavigationView {
            List {
                // Playback Settings
                NavigationLink(destination: PlaybackSettingsView()) {
                    SettingsRow(
                        icon: "play.circle.fill",
                        title: "Playback",
                        subtitle: settingsManager.playbackSummary
                    )
                }
                .focused($focusedField, equals: .playback)
                
                // Streaming Settings
                NavigationLink(destination: StreamingSettingsView()) {
                    SettingsRow(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Streaming & Network",
                        subtitle: settingsManager.streamingSummary
                    )
                }
                .focused($focusedField, equals: .streaming)
                
                // Subtitle Settings
                NavigationLink(destination: SubtitleSettingsView()) {
                    SettingsRow(
                        icon: "captions.bubble.fill",
                        title: "Subtitles",
                        subtitle: settingsManager.subtitleSummary
                    )
                }
                .focused($focusedField, equals: .subtitles)
                
                // Skip Settings
                NavigationLink(destination: SkipSettingsView()) {
                    SettingsRow(
                        icon: "forward.fill",
                        title: "Auto-Skip",
                        subtitle: settingsManager.skipSummary
                    )
                }
                .focused($focusedField, equals: .skip)
                
                Section {
                    // Account Settings
                    NavigationLink(destination: AccountSettingsView()) {
                        SettingsRow(
                            icon: "person.circle.fill",
                            title: "Account",
                            subtitle: settingsManager.currentUser?.name ?? "Not signed in"
                        )
                    }
                    .focused($focusedField, equals: .account)
                    
                    // App Settings
                    NavigationLink(destination: AppSettingsView()) {
                        SettingsRow(
                            icon: "gear",
                            title: "App Settings",
                            subtitle: "Interface, storage, and more"
                        )
                    }
                    .focused($focusedField, equals: .app)
                }
            }
            .navigationTitle("Settings")
            .listStyle(.grouped)
        }
        .onAppear {
            focusedField = .playback // Default focus
        }
    }
}

// Reusable settings row component
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "667eea"))
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}
```

### Playback Settings Detail View

```swift
struct PlaybackSettingsView: View {
    @AppStorage("videoQuality") private var videoQuality = VideoQuality.auto.rawValue
    @AppStorage("audioQuality") private var audioQuality = AudioQuality.high.rawValue
    @AppStorage("autoPlayNext") private var autoPlayNext = true
    @AppStorage("autoPlayCountdown") private var autoPlayCountdown = 10
    
    var body: some View {
        Form {
            Section {
                // Video Quality Picker
                Picker("Video Quality", selection: $videoQuality) {
                    ForEach(VideoQuality.allCases) { quality in
                        VStack(alignment: .leading) {
                            Text(quality.rawValue)
                                .font(.title3)
                            Text(quality.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(quality.rawValue)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text("Video")
            } footer: {
                Text(selectedVideoQuality.description)
            }
            
            Section {
                // Audio Quality Picker
                Picker("Audio Quality", selection: $audioQuality) {
                    ForEach(AudioQuality.allCases, id: \.rawValue) { quality in
                        VStack(alignment: .leading) {
                            Text(quality.rawValue)
                            Text(quality.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(quality.rawValue)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text("Audio")
            }
            
            Section {
                // Auto-play Toggle
                Toggle("Auto-Play Next Episode", isOn: $autoPlayNext)
                
                if autoPlayNext {
                    // Countdown Picker
                    Picker("Countdown", selection: $autoPlayCountdown) {
                        Text("5 seconds").tag(5)
                        Text("10 seconds").tag(10)
                        Text("15 seconds").tag(15)
                        Text("Off").tag(0)
                    }
                }
            } header: {
                Text("Behavior")
            } footer: {
                if autoPlayNext {
                    Text("Next episode will start after \(autoPlayCountdown) seconds")
                }
            }
        }
        .navigationTitle("Playback")
    }
    
    private var selectedVideoQuality: VideoQuality {
        VideoQuality(rawValue: videoQuality) ?? .auto
    }
}
```

### Streaming Settings with Bitrate Slider

```swift
struct StreamingSettingsView: View {
    @AppStorage("maxBitrate") private var maxBitrate = 20_000_000
    @AppStorage("streamingMode") private var streamingMode = StreamingMode.auto.rawValue
    @AppStorage("allowTranscoding") private var allowTranscoding = true
    @State private var showBandwidthTest = false
    
    var body: some View {
        Form {
            Section {
                // Streaming Mode
                Picker("Streaming Mode", selection: $streamingMode) {
                    ForEach(StreamingMode.allCases, id: \.rawValue) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.rawValue)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text("Mode")
            }
            
            Section {
                // Bitrate Slider
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Maximum Bitrate")
                        Spacer()
                        Text(bitrateDisplay)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(maxBitrate) },
                            set: { maxBitrate = Int($0) }
                        ),
                        in: 1_000_000...100_000_000,
                        step: 1_000_000
                    )
                }
                
                // Quick presets
                HStack(spacing: 12) {
                    BitratePresetButton(title: "2 Mbps", bitrate: 2_000_000, current: $maxBitrate)
                    BitratePresetButton(title: "5 Mbps", bitrate: 5_000_000, current: $maxBitrate)
                    BitratePresetButton(title: "10 Mbps", bitrate: 10_000_000, current: $maxBitrate)
                    BitratePresetButton(title: "20 Mbps", bitrate: 20_000_000, current: $maxBitrate)
                    BitratePresetButton(title: "40 Mbps", bitrate: 40_000_000, current: $maxBitrate)
                }
            } header: {
                Text("Quality")
            } footer: {
                Text("Higher bitrate means better quality but requires faster connection")
            }
            
            Section {
                Button("Test Connection Speed") {
                    showBandwidthTest = true
                }
            }
        }
        .navigationTitle("Streaming & Network")
        .sheet(isPresented: $showBandwidthTest) {
            BandwidthTestView()
        }
    }
    
    private var bitrateDisplay: String {
        let mbps = Double(maxBitrate) / 1_000_000
        return String(format: "%.1f Mbps", mbps)
    }
}

struct BitratePresetButton: View {
    let title: String
    let bitrate: Int
    @Binding var current: Int
    
    var body: some View {
        Button(title) {
            current = bitrate
        }
        .buttonStyle(.bordered)
        .tint(current == bitrate ? Color(hex: "667eea") : .gray)
    }
}
```

### Skip Settings with Toggle Groups

```swift
struct SkipSettingsView: View {
    @AppStorage("autoSkipIntros") private var autoSkipIntros = false
    @AppStorage("skipIntroCountdown") private var skipIntroCountdown = 5
    @AppStorage("autoSkipCredits") private var autoSkipCredits = true
    @AppStorage("skipCreditsCountdown") private var skipCreditsCountdown = 10
    @AppStorage("autoSkipRecaps") private var autoSkipRecaps = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-Skip Intros", isOn: $autoSkipIntros)
                
                if autoSkipIntros {
                    Picker("Skip After", selection: $skipIntroCountdown) {
                        Text("Instantly").tag(0)
                        Text("3 seconds").tag(3)
                        Text("5 seconds").tag(5)
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Intros")
            } footer: {
                Text(autoSkipIntros ? "Opening credits will be skipped automatically" : "A 'Skip Intro' button will appear during opening credits")
            }
            
            Section {
                Toggle("Auto-Skip Credits", isOn: $autoSkipCredits)
                
                if autoSkipCredits {
                    Picker("Start Next Episode After", selection: $skipCreditsCountdown) {
                        Text("5 seconds").tag(5)
                        Text("10 seconds").tag(10)
                        Text("15 seconds").tag(15)
                    }
                }
            } header: {
                Text("Credits")
            } footer: {
                Text(autoSkipCredits ? "Next episode will start automatically during end credits" : "A 'Next Episode' button will appear during end credits")
            }
            
            Section {
                Toggle("Auto-Skip Recaps", isOn: $autoSkipRecaps)
            } header: {
                Text("Recaps")
            } footer: {
                Text("Skip 'Previously on...' segments at the start of episodes")
            }
            
            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Skip markers are provided by your Jellyfin server and may not be available for all content.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Auto-Skip")
    }
}
```

### Subtitle Settings with Live Preview

```swift
struct SubtitleSettingsView: View {
    @AppStorage("subtitleSize") private var subtitleSize = SubtitleSize.medium.rawValue
    @AppStorage("subtitleColor") private var subtitleColor = "white"
    @AppStorage("subtitleBackground") private var subtitleBackground = "semitransparent"
    @AppStorage("subtitleEdgeStyle") private var subtitleEdgeStyle = "dropShadow"
    
    var body: some View {
        Form {
            Section {
                Picker("Default Language", selection: .constant("eng")) {
                    Text("None").tag("none")
                    Text("English").tag("eng")
                    Text("Spanish").tag("spa")
                    Text("French").tag("fra")
                    Text("German").tag("deu")
                }
            }
            
            Section {
                Picker("Size", selection: $subtitleSize) {
                    ForEach(SubtitleSize.allCases, id: \.rawValue) { size in
                        Text(size.rawValue).tag(size.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Color", selection: $subtitleColor) {
                    ColorOption(name: "White", hex: "FFFFFF").tag("white")
                    ColorOption(name: "Yellow", hex: "FFFF00").tag("yellow")
                    ColorOption(name: "Cyan", hex: "00FFFF").tag("cyan")
                }
                
                Picker("Background", selection: $subtitleBackground) {
                    Text("None").tag("none")
                    Text("Semi-Transparent").tag("semitransparent")
                    Text("Black").tag("black")
                }
                
                Picker("Edge Style", selection: $subtitleEdgeStyle) {
                    Text("None").tag("none")
                    Text("Drop Shadow").tag("dropShadow")
                    Text("Outline").tag("outline")
                }
            } header: {
                Text("Appearance")
            }
            
            Section {
                // Live Preview
                SubtitlePreview(
                    size: SubtitleSize(rawValue: subtitleSize) ?? .medium,
                    color: subtitleColor,
                    background: subtitleBackground,
                    edgeStyle: subtitleEdgeStyle
                )
                .frame(height: 200)
            } header: {
                Text("Preview")
            }
        }
        .navigationTitle("Subtitles")
    }
}

struct SubtitlePreview: View {
    let size: SubtitleSize
    let color: String
    let background: String
    let edgeStyle: String
    
    var body: some View {
        ZStack {
            // Background scene
            Color.black
                .overlay(
                    Image(systemName: "tv")
                        .font(.system(size: 100))
                        .foregroundColor(.gray.opacity(0.3))
                )
            
            VStack {
                Spacer()
                
                // Sample subtitle
                Text("This is how your subtitles will look")
                    .font(.system(size: 24 * size.scaleFactor))
                    .foregroundColor(colorFromString(color))
                    .background(backgroundFromString(background))
                    .shadow(radius: edgeStyle == "dropShadow" ? 4 : 0)
                    .overlay(
                        Text("This is how your subtitles will look")
                            .font(.system(size: 24 * size.scaleFactor))
                            .foregroundColor(.clear)
                            .background(Color.clear)
                            .overlay(
                                Text("This is how your subtitles will look")
                                    .font(.system(size: 24 * size.scaleFactor))
                                    .foregroundColor(.clear)
                                    .stroke(edgeStyle == "outline" ? Color.black : Color.clear, lineWidth: 2)
                            )
                    )
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .padding(.bottom, 40)
            }
        }
        .cornerRadius(12)
    }
    
    func colorFromString(_ string: String) -> Color {
        switch string {
        case "white": return .white
        case "yellow": return .yellow
        case "cyan": return .cyan
        default: return .white
        }
    }
    
    func backgroundFromString(_ string: String) -> Color {
        switch string {
        case "none": return .clear
        case "semitransparent": return .black.opacity(0.6)
        case "black": return .black
        default: return .clear
        }
    }
}

extension View {
    func stroke(_ color: Color, lineWidth: CGFloat) -> some View {
        self.overlay(
            self
                .offset(x: -lineWidth, y: -lineWidth)
                .foregroundColor(color)
        )
    }
}
```

## Settings Persistence Strategy

### UserDefaults with @AppStorage
For simple settings that don't need encryption:

```swift
class SettingsManager: ObservableObject {
    // Video Settings
    @AppStorage("videoQuality") var videoQuality = VideoQuality.auto.rawValue
    @AppStorage("maxBitrate") var maxBitrate = 20_000_000
    @AppStorage("streamingMode") var streamingMode = StreamingMode.auto.rawValue
    
    // Audio Settings
    @AppStorage("audioQuality") var audioQuality = AudioQuality.high.rawValue
    @AppStorage("defaultAudioLanguage") var defaultAudioLanguage = "eng"
    
    // Subtitle Settings
    @AppStorage("subtitleSize") var subtitleSize = SubtitleSize.medium.rawValue
    @AppStorage("defaultSubtitleLanguage") var defaultSubtitleLanguage = "eng"
    
    // Skip Settings
    @AppStorage("autoSkipIntros") var autoSkipIntros = false
    @AppStorage("autoSkipCredits") var autoSkipCredits = true
    @AppStorage("autoSkipRecaps") var autoSkipRecaps = false
    
    // Playback Settings
    @AppStorage("autoPlayNext") var autoPlayNext = true
    @AppStorage("resumeBehavior") var resumeBehavior = ResumeBehavior.alwaysAsk.rawValue
    
    // Computed summaries for settings menu
    var playbackSummary: String {
        let quality = VideoQuality(rawValue: videoQuality) ?? .auto
        return "\(quality.rawValue) quality, \(autoPlayNext ? "Auto-play on" : "Auto-play off")"
    }
    
    var streamingSummary: String {
        let mbps = Double(maxBitrate) / 1_000_000
        return String(format: "Max %.1f Mbps", mbps)
    }
    
    var subtitleSummary: String {
        let lang = defaultSubtitleLanguage == "none" ? "Off" : defaultSubtitleLanguage.uppercased()
        return "Default: \(lang)"
    }
    
    var skipSummary: String {
        var enabled: [String] = []
        if autoSkipIntros { enabled.append("Intros") }
        if autoSkipCredits { enabled.append("Credits") }
        if autoSkipRecaps { enabled.append("Recaps") }
        
        return enabled.isEmpty ? "All disabled" : enabled.joined(separator: ", ")
    }
}
```

### Keychain for Sensitive Data
For API keys and tokens:

```swift
class KeychainManager {
    static let shared = KeychainManager()
    
    func saveToken(_ token: String, for key: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getToken(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

## Integration with Jellyfin API

### Applying Settings to Playback

```swift
class JellyfinPlaybackManager {
    let settings: SettingsManager
    
    func buildStreamURL(for item: MediaItem) -> URL {
        var components = URLComponents(string: "\(serverURL)/Videos/\(item.id)/master.m3u8")!
        
        // Apply bitrate setting
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "MaxStreamingBitrate", value: "\(settings.maxBitrate)")
        ]
        
        // Apply quality setting
        if let maxHeight = VideoQuality(rawValue: settings.videoQuality)?.maxHeight {
            queryItems.append(URLQueryItem(name: "MaxHeight", value: "\(maxHeight)"))
        }
        
        // Apply audio settings
        let audioCodecs = getAudioCodecs(for: settings.audioQuality)
        queryItems.append(URLQueryItem(name: "AudioCodec", value: audioCodecs))
        
        // Apply streaming mode
        if settings.streamingMode == StreamingMode.directPlay.rawValue {
            // Use direct play URL instead
            return buildDirectPlayURL(for: item)
        }
        
        components.queryItems = queryItems
        return components.url!
    }
    
    func applySubtitleSettings(to player: AVPlayer) {
        guard let currentItem = player.currentItem else { return }
        
        // Get subtitle preferences
        let preferredLanguage = settings.defaultSubtitleLanguage
        
        // Find matching subtitle track
        if let subtitleGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            let matchingOptions = subtitleGroup.options.filter { option in
                option.extendedLanguageTag == preferredLanguage
            }
            
            if let option = matchingOptions.first {
                currentItem.select(option, in: subtitleGroup)
            } else if settings.subtitleMode == SubtitleMode.off.rawValue {
                currentItem.select(nil, in: subtitleGroup)
            }
        }
    }
    
    func checkSkipMarkers(currentTime: Double, for item: MediaItem) async {
        guard let markers = await fetchSkipMarkers(for: item.id) else { return }
        
        // Check if we should skip intro
        if settings.autoSkipIntros && currentTime >= markers.introStart && currentTime < markers.introEnd {
            if settings.skipIntroCountdown == 0 {
                // Skip immediately
                skipToTimestamp(markers.introEnd)
            } else {
                // Show countdown and skip
                showSkipCountdown(seconds: settings.skipIntroCountdown) {
                    self.skipToTimestamp(markers.introEnd)
                }
            }
        }
        
        // Check if we should skip credits
        if let creditsStart = markers.creditsStart,
           settings.autoSkipCredits &&
           currentTime >= creditsStart {
            showNextEpisodeOverlay(countdown: settings.skipCreditsCountdown)
        }
    }
}
```

### Saving Settings to Jellyfin User Profile

```swift
extension JellyfinAPIClient {
    func syncUserPreferences() async throws {
        // Jellyfin allows saving user preferences
        let preferences = [
            "SubtitleLanguagePreference": settings.defaultSubtitleLanguage,
            "AudioLanguagePreference": settings.defaultAudioLanguage,
            "MaxBitrate": "\(settings.maxBitrate)",
            "EnableNextEpisodeAutoPlay": settings.autoPlayNext
        ]
        
        let url = "\(serverURL)/Users/\(userId)/Configuration"
        // POST preferences to Jellyfin
    }
    
    func loadUserPreferences() async throws {
        // Load preferences from Jellyfin
        let url = "\(serverURL)/Users/\(userId)/Configuration"
        // GET preferences and update local settings
    }
}
```

## Testing Settings

### Settings Test Checklist

```
Playback Settings:
- [ ] Video quality changes affect stream quality
- [ ] Audio quality setting works
- [ ] Auto-play next episode functions
- [ ] Resume behavior works as configured

Streaming Settings:
- [ ] Bitrate limit is respected
- [ ] Streaming mode affects playback method
- [ ] Connection test works
- [ ] Cache settings take effect

Subtitle Settings:
- [ ] Default language is applied
- [ ] Subtitle appearance changes are visible
- [ ] Preview shows accurate representation
- [ ] Subtitles persist across episodes

Skip Settings:
- [ ] Auto-skip intro works when enabled
- [ ] Auto-skip credits works when enabled
- [ ] Countdown displays correctly
- [ ] Skip markers are detected

Account Settings:
- [ ] User switching works
- [ ] Sign out clears credentials
- [ ] Server connection test works

App Settings:
- [ ] Theme changes take effect
- [ ] Cache can be cleared
- [ ] About info is accurate
```

## Advanced Features

### A/B Quality Comparison
Allow users to compare quality settings:

```swift
struct QualityComparisonView: View {
    let item: MediaItem
    @State private var leftQuality = VideoQuality.hd
    @State private var rightQuality = VideoQuality.uhd4K
    
    var body: some View {
        HStack(spacing: 0) {
            VideoPlayer(buildPlayer(quality: leftQuality))
            VideoPlayer(buildPlayer(quality: rightQuality))
        }
    }
}
```

### Smart Bandwidth Detection
Automatically adjust quality based on network:

```swift
class SmartBandwidthManager {
    func detectOptimalBitrate() async -> Int {
        // Measure download speed
        let speed = await measureDownloadSpeed()
        
        // Recommend bitrate (use 80% of available bandwidth)
        let recommendedBitrate = Int(speed * 0.8)
        
        return recommendedBitrate
    }
    
    func autoAdjustQuality() async {
        let bitrate = await detectOptimalBitrate()
        
        switch bitrate {
        case 25_000_000...: 
            settings.videoQuality = VideoQuality.uhd4K.rawValue
        case 8_000_000..<25_000_000:
            settings.videoQuality = VideoQuality.fullHD.rawValue
        case 3_000_000..<8_000_000:
            settings.videoQuality = VideoQuality.hd.rawValue
        default:
            settings.videoQuality = VideoQuality.sd.rawValue
        }
    }
}
```

### Per-Content Settings
Remember settings per show/movie:

```swift
class ContentSpecificSettings {
    func saveAudioTrack(for itemId: String, track: String) {
        UserDefaults.standard.set(track, forKey: "audio_\(itemId)")
    }
    
    func getPreferredAudioTrack(for itemId: String) -> String? {
        return UserDefaults.standard.string(forKey: "audio_\(itemId)")
    }
}
```

## Summary

A well-designed settings interface gives users:
- **Control**: Fine-tune their viewing experience
- **Confidence**: See exactly what each setting does
- **Convenience**: Smart defaults with easy customization
- **Clarity**: Clear descriptions and visual feedback

Key principles:
1. **Organize logically** - Group related settings
2. **Use clear language** - Avoid technical jargon
3. **Provide context** - Explain what each setting does
4. **Show impact** - Preview changes when possible
5. **Smart defaults** - Most users shouldn't need to change anything
6. **Persist choices** - Remember user preferences
7. **Sync with server** - Keep Jellyfin and app in sync

With these comprehensive settings, MediaMio gives users Netflix-level control over their streaming experience! 🎛️
