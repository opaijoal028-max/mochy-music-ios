import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import AVFoundation
import AVFAudio
import MediaPlayer
import Combine
import UIKit
import SwiftUI

@MainActor
final class PlayerManager: ObservableObject {
    @Published private(set) var currentSong: Song?
    @Published private(set) var queue: [Song] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var isBuffering = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var errorMessage: String?
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffle = false
    @Published private(set) var artworkImage: UIImage?
    @Published private(set) var artworkColor: Color?
    @Published private(set) var sleepTimerEnds: Date?
    @Published private(set) var isPlayingLocalFile = false

    let player = AVPlayer()

    var onSongStarted: ((Song) -> Void)?
    var localURLProvider: ((Song) -> URL?)?
    var onQueueEnded: (() -> Void)?

    private var originalQueue: [Song] = []
    private var loadTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var sleepTask: Task<Void, Never>?
    private var timeObserver: Any?
    private var itemStatusObservation: NSKeyValueObservation?
    private var itemEndObserver: NSObjectProtocol?
    private var itemFailureObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    private var wasPlayingBeforeInterruption = false
    private var audioQuality: AudioQuality = .high
    private var mixWithOthers = false
    private var didConfigureSession = false

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
        configureSession()
        observePlayer()
        configureRemoteCommands()
        observeInterruptions()
    }

    // MARK: - Queue control

    func play(song: Song, queue suggestedQueue: [Song]? = nil) {
        var list = suggestedQueue?.isEmpty == false ? (suggestedQueue ?? []) : [song]
        if !list.contains(where: { $0.id == song.id }) {
            list.insert(song, at: 0)
        }
        originalQueue = list
        queue = list
        if shuffle {
            var rest = list
            if let index = rest.firstIndex(where: { $0.id == song.id }) {
                rest.remove(at: index)
            }
            rest.shuffle()
            queue = [song] + rest.filter { $0.id != song.id }
            currentIndex = 0
        } else {
            currentIndex = queue.firstIndex(where: { $0.id == song.id }) ?? 0
        }
        startCurrentSong(record: true)
    }

    func play(songs: [Song], startingAt index: Int) {
        guard songs.indices.contains(index) else { return }
        play(song: songs[index], queue: songs)
    }

    func playNext(_ song: Song) {
        guard !queue.isEmpty else {
            play(song: song)
            return
        }
        let insertIndex = min(currentIndex + 1, queue.count)
        queue.insert(song, at: insertIndex)
        originalQueue = queue
    }

    func addToQueue(_ songs: [Song]) {
        let fresh = songs.filter { song in !queue.contains(where: { $0.id == song.id }) }
        queue.append(contentsOf: fresh)
        originalQueue = queue
        if currentSong == nil, let first = queue.first {
            currentIndex = 0
            startCurrentSong(record: true)
            _ = first
        }
    }

    func removeFromQueue(at offsets: IndexSet) {
        let current = currentSong
        for index in offsets.sorted(by: >) where queue.indices.contains(index) {
            let removed = queue.remove(at: index)
            if index < currentIndex { currentIndex -= 1 }
            if removed.id == current?.id { currentIndex = min(currentIndex, max(queue.count - 1, 0)) }
        }
        originalQueue = originalQueue.filter { song in queue.contains(where: { $0.id == song.id }) }
        if queue.isEmpty {
            stop()
        } else if let song = currentSong, queue.indices.contains(currentIndex), queue[currentIndex].id != song.id {
            startCurrentSong(record: false)
        }
    }

    func moveQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        originalQueue = queue
        if let song = currentSong, let index = queue.firstIndex(where: { $0.id == song.id }) {
            currentIndex = index
        }
    }

    func jumpToQueueItem(_ index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        startCurrentSong(record: true)
    }

    func next(userInitiated: Bool = true) {
        guard !queue.isEmpty else { return }
        if repeatMode == .one && !userInitiated {
            seek(to: 0)
            resume()
            return
        }
        if currentIndex + 1 < queue.count {
            currentIndex += 1
            startCurrentSong(record: true)
        } else if repeatMode == .all {
            currentIndex = 0
            startCurrentSong(record: true)
        } else {
            pause()
            seek(to: 0)
            updateNowPlayingElapsed()
            onQueueEnded?()
        }
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        if currentIndex > 0 {
            currentIndex -= 1
        } else if repeatMode == .all {
            currentIndex = queue.count - 1
        } else {
            seek(to: 0)
            return
        }
        startCurrentSong(record: true)
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        guard currentSong != nil else { return }
        configureSession()
        player.play()
        isPlaying = true
        updateNowPlayingElapsed()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingElapsed()
    }

    func stop() {
        loadTask?.cancel()
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentSong = nil
        queue = []
        originalQueue = []
        currentIndex = 0
        currentTime = 0
        duration = 0
        isPlaying = false
        isLoading = false
        isBuffering = false
        artworkImage = nil
        artworkColor = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to time: Double) {
        guard time.isFinite else { return }
        let clamped = max(0, min(time, duration > 0 ? duration : time))
        currentTime = clamped
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        updateNowPlayingElapsed()
    }

    func skip(by seconds: Double) {
        seek(to: currentTime + seconds)
    }

    func setShuffle(_ enabled: Bool) {
        guard enabled != shuffle else { return }
        shuffle = enabled
        if enabled {
            guard let current = currentSong else { return }
            originalQueue = queue
            var rest = queue.filter { $0.id != current.id }
            rest.shuffle()
            queue = [current] + rest
            currentIndex = 0
        } else if !originalQueue.isEmpty {
            let current = currentSong
            queue = originalQueue
            if let current, let index = queue.firstIndex(where: { $0.id == current.id }) {
                currentIndex = index
            } else {
                currentIndex = 0
            }
        }
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    // MARK: - Settings

    func updateSettings(_ settings: AppSettings) {
        audioQuality = settings.audioQuality
        if mixWithOthers != settings.mixWithOtherApps {
            mixWithOthers = settings.mixWithOtherApps
            configureSession()
        }
    }

    func setSleepTimer(minutes: Int?) {
        sleepTask?.cancel()
        sleepTask = nil
        guard let minutes, minutes > 0 else {
            sleepTimerEnds = nil
            return
        }
        let end = Date().addingTimeInterval(Double(minutes) * 60)
        sleepTimerEnds = end
        sleepTask = Task { [weak self] in
            let seconds = UInt64(minutes) * 60
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.sleepTimerEnds = nil
            self?.pause()
        }
    }

    // MARK: - Playback loading

    private func startCurrentSong(record: Bool) {
        guard queue.indices.contains(currentIndex) else { return }
        let song = queue[currentIndex]
        currentSong = song
        currentTime = 0
        duration = Double(song.duration ?? 0)
        errorMessage = nil
        isLoading = true
        isBuffering = false
        loadArtwork(for: song)
        updateNowPlayingMetadata()
        if record {
            onSongStarted?(song)
        }

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            if let localURL = self.localURLProvider?(song) {
                self.isPlayingLocalFile = true
                self.startItem(url: localURL, headers: [:], mimeType: nil, expectedDuration: song.duration)
                return
            }
            self.isPlayingLocalFile = false
            do {
                let source = try await InnerTubeAPI.shared.stream(videoId: song.id, quality: self.audioQuality)
                guard !Task.isCancelled, self.currentSong?.id == song.id else { return }
                self.startItem(
                    url: source.url,
                    headers: source.headers,
                    mimeType: source.mimeType,
                    expectedDuration: source.duration ?? song.duration
                )
            } catch {
                guard !Task.isCancelled else { return }
                self.isLoading = false
                self.isPlaying = false
                self.errorMessage = error.localizedDescription
                self.updateNowPlayingElapsed()
            }
        }
    }

    private func startItem(url: URL, headers: [String: String], mimeType: String?, expectedDuration: Int?) {
        itemStatusObservation?.invalidate()
        if let itemEndObserver {
            NotificationCenter.default.removeObserver(itemEndObserver)
        }
        if let itemFailureObserver {
            NotificationCenter.default.removeObserver(itemFailureObserver)
        }

        var options: [String: Any] = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        if !headers.isEmpty {
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }
        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 12
        if let expectedDuration, expectedDuration > 0 {
            duration = Double(expectedDuration)
        }

        itemStatusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isLoading = false
                    let seconds = item.duration.seconds
                    if seconds.isFinite, seconds > 0 {
                        self.duration = seconds
                    }
                    self.player.play()
                    self.isPlaying = true
                    self.updateNowPlayingElapsed()
                case .failed:
                    self.isLoading = false
                    self.isPlaying = false
                    self.errorMessage = item.error?.localizedDescription ?? "Playback failed."
                default:
                    break
                }
            }
        }

        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.next(userInitiated: false)
            }
        }

        itemFailureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                self?.isPlaying = false
                self?.isLoading = false
                self?.errorMessage = error?.localizedDescription ?? "Playback failed."
            }
        }

        player.replaceCurrentItem(with: item)
        observePlayer()
        if let mimeType {
            _ = mimeType
        }
    }

    private func loadArtwork(for song: Song) {
        artworkTask?.cancel()
        artworkImage = nil
        artworkColor = nil
        guard let raw = song.thumbnail, let url = URL(string: raw) else {
            updateNowPlayingMetadata()
            return
        }
        artworkTask = Task { [weak self] in
            guard let self else { return }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            guard !Task.isCancelled, self.currentSong?.id == song.id else { return }
            self.artworkImage = image
            self.artworkColor = image.averageColor()
            self.updateNowPlayingMetadata()
        }
    }

    // MARK: - Observation

    private func observePlayer() {
        guard timeObserver == nil else { return }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite {
                    self.currentTime = max(0, seconds)
                }
                if let itemDuration = self.player.currentItem?.duration.seconds,
                   itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
                self.updateNowPlayingElapsed()
            }
        }

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .playing:
                    self.isPlaying = true
                    self.isBuffering = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                case .paused:
                    self.isPlaying = false
                    self.isBuffering = false
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions = mixWithOthers ? [.mixWithOthers] : []
        try? session.setCategory(.playback, mode: .default, options: options)
        try? session.setActive(true)
        didConfigureSession = true
    }

    private func observeInterruptions() {
        _ = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                guard let self,
                      let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                switch type {
                case .began:
                    self.wasPlayingBeforeInterruption = self.isPlaying
                    self.pause()
                case .ended:
                    let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                    if options.contains(.shouldResume), self.wasPlayingBeforeInterruption {
                        self.resume()
                    }
                @unknown default:
                    break
                }
            }
        }

        _ = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                guard let self,
                      let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
                if reason == .oldDeviceUnavailable {
                    self.pause()
                }
            }
        }
    }

    // MARK: - Now Playing / remote commands

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        _ = center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        _ = center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        _ = center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        _ = center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        _ = center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        _ = center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor in self?.seek(to: position) }
            return .success
        }
    }

    private func updateNowPlayingMetadata() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artistLine,
            MPMediaItemPropertyAlbumTitle: song.albumTitle ?? "",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let artworkImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
                artworkImage
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func updateNowPlayingElapsed() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            updateNowPlayingMetadata()
            return
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
