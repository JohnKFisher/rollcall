import AVFoundation
import Foundation
import MediaPlayer
import MusicKit

enum SongWaveformError: Error {
    case unreadableAudio
}

struct SongWaveformService: Sendable {
    func samples(from url: URL, sampleCount: Int) async throws -> [Float] {
        guard sampleCount > 0 else { return [] }

        return try await Task.detached(priority: .utility) {
            try Self.readSamples(from: url, sampleCount: sampleCount)
        }.value
    }

    private static func readSamples(from url: URL, sampleCount: Int) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0 else {
            throw SongWaveformError.unreadableAudio
        }

        let format = file.processingFormat
        let framesPerBucket = max(1, Int(ceil(Double(file.length) / Double(sampleCount))))
        let bufferCapacity = AVAudioFrameCount(min(8_192, framesPerBucket))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferCapacity) else {
            throw SongWaveformError.unreadableAudio
        }

        var peaks = Array(repeating: Float.zero, count: sampleCount)
        var framePosition = 0

        while file.framePosition < file.length {
            try file.read(into: buffer)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else {
                throw SongWaveformError.unreadableAudio
            }

            let channelCount = Int(format.channelCount)
            for frameIndex in 0..<Int(buffer.frameLength) {
                let bucket = min(sampleCount - 1, framePosition / framesPerBucket)
                var peak = Float.zero
                for channelIndex in 0..<channelCount {
                    peak = max(peak, abs(channels[channelIndex][frameIndex]))
                }
                peaks[bucket] = max(peaks[bucket], peak)
                framePosition += 1
            }
        }

        guard let maximum = peaks.max(), maximum > 0 else {
            return peaks
        }
        return peaks.map { min(1, $0 / maximum) }
    }
}

actor SongWaveformRepository {
    static let shared = SongWaveformRepository()

    private var cache: [String: [Float]] = [:]
    private var activeTasks: [String: Task<[Float], Error>] = [:]

    func samples(from url: URL, sampleCount: Int) async throws -> [Float] {
        let key = "\(url.standardizedFileURL.absoluteString)|\(sampleCount)"
        if let cached = cache[key] {
            return cached
        }
        if let activeTask = activeTasks[key] {
            return try await activeTask.value
        }

        let task = Task {
            try await SongWaveformService().samples(from: url, sampleCount: sampleCount)
        }
        activeTasks[key] = task

        do {
            let samples = try await task.value
            cache[key] = samples
            activeTasks[key] = nil
            return samples
        } catch {
            activeTasks[key] = nil
            throw error
        }
    }

    func prefetch(from url: URL, sampleCount: Int) async {
        _ = try? await samples(from: url, sampleCount: sampleCount)
    }
}

@MainActor
enum SongWaveformSourceResolver {
    static func url(for cue: Cue) -> URL? {
        switch cue.source {
        case .localAudio(let source):
            return try? AppPaths.assetURL(relativePath: source.relativePath)
        case .builtInClip(let source):
            return try? AppPaths.assetURL(relativePath: "\(source.id).mp3")
        case .appleMusic(let source):
            guard MusicAuthorization.currentStatus == .authorized else { return nil }
            return MPMediaQuery.songs().items?
                .first { $0.playbackStoreID == source.songID }?
                .assetURL
        }
    }
}
