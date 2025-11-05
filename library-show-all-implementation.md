# Library Tab & Show All Views - Complete Implementation Guide

## UX Recommendations

### Where "Show All" Buttons Should Lead

**Movies "Show All" →** Movies Library View
- Grid layout of all movies
- Filters: Genre, Year, Rating, Sort by (A-Z, Recently Added, Rating, etc.)
- Search within movies

**TV Shows "Show All" →** TV Shows Library View
- Grid layout of all TV shows
- Filters: Genre, Status, Network, Sort by
- Search within TV shows

### Library Tab Structure

**Library** (Main Tab)
├── **Movies** (Submenu/Tab)
│   ├── Grid of all movies
│   ├── Filter sidebar: Genre, Year, Rating, Sort
│   └── Search bar
│
└── **TV Shows** (Submenu/Tab)
    ├── Grid of all TV shows
    ├── Filter sidebar: Genre, Status, Network, Sort
    └── Search bar

## Navigation Flow

```
Home Tab
  ↓
User clicks "Show All" on Movies row
  ↓
Navigate to Movies Library View
  - Shows all movies in grid
  - Can filter/sort
  - Can search
  - Can navigate back to Home

OR

Library Tab
  ↓
Shows Movies/TV Shows submenu
  ↓
Select "Movies"
  ↓
Shows Movies Library View (same as Show All)
```

## Complete Implementation

### 1. Library Tab with Submenu

```swift
import SwiftUI

struct LibraryView: View {
    @State private var selectedCategory: LibraryCategory = .movies
    
    enum LibraryCategory: String, CaseIterable {
        case movies = "Movies"
        case tvShows = "TV Shows"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category tabs
                CategorySelector(selected: $selectedCategory)
                
                // Content based on selection
                switch selectedCategory {
                case .movies:
                    MoviesLibraryView()
                case .tvShows:
                    TVShowsLibraryView()
                }
            }
            .navigationTitle("Library")
        }
    }
}

struct CategorySelector: View {
    @Binding var selected: LibraryView.LibraryCategory
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 40) {
            ForEach(LibraryView.LibraryCategory.allCases, id: \.self) { category in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selected = category
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(category.rawValue)
                            .font(.title3)
                            .fontWeight(selected == category ? .bold : .regular)
                            .foregroundColor(selected == category ? .white : .secondary)
                        
                        if selected == category {
                            Rectangle()
                                .fill(Color(hex: "667eea"))
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "underline", in: animation)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 20)
        .background(Color.black.opacity(0.3))
    }
}
```

### 2. Movies Library View

```swift
import SwiftUI

struct MoviesLibraryView: View {
    @StateObject private var viewModel = MoviesLibraryViewModel()
    @State private var showFilters = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content area
            VStack(spacing: 0) {
                // Toolbar with filters and sort
                LibraryToolbar(
                    activeFilters: viewModel.activeFiltersCount,
                    sortOption: $viewModel.sortOption,
                    onFilterTap: { showFilters.toggle() },
                    onSearchTap: { /* Show search */ }
                )
                
                // Movies grid
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 30) {
                        ForEach(viewModel.movies) { movie in
                            NavigationLink(destination: DetailView(item: movie)) {
                                ContentCard(item: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 20)
                }
            }
            
            // Filter sidebar (slide in from right)
            if showFilters {
                MovieFilterSidebar(
                    filters: $viewModel.filters,
                    onClose: { showFilters = false }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showFilters)
        .onAppear {
            viewModel.loadMovies()
        }
    }
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 250, maximum: 350), spacing: 30)
        ]
    }
}

struct LibraryToolbar: View {
    let activeFilters: Int
    @Binding var sortOption: SortOption
    let onFilterTap: () -> Void
    let onSearchTap: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Filter button
            Button {
                onFilterTap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                    Text("Filters")
                    if activeFilters > 0 {
                        Text("(\(activeFilters))")
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(activeFilters > 0 ? Color(hex: "667eea").opacity(0.3) : Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // Sort picker
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.title3)
                    Text("Sort: \(sortOption.rawValue)")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // View toggle (grid/list)
            HStack(spacing: 4) {
                Button {
                    // Grid view
                } label: {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button {
                    // List view
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Search button
            Button {
                onSearchTap()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.3))
    }
}

enum SortOption: String, CaseIterable {
    case recentlyAdded = "Recently Added"
    case titleAZ = "Title (A-Z)"
    case titleZA = "Title (Z-A)"
    case releaseDate = "Release Date"
    case rating = "Rating"
    case runtime = "Runtime"
}
```

### 3. Filter Sidebar

```swift
struct MovieFilterSidebar: View {
    @Binding var filters: MovieFilters
    let onClose: () -> Void
    @FocusState private var focusedFilter: FilterSection?
    
    enum FilterSection {
        case genre, year, rating, close
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Filters")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .focused($focusedFilter, equals: .close)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Genre filter
                    FilterSection(title: "Genre") {
                        FlowLayout(spacing: 12) {
                            ForEach(Genre.allCases, id: \.self) { genre in
                                GenreChip(
                                    genre: genre,
                                    isSelected: filters.selectedGenres.contains(genre)
                                ) {
                                    toggleGenre(genre)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Year filter
                    FilterSection(title: "Year") {
                        YearRangePicker(
                            startYear: $filters.startYear,
                            endYear: $filters.endYear
                        )
                    }
                    
                    Divider()
                    
                    // Rating filter
                    FilterSection(title: "Minimum Rating") {
                        RatingPicker(rating: $filters.minimumRating)
                    }
                    
                    Divider()
                    
                    // Watched status
                    FilterSection(title: "Status") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Show Watched", isOn: $filters.showWatched)
                            Toggle("Show Unwatched", isOn: $filters.showUnwatched)
                        }
                    }
                }
                .padding()
            }
            
            // Footer with clear/apply
            HStack(spacing: 16) {
                Button("Clear All") {
                    filters.clear()
                }
                .buttonStyle(.bordered)
                
                Button("Apply") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "667eea"))
            }
            .padding()
        }
        .frame(width: 400)
        .background(Color.black.opacity(0.95))
    }
    
    private func toggleGenre(_ genre: Genre) {
        if filters.selectedGenres.contains(genre) {
            filters.selectedGenres.remove(genre)
        } else {
            filters.selectedGenres.insert(genre)
        }
    }
}

struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            content
        }
    }
}

struct GenreChip: View {
    let genre: Genre
    let isSelected: Bool
    let action: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: action) {
            Text(genre.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(backgroundColor)
                .foregroundColor(textColor)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(borderColor, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($isFocused)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color(hex: "667eea")
        } else if isFocused {
            return Color(hex: "667eea").opacity(0.3)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        isSelected || isFocused ? .white : .secondary
    }
    
    private var borderColor: Color {
        isSelected ? Color.clear : (isFocused ? Color(hex: "667eea") : Color.clear)
    }
}
```

### 4. View Models

```swift
@MainActor
class MoviesLibraryViewModel: ObservableObject {
    @Published var movies: [MediaItem] = []
    @Published var filters = MovieFilters()
    @Published var sortOption: SortOption = .recentlyAdded
    @Published var isLoading = false
    
    private let jellyfinAPI: JellyfinAPIClient
    
    init(jellyfinAPI: JellyfinAPIClient = .shared) {
        self.jellyfinAPI = jellyfinAPI
    }
    
    var activeFiltersCount: Int {
        var count = 0
        if !filters.selectedGenres.isEmpty { count += filters.selectedGenres.count }
        if filters.startYear != nil || filters.endYear != nil { count += 1 }
        if filters.minimumRating > 0 { count += 1 }
        if !filters.showWatched || !filters.showUnwatched { count += 1 }
        return count
    }
    
    func loadMovies() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                movies = try await jellyfinAPI.fetchMovies(
                    filters: filters,
                    sortBy: sortOption
                )
            } catch {
                print("❌ Failed to load movies: \(error)")
            }
        }
    }
}

struct MovieFilters {
    var selectedGenres: Set<Genre> = []
    var startYear: Int?
    var endYear: Int?
    var minimumRating: Double = 0
    var showWatched = true
    var showUnwatched = true
    
    mutating func clear() {
        selectedGenres.removeAll()
        startYear = nil
        endYear = nil
        minimumRating = 0
        showWatched = true
        showUnwatched = true
    }
    
    func toJellyfinParams() -> [String: String] {
        var params: [String: String] = [:]
        
        if !selectedGenres.isEmpty {
            params["Genres"] = selectedGenres.map { $0.rawValue }.joined(separator: ",")
        }
        
        if let start = startYear {
            params["MinPremiereDate"] = "\(start)-01-01"
        }
        
        if let end = endYear {
            params["MaxPremiereDate"] = "\(end)-12-31"
        }
        
        if minimumRating > 0 {
            params["MinCommunityRating"] = String(minimumRating)
        }
        
        return params
    }
}

enum Genre: String, CaseIterable {
    case action = "Action"
    case comedy = "Comedy"
    case drama = "Drama"
    case horror = "Horror"
    case sciFi = "Sci-Fi"
    case thriller = "Thriller"
    case romance = "Romance"
    case documentary = "Documentary"
    case animation = "Animation"
    case fantasy = "Fantasy"
    case crime = "Crime"
    case adventure = "Adventure"
}
```

### 5. TV Shows Library (Similar Structure)

```swift
struct TVShowsLibraryView: View {
    @StateObject private var viewModel = TVShowsLibraryViewModel()
    @State private var showFilters = false
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                LibraryToolbar(
                    activeFilters: viewModel.activeFiltersCount,
                    sortOption: $viewModel.sortOption,
                    onFilterTap: { showFilters.toggle() },
                    onSearchTap: { }
                )
                
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 30) {
                        ForEach(viewModel.shows) { show in
                            NavigationLink(destination: DetailView(item: show)) {
                                ContentCard(item: show)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 20)
                }
            }
            
            if showFilters {
                TVShowFilterSidebar(
                    filters: $viewModel.filters,
                    onClose: { showFilters = false }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showFilters)
        .onAppear {
            viewModel.loadShows()
        }
    }
    
    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 250, maximum: 350), spacing: 30)]
    }
}

struct TVShowFilterSidebar: View {
    @Binding var filters: TVShowFilters
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Similar to MovieFilterSidebar but with TV-specific filters
            HStack {
                Text("Filters")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Genre
                    FilterSection(title: "Genre") {
                        FlowLayout(spacing: 12) {
                            ForEach(Genre.allCases, id: \.self) { genre in
                                GenreChip(
                                    genre: genre,
                                    isSelected: filters.selectedGenres.contains(genre)
                                ) {
                                    toggleGenre(genre)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Status (Continuing/Ended)
                    FilterSection(title: "Status") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Continuing", isOn: $filters.showContinuing)
                            Toggle("Ended", isOn: $filters.showEnded)
                        }
                    }
                    
                    Divider()
                    
                    // Network
                    FilterSection(title: "Network") {
                        // List of networks
                        ForEach(filters.availableNetworks, id: \.self) { network in
                            Toggle(network, isOn: binding(for: network))
                        }
                    }
                }
                .padding()
            }
            
            HStack(spacing: 16) {
                Button("Clear All") { filters.clear() }
                    .buttonStyle(.bordered)
                Button("Apply") { onClose() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "667eea"))
            }
            .padding()
        }
        .frame(width: 400)
        .background(Color.black.opacity(0.95))
    }
    
    private func toggleGenre(_ genre: Genre) {
        if filters.selectedGenres.contains(genre) {
            filters.selectedGenres.remove(genre)
        } else {
            filters.selectedGenres.insert(genre)
        }
    }
    
    private func binding(for network: String) -> Binding<Bool> {
        Binding(
            get: { filters.selectedNetworks.contains(network) },
            set: { isOn in
                if isOn {
                    filters.selectedNetworks.insert(network)
                } else {
                    filters.selectedNetworks.remove(network)
                }
            }
        )
    }
}

struct TVShowFilters {
    var selectedGenres: Set<Genre> = []
    var selectedNetworks: Set<String> = []
    var showContinuing = true
    var showEnded = true
    var minimumRating: Double = 0
    
    let availableNetworks = ["Netflix", "HBO", "ABC", "CBS", "NBC", "FOX", "AMC", "FX"]
    
    mutating func clear() {
        selectedGenres.removeAll()
        selectedNetworks.removeAll()
        showContinuing = true
        showEnded = true
        minimumRating = 0
    }
}
```

### 6. Show All Button Integration

```swift
struct MoviesRow: View {
    let movies: [MediaItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Movies")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Show All button
                NavigationLink(destination: MoviesLibraryView()) {
                    HStack(spacing: 8) {
                        Text("Show All")
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundColor(Color(hex: "667eea"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 60)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 30) {
                    ForEach(movies) { movie in
                        NavigationLink(destination: DetailView(item: movie)) {
                            ContentCard(item: movie)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 60)
            }
        }
    }
}
```

### 7. Jellyfin API Integration

```swift
extension JellyfinAPIClient {
    func fetchMovies(filters: MovieFilters, sortBy: SortOption) async throws -> [MediaItem] {
        var params = filters.toJellyfinParams()
        params["IncludeItemTypes"] = "Movie"
        params["Recursive"] = "true"
        params["Fields"] = "PrimaryImageAspectRatio,BasicSyncInfo,MediaSources"
        
        // Add sort
        switch sortBy {
        case .recentlyAdded:
            params["SortBy"] = "DateCreated"
            params["SortOrder"] = "Descending"
        case .titleAZ:
            params["SortBy"] = "SortName"
            params["SortOrder"] = "Ascending"
        case .titleZA:
            params["SortBy"] = "SortName"
            params["SortOrder"] = "Descending"
        case .releaseDate:
            params["SortBy"] = "PremiereDate"
            params["SortOrder"] = "Descending"
        case .rating:
            params["SortBy"] = "CommunityRating"
            params["SortOrder"] = "Descending"
        case .runtime:
            params["SortBy"] = "Runtime"
            params["SortOrder"] = "Descending"
        }
        
        let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        let url = "\(serverURL)/Users/\(userId)/Items?\(queryString)"
        
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("MediaBrowser Token=\"\(apiToken)\"", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(JellyfinItemsResponse.self, from: data)
        
        return response.items
    }
}
```

## Claude Code Prompt

```
Implement Library tab with Movies/TV Shows submenu and Show All functionality.

Create complete browsing experience with filtering and sorting:

1. LIBRARY TAB STRUCTURE
   - Add submenu/tabs for Movies and TV Shows
   - Use CategorySelector with animated underline
   - Switch between MoviesLibraryView and TVShowsLibraryView

2. MOVIES LIBRARY VIEW
   - Grid layout (adaptive, 250-350pt)
   - LibraryToolbar with filter button, sort picker, view toggle, search
   - Show active filter count badge
   - Clicking filter button slides in MovieFilterSidebar from right

3. MOVIE FILTER SIDEBAR (400pt wide)
   - Genre chips (selectable, flow layout)
   - Year range picker
   - Minimum rating slider
   - Watched/Unwatched toggles
   - Clear All and Apply buttons
   - Slide in/out animation from right edge

4. TV SHOWS LIBRARY VIEW
   - Same structure as Movies
   - TV-specific filters: Status (Continuing/Ended), Network
   - Use TVShowFilterSidebar

5. SHOW ALL BUTTONS
   - Add to Movies and TV Shows rows on Home
   - NavigationLink to MoviesLibraryView / TVShowsLibraryView
   - Same view as Library tab content

6. SORT OPTIONS
   - Recently Added (default)
   - Title A-Z / Z-A
   - Release Date
   - Rating
   - Runtime

7. JELLYFIN API INTEGRATION
   - fetchMovies(filters:sortBy:) with query params
   - Convert filters to Jellyfin params
   - Handle Genre, Year, Rating filtering
   - Apply sort order to API call

8. VIEW MODELS
   - MoviesLibraryViewModel with filters, sort, loading
   - TVShowsLibraryViewModel (similar)
   - Compute activeFiltersCount for badge
   - loadMovies() / loadShows() on appear

KEY UX:
- Library tab is main browsing interface
- Show All buttons navigate to same views
- Filter sidebar slides in from right
- Selected filters show count badge
- Smooth animations (spring)
- Grid adapts to screen size

TESTING:
- Library → Movies → Grid shows all movies
- Click Filter → Sidebar slides in
- Select genres → Apply → Grid filters
- Change sort → Grid re-sorts
- Show All button → Navigates to same view
- Test TV Shows section similarly

Read library-show-all-implementation.md for complete code.
```

## Summary

**Show All Buttons Lead To:**
- Movies → Movies Library View (with filters/sort)
- TV Shows → TV Shows Library View (with filters/sort)

**Library Tab Contains:**
- Movies submenu (grid + filters)
- TV Shows submenu (grid + filters)

**Filtering Options:**
- **Movies:** Genre, Year, Rating, Watched Status
- **TV Shows:** Genre, Status, Network, Rating

**Result:** Complete browsing experience like Netflix! 🎬
