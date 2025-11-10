# Claude Code Prompt: Premium Jellyfin Client for Apple TV

## Project Overview
Create a premium, production-ready Jellyfin client for Apple TV (tvOS) that rivals Netflix in smoothness, visual design, and user experience. The app should feel native, fast, and beautiful while providing seamless access to a remote Jellyfin media server.

## Initial Setup Instructions

### Apple Developer Account & Signing
1. **Create the tvOS project in Xcode**:
   - Open Xcode → File → New → Project
   - Select "tvOS" → "App"
   - Use SwiftUI for Interface and Swift for Language
   - Choose a unique Bundle Identifier (e.g., `com.yourname.jellyfintv`)

2. **Configure Code Signing**:
   - Select the project in Xcode's navigator
   - Select the tvOS target
   - Go to "Signing & Capabilities" tab
   - Enable "Automatically manage signing"
   - Select your Apple ID team from the dropdown
   - Xcode will automatically create necessary provisioning profiles

3. **Development Environment**:
   - Use the tvOS Simulator for initial development (no Apple TV hardware required)
   - Select "Apple TV 4K" or similar from the device dropdown
   - Test on actual Apple TV hardware when available for best results

4. **Minimum Requirements**:
   - macOS with Xcode 15+
   - Apple ID (free tier works for simulator testing)
   - Paid Apple Developer account ($99/year) only needed for App Store submission

## Core Objectives
- **Performance**: Buttery smooth 60fps UI, instant responses, pre-loading content
- **Design**: Modern, elegant interface inspired by top streaming apps (Netflix, Apple TV+)
- **Authentication**: Frictionless server connection and login experience
- **Video Playback**: Hardware-accelerated, with subtitle support, quality selection, and resume functionality
- **User Experience**: Intuitive navigation optimized for the Siri Remote

## Technical Stack
- **Language**: Swift
- **UI Framework**: SwiftUI with tvOS optimizations
- **Minimum Target**: tvOS 16.0+
- **Architecture**: MVVM with async/await for clean, maintainable code
- **Networking**: URLSession with Jellyfin API integration
- **Media Playback**: AVKit/AVFoundation
- **Data Persistence**: UserDefaults for settings, Keychain for credentials

## Key Features to Implement

### 1. Server Connection & Authentication
- **Server Discovery**: 
  - Manual server URL entry with validation
  - Auto-discovery on local network (optional)
  - Support for HTTP/HTTPS with custom ports
  
- **Login Flow**:
  - Clean, focused login screen
  - Username/password authentication
  - "Remember me" option with secure Keychain storage
  - Quick user switching support
  - Server connection status indicators

### 2. Home Screen
- **Hero Banner**: 
  - Large, cinematic backdrop for featured content
  - Auto-rotating featured items with smooth transitions
  - Play/Resume buttons with progress indicators
  
- **Content Rows**:
  - "Continue Watching" (with progress bars)
  - "Recently Added"
  - "Movies", "TV Shows", "Collections"
  - Genre-based rows
  - Horizontal scrolling with momentum
  - Smooth focus animations
  
- **Poster Loading**:
  - Progressive image loading
  - High-quality artwork from Jellyfin
  - Intelligent caching strategy
  - Placeholder images during load

### 3. Content Detail Pages
- **Layout**:
  - Large backdrop image with gradient overlay
  - Poster thumbnail
  - Title, year, rating, duration
  - Plot summary
  - Cast & crew information
  - Play/Resume button (primary action)
  - "Add to Favorites" option
  
- **TV Shows**:
  - Season selector
  - Episode list with thumbnails
  - Episode descriptions and air dates
  - Next episode suggestion

### 4. Video Player
- **Playback Features**:
  - Hardware-accelerated video decoding
  - Direct play when formats are supported
  - Transcoding support when necessary
  - Adaptive bitrate streaming
  
- **Controls**:
  - Swipe gestures for seek (10s forward/back)
  - Play/pause with center button
  - Volume control
  - On-screen progress bar
  - Time remaining display
  
- **Subtitle Support**:
  - Multiple subtitle tracks
  - Subtitle selection menu
  - Styling options (size, color, background)
  - Proper synchronization
  
- **Quality Selection**:
  - Auto quality (default)
  - Manual quality override
  - Display current bitrate
  
- **Resume Functionality**:
  - Save playback position
  - Resume prompt on restart
  - "Up Next" suggestions

### 5. Search & Discovery
- **Search Screen**:
  - On-screen keyboard optimized for TV
  - Real-time search results
  - Filter by type (Movies, TV Shows, People)
  - Search history
  
- **Library Browsing**:
  - Filter by genre, year, rating
  - Sort options (Title, Date Added, Release Date)
  - Alphabet quick-jump for large libraries

### 6. Settings
- **Playback Settings**:
  - Default quality preference
  - Auto-play next episode
  - Skip intro/credits (if available)
  - Subtitle preferences
  
- **Account Settings**:
  - User profile switching
  - Server management
  - Sign out option
  
- **App Settings**:
  - Theme selection (if implementing)
  - Cache management
  - About/version info

## Jellyfin API Integration

### Required Endpoints
```
Authentication:
- POST /Users/AuthenticateByName

Content Discovery:
- GET /Users/{userId}/Items/Resume
- GET /Users/{userId}/Items (with filters for various views)
- GET /Items/{itemId}
- GET /Shows/{seriesId}/Episodes

Media Streaming:
- GET /Videos/{itemId}/stream
- GET /Videos/{itemId}/master.m3u8 (HLS)

Images:
- GET /Items/{itemId}/Images/{imageType}

Playback Reporting:
- POST /Sessions/Playing/Progress
- POST /Sessions/Playing/Stopped

Search:
- GET /Users/{userId}/Items (with searchTerm)
```

### API Client Architecture
- Create a dedicated `JellyfinAPIClient` class
- Implement request/response models with Codable
- Handle authentication tokens securely
- Implement retry logic for network failures
- Cache responses where appropriate

## UI/UX Design Principles

### Focus Management
- Smooth, predictable focus transitions
- Clear visual indication of focused element (scale + shadow)
- Smart focus memory when navigating back
- Proper focus order through the interface

### Animations
- Parallax effects on hero banners
- Smooth card scaling on focus (1.0 → 1.1 scale)
- Fade transitions between views
- Loading indicators that feel premium
- Skeleton screens for content loading

### Typography
- Large, readable text optimized for TV viewing distance
- Proper hierarchy (titles, descriptions, metadata)
- System fonts with proper weight variations

### Color Scheme
- Dark theme optimized for TV viewing
- High contrast for readability
- Accent colors for interactive elements
- Proper use of transparency and blurs

### Accessibility
- VoiceOver support
- High contrast mode compatibility
- Proper label descriptions for all interactive elements

## Performance Optimizations

### Image Loading
- Implement progressive JPEG support
- Use thumbnail images for scrolling rows
- Preload images for adjacent items
- Memory-efficient cache with size limits

### Content Prefetching
- Preload content metadata for likely navigation paths
- Prefetch video segments for instant playback
- Smart cache invalidation

### Memory Management
- Release unused assets aggressively
- Monitor memory warnings
- Implement proper cache limits
- Lazy loading for large lists

## Project Structure
```
JellyfinTV/
├── App/
│   ├── JellyfinTVApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── Media/
│   │   ├── MediaItem.swift
│   │   ├── Movie.swift
│   │   ├── TVShow.swift
│   │   └── Episode.swift
│   └── User/
│       ├── User.swift
│       └── ServerInfo.swift
├── Services/
│   ├── JellyfinAPIClient.swift
│   ├── AuthenticationService.swift
│   ├── ImageLoader.swift
│   └── PlaybackReporter.swift
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── DetailViewModel.swift
│   ├── PlayerViewModel.swift
│   └── SearchViewModel.swift
├── Views/
│   ├── Authentication/
│   │   ├── ServerEntryView.swift
│   │   └── LoginView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HeroBannerView.swift
│   │   └── ContentRowView.swift
│   ├── Detail/
│   │   ├── DetailView.swift
│   │   └── EpisodeListView.swift
│   ├── Player/
│   │   └── VideoPlayerView.swift
│   └── Components/
│       ├── PosterCard.swift
│       ├── LoadingView.swift
│       └── FocusableButton.swift
└── Utilities/
    ├── Extensions/
    ├── KeychainHelper.swift
    └── Constants.swift
```

## Development Phases

### Phase 1: Foundation (Start Here)
1. Set up the Xcode tvOS project
2. Implement JellyfinAPIClient with authentication
3. Create server entry and login views
4. Test successful authentication and token storage

### Phase 2: Core UI
1. Build HomeView with mock data
2. Implement ContentRowView with horizontal scrolling
3. Create PosterCard with focus effects
4. Add basic navigation

### Phase 3: Content Loading
1. Integrate real Jellyfin data into HomeView
2. Implement image loading and caching
3. Create DetailView for movies/shows
4. Add metadata display

### Phase 4: Video Playback
1. Implement VideoPlayerView with AVPlayer
2. Add playback controls
3. Implement subtitle support
4. Add resume functionality

### Phase 5: Polish
1. Add search functionality
2. Implement settings screen
3. Optimize performance
4. Add loading states and error handling
5. Test on actual Apple TV hardware

## Testing Checklist
- [ ] Server connection with various URL formats
- [ ] Authentication with valid/invalid credentials
- [ ] Content loading for different library types
- [ ] Image loading and caching
- [ ] Video playback (direct play and transcoding)
- [ ] Subtitle rendering
- [ ] Resume functionality
- [ ] Focus navigation through all screens
- [ ] Memory usage under extended use
- [ ] Network error handling
- [ ] Multiple user profiles

## Success Criteria
- App launches in under 2 seconds
- Content loads and displays within 1 second of navigation
- Video playback starts within 2 seconds
- Smooth 60fps scrolling throughout the app
- Zero crashes during normal usage
- Intuitive enough that users don't need documentation

## Additional Notes
- Follow Apple's Human Interface Guidelines for tvOS
- Test on multiple Apple TV generations if possible
- Consider implementing tvOS-specific features like Top Shelf integration
- Plan for App Store submission (privacy policy, screenshots, description)
- Keep code modular for easy feature additions and maintenance

---

## Getting Started Command
```bash
# Create new tvOS project
# Then ask Claude Code to begin with Phase 1
```

Let's build something amazing! Start with authentication and the core API client, then progressively build up the UI to match that Netflix-level polish.