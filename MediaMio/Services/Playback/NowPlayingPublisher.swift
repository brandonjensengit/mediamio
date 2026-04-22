//
//  NowPlayingPublisher.swift
//  MediaMio
//
//  Publishes now-playing metadata + artwork to the system so AirPlay, the
//  Siri remote overlay, and Control Center can surface the currently-playing
//  item. Also wires remote command callbacks (play/pause/skip) back to the
//  `VideoPlayerViewModel`.
//
//  Constraint: knows nothing about the stream URL, subtitles, or failover —
//  only the metadata + playback-position feed the system needs. Fully
//  self-contained; `deinit` clears the now-playing info so the OS doesn't
//  show stale data after the player closes.
//

import Foundation
import MediaPlayer
import UIKit

@MainActor
final class NowPlayingPublisher {
    private let item: MediaItem
    private let artworkURL: String?
    private var artwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?

    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()

    struct Handlers {
        let play: () -> Void
        let pause: () -> Void
        let togglePlayPause: () -> Void
        let seekForward: () -> Void
        let seekBackward: () -> Void
        let seek: (Double) -> Void
    }

    init(item: MediaItem, baseURL: String, handlers: Handlers) {
        self.item = item
        self.artworkURL = item.primaryImageURL(baseURL: baseURL, maxWidth: 1000)
        wireCommands(handlers: handlers)
        publishInitialMetadata()
        fetchArtworkIfNeeded()
    }

    deinit {
        // Release `self` from the OS' info cache so Control Center / AirPlay
        // don't linger on a stopped item. Doing this in `deinit` is safe —
        // UIKit touches are fine, and we explicitly don't touch MainActor-
        // isolated state beyond the info center (which is thread-safe).
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Public updates

    /// Called from the periodic time observer with playback position.
    func update(elapsed: Double, duration: Double, rate: Float) {
        var info = infoCenter.nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        infoCenter.nowPlayingInfo = info
    }

    // MARK: - Private

    private func publishInitialMetadata() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = item.name
        if let seriesName = item.seriesName { info[MPMediaItemPropertyAlbumTitle] = seriesName }
        if let genres = item.genres, !genres.isEmpty { info[MPMediaItemPropertyGenre] = genres.joined(separator: ", ") }
        if let year = item.productionYear { info[MPMediaItemPropertyReleaseDate] = "\(year)" }
        if let runtime = item.runTimeTicks { info[MPMediaItemPropertyPlaybackDuration] = Double(runtime) / 10_000_000.0 }
        info[MPNowPlayingInfoPropertyMediaType] = (item.type == "Episode" || item.type == "Series"
            ? MPNowPlayingInfoMediaType.video.rawValue
            : MPNowPlayingInfoMediaType.video.rawValue)
        infoCenter.nowPlayingInfo = info
    }

    private func fetchArtworkIfNeeded() {
        guard let urlString = artworkURL, let url = URL(string: urlString) else { return }
        artworkTask = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }
                let art = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                await MainActor.run {
                    guard let self = self else { return }
                    self.artwork = art
                    var info = self.infoCenter.nowPlayingInfo ?? [:]
                    info[MPMediaItemPropertyArtwork] = art
                    self.infoCenter.nowPlayingInfo = info
                }
            } catch {
                // Artwork is best-effort; a failure here is not worth
                // surfacing to the user.
                print("⚠️ Now-playing artwork fetch failed: \(error)")
            }
        }
    }

    private func wireCommands(handlers: Handlers) {
        commandCenter.playCommand.addTarget { _ in
            handlers.play()
            return .success
        }
        commandCenter.pauseCommand.addTarget { _ in
            handlers.pause()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            handlers.togglePlayPause()
            return .success
        }
        commandCenter.skipForwardCommand.preferredIntervals = [10]
        commandCenter.skipForwardCommand.addTarget { _ in
            handlers.seekForward()
            return .success
        }
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { _ in
            handlers.seekBackward()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            handlers.seek(event.positionTime)
            return .success
        }
    }
}
