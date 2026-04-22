//
//  ImageCache.swift
//  MediaMio
//
//  Two-tier image cache for tvOS.
//  Memory cache (NSCache) for hot access. Disk cache (FileManager) for persistence.
//  Keys are SHA256 hashes so filenames stay short and filesystem-safe regardless of URL length.
//  Cache is size-aware: the same URL requested at different target pixel sizes
//  produces separate entries so a 200×300 poster decode never aliases a 1920×1080 backdrop.
//

import UIKit
import Foundation
import CryptoKit

class ImageCache: NSObject {
    static let shared = ImageCache()

    // MARK: - Properties

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private let maxMemoryCacheSize = 100 * 1024 * 1024  // 100 MB in memory
    private let maxDiskCacheSize = 500 * 1024 * 1024    // 500 MB on disk
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60  // 7 days

    // MARK: - Initialization

    private override init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache", isDirectory: true)
        super.init()

        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 200

        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Under memory pressure, drop the in-memory tier only (disk survives).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        Task {
            await cleanOldCache()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Cache Key Generation

    /// SHA256-of-(url + optional size) → hex. Fixed-length, filesystem-safe, collision-resistant.
    /// Target size is folded in so the same URL at two different pixel sizes can coexist.
    private func cacheKey(for url: String, targetPixelSize: CGSize?) -> String {
        var composite = url
        if let size = targetPixelSize {
            composite += "|w\(Int(size.width))h\(Int(size.height))"
        }
        let digest = SHA256.hash(data: Data(composite.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func diskCacheURL(for key: String) -> URL {
        return cacheDirectory.appendingPathComponent(key)
    }

    // MARK: - Retrieve Image

    /// Memory first, then disk. `targetPixelSize` must match what was used at store-time.
    func image(for url: String, targetPixelSize: CGSize? = nil) -> UIImage? {
        let key = cacheKey(for: url, targetPixelSize: targetPixelSize)

        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }

        let fileURL = diskCacheURL(for: key)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            let cost = estimatedMemorySize(for: image)
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)
            return image
        }

        return nil
    }

    // MARK: - Store Image

    func store(_ image: UIImage, for url: String, targetPixelSize: CGSize? = nil) {
        let key = cacheKey(for: url, targetPixelSize: targetPixelSize)

        let cost = estimatedMemorySize(for: image)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)

        Task {
            await storeToDisk(image, for: key)
        }
    }

    private func storeToDisk(_ image: UIImage, for key: String) async {
        let fileURL = diskCacheURL(for: key)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        do {
            try data.write(to: fileURL)
            await checkDiskCacheSize()
        } catch {
            print("❌ Failed to write image to disk cache: \(error)")
        }
    }

    // MARK: - Remove Image

    func removeImage(for url: String, targetPixelSize: CGSize? = nil) {
        let key = cacheKey(for: url, targetPixelSize: targetPixelSize)
        memoryCache.removeObject(forKey: key as NSString)
        try? fileManager.removeItem(at: diskCacheURL(for: key))
    }

    // MARK: - Clear Cache

    func clearAll() {
        memoryCache.removeAllObjects()
        Task {
            await clearDiskCache()
        }
    }

    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    @objc private func handleMemoryWarning() {
        print("⚠️ Memory warning — clearing in-memory image cache")
        clearMemoryCache()
    }

    private func clearDiskCache() async {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try? fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("❌ Failed to clear disk cache: \(error)")
        }
    }

    // MARK: - Cache Management

    private func checkDiskCacheSize() async {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: .skipsHiddenFiles
            )

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

            if totalSize > Int64(maxDiskCacheSize) {
                files.sort { $0.date < $1.date }

                var removedSize: Int64 = 0
                let targetRemovalSize = totalSize - (Int64(maxDiskCacheSize) * 8 / 10)

                for file in files {
                    if removedSize >= targetRemovalSize {
                        break
                    }
                    try? fileManager.removeItem(at: file.url)
                    removedSize += file.size
                }

                print("🗑️ Pruned \(removedSize / 1024 / 1024) MB from disk cache")
            }
        } catch {
            print("❌ Failed to check disk cache size: \(error)")
        }
    }

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

    private func estimatedMemorySize(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        return cgImage.width * cgImage.height * bytesPerPixel
    }

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

        return (0, diskSize, diskCount)
    }
}
