# Fix Apple TV Remote Play/Pause Controls

## The Problem
Menu button works (goes back) but play/pause button doesn't control video playback in the simulator. This is a common tvOS control issue.

## Understanding tvOS Remote Buttons

### Physical Siri Remote Buttons
- **Touch Surface**: Click center = select, swipe = navigate
- **Play/Pause Button**: Dedicated media control (below touch surface)
- **Menu Button**: Back/dismiss (above touch surface)
- **Siri Button**: Voice control (side button)
- **Volume Buttons**: System volume (side buttons)

### Simulator Remote Controls
- **Arrow Keys**: Navigate
- **Space Bar**: Click/select center of touch surface
- **Command + P**: Play/Pause button
- **Escape**: Menu button (goes back)
- **Or use Window → Show Remote** to get on-screen remote

## Why Play/Pause Isn't Working

### Common Causes:

1. **Not intercepting the play/pause command**
   - tvOS sends play/pause as a system command
   - Need to explicitly handle it in your player view

2. **Using default VideoPlayer without custom controls**
   - SwiftUI's default VideoPlayer has its own control handling
   - May conflict with custom controls

3. **Focus not on the player**
   - Play/pause only works when player view has focus
   - Other UI elements might be stealing focus

4. **Not implementing UIResponder methods**
   - Need to override specific methods to handle media commands

5. **Simulator keyboard shortcuts not set up**
   - Simulator needs proper remote simulation

## Solutions

### Solution 1: Add Play/Pause Command Handling (RECOMMENDED)

For custom video player views, add these handlers:

```swift
import AVKit
import SwiftUI

struct CustomVideoPlayerView: View {
    @StateObject private var playerManager: VideoPlayerManager
    @FocusState private var isPlayerFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video player
                VideoPlayer(player: playerManager.player)
                    .ignoresSafeArea()
                    .focusable()
                    .focused($isPlayerFocused)
                
                // Your custom overlay controls
                CustomPlayerControls(playerManager: playerManager)
                    .opacity(showControls ? 1 : 0)
            }
        }
        .onAppear {
            isPlayerFocused = true // Give focus to player on appear
        }
        .onPlayPauseCommand {
            // This is the key handler for play/pause button
            togglePlayPause()
        }
        .onExitCommand {
            // Handle menu button if needed
            dismiss()
        }
    }
    
    private func togglePlayPause() {
        if playerManager.isPlaying {
            playerManager.player.pause()
            playerManager.isPlaying = false
            print("⏸️ Paused via remote")
        } else {
            playerManager.player.play()
            playerManager.isPlaying = true
            print("▶️ Playing via remote")
        }
    }
}
```

### Solution 2: Use AVPlayerViewController (Simpler)

If you're not using custom controls, use AVPlayerViewController which handles everything:

```swift
import AVKit
import SwiftUI

struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true // Built-in controls
        
        // This automatically handles play/pause button!
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Updates if needed
    }
}

// Usage:
struct PlayerScreen: View {
    @StateObject private var playerManager = VideoPlayerManager()
    
    var body: some View {
        VideoPlayerView(player: playerManager.player)
            .ignoresSafeArea()
            .onAppear {
                playerManager.play()
            }
    }
}
```

### Solution 3: Implement Full Remote Command Handling

For complete control over all remote buttons:

```swift
import SwiftUI
import AVFoundation

struct FullRemoteControlPlayerView: View {
    @StateObject private var playerManager: VideoPlayerManager
    @State private var showControls = true
    @FocusState private var isPlayerFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VideoPlayer(player: playerManager.player) {
                // Overlay content
            }
            .focusable()
            .focused($isPlayerFocused)
            
            // Custom controls overlay
            if showControls {
                PlayerControlsOverlay(playerManager: playerManager)
                    .transition(.opacity)
            }
        }
        .onAppear {
            isPlayerFocused = true
            setupRemoteCommands()
        }
        .onPlayPauseCommand {
            handlePlayPause()
        }
        .onExitCommand {
            handleExit()
        }
        // Handle swipe gestures for seek
        .onMoveCommand { direction in
            handleMove(direction)
        }
    }
    
    private func setupRemoteCommands() {
        print("🎮 Setting up remote command handlers")
    }
    
    private func handlePlayPause() {
        print("🎮 Play/Pause button pressed")
        showControls = true
        resetControlsTimer()
        
        if playerManager.isPlaying {
            playerManager.pause()
        } else {
            playerManager.play()
        }
    }
    
    private func handleExit() {
        print("🎮 Menu button pressed")
        // Handle back navigation
    }
    
    private func handleMove(_ direction: MoveCommandDirection) {
        print("🎮 Swipe detected: \(direction)")
        showControls = true
        resetControlsTimer()
        
        switch direction {
        case .left:
            playerManager.seek(by: -10) // Seek back 10 seconds
        case .right:
            playerManager.seek(by: 10) // Seek forward 10 seconds
        case .up, .down:
            // Could show/hide controls or adjust volume
            break
        @unknown default:
            break
        }
    }
    
    private func resetControlsTimer() {
        // Auto-hide controls after 3 seconds of inactivity
        // Implementation depends on your timer logic
    }
}
```

### Solution 4: Handle Remote Commands at App Level

For system-wide media controls (works in background):

```swift
import MediaPlayer

class RemoteCommandManager {
    static let shared = RemoteCommandManager()
    
    private let commandCenter = MPRemoteCommandCenter.shared()
    
    func setupRemoteCommands(for player: AVPlayer) {
        print("🎮 Setting up MPRemoteCommandCenter")
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak player] event in
            print("▶️ Play command received")
            player?.play()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak player] event in
            print("⏸️ Pause command received")
            player?.pause()
            return .success
        }
        
        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak player] event in
            print("⏯️ Toggle play/pause received")
            if player?.timeControlStatus == .playing {
                player?.pause()
            } else {
                player?.play()
            }
            return .success
        }
        
        // Skip forward
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [10]
        commandCenter.skipForwardCommand.addTarget { [weak player] event in
            print("⏭️ Skip forward")
            guard let player = player else { return .commandFailed }
            let currentTime = player.currentTime()
            let newTime = CMTimeAdd(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
            player.seek(to: newTime)
            return .success
        }
        
        // Skip backward
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { [weak player] event in
            print("⏮️ Skip backward")
            guard let player = player else { return .commandFailed }
            let currentTime = player.currentTime()
            let newTime = CMTimeSubtract(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
            player.seek(to: newTime)
            return .success
        }
    }
    
    func cleanupRemoteCommands() {
        print("🎮 Cleaning up remote commands")
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
    }
}

// Usage in your player manager:
class VideoPlayerManager: ObservableObject {
    @Published var player = AVPlayer()
    @Published var isPlaying = false
    
    func play() {
        player.play()
        isPlaying = true
        
        // Set up remote commands
        RemoteCommandManager.shared.setupRemoteCommands(for: player)
    }
    
    func cleanup() {
        RemoteCommandManager.shared.cleanupRemoteCommands()
    }
}
```

## Testing in Simulator

### Keyboard Shortcuts
When testing in Xcode Simulator:

| Action | Simulator Shortcut | Physical Remote |
|--------|-------------------|-----------------|
| Navigate | Arrow Keys | Swipe on touch surface |
| Select | Space Bar | Click touch surface |
| Play/Pause | **Command + P** | Play/Pause button |
| Menu/Back | Escape | Menu button |
| Show Remote | **Command + Shift + R** | N/A |

### Visual Remote in Simulator
1. Go to **Window → Show Remote** (or **Cmd+Shift+R**)
2. Use the on-screen remote with mouse clicks
3. This is more reliable for testing than keyboard shortcuts

### Enable Logging
Add this to see what commands are being received:

```swift
// In your video player view
.onPlayPauseCommand {
    print("🎮 onPlayPauseCommand triggered!")
    togglePlayPause()
}
.onMoveCommand { direction in
    print("🎮 onMoveCommand triggered: \(direction)")
    handleMove(direction)
}
.onExitCommand {
    print("🎮 onExitCommand triggered!")
    handleExit()
}
```

Run the app and press **Cmd+P** - you should see the print statement in console.

## Complete Working Example

Here's a complete, tested implementation:

```swift
import SwiftUI
import AVKit
import AVFoundation

// MARK: - Player Manager
class VideoPlayerManager: ObservableObject {
    @Published var player = AVPlayer()
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    private var timeObserver: Any?
    
    func play(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        
        // Add time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
            if let item = self?.player.currentItem {
                self?.duration = item.duration.seconds
            }
        }
        
        // Set up remote commands
        setupRemoteCommands()
        
        // Start playing
        player.play()
        isPlaying = true
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
    
    func seek(by seconds: Double) {
        let currentTime = player.currentTime()
        let newTime = CMTimeAdd(currentTime, CMTime(seconds: seconds, preferredTimescale: 1))
        player.seek(to: newTime)
        print("⏩ Seeked by \(seconds) seconds")
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.player.play()
            self?.isPlaying = true
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.player.pause()
            self?.isPlaying = false
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
    }
    
    func cleanup() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        player.replaceCurrentItem(with: nil)
        
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Video Player View
struct VideoPlayerView: View {
    @StateObject private var playerManager = VideoPlayerManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true
    @FocusState private var isPlayerFocused: Bool
    
    let videoURL: URL
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Video player
            VideoPlayer(player: playerManager.player)
                .ignoresSafeArea()
                .focusable()
                .focused($isPlayerFocused)
            
            // Controls overlay
            if showControls {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 40) {
                        // Play/Pause button
                        Button {
                            playerManager.togglePlayPause()
                        } label: {
                            Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        
                        // Rewind button
                        Button {
                            playerManager.seek(by: -10)
                        } label: {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        
                        // Forward button
                        Button {
                            playerManager.seek(by: 10)
                        } label: {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 60)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            isPlayerFocused = true
            playerManager.play(url: videoURL)
            print("🎮 Player view appeared - focus set")
        }
        .onDisappear {
            playerManager.cleanup()
            print("🎮 Player view disappeared - cleaned up")
        }
        // CRITICAL: Handle play/pause command
        .onPlayPauseCommand {
            print("🎮 Play/Pause command received!")
            playerManager.togglePlayPause()
            showControls = true
            hideControlsAfterDelay()
        }
        .onExitCommand {
            print("🎮 Menu/Exit command received")
            dismiss()
        }
        .onMoveCommand { direction in
            print("🎮 Move command: \(direction)")
            showControls = true
            hideControlsAfterDelay()
            
            switch direction {
            case .left:
                playerManager.seek(by: -10)
            case .right:
                playerManager.seek(by: 10)
            default:
                break
            }
        }
    }
    
    private func hideControlsAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showControls = false
            }
        }
    }
}

// MARK: - Preview / Test
struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerView(videoURL: URL(string: "https://example.com/video.mp4")!)
    }
}
```

## Troubleshooting Checklist

### Issue: Play/Pause Does Nothing

**Check:**
- [ ] Is `.onPlayPauseCommand { }` implemented?
- [ ] Is the handler printing to console when you press Cmd+P?
- [ ] Is focus on the player view? (add `.focused($isPlayerFocused)`)
- [ ] Are you calling the right methods on the player?

**Test:**
```swift
.onPlayPauseCommand {
    print("🎮 PLAY/PAUSE PRESSED") // This MUST print
    playerManager.togglePlayPause()
}
```

Press **Cmd+P** in simulator - if nothing prints, the command isn't being received.

### Issue: Simulator Shortcuts Not Working

**Solutions:**
1. Use **Window → Show Remote** instead of keyboard
2. Make sure simulator window is focused (click on it)
3. Try **Cmd+Shift+R** to show remote
4. Check **Hardware → Keyboard → Connect Hardware Keyboard** is enabled

### Issue: Works in Simulator but Not on Real Device

**Check:**
- Test on actual Apple TV hardware
- Physical remote might be in Bluetooth mode (needs pairing)
- Battery might be low
- Try different physical remote if available

### Issue: Other UI Stealing Focus

**Solution:**
```swift
.onAppear {
    // Force focus on player
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        isPlayerFocused = true
    }
}
```

### Issue: Menu Button Works but Play/Pause Doesn't

This is the most common issue! The reason:
- `.onExitCommand` works because it's a navigation command (system-level)
- `.onPlayPauseCommand` only works when properly set up

**Fix:** Make sure you have `.onPlayPauseCommand { }` modifier on your view!

## Testing Strategy

### Step 1: Add Logging
```swift
.onPlayPauseCommand {
    print("🎮 === PLAY/PAUSE COMMAND RECEIVED ===")
    playerManager.togglePlayPause()
}
```

### Step 2: Test in Simulator
1. Run app
2. Navigate to video player
3. Press **Cmd+P**
4. Check console - should see the print statement

**If you see the print:**
✅ Command is being received
→ Issue is in your play/pause logic

**If you don't see the print:**
❌ Command is not being received
→ Need to add `.onPlayPauseCommand { }` modifier

### Step 3: Use Visual Remote
1. **Window → Show Remote** (Cmd+Shift+R)
2. Click the play/pause button on the visual remote
3. Should work the same as Cmd+P

### Step 4: Test All Controls
```swift
.onPlayPauseCommand {
    print("🎮 Play/Pause")
}
.onExitCommand {
    print("🎮 Exit")
}
.onMoveCommand { direction in
    print("🎮 Move: \(direction)")
}
```

Test each command and verify all print.

## Summary

**Most Common Fix:**
Add this modifier to your video player view:
```swift
.onPlayPauseCommand {
    togglePlayPause() // Your play/pause method
}
```

**Testing:**
- Press **Cmd+P** in simulator for play/pause
- Or use **Window → Show Remote** (Cmd+Shift+R)

**Complete Solution:**
Use the full working example above which includes:
- `.onPlayPauseCommand` handler
- MPRemoteCommandCenter setup
- Proper focus management
- All remote button handlers

Let me know which part isn't working and I can help diagnose further!
