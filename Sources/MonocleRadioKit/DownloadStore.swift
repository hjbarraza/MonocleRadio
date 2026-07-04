// DownloadStore.swift — offline episodes: download, track progress, play local
// MonocleRadioKit — shared core for the macOS and iOS Monocle Radio apps

import Foundation
import CryptoKit

/// Episode MP3s saved under Documents/Episodes, keyed by a hash of their
/// audio URL. Files on disk ARE the index — no separate database.
@Observable
public final class DownloadStore {
    public static let shared = DownloadStore()

    /// Download progress by audio-URL string, 0...1. Absent = not downloading.
    public private(set) var progress: [String: Double] = [:]

    /// Bumped when a download lands or is removed, so views re-query disk.
    public private(set) var revision = 0

    @ObservationIgnored private var observations: [String: NSKeyValueObservation] = [:]

    private let directory: URL

    public init() {
        directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Episodes", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Queries

    public func localURL(for episode: Episode) -> URL? {
        guard let remote = episode.audioURL else { return nil }
        let file = fileURL(for: remote)
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    public func isDownloaded(_ episode: Episode) -> Bool {
        localURL(for: episode) != nil
    }

    public func isDownloading(_ episode: Episode) -> Bool {
        guard let remote = episode.audioURL else { return false }
        return progress[remote.absoluteString] != nil
    }

    // MARK: - Download / Remove

    @MainActor
    public func download(_ episode: Episode) {
        guard let remote = episode.audioURL,
              !isDownloaded(episode), !isDownloading(episode) else { return }
        let key = remote.absoluteString
        progress[key] = 0

        let destination = fileURL(for: remote)
        let task = URLSession.shared.downloadTask(with: remote) { [weak self] temp, _, _ in
            if let temp {
                try? FileManager.default.moveItem(at: temp, to: destination)
            }
            Task { @MainActor in
                guard let self else { return }
                self.observations[key] = nil
                self.progress[key] = nil
                self.revision += 1
            }
        }
        observations[key] = task.progress.observe(\.fractionCompleted) { [weak self] p, _ in
            Task { @MainActor in
                if self?.progress[key] != nil { self?.progress[key] = p.fractionCompleted }
            }
        }
        task.resume()
    }

    @MainActor
    public func remove(_ episode: Episode) {
        guard let local = localURL(for: episode) else { return }
        try? FileManager.default.removeItem(at: local)
        revision += 1
    }

    // MARK: - Helpers

    private func fileURL(for remote: URL) -> URL {
        let digest = SHA256.hash(data: Data(remote.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined().prefix(32)
        return directory.appendingPathComponent("\(name).mp3")
    }
}
