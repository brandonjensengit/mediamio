# Launch Experience: Animated Splash Screen + Startup Sound

## The Vision

Like Netflix's iconic "ta-dum" sound and animation, MediaMio should have a premium launch experience:

1. **App launches** → MediaMio icon appears (animated)
2. **Icon animation** → Smooth scale/fade effect
3. **Startup sound** → Custom sound plays (like Netflix "ta-dum")
4. **Background loading** → Jellyfin server connects
5. **Smooth transition** → Fade to main app when ready

No menu, no content - just the beautiful icon until everything is loaded!

## Complete Implementation

### 1. Splash Screen View

```swift
import SwiftUI
import AVFoundation

struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @Binding var isActive: Bool
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // MediaMio icon
            Image("mediamio-icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            // Play startup sound
            playStartupSound()
            
            // Animate icon in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Start loading Jellyfin in background
            loadJellyfinData()
        }
    }
    
    private func playStartupSound() {
        guard let soundURL = Bundle.main.url(forResource: "startup-sound", withExtension: "mp3") else {
            print("⚠️ Startup sound file not found")
            return
        }
        
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer.volume = 0.5
            audioPlayer.play()
        } catch {
            print("❌ Failed to play startup sound: \(error)")
        }
    }
    
    private func loadJellyfinData() {
        Task {
            do {
                // Connect to Jellyfin
                try await JellyfinAPIClient.shared.connect()
                
                // Load initial data
                try await JellyfinAPIClient.shared.fetchLibraries()
                
                // Wait minimum time for animation (feels premium)
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds minimum
                
                // Transition to main app
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.5)) {
                        isActive = true
                    }
                }
            } catch {
                print("❌ Failed to load Jellyfin: \(error)")
                // Show error state or retry
            }
        }
    }
}
```

### 2. App Entry Point

```swift
import SwiftUI

@main
struct MediaMioApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            if appState.isLaunching {
                // Show splash screen
                SplashScreenView(isActive: $appState.isLaunching)
                    .transition(.opacity)
            } else {
                // Show main app
                MainTabView()
                    .environmentObject(appState)
                    .transition(.opacity)
            }
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isLaunching = true
    @Published var jellyfinConnected = false
}
```

### 3. Enhanced Animation Options

#### Option A: Netflix-Style Fade + Scale

```swift
struct NetflixStyleSplash: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @Binding var isActive: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image("mediamio-icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            playStartupSound()
            
            // Animate in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Hold for a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Slight scale pulse
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = 1.05
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scale = 1.0
                    }
                }
            }
            
            loadJellyfinData()
        }
    }
}
```

#### Option B: Elegant Fade In (Minimal)

```swift
struct MinimalSplash: View {
    @State private var opacity: Double = 0
    @Binding var isActive: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image("mediamio-icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
                .opacity(opacity)
        }
        .onAppear {
            playStartupSound()
            
            withAnimation(.easeIn(duration: 0.8)) {
                opacity = 1.0
            }
            
            loadJellyfinData()
        }
    }
}
```

#### Option C: Bouncy Scale (Playful)

```swift
struct BouncySplash: View {
    @State private var scale: CGFloat = 0.3
    @State private var rotation: Double = -10
    @Binding var isActive: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image("mediamio-icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            playStartupSound()
            
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                scale = 1.0
                rotation = 0
            }
            
            loadJellyfinData()
        }
    }
}
```

### 4. Adding Custom Startup Sound

#### Step 1: Get a Sound Effect

**Option A: Create Your Own**
- Use GarageBand or Logic Pro
- Create a short (~1-2 second) musical sting
- Export as MP3 or M4A
- Keep it subtle and premium

**Option B: Use Free Sounds**
- [FreeSound.org](https://freesound.org/) - Free sound effects
- Search: "whoosh", "sting", "logo", "brand"
- Download MP3 format
- Keep under 2 seconds

**Option C: Netflix-Inspired Sound**
Key characteristics:
- 1-2 seconds duration
- Rising pitch or "ta-dum" style
- Professional and recognizable
- Not too loud or jarring

#### Step 2: Add Sound to Xcode

```
1. In Xcode, right-click project folder
2. Select "Add Files to [Project]"
3. Choose your sound file (e.g., "startup-sound.mp3")
4. ✅ Check "Copy items if needed"
5. ✅ Check "Add to targets: [YourApp]"
6. Click "Add"
```

#### Step 3: Audio Player Manager

```swift
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    func playStartupSound() {
        guard let soundURL = Bundle.main.url(forResource: "startup-sound", withExtension: "mp3") else {
            print("⚠️ Startup sound not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.volume = 0.5 // Adjust volume (0.0 - 1.0)
            audioPlayer?.play()
            
            print("✅ Playing startup sound")
        } catch {
            print("❌ Failed to play startup sound: \(error)")
        }
    }
    
    func stopStartupSound() {
        audioPlayer?.stop()
    }
}
```

#### Step 4: Use in Splash Screen

```swift
struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @Binding var isActive: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image("mediamio-icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            // ✅ Play sound
            AudioManager.shared.playStartupSound()
            
            // Animate icon
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Load Jellyfin
            loadJellyfinData()
        }
    }
    
    private func loadJellyfinData() {
        Task {
            do {
                // Connect to server
                try await JellyfinAPIClient.shared.connect()
                
                // Load initial data
                try await JellyfinAPIClient.shared.fetchLibraries()
                
                // Minimum display time (feels premium)
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Transition to app
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.5)) {
                        isActive = false
                    }
                }
            } catch {
                print("❌ Failed to load: \(error)")
                // Handle error - show retry screen
            }
        }
    }
}
```

### 5. Loading States

Handle different loading scenarios:

```swift
struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var loadingState: LoadingState = .loading
    @Binding var isActive: Bool
    
    enum LoadingState {
        case loading
        case success
        case error(String)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Icon
                Image("mediamio-icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 300, height: 300)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                // Loading indicator (subtle)
                if loadingState == .loading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "667eea")))
                        .scaleEffect(1.5)
                        .transition(.opacity)
                }
                
                // Error message (if needed)
                if case .error(let message) = loadingState {
                    VStack(spacing: 16) {
                        Text("Connection Error")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text(message)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            loadingState = .loading
                            loadJellyfinData()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "667eea"))
                    }
                    .padding()
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            AudioManager.shared.playStartupSound()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            loadJellyfinData()
        }
    }
    
    private func loadJellyfinData() {
        Task {
            do {
                try await JellyfinAPIClient.shared.connect()
                try await JellyfinAPIClient.shared.fetchLibraries()
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                await MainActor.run {
                    loadingState = .success
                    withAnimation(.easeOut(duration: 0.5)) {
                        isActive = false
                    }
                }
            } catch {
                await MainActor.run {
                    loadingState = .error(error.localizedDescription)
                }
            }
        }
    }
}
```

### 6. Premium Transition to Main App

```swift
@main
struct MediaMioApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app (loaded underneath)
                MainTabView()
                    .environmentObject(appState)
                    .opacity(appState.isLaunching ? 0 : 1)
                
                // Splash screen (on top while launching)
                if appState.isLaunching {
                    SplashScreenView(isActive: $appState.isLaunching)
                        .zIndex(1)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: appState.isLaunching)
        }
    }
}
```

## Recommended Configuration

### Best Animation (Netflix-like):

```swift
struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @Binding var isActive: Bool
    
    var body: some View {
        ZStack {
            // Pure black background
            Color.black.ignoresSafeArea()
            
            // MediaMio icon
            Image("mediamio-icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            // Sound plays immediately
            AudioManager.shared.playStartupSound()
            
            // Icon animates in smoothly
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Load Jellyfin (hidden)
            loadJellyfinData()
        }
    }
    
    private func loadJellyfinData() {
        Task {
            do {
                try await JellyfinAPIClient.shared.connect()
                try await JellyfinAPIClient.shared.fetchLibraries()
                
                // Minimum 2 seconds display (feels premium)
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                // Smooth fade to main app
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.5)) {
                        isActive = false
                    }
                }
            } catch {
                // Handle error
                print("❌ Failed to load Jellyfin: \(error)")
            }
        }
    }
}
```

### Sound Timing:

**Perfect Timing (Netflix-style):**
- Sound starts: 0ms (immediately)
- Icon animation starts: 0ms (with sound)
- Icon fully visible: 600ms
- Hold: 1400ms (viewing icon + sound finishes)
- Fade to app: 500ms
- **Total: ~2.5 seconds**

### Volume Recommendations:

```swift
audioPlayer?.volume = 0.4  // Subtle (good for living rooms)
audioPlayer?.volume = 0.5  // Balanced ← Recommended
audioPlayer?.volume = 0.6  // Noticeable
```

## Creating the Perfect Startup Sound

### Characteristics of Great Startup Sounds:

1. **Duration**: 1-2 seconds (not too long)
2. **Pitch**: Rising or resolving (feels satisfying)
3. **Volume**: Moderate (not startling)
4. **Style**: Matches brand (modern, elegant)
5. **Ending**: Clean cutoff or fade (not abrupt)

### Example Sound Ideas:

**Option 1: "Ta-Dum" Style (Netflix)**
- Short orchestral hit
- 2 notes (low → high)
- ~1.5 seconds
- Professional sound

**Option 2: "Whoosh + Chime"**
- Subtle whoosh sound
- Followed by pleasant chime
- ~1 second
- Modern feel

**Option 3: "Rising Synth"**
- Electronic rising tone
- Smooth and futuristic
- ~1.2 seconds
- Tech-forward

### Finding/Creating Sounds:

**Free Resources:**
- [FreeSound.org](https://freesound.org/)
- [Zapsplat.com](https://www.zapsplat.com/)
- [SoundBible.com](http://soundbible.com/)

**Create Your Own:**
- GarageBand (Mac) - Free
- Logic Pro (Mac) - Professional
- Audacity (Free, cross-platform)

**Tips:**
1. Keep it SHORT (1-2 seconds max)
2. Export as MP3 or M4A
3. Normalize audio levels
4. Test at different volumes
5. Get feedback from others

## Claude Code Prompt

```
Implement premium launch experience with animated splash screen and startup sound.

Create Netflix-style app launch:

1. SPLASH SCREEN VIEW
   - Pure black background (Color.black.ignoresSafeArea())
   - MediaMio icon centered (300x300pt)
   - Initial state: scale = 0.5, opacity = 0
   - Animate on appear: scale to 1.0, opacity to 1.0
   - Use spring animation: .spring(response: 0.6, dampingFraction: 0.7)

2. STARTUP SOUND
   - Create AudioManager singleton
   - Setup audio session with .ambient category
   - Load sound file: "startup-sound.mp3" from bundle
   - Play at volume 0.5
   - Play immediately on splash screen appear

3. BACKGROUND LOADING
   - Load Jellyfin connection in background Task
   - Fetch initial libraries
   - Minimum display time: 2 seconds (feels premium)
   - Smooth transition to main app with fade

4. APP ENTRY POINT
   - Create AppState with @Published isLaunching = true
   - Show SplashScreenView while isLaunching
   - Show MainTabView when isLaunching = false
   - Use .transition(.opacity) for smooth fade

5. ERROR HANDLING
   - If Jellyfin fails to connect, show error below icon
   - Add "Retry" button
   - Keep icon visible during error state

ANIMATION SEQUENCE:
0ms: Sound plays + icon animation starts
600ms: Icon fully visible
2000ms: Jellyfin loads complete (minimum hold)
2500ms: Fade to main app

IMPORTANT:
- NO menu or content during splash
- ONLY the MediaMio icon and sound
- Black background throughout
- Smooth spring animation
- Professional feel like Netflix

For startup sound:
- I'll need to add a sound file (startup-sound.mp3)
- 1-2 seconds duration
- Rising pitch or "ta-dum" style
- Volume: 0.5 (balanced)

TESTING:
1. Launch app → Icon animates in smoothly
2. Sound plays immediately
3. Icon holds for ~2 seconds
4. Smooth fade to main app
5. Verify timing feels premium

Read launch-experience-implementation.md for complete code.
```

## Testing Checklist

```
✅ App launches with black screen
✅ Icon appears with smooth scale animation
✅ Startup sound plays (not too loud)
✅ Icon holds for ~2 seconds
✅ Smooth fade to main app
✅ No menu visible during splash
✅ Jellyfin loads in background
✅ Error state shows if connection fails
✅ Timing feels premium (not rushed)
✅ Animation is smooth (60fps)
```

## Summary

**Launch Sequence:**
1. Black screen with MediaMio icon (animated in)
2. Custom startup sound plays
3. Jellyfin loads in background (hidden)
4. Minimum 2-second display for premium feel
5. Smooth fade to main app

**Result:** Premium Netflix-like launch that sets the tone for the entire app! 🎬✨

**Key Files to Add:**
- SplashScreenView.swift
- AudioManager.swift
- startup-sound.mp3 (your custom sound)
- AppState.swift (if not already exists)
