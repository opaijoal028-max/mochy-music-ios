import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SwiftUI
import Combine
import UIKit

// MARK: - Files

enum MochyFiles {
    static let fileManager = FileManager.default

    static var appDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Mochy", isDirectory: true)
    }

    static var downloadsDirectory: URL {
        appDirectory.appendingPathComponent("Downloads", isDirectory: true)
    }

    @discardableResult
    static func prepare() -> Bool {
        do {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    static var libraryFile: URL {
        appDirectory.appendingPathComponent("library.json")
    }
}

// MARK: - Persistence

private struct LibrarySnapshot: Codable {
    var likedSongs: [Song]
    var recentlyPlayed: [HistoryEntry]
    var playlists: [UserPlaylist]
    var downloads: [Download]
    var playEvents: [PlayEvent]
}

struct ArtistStat: Identifiable {
    var id: String { name }
    var name: String
    var plays: Int
    var artwork: String?
}

struct SongStat: Identifiable {
    var id: String { song.id }
    var song: Song
    var plays: Int
}

// MARK: - Store

@MainActor
final class AppStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            saveSettings()
            player.updateSettings(settings)
        }
    }

    let player = PlayerManager()

    @Published var selectedTab: AppTab
    @Published var home: HomePage?
    @Published var homeLoading = false
    @Published var homeError: String?
    @Published var playerPresented = false
    @Published var libraryPath = NavigationPath()

    @Published var likedSongs: [Song] = []
    @Published var recentlyPlayed: [HistoryEntry] = []
    @Published var playlists: [UserPlaylist] = []
    @Published var downloads: [Download] = []
    @Published var playEvents: [PlayEvent] = []

    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadErrors: [String: String] = [:]

    @Published var toast: String?

    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private var toastTask: Task<Void, Never>?
    private var activePlayEventIndex: Int?
    private var activePlayStartedAt: Date?

    init() {
        let loaded = Self.loadSettings()
        settings = loaded
        selectedTab = loaded.defaultTab
        MochyFiles.prepare()
        loadLibrary()

        player.updateSettings(loaded)
        player.localURLProvider = { [weak self] song in
            self?.localFileURL(for: song)
        }
        player.onSongStarted = { [weak self] song in
            self?.handleSongStarted(song)
        }
        player.onQueueEnded = { [weak self] in
            self?.finishActivePlayEvent()
        }
    }

    // MARK: - Home

    func loadHome(force: Bool = false) async {
        if homeLoading { return }
        if !force, home != nil { return }
        homeLoading = true
        homeError = nil
        do {
            let page = try await InnerTubeAPI.shared.home()
            home = page
        } catch {
            homeError = error.localizedDescription
        }
        homeLoading = false
    }

    func refreshHome() async {
        await loadHome(force: true)
    }

    // MARK: - Playback helpers

    func play(_ song: Song, queue suggested: [Song]? = nil) {
        player.play(song: song, queue: suggested)
        playerPresented = true
    }

    func play(_ songs: [Song], startingAt index: Int) {
        guard songs.indices.contains(index) else { return }
        player.play(songs: songs, startingAt: index)
        playerPresented = true
    }

    func playNext(_ song: Song) {
        player.playNext(song)
        showToast("Playing next")
    }

    func queue(_ song: Song) {
        player.addToQueue([song])
        showToast("Added to queue")
    }

    func queue(_ songs: [Song]) {
        player.addToQueue(songs)
        showToast("Added \(songs.count) songs to queue")
    }

    // MARK: - Likes

    func isLiked(_ song: Song) -> Bool {
        likedSongs.contains { $0.id == song.id }
    }

    func toggleLike(_ song: Song) {
        if isLiked(song) {
            likedSongs.removeAll { $0.id == song.id }
            showToast("Removed from liked songs")
        } else {
            likedSongs.insert(song, at: 0)
            showToast("Added to liked songs")
            autoDownloadIfNeeded(song)
        }
        saveLibrary()
    }

    func like(_ song: Song) {
        guard !isLiked(song) else { return }
        likedSongs.insert(song, at: 0)
        autoDownloadIfNeeded(song)
        saveLibrary()
    }

    func unlike(_ song: Song) {
        likedSongs.removeAll { $0.id == song.id }
        saveLibrary()
    }

    // MARK: - Playlists

    @discardableResult
    func createPlaylist(name: String, description: String = "") -> UserPlaylist {
        let playlist = UserPlaylist(name: name.isEmpty ? "New playlist" : name, description: description)
        playlists.insert(playlist, at: 0)
        saveLibrary()
        return playlist
    }

    func deletePlaylist(_ playlist: UserPlaylist) {
        playlists.removeAll { $0.id == playlist.id }
        saveLibrary()
    }

    func renamePlaylist(_ playlist: UserPlaylist, name: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].name = name
        playlists[index].updatedAt = Date()
        saveLibrary()
    }

    func add(_ song: Song, to playlist: UserPlaylist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        guard !playlists[index].songs.contains(where: { $0.id == song.id }) else {
            showToast("Already in playlist")
            return
        }
        playlists[index].songs.append(song)
        playlists[index].updatedAt = Date()
        saveLibrary()
        showToast("Added to \(playlists[index].name)")
    }

    func remove(_ song: Song, from playlist: UserPlaylist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].songs.removeAll { $0.id == song.id }
        playlists[index].updatedAt = Date()
        saveLibrary()
    }

    func removeSongs(from playlist: UserPlaylist, at offsets: IndexSet) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].songs.remove(atOffsets: offsets)
        playlists[index].updatedAt = Date()
        saveLibrary()
    }

    func moveSongs(in playlist: UserPlaylist, from source: IndexSet, to destination: Int) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].songs.move(fromOffsets: source, toOffset: destination)
        playlists[index].updatedAt = Date()
        saveLibrary()
    }

    func playlist(id: String) -> UserPlaylist? {
        playlists.first { $0.id == id }
    }

    // MARK: - History and stats

    private func handleSongStarted(_ song: Song) {
        finishActivePlayEvent()

        let entry = HistoryEntry(song: song, playedAt: Date())
        recentlyPlayed.insert(entry, at: 0)
        if recentlyPlayed.count > 120 {
            recentlyPlayed = Array(recentlyPlayed.prefix(120))
        }

        let event = PlayEvent(
            songId: song.id,
            title: song.title,
            artist: song.artistLine,
            thumbnail: song.thumbnail,
            playedAt: Date(),
            secondsPlayed: 0
        )
        playEvents.append(event)
        if playEvents.count > 1500 {
            playEvents = Array(playEvents.suffix(1500))
        }
        activePlayEventIndex = playEvents.count - 1
        activePlayStartedAt = Date()
        saveLibrary()
    }

    func finishActivePlayEvent() {
        guard let index = activePlayEventIndex,
              let started = activePlayStartedAt,
              playEvents.indices.contains(index) else { return }
        let seconds = Int(Date().timeIntervalSince(started))
        playEvents[index].secondsPlayed += max(0, seconds)
        activePlayEventIndex = nil
        activePlayStartedAt = nil
        saveLibrary()
    }

    var recentSongs: [Song] {
        var seen = Set<String>()
        return recentlyPlayed.compactMap { entry in
            guard seen.insert(entry.song.id).inserted else { return nil }
            return entry.song
        }
    }

    var totalListeningSeconds: Int {
        playEvents.reduce(0) { $0 + $1.secondsPlayed }
    }

    var totalPlays: Int {
        playEvents.count
    }

    var topArtists: [ArtistStat] {
        var counts: [String: (Int, String?)] = [:]
        for event in playEvents {
            guard !event.artist.isEmpty else { continue }
            let current = counts[event.artist] ?? (0, event.thumbnail)
            counts[event.artist] = (current.0 + 1, current.1 ?? event.thumbnail)
        }
        return counts.map { ArtistStat(name: $0.key, plays: $0.value.0, artwork: $0.value.1) }
            .sorted { $0.plays > $1.plays }
    }

    var topSongs: [SongStat] {
        var songs: [String: Song] = [:]
        var counts: [String: Int] = [:]
        for event in playEvents {
            counts[event.songId, default: 0] += 1
            if songs[event.songId] == nil {
                songs[event.songId] = recentlyPlayed.first(where: { $0.song.id == event.songId })?.song
                    ?? Song(id: event.songId, title: event.title, artists: [ArtistRef(name: event.artist, id: nil)], thumbnail: event.thumbnail)
            }
        }
        return counts.compactMap { id, count in
            guard let song = songs[id] else { return nil }
            return SongStat(song: song, plays: count)
        }
        .sorted { $0.plays > $1.plays }
    }

    func clearHistory() {
        recentlyPlayed = []
        playEvents = []
        saveLibrary()
        showToast("History cleared")
    }

    // MARK: - Downloads

    private func autoDownloadIfNeeded(_ song: Song) {
        guard settings.autoDownloadLiked else { return }
        download(song)
    }

    func isDownloaded(_ song: Song) -> Bool {
        downloads.contains { $0.song.id == song.id }
    }

    func localFileURL(for song: Song) -> URL? {
        guard let download = downloads.first(where: { $0.song.id == song.id }) else { return nil }
        let url = MochyFiles.downloadsDirectory.appendingPathComponent(download.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func download(_ song: Song) {
        guard !isDownloaded(song), downloadTasks[song.id] == nil else { return }
        downloadErrors[song.id] = nil
        downloadProgress[song.id] = 0.05

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let quality = AudioQuality(rawValue: self.settings.downloadQuality.rawValue) ?? .high
                let source = try await InnerTubeAPI.shared.stream(videoId: song.id, quality: quality)
                self.downloadProgress[song.id] = 0.25
                var request = URLRequest(url: source.url)
                for (key, value) in source.headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                guard !data.isEmpty else { throw URLError(.zeroByteResource) }

                MochyFiles.prepare()
                let ext = source.mimeType.contains("mp4") ? "m4a" : "webm"
                let base = self.sanitizedFileName("\(song.artistLine) - \(song.title)")
                let fileName = "\(base)-\(song.id).\(ext)"
                let url = MochyFiles.downloadsDirectory.appendingPathComponent(fileName)
                try data.write(to: url, options: .atomic)

                let download = Download(
                    song: song,
                    fileName: fileName,
                    quality: self.settings.downloadQuality.rawValue,
                    bytes: Int64(data.count),
                    createdAt: Date()
                )
                self.downloads.insert(download, at: 0)
                self.downloadProgress[song.id] = 1
                self.downloadTasks[song.id] = nil
                self.saveLibrary()
                self.showToast("Downloaded \(song.title)")
            } catch {
                self.downloadErrors[song.id] = error.localizedDescription
                self.downloadProgress[song.id] = nil
                self.downloadTasks[song.id] = nil
                self.showToast("Download failed")
            }
        }
        downloadTasks[song.id] = task
    }

    func cancelDownload(_ song: Song) {
        downloadTasks[song.id]?.cancel()
        downloadTasks[song.id] = nil
        downloadProgress[song.id] = nil
    }

    func deleteDownload(_ download: Download) {
        let url = MochyFiles.downloadsDirectory.appendingPathComponent(download.fileName)
        try? FileManager.default.removeItem(at: url)
        downloads.removeAll { $0.song.id == download.song.id }
        downloadProgress[download.song.id] = nil
        saveLibrary()
    }

    func deleteAllDownloads() {
        for download in downloads {
            let url = MochyFiles.downloadsDirectory.appendingPathComponent(download.fileName)
            try? FileManager.default.removeItem(at: url)
        }
        downloads = []
        saveLibrary()
    }

    var downloadBytes: Int64 {
        downloads.reduce(0) { $0 + $1.bytes }
    }

    var downloadBytesText: String {
        ByteCountFormatter.string(fromByteCount: downloadBytes, countStyle: .file)
    }

    private func sanitizedFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        let cleaned = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let text = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(text.prefix(60)).replacingOccurrences(of: " ", with: "-")
    }

    // MARK: - Settings / app icon

    func applyAppIcon(_ style: AppIconStyle) {
        guard UIApplication.shared.supportsAlternateIcons else {
            showToast("Alternate icons are not supported")
            return
        }
        let name: String? = style == .mark ? nil : style.rawValue
        UIApplication.shared.setAlternateIconName(name) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.showToast(error.localizedDescription)
                } else {
                    self.settings.appIcon = style
                    self.showToast("Icon updated")
                }
            }
        }
    }

    func resetSettings() {
        let onboarding = settings.onboardingCompleted
        settings = AppSettings()
        settings.onboardingCompleted = onboarding
        selectedTab = .home
        showToast("Settings reset")
    }

    func completeOnboarding(name: String, accent: String?) {
        settings.profileName = name.isEmpty ? "music lover" : name
        if let accent { settings.accentHex = accent }
        settings.onboardingCompleted = true
        saveSettings()
    }

    // MARK: - Toasts

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            if self?.toast == message {
                self?.toast = nil
            }
        }
    }

    // MARK: - Persistence

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: "mochy.settings")
    }

    private static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "mochy.settings"),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return decoded
    }

    private func saveLibrary() {
        let snapshot = LibrarySnapshot(
            likedSongs: likedSongs,
            recentlyPlayed: recentlyPlayed,
            playlists: playlists,
            downloads: downloads,
            playEvents: playEvents
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        MochyFiles.prepare()
        try? data.write(to: MochyFiles.libraryFile, options: .atomic)
    }

    private func loadLibrary() {
        guard let data = try? Data(contentsOf: MochyFiles.libraryFile),
              let snapshot = try? JSONDecoder().decode(LibrarySnapshot.self, from: data) else {
            return
        }
        likedSongs = snapshot.likedSongs
        recentlyPlayed = snapshot.recentlyPlayed
        playlists = snapshot.playlists
        downloads = snapshot.downloads
        playEvents = snapshot.playEvents
    }
}
