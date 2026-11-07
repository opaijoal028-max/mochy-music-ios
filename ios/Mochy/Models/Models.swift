import Foundation

// MARK: - Core media models

struct ArtistRef: Codable, Hashable, Identifiable {
    var name: String
    var id: String?

    var identifier: String { id ?? name }
}

struct Song: Codable, Hashable, Identifiable {
    let id: String
    var title: String
    var artists: [ArtistRef]
    var albumTitle: String?
    var albumId: String?
    var duration: Int?
    var thumbnail: String?
    var explicit: Bool
    var musicVideoType: String?
    var playlistId: String?
    var source: String

    init(
        id: String,
        title: String,
        artists: [ArtistRef] = [],
        albumTitle: String? = nil,
        albumId: String? = nil,
        duration: Int? = nil,
        thumbnail: String? = nil,
        explicit: Bool = false,
        musicVideoType: String? = nil,
        playlistId: String? = nil,
        source: String = "youtube"
    ) {
        self.id = id
        self.title = title
        self.artists = artists
        self.albumTitle = albumTitle
        self.albumId = albumId
        self.duration = duration
        self.thumbnail = thumbnail
        self.explicit = explicit
        self.musicVideoType = musicVideoType
        self.playlistId = playlistId
        self.source = source
    }

    var artistLine: String {
        artists.map(\.name).filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var durationText: String {
        guard let duration else { return "" }
        return Self.timeText(duration)
    }

    var isVideoSong: Bool {
        musicVideoType == "MUSIC_VIDEO_TYPE_OMV" ||
        musicVideoType == "MUSIC_VIDEO_TYPE_UGC" ||
        musicVideoType == "MUSIC_VIDEO_TYPE_PODCAST_EPISODE"
    }

    var isUploaded: Bool {
        musicVideoType == "MUSIC_VIDEO_TYPE_PRIVATELY_OWNED_TRACK"
    }

    var shareURL: URL? {
        URL(string: "https://music.youtube.com/watch?v=\(id)")
    }

    static func timeText(_ seconds: Int) -> String {
        let seconds = max(0, seconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func == (lhs: Song, rhs: Song) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Album: Codable, Hashable, Identifiable {
    var id: String
    var playlistId: String?
    var title: String
    var artists: [ArtistRef]
    var year: Int?
    var thumbnail: String?
    var explicit: Bool
    var description: String?

    var artistLine: String {
        artists.map(\.name).filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct Artist: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var thumbnail: String?
    var subscriberCount: String?
    var description: String?
}

struct Playlist: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var author: String
    var thumbnail: String?
    var songCount: String?
    var description: String?
    var isLocal: Bool
}

enum MediaItem: Codable, Hashable, Identifiable {
    case song(Song)
    case album(Album)
    case artist(Artist)
    case playlist(Playlist)

    var id: String {
        switch self {
        case .song(let value): return "song:\(value.id)"
        case .album(let value): return "album:\(value.id)"
        case .artist(let value): return "artist:\(value.id)"
        case .playlist(let value): return "playlist:\(value.id)"
        }
    }

    var title: String {
        switch self {
        case .song(let value): return value.title
        case .album(let value): return value.title
        case .artist(let value): return value.name
        case .playlist(let value): return value.title
        }
    }

    var subtitle: String {
        switch self {
        case .song(let value):
            var parts = [value.artistLine]
            if let album = value.albumTitle, !album.isEmpty { parts.append(album) }
            return parts.filter { !$0.isEmpty }.joined(separator: " · ")
        case .album(let value):
            return [value.artistLine, value.year.map(String.init)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        case .artist(let value):
            return value.subscriberCount ?? "Artist"
        case .playlist(let value):
            return [value.author, value.songCount].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }

    var thumbnail: String? {
        switch self {
        case .song(let value): return value.thumbnail
        case .album(let value): return value.thumbnail
        case .artist(let value): return value.thumbnail
        case .playlist(let value): return value.thumbnail
        }
    }

    var song: Song? {
        if case .song(let value) = self { return value }
        return nil
    }

    var album: Album? {
        if case .album(let value) = self { return value }
        return nil
    }

    var artist: Artist? {
        if case .artist(let value) = self { return value }
        return nil
    }

    var playlist: Playlist? {
        if case .playlist(let value) = self { return value }
        return nil
    }
}

struct HomeSection: Identifiable, Hashable {
    var id: String
    var title: String
    var subtitle: String?
    var items: [MediaItem]
    var moreId: String?
    var moreParams: String?
}

struct SearchGroup: Identifiable, Hashable {
    var id: String { title }
    var title: String
    var items: [MediaItem]
}

struct HomeChip: Identifiable, Hashable {
    var title: String
    var browseId: String?
    var params: String?

    var id: String { "\(title)-\(browseId ?? "")-\(params ?? "")" }
    var isBrowsable: Bool { browseId != nil || params != nil }
}

struct HomePage {
    var chips: [HomeChip]
    var sections: [HomeSection]
}

struct AlbumDetail {
    var album: Album
    var songs: [Song]
    var description: String?
}

struct ArtistDetail {
    var artist: Artist
    var sections: [HomeSection]
    var description: String?
}

struct PlaylistDetail {
    var playlist: Playlist
    var songs: [Song]
    var description: String?
}

// MARK: - Lyrics

struct LyricLine: Identifiable, Hashable {
    var id: Int { index }
    var index: Int
    var time: Double
    var text: String
}

struct Lyrics: Hashable {
    var plain: String
    var synced: [LyricLine]?

    var isSynced: Bool { (synced?.isEmpty == false) }
}

// MARK: - Local library

struct UserPlaylist: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var description: String
    var songs: [Song]
    var createdAt: Date
    var updatedAt: Date
    var cover: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        songs: [Song] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        cover: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.songs = songs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cover = cover
    }

    var thumbnail: String? {
        cover ?? songs.first(where: { ($0.thumbnail?.isEmpty == false) })?.thumbnail
    }
}

struct Download: Codable, Hashable, Identifiable {
    var song: Song
    var fileName: String
    var quality: String
    var bytes: Int64
    var createdAt: Date

    var id: String { song.id }

    var fileURL: URL {
        MochyFiles.downloadsDirectory.appendingPathComponent(fileName)
    }
}

struct HistoryEntry: Codable, Hashable, Identifiable {
    var song: Song
    var playedAt: Date
    var id: String { "\(song.id)-\(playedAt.timeIntervalSince1970)" }
}

struct PlayEvent: Codable, Hashable {
    var songId: String
    var title: String
    var artist: String
    var thumbnail: String?
    var playedAt: Date
    var secondsPlayed: Int
}

// MARK: - Settings

enum HomeStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case mochyy = "Mochyy"
    case listenNow = "Listen now"
    case hopIn = "Hop in"
    var id: String { rawValue }
}

enum PlaylistStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case flow = "Flow"
    case classic = "Classic"
    case minimal = "Minimal"
    var id: String { rawValue }
}

enum PlayerStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case flagship = "Flagship"
    case classic = "Classic"
    case turntable = "Turntable"
    case video = "Full video"
    case ipod = "iPod"
    case poster = "Poster"
    case timeline = "Timeline"
    case lyrics = "Lyrics stage"
    case bedside = "Bedside clock"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .flagship: return "play.square.fill"
        case .classic: return "rectangle.portrait.fill"
        case .turntable: return "record.circle"
        case .video: return "play.rectangle.fill"
        case .ipod: return "ipod"
        case .poster: return "photo.fill"
        case .timeline: return "chart.bar.fill"
        case .lyrics: return "quote.bubble.fill"
        case .bedside: return "clock.fill"
        }
    }
}

enum IpodTheme: String, Codable, CaseIterable, Identifiable, Hashable {
    case silver = "Silver"
    case black = "Black"
    case u2 = "U2"
    case trueDark = "True dark"
    var id: String { rawValue }
}

enum IpodWheelColor: String, Codable, CaseIterable, Identifiable, Hashable {
    case theme = "Theme"
    case white = "White"
    case black = "Black"
    case red = "Red"
    var id: String { rawValue }
}

enum LyricsAnimation: String, Codable, CaseIterable, Identifiable, Hashable {
    case glow = "Glow"
    case wave = "Wave"
    case focus = "Focus"
    case plain = "Plain"
    var id: String { rawValue }
}

enum AudioQuality: String, Codable, CaseIterable, Identifiable, Hashable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    var id: String { rawValue }
}

enum DownloadQuality: String, Codable, CaseIterable, Identifiable, Hashable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    var id: String { rawValue }
}

enum RepeatMode: String, Codable, CaseIterable, Hashable {
    case off
    case all
    case one
}

enum AppTab: String, Codable, CaseIterable, Identifiable, Hashable {
    case home = "Home"
    case search = "Search"
    case library = "Library"
    case settings = "Settings"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .library: return "books.vertical"
        case .settings: return "m.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "books.vertical.fill"
        case .settings: return "m.circle.fill"
        }
    }
}

enum AppIconStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case mark = "AppIcon"
    case light = "AppIconLight"
    case blue = "AppIconBlue"
    case pink = "AppIconPink"
    case green = "AppIconGreen"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mark: return "Mochy mark"
        case .light: return "Light"
        case .blue: return "Blue"
        case .pink: return "Pink"
        case .green: return "Green"
        }
    }
}

enum SwipeAction: String, Codable, CaseIterable, Identifiable, Hashable {
    case like = "Like"
    case queue = "Add to queue"
    case download = "Download"
    case playlist = "Add to playlist"
    case none = "Nothing"
    var id: String { rawValue }
}

struct AppSettings: Codable, Equatable {
    var onboardingCompleted = false
    var profileName = "music lover"

    var accentHex = "#8E8E8E"
    var dynamicTheme = true
    var pureBlack = true
    var pureBlackMiniPlayer = true
    var homeStyle: HomeStyle = .mochyy
    var playlistStyle: PlaylistStyle = .flow
    var playerStyle: PlayerStyle = .flagship
    var coverRadius: Double = 22
    var hidePlayerThumbnail = false
    var cropAlbumArt = true

    var animations = true
    var animationSpeed = 1.0
    var blurEnabled = true
    var progressiveBlur = true

    var lyricsAnimation: LyricsAnimation = .glow
    var showLyricsTranslation = false

    var ipodTheme: IpodTheme = .silver
    var ipodWheelColor: IpodWheelColor = .theme

    var audioQuality: AudioQuality = .high
    var downloadQuality: DownloadQuality = .high
    var crossfade = false
    var crossfadeDuration = 6.0
    var skipSilence = false
    var normalizeAudio = false
    var mixWithOtherApps = false
    var resumeOnBluetooth = true

    var persistentQueue = true
    var showExplicit = true
    var showVideoSongs = true
    var autoDownloadLiked = false
    var streamFailureTimeout = 10.0

    var defaultTab: AppTab = .home
    var appIcon: AppIconStyle = .mark
    var swipeRight: SwipeAction = .like
    var swipeLeft: SwipeAction = .queue
    var playerSwipeDown = true
    var hideStatusBarInPlayer = false

    var scrobbleLastFM = false
    var lastFMUsername = ""
    var shareDiscordPresence = false

    var contentLanguage = "en"
    var contentRegion = "US"
}

// MARK: - Formatting helpers

enum TimeFormat {
    static func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        return Song.timeText(Int(seconds.rounded(.down)))
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
