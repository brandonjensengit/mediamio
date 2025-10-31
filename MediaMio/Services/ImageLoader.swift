//
//  ImageLoader.swift
//  MediaMio
//
//  Created by Claude Code
//

import UIKit
import Combine

/// Async image loader with caching and request deduplication
@MainActor
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let cache = ImageCache.shared
    private var currentTask: Task<Void, Never>?

    // Request deduplication - track in-flight requests globally
    private static var inFlightRequests: [String: Task<UIImage?, Never>] = [:]
    private static let requestLock = NSLock()

    // MARK: - Load Image

    func load(from urlString: String?) {
        // Cancel any existing task
        currentTask?.cancel()
        currentTask = nil

        guard let urlString = urlString, !urlString.isEmpty else {
            self.image = nil
            self.isLoading = false
            return
        }

        // Check cache first
        if let cachedImage = cache.image(for: urlString) {
            self.image = cachedImage
            self.isLoading = false
            return
        }

        // Start loading
        isLoading = true
        error = nil

        currentTask = Task {
            do {
                let loadedImage = try await downloadImage(from: urlString)

                // Check if task was cancelled
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

    /// Download image with request deduplication
    private func downloadImage(from urlString: String) async throws -> UIImage {
        // Check for in-flight request
        ImageLoader.requestLock.lock()
        if let existingTask = ImageLoader.inFlightRequests[urlString] {
            ImageLoader.requestLock.unlock()
            print("⏳ Waiting for existing request: \(urlString)")

            // Wait for existing request
            if let image = await existingTask.value {
                return image
            } else {
                throw ImageLoaderError.downloadFailed
            }
        }

        // Create new download task
        let downloadTask = Task<UIImage?, Never> {
            do {
                let image = try await performDownload(from: urlString)
                return image
            } catch {
                print("❌ Download error: \(error)")
                return nil
            }
        }

        ImageLoader.inFlightRequests[urlString] = downloadTask
        ImageLoader.requestLock.unlock()

        // Wait for download
        guard let image = await downloadTask.value else {
            // Clean up request
            ImageLoader.requestLock.lock()
            ImageLoader.inFlightRequests.removeValue(forKey: urlString)
            ImageLoader.requestLock.unlock()

            throw ImageLoaderError.downloadFailed
        }

        // Clean up request
        ImageLoader.requestLock.lock()
        ImageLoader.inFlightRequests.removeValue(forKey: urlString)
        ImageLoader.requestLock.unlock()

        return image
    }

    /// Perform actual download
    private func performDownload(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw ImageLoaderError.invalidURL
        }

        print("⬇️ Downloading image: \(urlString)")

        // Download data
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageLoaderError.invalidResponse
        }

        // Decode image off main thread
        guard let image = await decodeImage(from: data) else {
            throw ImageLoaderError.decodingFailed
        }

        // Store in cache
        cache.store(image, for: urlString)

        return image
    }

    /// Decode image on background thread
    private func decodeImage(from data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: data) else {
                return nil
            }

            // Force decoding to avoid UI thread blocking
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(at: .zero)
            let decodedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return decodedImage ?? image
        }.value
    }

    // MARK: - Cancel

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
    }

    // MARK: - Reset

    func reset() {
        cancel()
        image = nil
        error = nil
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
