//
//  ImageCache.swift
//  MediaMio
//
//  Created by Claude Code
//

import UIKit
import Foundation

/// Two-tier image cache for tvOS
/// - Memory cache using NSCache for fast access
/// - Disk cache using FileManager for persistence
class ImageCache {
    static let shared = ImageCache()

    // MARK: - Properties

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    // Cache limits (conservative for tvOS)
    private let maxMemoryCacheSize = 100 * 1024 * 1024  // 100 MB in memory
    private let maxDiskCacheSize = 500 * 1024 * 1024    // 500 MB on disk
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60  // 7 days

    // MARK: - Initialization

    private init() {
        // Set memory cache limits
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 200  // Max 200 images in memory

        // Create cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache", isDirectory: true)

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Clean old cache on init
        Task {
            await cleanOldCache()
        }
    }

    // MARK: - Cache Key Generation

    private func cacheKey(for url: String) -> String {
        return url.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? url
    }

    private func diskCacheURL(for key: String) -> URL {
        let filename = key.replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appendingPathComponent(filename)
    }

    // MARK: - Retrieve Image

    /// Get image from cache (memory first, then disk)
    func image(for url: String) -> UIImage? {
        let key = cacheKey(for: url)

        // Try memory cache first
        if let image = memoryCache.object(forKey: key as NSString) {
            print("📸 Memory cache hit for: \(url)")
            return image
        }

        // Try disk cache
        let fileURL = diskCacheURL(for: key)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            print("💾 Disk cache hit for: \(url)")

            // Store in memory cache for faster future access
            let cost = estimatedMemorySize(for: image)
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)

            return image
        }

        print("❌ Cache miss for: \(url)")
        return nil
    }

    // MARK: - Store Image

    /// Store image in both memory and disk cache
    func store(_ image: UIImage, for url: String) {
        let key = cacheKey(for: url)

        // Store in memory cache
        let cost = estimatedMemorySize(for: image)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
        print("💾 Stored in memory cache: \(url)")

        // Store in disk cache (async)
        Task {
            await storeToDisk(image, for: key)
        }
    }

    private func storeToDisk(_ image: UIImage, for key: String) async {
        let fileURL = diskCacheURL(for: key)

        // Convert to JPEG for better compression
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        do {
            try data.write(to: fileURL)
            print("💿 Stored in disk cache: \(key)")

            // Check disk cache size and clean if needed
            await checkDiskCacheSize()
        } catch {
            print("❌ Failed to write to disk cache: \(error)")
        }
    }

    // MARK: - Remove Image

    /// Remove image from both caches
    func removeImage(for url: String) {
        let key = cacheKey(for: url)

        // Remove from memory
        memoryCache.removeObject(forKey: key as NSString)

        // Remove from disk
        let fileURL = diskCacheURL(for: key)
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Clear Cache

    /// Clear all cached images
    func clearAll() {
        // Clear memory cache
        memoryCache.removeAllObjects()
        print("🗑️ Cleared memory cache")

        // Clear disk cache
        Task {
            await clearDiskCache()
        }
    }

    private func clearDiskCache() async {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try? fileManager.removeItem(at: fileURL)
            }
            print("🗑️ Cleared disk cache")
        } catch {
            print("❌ Failed to clear disk cache: \(error)")
        }
    }

    // MARK: - Cache Management

    /// Check disk cache size and remove oldest files if needed
    private func checkDiskCacheSize() async {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: .skipsHiddenFiles
            )

            // Calculate total size
            var totalSize: Int64 = 0
            var files: [(url: URL, size: Int64, date: Date)] = []

            for fileURL in contents {
                let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])

                if let size = attributes.fileSize,
                   let date = attributes.contentModificationDate {
                    totalSize += Int64(size)
                    files.append((url: fileURL, size: Int64(size), date: date))
                }
            }

            print("💿 Disk cache size: \(totalSize / 1024 / 1024) MB")

            // If over limit, remove oldest files
            if totalSize > maxDiskCacheSize {
                // Sort by date (oldest first)
                files.sort { $0.date < $1.date }

                var removedSize: Int64 = 0
                let targetRemovalSize = totalSize - (maxDiskCacheSize * 8 / 10)  // Remove down to 80% of max

                for file in files {
                    if removedSize >= targetRemovalSize {
                        break
                    }

                    try? fileManager.removeItem(at: file.url)
                    removedSize += file.size
                }

                print("🗑️ Removed \(removedSize / 1024 / 1024) MB from disk cache")
            }
        } catch {
            print("❌ Failed to check disk cache size: \(error)")
        }
    }

    /// Clean cache files older than maxCacheAge
    private func cleanOldCache() async {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )

            let now = Date()
            var removedCount = 0

            for fileURL in contents {
                if let attributes = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modificationDate = attributes.contentModificationDate {

                    let age = now.timeIntervalSince(modificationDate)
                    if age > maxCacheAge {
                        try? fileManager.removeItem(at: fileURL)
                        removedCount += 1
                    }
                }
            }

            if removedCount > 0 {
                print("🗑️ Removed \(removedCount) old cache files")
            }
        } catch {
            print("❌ Failed to clean old cache: \(error)")
        }
    }

    // MARK: - Helpers

    /// Estimate memory size of an image
    private func estimatedMemorySize(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else {
            return 0
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let width = cgImage.width
        let height = cgImage.height

        return width * height * bytesPerPixel
    }

    /// Get cache statistics
    func getCacheStats() async -> (memoryCacheCount: Int, diskCacheSize: Int64, diskCacheCount: Int) {
        var diskSize: Int64 = 0
        var diskCount = 0

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )

            diskCount = contents.count

            for fileURL in contents {
                if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let size = attributes.fileSize {
                    diskSize += Int64(size)
                }
            }
        } catch {
            print("❌ Failed to get cache stats: \(error)")
        }

        // NSCache doesn't expose count, estimate based on cost
        let memoryCount = 0  // Would need custom tracking for exact count

        return (memoryCount, diskSize, diskCount)
    }
}
