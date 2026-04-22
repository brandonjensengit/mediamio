//
//  ImageLoader.swift
//  MediaMio
//
//  Async image loader with caching, request deduplication, and ImageIO downsampling.
//  Downsampling uses CGImageSource thumbnail APIs so 4K backdrops never decode at full
//  resolution into GPU memory; callers pass `targetPixelSize` in pixels (not points).
//

import UIKit
import Combine
import ImageIO

@MainActor
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let cache = ImageCache.shared
    private var currentTask: Task<Void, Never>?

    // MARK: - Load Image

    /// Load the image at `urlString`, optionally downsampled to `targetPixelSize` in pixels.
    /// When `targetPixelSize` is nil, the image is decoded at its native resolution.
    func load(from urlString: String?, targetPixelSize: CGSize? = nil) {
        currentTask?.cancel()
        currentTask = nil

        guard let urlString = urlString, !urlString.isEmpty else {
            self.image = nil
            self.isLoading = false
            return
        }

        if let cachedImage = cache.image(for: urlString, targetPixelSize: targetPixelSize) {
            self.image = cachedImage
            self.isLoading = false
            return
        }

        isLoading = true
        error = nil

        currentTask = Task {
            do {
                let loadedImage = try await downloadImage(from: urlString, targetPixelSize: targetPixelSize)
                if !Task.isCancelled {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    self.error = error
                    self.isLoading = false
                    print("❌ Failed to load image: \(error.localizedDescription)")
                }
            }
        }
    }

    private func downloadImage(from urlString: String, targetPixelSize: CGSize?) async throws -> UIImage {
        // Coordinator dedups the network fetch across concurrent callers sharing the same URL.
        // Downsample happens per-caller after the Data is shared — decode cost is small vs download.
        let data = try await ImageRequestCoordinator.shared.data(for: urlString) {
            try await ImageLoader.performDownload(from: urlString)
        }

        guard let image = await ImageLoader.decodeImage(from: data, targetPixelSize: targetPixelSize) else {
            throw ImageLoaderError.decodingFailed
        }

        cache.store(image, for: urlString, targetPixelSize: targetPixelSize)
        return image
    }

    /// Shared network fetch. Returns raw bytes; the caller decides how to decode.
    nonisolated private static func performDownload(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw ImageLoaderError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageLoaderError.invalidResponse
        }

        return data
    }

    /// Decode on a background task. When `targetPixelSize` is set, use ImageIO's thumbnail
    /// pipeline which decodes directly at the downsampled resolution — dramatically less
    /// GPU memory than decoding full-res and then resizing.
    nonisolated private static func decodeImage(from data: Data, targetPixelSize: CGSize?) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            if let targetPixelSize = targetPixelSize {
                return decodeDownsampled(data: data, targetPixelSize: targetPixelSize)
            }
            return decodeFullResolution(data: data)
        }.value
    }

    nonisolated private static func decodeDownsampled(data: Data, targetPixelSize: CGSize) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }

        let maxPixelDimension = max(targetPixelSize.width, targetPixelSize.height)
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    nonisolated private static func decodeFullResolution(data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        // Force decode off the main thread to avoid UI hitches at first render.
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(at: .zero)
        let decodedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return decodedImage ?? image
    }

    // MARK: - Prefetch

    /// Warm the cache for `urlString` without binding to a view. Idempotent with
    /// an in-flight load via the request coordinator — a concurrent view load
    /// and prefetch for the same URL share one network fetch.
    nonisolated static func prefetch(urlString: String, targetPixelSize: CGSize? = nil) {
        Task.detached(priority: .utility) {
            if ImageCache.shared.image(for: urlString, targetPixelSize: targetPixelSize) != nil {
                return
            }
            do {
                let data = try await ImageRequestCoordinator.shared.data(for: urlString) {
                    try await performDownload(from: urlString)
                }
                if let image = await decodeImage(from: data, targetPixelSize: targetPixelSize) {
                    ImageCache.shared.store(image, for: urlString, targetPixelSize: targetPixelSize)
                }
            } catch {
                // Prefetch is best-effort; a real load will surface errors to the user.
                print("↩︎ Prefetch failed for \(urlString): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cancel / Reset

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
    }

    func reset() {
        cancel()
        image = nil
        error = nil
    }
}

// MARK: - Request Coordinator

/// Serializes in-flight image fetches so N concurrent callers hitting the same URL
/// share a single network request. Actor isolation replaces the previous NSLock +
/// async-await-around-lock pattern that had a subtle cleanup race on failure.
actor ImageRequestCoordinator {
    static let shared = ImageRequestCoordinator()

    private var inFlight: [String: Task<Data, Error>] = [:]

    func data(for urlString: String, download: @escaping @Sendable () async throws -> Data) async throws -> Data {
        if let existing = inFlight[urlString] {
            return try await existing.value
        }
        let task = Task<Data, Error> { try await download() }
        inFlight[urlString] = task
        defer { inFlight.removeValue(forKey: urlString) }
        return try await task.value
    }
}

// MARK: - Error Types

enum ImageLoaderError: LocalizedError {
    case invalidURL
    case invalidResponse
    case downloadFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid image URL"
        case .invalidResponse:
            return "Invalid server response"
        case .downloadFailed:
            return "Failed to download image"
        case .decodingFailed:
            return "Failed to decode image"
        }
    }
}
