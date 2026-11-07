import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - JSON helpers

typealias JSON = [String: Any]

private func obj(_ value: Any?) -> JSON? {
    if let value = value as? JSON { return value }
    if let value = value as? [String: Any] { return value }
    return nil
}

private func arr(_ value: Any?) -> [Any]? {
    value as? [Any]
}

private func str(_ value: Any?) -> String? {
    value as? String
}

private func runs(_ value: Any?) -> [JSON] {
    obj(value)?["runs"] as? [JSON] ?? []
}

private func text(_ value: Any?) -> String? {
    if let string = value as? String { return string }
    guard let value = obj(value) else { return nil }
    if let simple = value["simpleText"] as? String { return simple }
    let pieces = (value["runs"] as? [JSON])?.compactMap { $0["text"] as? String } ?? []
    return pieces.isEmpty ? nil : pieces.joined()
}

private func firstRun(_ value: Any?) -> String? {
    runs(value).first?["text"] as? String
}

private func browseIdentifier(_ run: JSON) -> String? {
    obj(run["navigationEndpoint"])?.dig("browseEndpoint", "browseId") as? String
}

private func watchVideoId(_ value: Any?) -> String? {
    guard let value = obj(value) else { return nil }
    if let watch = obj(value["watchEndpoint"]), let id = watch["videoId"] as? String { return id }
    if let nav = obj(value["navigationEndpoint"]) {
        return nav.dig("watchEndpoint", "videoId") as? String
    }
    return nil
}

private func pageType(_ value: Any?) -> String? {
    guard let value = obj(value) else { return nil }
    let nav = obj(value["navigationEndpoint"])
    if let type = nav?.dig(
        "browseEndpoint",
        "browseEndpointContextSupportedConfigs",
        "browseEndpointContextMusicConfig",
        "pageType"
    ) as? String {
        return type
    }
    return nil
}

private func thumbnailURL(_ value: Any?) -> String? {
    guard let value = obj(value) else { return nil }
    if let thumbs = value["thumbnails"] as? [JSON],
       let best = thumbs.max(by: { (($0["width"] as? Int) ?? 0) < (($1["width"] as? Int) ?? 0) }),
       let url = best["url"] as? String {
        return url
    }
    for child in value.values {
        if let found = thumbnailURL(child) { return found }
    }
    return nil
}

private func hasExplicitBadge(_ value: Any?) -> Bool {
    if let array = value as? [Any] {
        return array.contains { hasExplicitBadge($0) }
    }
    guard let value = obj(value) else { return false }
    if let icon = value.dig("musicInlineBadgeRenderer", "icon", "iconType") as? String,
       icon == "MUSIC_EXPLICIT_BADGE" {
        return true
    }
    return value.values.contains { hasExplicitBadge($0) }
}

private func firstPlaylistId(_ value: Any?, depth: Int = 0) -> String? {
    guard depth < 8, let value = obj(value) else { return nil }
    if let id = value["playlistId"] as? String, !id.isEmpty { return id }
    for child in value.values {
        if let found = firstPlaylistId(child, depth: depth + 1) { return found }
    }
    return nil
}

private func splitSegments(_ values: [JSON]) -> [[JSON]] {
    var result: [[JSON]] = []
    var current: [JSON] = []
    for run in values {
        if run["text"] as? String == " • " || run["text"] as? String == "•" {
            result.append(current)
            current = []
        } else {
            current.append(run)
        }
    }
    result.append(current)
    return result
}

private func oddRuns(_ values: [JSON]) -> [JSON] {
    values.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
}

private func parseTime(_ raw: String?) -> Int? {
    guard let raw else { return nil }
    let cleaned = raw.trimmingCharacters(in: .whitespaces)
    let pieces = cleaned.split(separator: ":").map(String.init)
    guard pieces.count == 2 || pieces.count == 3 else {
        if cleaned.count > 5 { return nil }
        return nil
    }
    guard let first = Int(pieces[0]), let last = Int(pieces[pieces.count - 1]) else { return nil }
    if pieces.count == 2 { return first * 60 + last }
    guard let middle = Int(pieces[1]) else { return nil }
    return first * 3600 + middle * 60 + last
}

private func looksLikeTimestamp(_ value: String) -> Bool {
    value.range(of: #"^\d{1,2}[:.]\d{2}([:.]\d{2})?$"#, options: .regularExpression) != nil
}

private func isMetadataLabel(_ value: String) -> Bool {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return ["song", "video", "album", "single", "ep", "playlist", "artist", "music", "episode"].contains(normalized)
}

private extension Dictionary where Key == String, Value == Any {
    func dig(_ keys: String...) -> Any? {
        var current: Any? = self
        for key in keys {
            guard let dictionary = current as? [String: Any] else { return nil }
            current = dictionary[key]
        }
        return current
    }

    func firstValue(forKey key: String, depth: Int = 0) -> Any? {
        if depth > 10 { return nil }
        if let value = self[key] { return value }
        for child in values {
            if let dictionary = child as? [String: Any],
               let value = dictionary.firstValue(forKey: key, depth: depth + 1) {
                return value
            }
            if let array = child as? [Any] {
                for item in array {
                    if let dictionary = item as? [String: Any],
                       let value = dictionary.firstValue(forKey: key, depth: depth + 1) {
                        return value
                    }
                }
            }
        }
        return nil
    }
}

// MARK: - Client contexts

struct InnerTubeClient {
    var name: String
    var version: String
    var id: String
    var userAgent: String
    var osName: String?
    var osVersion: String?
    var deviceMake: String?
    var deviceModel: String?
    var androidSdkVersion: Int?

    static let webRemix = InnerTubeClient(
        name: "WEB_REMIX",
        version: "1.20260707.12.00",
        id: "67",
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
        osName: nil,
        osVersion: nil,
        deviceMake: nil,
        deviceModel: nil,
        androidSdkVersion: nil
    )

    static let visionOS = InnerTubeClient(
        name: "VISIONOS",
        version: "0.1",
        id: "101",
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
        osName: "visionOS",
        osVersion: "1.3.0",
        deviceMake: "Apple",
        deviceModel: "RealityDevice14,1",
        androidSdkVersion: nil
    )

    static let iOS = InnerTubeClient(
        name: "IOS",
        version: "20.10.4",
        id: "5",
        userAgent: "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)",
        osName: "iPhone",
        osVersion: "18.3.2.22D82",
        deviceMake: "Apple",
        deviceModel: "iPhone16,2",
        androidSdkVersion: nil
    )

    static let androidMusic = InnerTubeClient(
        name: "ANDROID_MUSIC",
        version: "8.15.51",
        id: "21",
        userAgent: "com.google.android.apps.youtube.music/8.15.51 (Linux; U; Android 14; en-US) gzip",
        osName: "Android",
        osVersion: "14",
        deviceMake: "Google",
        deviceModel: "Pixel 8",
        androidSdkVersion: 34
    )
}

// MARK: - API

enum SearchFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case songs
    case videos
    case albums
    case artists
    case playlists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Top"
        case .songs: return "Songs"
        case .videos: return "Videos"
        case .albums: return "Albums"
        case .artists: return "Artists"
        case .playlists: return "Playlists"
        }
    }

    var params: String? {
        switch self {
        case .all: return nil
        case .songs: return "EgWKAQIIAWoKEAkQBRAKEAMQBA=="
        case .videos: return "EgWKAQIQAWoKEAkQChAFEAMQBA=="
        case .albums: return "EgWKAQIYAWoKEAkQChAFEAMQBA=="
        case .artists: return "EgWKAQIgAWoKEAkQChAFEAMQBA=="
        case .playlists: return "EgWKAQIoAWoKEAkQChAFEAMQBA=="
        }
    }
}

struct PlaybackSource {
    var url: URL
    var headers: [String: String]
    var mimeType: String
    var itag: Int?
    var bitrate: Int
    var duration: Int?
}

enum InnerTubeError: LocalizedError {
    case unavailable(String)
    case parse(String)
    case http(Int)
    case noStream

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        case .parse(let what): return "Could not parse \(what)."
        case .http(let code): return "YouTube Music returned HTTP \(code)."
        case .noStream: return "No playable audio stream was found."
        }
    }
}

final class InnerTubeAPI {
    static let shared = InnerTubeAPI()

    private let base = "https://music.youtube.com/youtubei/v1/"
    private let session: URLSession
    private let defaults = UserDefaults.standard

    private(set) var contentLanguage = "en"
    private(set) var contentRegion = "US"

    func configure(settings: AppSettings) {
        contentLanguage = settings.contentLanguage
        contentRegion = settings.contentRegion
    }

    private(set) var visitorData: String? {
        didSet {
            if let visitorData {
                defaults.set(visitorData, forKey: "mochy.visitorData")
            }
        }
    }

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 45
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = ["Accept-Language": "en-US,en;q=0.9"]
        session = URLSession(configuration: configuration)
        visitorData = defaults.string(forKey: "mochy.visitorData")
    }

    // MARK: Public pages

    func home() async throws -> HomePage {
        try await ensureVisitorData()
        let response = try await perform(endpoint: "browse", client: .webRemix, body: [
            "browseId": "FEmusic_home"
        ])

        var chips: [HomeChip] = []
        if let chipList = response.dig(
            "contents",
            "singleColumnBrowseResultsRenderer",
            "tabs"
        ) as? [JSON] {
            if let header = chipList.first?.dig(
                "tabRenderer",
                "content",
                "sectionListRenderer",
                "header",
                "chipCloudRenderer",
                "chips"
            ) as? [JSON] {
                chips = header.compactMap { raw in
                    guard let chip = obj(raw["chipCloudChipRenderer"]) else { return nil }
                    let title = firstRun(chip["text"]) ?? ""
                    guard !title.isEmpty else { return nil }
                    let browse = obj(chip["navigationEndpoint"])?["browseEndpoint"].flatMap { obj($0) }
                    return HomeChip(
                        title: title,
                        browseId: browse?["browseId"] as? String,
                        params: browse?["params"] as? String
                    )
                }
            }
        }

        let sections = parseHomeSections(response)
        return HomePage(chips: chips, sections: sections)
    }

    func browse(id: String, params: String? = nil) async throws -> HomePage {
        try await ensureVisitorData()
        var body: JSON = ["browseId": id]
        if let params { body["params"] = params }
        let response = try await perform(endpoint: "browse", client: .webRemix, body: body)
        return HomePage(chips: [], sections: parseHomeSections(response))
    }

    func search(query: String, filter: SearchFilter = .all) async throws -> [MediaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        try await ensureVisitorData()

        var body: JSON = ["query": trimmed]
        if let params = filter.params { body["params"] = params }
        let response = try await perform(endpoint: "search", client: .webRemix, body: body)

        var items: [MediaItem] = []
        var seen = Set<String>()

        if filter == .all,
           let card = findFirstRenderer(in: response, named: "musicCardShelfRenderer") {
            var synthetic = card
            synthetic["navigationEndpoint"] = card["onTap"]
            synthetic["thumbnailRenderer"] = card["thumbnail"]
            if let item = parseTwoRow(synthetic) {
                items.append(item)
                seen.insert(item.id)
            }
        }

        var renderers: [JSON] = []
        collectRenderers(response, keys: ["musicTwoRowItemRenderer", "musicResponsiveListItemRenderer"], into: &renderers)
        for renderer in renderers {
            let item: MediaItem?
            if renderer["flexColumns"] != nil {
                item = parseResponsive(renderer)
            } else {
                item = parseTwoRow(renderer)
            }
            guard let item else { continue }
            if seen.insert(item.id).inserted {
                items.append(item)
            }
        }

        if filter != .all {
            items.sort { lhs, rhs in
                kindRank(lhs) < kindRank(rhs)
            }
        } else if items.contains(where: { $0.song != nil }) {
            var richerSongs: [MediaItem] = []
            if let found = try? await search(query: trimmed, filter: .songs) {
                richerSongs.append(contentsOf: found)
            }
            let hasVideoSongs = items.contains { item in
                guard case .song(let song) = item else { return false }
                return song.isVideoSong
            }
            if hasVideoSongs, let found = try? await search(query: trimmed, filter: .videos) {
                richerSongs.append(contentsOf: found)
            }

            var songsByID: [String: Song] = [:]
            for item in richerSongs {
                guard case .song(let song) = item, songsByID[song.id] == nil else { continue }
                songsByID[song.id] = song
            }
            items = items.map { item in
                guard case .song(var song) = item, let richer = songsByID[song.id] else { return item }
                if song.artists.isEmpty { song.artists = richer.artists }
                if song.albumTitle == nil { song.albumTitle = richer.albumTitle }
                if song.albumId == nil { song.albumId = richer.albumId }
                if song.duration == nil { song.duration = richer.duration }
                if song.playlistId == nil { song.playlistId = richer.playlistId }
                if song.musicVideoType == nil { song.musicVideoType = richer.musicVideoType }
                return .song(song)
            }
        }
        return items
    }

    func searchSuggestions(query: String) async throws -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        try await ensureVisitorData()
        let response = try await perform(endpoint: "music/get_search_suggestions", client: .webRemix, body: [
            "input": trimmed
        ])
        var suggestions: [String] = []
        collectSuggestions(in: response, into: &suggestions)
        var seen = Set<String>()
        return suggestions.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    func album(browseId: String, playlistId: String? = nil) async throws -> AlbumDetail {
        try await ensureVisitorData()
        let response = try await perform(endpoint: "browse", client: .webRemix, body: [
            "browseId": browseId
        ])

        let tab = firstTabSection(response)
        let header = obj(tab?["musicResponsiveHeaderRenderer"])
            ?? findFirstRenderer(in: response, named: "musicResponsiveHeaderRenderer")
            ?? findFirstRenderer(in: response, named: "musicDetailHeaderRenderer")

        let title = firstRun(header?["title"]) ?? text(response.dig("header", "musicDetailHeaderRenderer", "title")) ?? "Album"
        let subtitleRuns = runs(header?["subtitle"])
        let straplineRuns = runs(header?["straplineTextOne"]) + runs(header?["straplineTextTwo"])

        let candidateArtistRuns = straplineRuns.isEmpty ? (splitSegments(subtitleRuns).first ?? []) : straplineRuns
        var artists: [ArtistRef] = candidateArtistRuns.compactMap { run in
            guard let name = run["text"] as? String, !name.isEmpty,
                  !isMetadataLabel(name), !looksLikeTimestamp(name),
                  Int(name.trimmingCharacters(in: .whitespaces)) == nil else { return nil }
            if let id = browseIdentifier(run), id.hasPrefix("MPREb_") { return nil }
            return ArtistRef(name: name, id: browseIdentifier(run))
        }
        if artists.isEmpty {
            artists = subtitleRuns.compactMap { run in
                guard let id = browseIdentifier(run), id.hasPrefix("UC") else { return nil }
                return ArtistRef(name: (run["text"] as? String) ?? "", id: id)
            }
        }

        let year = subtitleRuns.compactMap { run -> Int? in
            guard let raw = run["text"] as? String else { return nil }
            return Int(raw.trimmingCharacters(in: .whitespaces))
        }.last

        var resolvedPlaylist = playlistId
        if resolvedPlaylist == nil {
            resolvedPlaylist = response.dig("microformat", "microformatDataRenderer", "urlCanonical")
                .flatMap { value -> String? in
                    guard let url = value as? String else { return nil }
                    return url.components(separatedBy: "list=").last
                }
            resolvedPlaylist = resolvedPlaylist ?? firstPlaylistId(header)
        }

        let thumbnail = thumbnailURL(response["background"])
            ?? thumbnailURL(header?["thumbnail"])
            ?? thumbnailURL(obj(tab?["musicResponsiveHeaderRenderer"])?["thumbnail"])
        let description = text(header?["description"])
        let album = Album(
            id: browseId,
            playlistId: resolvedPlaylist,
            title: title,
            artists: artists,
            year: year,
            thumbnail: thumbnail,
            explicit: hasExplicitBadge(header),
            description: description
        )

        var songContents: [Any] = []
        if let shelf = obj(tab?["musicShelfRenderer"]), let contents = shelf["contents"] as? [Any] {
            songContents = contents
        } else if let contents = firstShelfContents(response, keys: ["musicShelfRenderer"]) {
            songContents = contents
        }

        var songs = songContents.compactMap { renderer -> Song? in
            guard let wrapper = obj(renderer),
                  let dictionary = obj(wrapper["musicResponsiveListItemRenderer"]) else { return nil }
            guard let song = parseResponsive(dictionary)?.song else { return nil }
            var result = song
            if result.artists.isEmpty { result.artists = artists }
            if result.albumTitle == nil { result.albumTitle = title }
            if result.albumId == nil { result.albumId = browseId }
            return result
        }
        songs = await appendContinuationSongs(to: songs, response: response, client: .webRemix, shelfName: "musicShelfRenderer")

        return AlbumDetail(album: album, songs: songs, description: description)
    }

    func playlist(id: String) async throws -> PlaylistDetail {
        try await ensureVisitorData()
        let browseId = id.hasPrefix("VL") ? id : "VL\(id)"
        let response = try await perform(endpoint: "browse", client: .webRemix, body: [
            "browseId": browseId
        ])

        let tab = firstTabSection(response)
        let header = findFirstRenderer(in: response, named: "musicResponsiveHeaderRenderer")
            ?? findFirstRenderer(in: response, named: "musicDetailHeaderRenderer")

        let title = firstRun(header?["title"]) ?? "Playlist"
        let subtitleRuns = runs(header?["subtitle"])
        let strapline = runs(header?["straplineTextOne"]).compactMap { $0["text"] as? String }.joined()
        let subtitleAuthor = subtitleRuns.compactMap { $0["text"] as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0 != "•" && !isMetadataLabel($0) && Int($0) == nil }
        let author = !strapline.isEmpty ? strapline : (subtitleAuthor ?? "YouTube Music")
        let description = text(header?["description"])
        let thumbnail = thumbnailURL(header?["thumbnail"]) ?? thumbnailURL(response["background"])

        var songContents: [Any] = []
        if let shelf = obj(tab?["musicPlaylistShelfRenderer"]), let contents = shelf["contents"] as? [Any] {
            songContents = contents
        } else if let contents = firstShelfContents(response, keys: ["musicPlaylistShelfRenderer", "musicShelfRenderer"]) {
            songContents = contents
        }

        var songs = songContents.compactMap { renderer -> Song? in
            guard let wrapper = obj(renderer),
                  let dictionary = obj(wrapper["musicResponsiveListItemRenderer"]) else { return nil }
            return parseResponsive(dictionary)?.song
        }
        songs = await appendContinuationSongs(to: songs, response: response, client: .webRemix, shelfName: "musicPlaylistShelfRenderer")

        let playlist = Playlist(
            id: id.hasPrefix("VL") ? String(id.dropFirst(2)) : id,
            title: title,
            author: author,
            thumbnail: thumbnail,
            songCount: songs.isEmpty ? nil : "\(songs.count) songs",
            description: description,
            isLocal: false
        )
        return PlaylistDetail(playlist: playlist, songs: songs, description: description)
    }

    func artist(id: String) async throws -> ArtistDetail {
        try await ensureVisitorData()
        let response = try await perform(endpoint: "browse", client: .webRemix, body: [
            "browseId": id
        ])

        let header = findFirstRenderer(in: response, named: "musicImmersiveHeaderRenderer")
            ?? findFirstRenderer(in: response, named: "musicVisualHeaderRenderer")
            ?? findFirstRenderer(in: response, named: "musicResponsiveHeaderRenderer")

        let name = firstRun(header?["title"]) ?? "Artist"
        let description = text(header?["description"])
        let subscription = obj(header?["subscriptionButton"])
        let subscribeText = subscription.flatMap { obj($0["subscribeButtonRenderer"]) }
        let subscriber = text(subscribeText?["subscriberCountText"])
            ?? runs(header?["subtitle"]).compactMap { $0["text"] as? String }.last
        let thumbnail = thumbnailURL(header?["thumbnail"]) ?? thumbnailURL(response["background"])
        let artist = Artist(id: id, name: name, thumbnail: thumbnail, subscriberCount: subscriber, description: description)

        var sections: [HomeSection] = []
        if let tab = firstTabSection(response),
           let contents = obj(tab["sectionListRenderer"])?["contents"] as? [Any] {
            sections = parseSections(contents, includeResponsive: true)
        }
        if sections.isEmpty {
            sections = parseHomeSections(response)
        }

        return ArtistDetail(artist: artist, sections: sections, description: description)
    }

    // MARK: Playback

    func stream(videoId: String, quality: AudioQuality) async throws -> PlaybackSource {
        try await ensureVisitorData()
        let clients: [InnerTubeClient] = [.iOS, .visionOS, .androidMusic, .webRemix]
        var lastReason = "This track is unavailable."

        for client in clients {
            do {
                let response = try await perform(endpoint: "player", client: client, body: [
                    "videoId": videoId,
                    "contentCheckOk": true,
                    "racyCheckOk": true
                ])

                if let status = response.dig("playabilityStatus", "status") as? String, status != "OK" {
                    lastReason = response.dig("playabilityStatus", "reason") as? String ?? lastReason
                    continue
                }

                let streaming = obj(response["streamingData"])
                let formats = (streaming?["adaptiveFormats"] as? [JSON]) ?? []
                let audioFormats = formats.filter { format in
                    (format["mimeType"] as? String)?.hasPrefix("audio/") == true
                }
                guard !audioFormats.isEmpty else { continue }

                let mp4Formats = audioFormats.filter {
                    ($0["mimeType"] as? String)?.contains("mp4") == true
                }
                let pool = mp4Formats.isEmpty ? audioFormats : mp4Formats
                let sorted = pool.sorted {
                    (($0["bitrate"] as? Int) ?? 0) < (($1["bitrate"] as? Int) ?? 0)
                }
                let chosen: JSON?
                switch quality {
                case .low: chosen = sorted.first
                case .medium: chosen = sorted[sorted.count / 2]
                case .high: chosen = sorted.last
                }
                guard let chosen,
                      let urlString = chosen["url"] as? String,
                      let url = URL(string: urlString) else { continue }

                let duration = Int((response.dig("videoDetails", "lengthSeconds") as? String) ?? "")
                let headers = requestHeaders(client: client, includeVisitor: true)
                return PlaybackSource(
                    url: url,
                    headers: headers,
                    mimeType: (chosen["mimeType"] as? String) ?? "audio/mp4",
                    itag: chosen["itag"] as? Int,
                    bitrate: (chosen["bitrate"] as? Int) ?? 0,
                    duration: duration
                )
            } catch {
                lastReason = error.localizedDescription
                continue
            }
        }

        throw InnerTubeError.unavailable(lastReason)
    }

    // MARK: Lyrics

    func lyrics(title: String, artist: String, album: String?, duration: Int?) async throws -> Lyrics? {
        let attempts = lyricTitleCandidates(title)
        for candidate in attempts {
            var components = URLComponents(string: "https://lrclib.net/api/get")
            var query = [
                URLQueryItem(name: "track_name", value: candidate),
                URLQueryItem(name: "artist_name", value: artist)
            ]
            if let album, !album.isEmpty { query.append(URLQueryItem(name: "album_name", value: album)) }
            if let duration, duration > 0 { query.append(URLQueryItem(name: "duration", value: "\(duration)")) }
            components?.queryItems = query

            guard let url = components?.url else { continue }
            var request = URLRequest(url: url)
            request.setValue("Mochy Music iOS (https://github.com/realidkroo/mochy-music)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse,
               http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? JSON {
                if let parsed = parseLyrics(json), isUsableLyrics(parsed) { return parsed }
            }
        }

        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [URLQueryItem(name: "q", value: "\(title) \(artist)")]
        if let url = components?.url {
            var request = URLRequest(url: url)
            request.setValue("Mochy Music iOS (https://github.com/realidkroo/mochy-music)", forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse,
               http.statusCode == 200,
               let list = try? JSONSerialization.jsonObject(with: data) as? [JSON] {
                for json in list {
                    if let parsed = parseLyrics(json), isUsableLyrics(parsed) { return parsed }
                }
            }
        }

        return nil
    }

    // MARK: - Requests

    private func ensureVisitorData() async throws {
        if visitorData?.isEmpty == false { return }
        guard let url = URL(string: "https://music.youtube.com/sw.js_data") else { return }
        var request = URLRequest(url: url)
        request.setValue(InnerTubeClient.webRemix.userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await session.data(for: request) else { return }
        let raw = String(decoding: data, as: UTF8.self)
        let cleaned = raw.replacingOccurrences(of: ")]}'", with: "")
        guard let json = try? JSONSerialization.jsonObject(with: Data(cleaned.utf8)) as? [Any] else { return }
        if let found = findVisitor(in: json) {
            visitorData = found
        }
    }

    private func findVisitor(in value: Any) -> String? {
        if let string = value as? String {
            if string.hasPrefix("Cg"), string.count > 20, string.count < 300 {
                return string
            }
            return nil
        }
        if let array = value as? [Any] {
            for item in array {
                if let found = findVisitor(in: item) { return found }
            }
        }
        if let dictionary = value as? [String: Any] {
            for item in dictionary.values {
                if let found = findVisitor(in: item) { return found }
            }
        }
        return nil
    }

    private func perform(endpoint: String, client: InnerTubeClient, body: JSON) async throws -> JSON {
        guard let url = URL(string: base + endpoint) else {
            throw InnerTubeError.parse("request URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: buildBody(client: client, body: body))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(client.id, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(client.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("\(contentLanguage)-\(contentRegion)", forHTTPHeaderField: "X-Goog-Language")
        request.setValue("\(contentLanguage)-\(contentRegion),\(contentLanguage);q=0.9", forHTTPHeaderField: "Accept-Language")
        if let visitorData {
            request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw InnerTubeError.parse("response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw InnerTubeError.http(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? JSON else {
            throw InnerTubeError.parse("response body")
        }
        if let newVisitor = json.dig("responseContext", "visitorData") as? String, !newVisitor.isEmpty {
            visitorData = newVisitor
        }
        return json
    }

    private func buildBody(client: InnerTubeClient, body: JSON) -> JSON {
        var clientBody: JSON = [
            "clientName": client.name,
            "clientVersion": client.version,
            "gl": contentRegion,
            "hl": contentLanguage
        ]
        if let visitorData { clientBody["visitorData"] = visitorData }
        if let osName = client.osName { clientBody["osName"] = osName }
        if let osVersion = client.osVersion { clientBody["osVersion"] = osVersion }
        if let deviceMake = client.deviceMake { clientBody["deviceMake"] = deviceMake }
        if let deviceModel = client.deviceModel { clientBody["deviceModel"] = deviceModel }
        if let sdk = client.androidSdkVersion { clientBody["androidSdkVersion"] = sdk }

        var context: JSON = [
            "client": clientBody,
            "user": ["lockedSafetyMode": false],
            "request": ["useSsl": true, "internalExperimentFlags": [], "consistencyTokenJars": []]
        ]
        if let visitorData { context["request"] = ["useSsl": true, "visitorData": visitorData] }

        var result = body
        result["context"] = context
        return result
    }

    private func requestHeaders(client: InnerTubeClient, includeVisitor: Bool) -> [String: String] {
        var headers: [String: String] = [
            "User-Agent": client.userAgent,
            "Origin": "https://music.youtube.com",
            "Referer": "https://music.youtube.com/",
            "Accept-Language": "\(contentLanguage)-\(contentRegion),en;q=0.8"
        ]
        headers["X-YouTube-Client-Name"] = client.id
        headers["X-YouTube-Client-Version"] = client.version
        if includeVisitor, let visitorData {
            headers["X-Goog-Visitor-Id"] = visitorData
        }
        return headers
    }

    // MARK: - Parsing

    private func parseHomeSections(_ response: JSON) -> [HomeSection] {
        guard let contents = response.dig(
            "contents",
            "singleColumnBrowseResultsRenderer",
            "tabs"
        ).flatMap({ value -> [Any]? in
            guard let tabs = value as? [JSON], let first = tabs.first else { return nil }
            return first.dig("tabRenderer", "content", "sectionListRenderer", "contents") as? [Any]
        }) else {
            return []
        }
        return parseSections(contents, includeResponsive: true)
    }

    private func parseSections(_ contents: [Any], includeResponsive: Bool) -> [HomeSection] {
        var sections: [HomeSection] = []
        for (index, value) in contents.enumerated() {
            guard let dictionary = obj(value) else { continue }
            if let carousel = obj(dictionary["musicCarouselShelfRenderer"]) {
                let header = obj(carousel["header"])?["musicCarouselShelfBasicHeaderRenderer"].flatMap { obj($0) }
                let title = firstRun(header?["title"]) ?? ""
                let label = firstRun(header?["strapline"])
                let more = header?.dig("moreContentButton", "buttonRenderer", "navigationEndpoint", "browseEndpoint", "browseId") as? String
                let moreParams = header?.dig("moreContentButton", "buttonRenderer", "navigationEndpoint", "browseEndpoint", "params") as? String
                guard let rawItems = carousel["contents"] as? [Any] else { continue }
                var items: [MediaItem] = []
                for raw in rawItems {
                    guard let itemDict = obj(raw) else { continue }
                    if let twoRow = obj(itemDict["musicTwoRowItemRenderer"]), let item = parseTwoRow(twoRow) {
                        items.append(item)
                    } else if includeResponsive, let responsive = obj(itemDict["musicResponsiveListItemRenderer"]),
                              let item = parseResponsive(responsive) {
                        items.append(item)
                    }
                }
                if !items.isEmpty {
                    sections.append(HomeSection(id: "carousel-\(index)-\(title)", title: title, subtitle: label, items: items, moreId: more, moreParams: moreParams))
                }
            } else if let shelf = obj(dictionary["musicShelfRenderer"]) {
                let title = firstRun(shelf["title"]) ?? (includeResponsive ? "Music" : "")
                guard let rawItems = shelf["contents"] as? [Any] else { continue }
                var items: [MediaItem] = []
                for raw in rawItems {
                    guard let itemDict = obj(raw), let responsive = obj(itemDict["musicResponsiveListItemRenderer"]) else { continue }
                    if let item = parseResponsive(responsive) { items.append(item) }
                }
                if !items.isEmpty && !title.isEmpty {
                    let more = shelf.dig("moreContentButton", "buttonRenderer", "navigationEndpoint", "browseEndpoint", "browseId") as? String
                    let moreParams = shelf.dig("moreContentButton", "buttonRenderer", "navigationEndpoint", "browseEndpoint", "params") as? String
                    sections.append(HomeSection(id: "shelf-\(index)-\(title)", title: title, subtitle: nil, items: items, moreId: more, moreParams: moreParams))
                }
            }
        }
        return sections
    }

    private func fallbackArtists(_ name: String?) -> [ArtistRef] {
        guard let name, !name.isEmpty, !isMetadataLabel(name), !looksLikeTimestamp(name) else { return [] }
        return [ArtistRef(name: name, id: nil)]
    }

    private func parseTwoRow(_ renderer: JSON) -> MediaItem? {
        let title = firstRun(renderer["title"]) ?? text(renderer["title"]) ?? ""
        let subtitleRuns = runs(renderer["subtitle"])
        let subtitleSegments = splitSegments(subtitleRuns)
        let type = pageType(renderer)
        let navBrowse = renderer.dig("navigationEndpoint", "browseEndpoint", "browseId") as? String
        let videoId = renderer.dig("navigationEndpoint", "watchEndpoint", "videoId") as? String
        let thumb = thumbnailURL(renderer["thumbnailRenderer"]) ?? thumbnailURL(renderer["thumbnail"])
        let explicit = hasExplicitBadge(renderer["subtitleBadges"])

        if let videoId, type == nil {
            let odd = oddRuns(subtitleSegments.first ?? [])
            let artists = odd.compactMap { run -> ArtistRef? in
                guard let name = run["text"] as? String, !name.isEmpty, !looksLikeTimestamp(name), !isMetadataLabel(name) else { return nil }
                if let id = browseIdentifier(run), id.hasPrefix("MPREb_") { return nil }
                return ArtistRef(name: name, id: browseIdentifier(run))
            }
            let albumRun = subtitleRuns.first { browseIdentifier($0)?.hasPrefix("MPREb_") == true }
            let albumTitle = albumRun?["text"] as? String
            let albumId = albumRun.flatMap { browseIdentifier($0) }
            let playlistId = firstPlaylistId(renderer["thumbnailOverlay"])
            return .song(Song(
                id: videoId,
                title: title,
                artists: artists.isEmpty ? fallbackArtists(firstRun(renderer["subtitle"])) : artists,
                albumTitle: albumTitle,
                albumId: albumId,
                thumbnail: thumb,
                explicit: explicit,
                musicVideoType: renderer.dig(
                    "overlay",
                    "musicItemThumbnailOverlayRenderer",
                    "content",
                    "musicPlayButtonRenderer",
                    "playNavigationEndpoint",
                    "watchEndpoint",
                    "watchEndpointMusicSupportedConfigs",
                    "watchEndpointMusicConfig",
                    "musicVideoType"
                ) as? String,
                playlistId: playlistId
            ))
        }

        if type == "MUSIC_PAGE_TYPE_ARTIST" || type == "MUSIC_PAGE_TYPE_LIBRARY_ARTIST" || (navBrowse?.hasPrefix("UC") == true) {
            guard let navBrowse else { return nil }
            let name = runs(renderer["title"]).last?["text"] as? String ?? title
            return .artist(Artist(id: navBrowse, name: name, thumbnail: thumb, subscriberCount: firstRun(renderer["subtitle"]), description: nil))
        }

        if type == "MUSIC_PAGE_TYPE_PLAYLIST" || navBrowse?.hasPrefix("VL") == true {
            guard let navBrowse else { return nil }
            let id = navBrowse.hasPrefix("VL") ? String(navBrowse.dropFirst(2)) : navBrowse
            return .playlist(Playlist(
                id: id,
                title: title,
                author: subtitleSegments.dropFirst().flatMap { $0 }.compactMap { $0["text"] as? String }
                    .first { !$0.isEmpty && $0 != "•" && !isMetadataLabel($0) && Int($0) == nil } ?? "YouTube Music",
                thumbnail: thumb,
                songCount: nil,
                description: nil,
                isLocal: false
            ))
        }

        if type == "MUSIC_PAGE_TYPE_ALBUM" || type == "MUSIC_PAGE_TYPE_AUDIOBOOK" || navBrowse?.hasPrefix("MPREb_") == true {
            guard let navBrowse else { return nil }
            let artists = subtitleSegments.dropFirst().flatMap { oddRuns($0) }.compactMap { run -> ArtistRef? in
                guard let name = run["text"] as? String, !name.isEmpty,
                      !isMetadataLabel(name), Int(name.trimmingCharacters(in: .whitespaces)) == nil else { return nil }
                return ArtistRef(name: name, id: browseIdentifier(run))
            }
            let year = subtitleSegments.reversed().compactMap { segment -> Int? in
                segment.first?["text"].flatMap { Int(($0 as? String ?? "").trimmingCharacters(in: .whitespaces)) }
            }.first
            let playlistId = firstPlaylistId(renderer["thumbnailOverlay"]) ?? firstPlaylistId(renderer["menu"])
            return .album(Album(
                id: navBrowse,
                playlistId: playlistId,
                title: title,
                artists: artists,
                year: year,
                thumbnail: thumb,
                explicit: explicit,
                description: nil
            ))
        }

        if let videoId {
            return .song(Song(id: videoId, title: title, thumbnail: thumb, explicit: explicit))
        }
        return nil
    }

    private func parseResponsive(_ renderer: JSON) -> MediaItem? {
        let flex = renderer["flexColumns"] as? [JSON] ?? []
        let title = flex.first.flatMap { text($0.dig("musicResponsiveListItemFlexColumnRenderer", "text")) }
            ?? text(renderer["title"])
            ?? ""
        let secondaryRuns = (flex.count > 1 ? runs(flex[1].dig("musicResponsiveListItemFlexColumnRenderer", "text")) : [])
        let segments = splitSegments(secondaryRuns)
        let type = pageType(renderer)
        let navBrowse = renderer.dig("navigationEndpoint", "browseEndpoint", "browseId") as? String
        let videoId = (renderer["playlistItemData"] as? JSON)?["videoId"] as? String
            ?? renderer.dig("navigationEndpoint", "watchEndpoint", "videoId") as? String
        let thumb = thumbnailURL(renderer["thumbnail"])
        let explicit = hasExplicitBadge(renderer["badges"])
        let durationText = (renderer["fixedColumns"] as? [JSON])?.first.flatMap {
            text($0.dig("musicResponsiveListItemFixedColumnRenderer", "text"))
                ?? text($0.dig("musicResponsiveListItemFlexColumnRenderer", "text"))
        }

        if type == "MUSIC_PAGE_TYPE_ARTIST" || type == "MUSIC_PAGE_TYPE_LIBRARY_ARTIST" || (navBrowse?.hasPrefix("UC") == true && videoId == nil) {
            guard let navBrowse else { return nil }
            return .artist(Artist(
                id: navBrowse,
                name: title,
                thumbnail: thumb,
                subscriberCount: segments.last?.first?["text"] as? String,
                description: nil
            ))
        }

        if type == "MUSIC_PAGE_TYPE_PLAYLIST" || (navBrowse?.hasPrefix("VL") == true && videoId == nil) {
            guard let navBrowse else { return nil }
            let id = navBrowse.hasPrefix("VL") ? String(navBrowse.dropFirst(2)) : navBrowse
            return .playlist(Playlist(
                id: id,
                title: title,
                author: segments.first?.first?["text"] as? String ?? "YouTube Music",
                thumbnail: thumb,
                songCount: flex.count > 1 ? runs(flex[1].dig("musicResponsiveListItemFlexColumnRenderer", "text")).last?["text"] as? String : nil,
                description: nil,
                isLocal: false
            ))
        }

        if type == "MUSIC_PAGE_TYPE_ALBUM" || type == "MUSIC_PAGE_TYPE_AUDIOBOOK" || (navBrowse?.hasPrefix("MPREb_") == true && videoId == nil) {
            guard let navBrowse else { return nil }
            let artistRuns = segments.count > 1 ? oddRuns(segments[1]) : []
            let artists = artistRuns.compactMap { run -> ArtistRef? in
                guard let name = run["text"] as? String, !name.isEmpty, !looksLikeTimestamp(name), !isMetadataLabel(name) else { return nil }
                return ArtistRef(name: name, id: browseIdentifier(run))
            }
            let year = segments.count > 2 ? segments[2].first?["text"].flatMap { Int($0 as? String ?? "") } : nil
            return .album(Album(
                id: navBrowse,
                playlistId: firstPlaylistId(renderer["overlay"]) ?? firstPlaylistId(renderer["menu"]),
                title: title,
                artists: artists,
                year: year,
                thumbnail: thumb,
                explicit: explicit,
                description: nil
            ))
        }

        guard let videoId else { return nil }
        let artistRuns = segments.first ?? []
        var artists = oddRuns(artistRuns).compactMap { run -> ArtistRef? in
            guard let name = run["text"] as? String, !name.isEmpty,
                  !looksLikeTimestamp(name), !isMetadataLabel(name) else { return nil }
            return ArtistRef(name: name, id: browseIdentifier(run))
        }
        var albumTitle: String?
        var albumId: String?
        for segment in segments.dropFirst() {
            if let run = segment.first(where: { browseIdentifier($0)?.hasPrefix("MPREb_") == true }) {
                albumTitle = run["text"] as? String
                albumId = browseIdentifier(run)
                break
            }
        }
        if albumTitle == nil, flex.count > 2 {
            let textValue = flex[2].dig("musicResponsiveListItemFlexColumnRenderer", "text")
            if let first = runs(textValue).first, let id = browseIdentifier(first), id.hasPrefix("MPREb_") {
                albumTitle = first["text"] as? String
                albumId = id
            }
        }
        if artists.isEmpty, let first = secondaryRuns.first?["text"] as? String,
           !looksLikeTimestamp(first), !isMetadataLabel(first) {
            artists = [ArtistRef(name: first, id: nil)]
        }

        let duration = parseTime(durationText)
            ?? segments.last?.first?["text"].flatMap { parseTime($0 as? String) }

        return .song(Song(
            id: videoId,
            title: title,
            artists: artists,
            albumTitle: albumTitle,
            albumId: albumId,
            duration: duration,
            thumbnail: thumb,
            explicit: explicit,
            musicVideoType: renderer.dig(
                "overlay",
                "musicItemThumbnailOverlayRenderer",
                "content",
                "musicPlayButtonRenderer",
                "playNavigationEndpoint",
                "watchEndpoint",
                "watchEndpointMusicSupportedConfigs",
                "watchEndpointMusicConfig",
                "musicVideoType"
            ) as? String,
            playlistId: firstPlaylistId(renderer["overlay"])
        ))
    }

    private func continuationToken(in value: Any?) -> String? {
        if let dictionary = obj(value) {
            if let data = obj(dictionary["nextContinuationData"]),
               let token = data["continuation"] as? String, !token.isEmpty {
                return token
            }
            if let command = obj(dictionary["continuationCommand"]),
               let token = command["token"] as? String, !token.isEmpty {
                return token
            }
            for key in ["continuations", "continuationItemRenderer", "contents", "tabs", "sectionListRenderer", "secondaryContents"] {
                if let found = continuationToken(in: dictionary[key]) { return found }
            }
            for child in dictionary.values {
                if let found = continuationToken(in: child) { return found }
            }
        }
        if let array = value as? [Any] {
            for child in array {
                if let found = continuationToken(in: child) { return found }
            }
        }
        return nil
    }

    private func continuationSongsContents(_ response: JSON) -> [Any] {
        if let contents = response.dig("continuationContents", "musicPlaylistShelfContinuation", "contents") as? [Any] {
            return contents
        }
        if let contents = response.dig("continuationContents", "musicShelfContinuation", "contents") as? [Any] {
            return contents
        }
        if let actions = response["onResponseReceivedActions"] as? [Any] {
            var result: [Any] = []
            for action in actions {
                guard let dictionary = obj(action) else { continue }
                if let items = dictionary.dig("appendContinuationItemsAction", "continuationItems") as? [Any] {
                    result.append(contentsOf: items)
                }
                if let items = dictionary.dig("reloadContinuationItemsCommand", "continuationItems") as? [Any] {
                    result.append(contentsOf: items)
                }
            }
            return result
        }
        return []
    }

    private func appendContinuationSongs(
        to songs: [Song],
        response: JSON,
        client: InnerTubeClient,
        shelfName: String
    ) async -> [Song] {
        var songs = songs
        guard let shelf = findFirstRenderer(in: response, named: shelfName) else { return songs }
        var seen = Set(songs.map(\.id))
        var tokens = Set<String>()
        var token = continuationToken(in: shelf["continuations"])
        if token == nil, let contents = shelf["contents"] as? [Any], let last = contents.last {
            token = continuationToken(in: last)
        }
        var pages = 0
        while let current = token, tokens.insert(current).inserted, pages < 60 {
            pages += 1
            guard let more = try? await perform(endpoint: "browse", client: client, body: ["continuation": current]) else {
                break
            }
            let contents = continuationSongsContents(more)
            if contents.isEmpty { break }
            for renderer in contents {
                guard let wrapper = obj(renderer) else { continue }
                let dictionary = obj(wrapper["musicResponsiveListItemRenderer"])
                    ?? (wrapper["flexColumns"] != nil ? wrapper : nil)
                guard let dictionary, let song = parseResponsive(dictionary)?.song,
                      seen.insert(song.id).inserted else { continue }
                songs.append(song)
            }
            token = continuationToken(in: more["continuationContents"])
                ?? continuationToken(in: more["onResponseReceivedActions"])
        }
        return songs
    }

    private func firstTabSection(_ response: JSON) -> JSON? {
        if let tabs = response.dig("contents", "singleColumnBrowseResultsRenderer", "tabs") as? [JSON],
           let first = tabs.first,
           let contents = first.dig("tabRenderer", "content", "sectionListRenderer", "contents") as? [JSON] {
            return contents.first
        }
        if let tabs = response.dig("contents", "twoColumnBrowseResultsRenderer", "tabs") as? [JSON],
           let first = tabs.first,
           let contents = first.dig("tabRenderer", "content", "sectionListRenderer", "contents") as? [JSON] {
            return contents.first
        }
        if let contents = response.dig("contents", "twoColumnBrowseResultsRenderer", "secondaryContents", "sectionListRenderer", "contents") as? [JSON] {
            return contents.first
        }
        return nil
    }

    private func firstShelfContents(_ response: JSON, keys: [String]) -> [Any]? {
        var sections: [JSON] = []
        if let tabs = response.dig("contents", "singleColumnBrowseResultsRenderer", "tabs") as? [JSON],
           let first = tabs.first,
           let contents = first.dig("tabRenderer", "content", "sectionListRenderer", "contents") as? [JSON] {
            sections.append(contentsOf: contents)
        }
        if let tabs = response.dig("contents", "twoColumnBrowseResultsRenderer", "tabs") as? [JSON],
           let first = tabs.first,
           let contents = first.dig("tabRenderer", "content", "sectionListRenderer", "contents") as? [JSON] {
            sections.append(contentsOf: contents)
        }
        if let contents = response.dig("contents", "twoColumnBrowseResultsRenderer", "secondaryContents", "sectionListRenderer", "contents") as? [JSON] {
            sections.append(contentsOf: contents)
        }

        guard !sections.isEmpty else { return nil }
        for section in sections {
            for key in keys {
                if let contents = obj(section[key])?["contents"] as? [Any] {
                    return contents
                }
            }
        }
        return nil
    }

    private func collectRenderers(_ value: Any, keys: Set<String>, into result: inout [JSON]) {
        if let dictionary = value as? [String: Any] {
            for key in keys {
                if let renderer = dictionary[key] as? JSON {
                    result.append(renderer)
                }
            }
            for child in dictionary.values {
                collectRenderers(child, keys: keys, into: &result)
            }
        } else if let array = value as? [Any] {
            for item in array {
                collectRenderers(item, keys: keys, into: &result)
            }
        }
    }

    private func findFirstRenderer(in value: Any, named name: String, depth: Int = 0) -> JSON? {
        guard depth < 14 else { return nil }
        if let dictionary = value as? [String: Any] {
            if let renderer = dictionary[name] as? JSON { return renderer }
            for child in dictionary.values {
                if let found = findFirstRenderer(in: child, named: name, depth: depth + 1) { return found }
            }
        } else if let array = value as? [Any] {
            for item in array {
                if let found = findFirstRenderer(in: item, named: name, depth: depth + 1) { return found }
            }
        }
        return nil
    }

    private func collectSuggestions(in value: Any, into result: inout [String]) {
        if let dictionary = value as? [String: Any] {
            if let suggestion = dictionary["searchSuggestionRenderer"] as? JSON,
               let rendered = text(suggestion["suggestion"]) {
                result.append(rendered)
            }
            for child in dictionary.values {
                collectSuggestions(in: child, into: &result)
            }
        } else if let array = value as? [Any] {
            for item in array {
                collectSuggestions(in: item, into: &result)
            }
        }
    }

    private func kindRank(_ item: MediaItem) -> Int {
        switch item {
        case .song: return 0
        case .album: return 1
        case .artist: return 2
        case .playlist: return 3
        }
    }

    // MARK: Lyrics parsing

    private func lyricTitleCandidates(_ title: String) -> [String] {
        var candidates = [title]
        let patterns = [
            #"\s*[\(\[](official|lyrics?|audio|video|visualizer|music video|hd|hq)[^\)\]]*[\)\]]"#,
            #"\s*feat\..*$"#,
            #"\s*ft\..*$"#
        ]
        for pattern in patterns {
            if let range = title.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let trimmed = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !candidates.contains(trimmed) { candidates.append(trimmed) }
            }
        }
        return candidates
    }

    private func isUsableLyrics(_ lyrics: Lyrics) -> Bool {
        if lyrics.plain == "Instrumental" { return true }
        let plain = lyrics.plain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty else { return false }
        let syncedCount = lyrics.synced?.count ?? 0
        return syncedCount > 1 || plain.count >= 60
    }

    private func parseLyrics(_ json: JSON) -> Lyrics? {
        if (json["instrumental"] as? Bool) == true {
            return Lyrics(plain: "Instrumental", synced: nil)
        }
        if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
            let parsed = parseLRC(synced)
            if !parsed.isEmpty {
                return Lyrics(plain: synced, synced: parsed)
            }
        }
        if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
            return Lyrics(plain: plain, synced: nil)
        }
        return nil
    }

    private func parseLRC(_ source: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let pattern = try? NSRegularExpression(pattern: #"\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]"#)
        for rawLine in source.components(separatedBy: .newlines) {
            guard let regex = pattern else { continue }
            let ns = rawLine as NSString
            let matches = regex.matches(in: rawLine, range: NSRange(location: 0, length: ns.length))
            guard let last = matches.last else { continue }
            let textStart = last.range.location + last.range.length
            let lineText = ns.substring(from: textStart).trimmingCharacters(in: .whitespaces)
            if lineText.isEmpty { continue }
            for match in matches {
                let minutes = Double(ns.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(ns.substring(with: match.range(at: 2))) ?? 0
                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let raw = ns.substring(with: match.range(at: 3))
                    fraction = (Double(raw) ?? 0) / pow(10, Double(raw.count))
                }
                let time = minutes * 60 + seconds + fraction
                lines.append(LyricLine(index: lines.count, time: time, text: lineText))
            }
        }
        return lines.sorted { $0.time < $1.time }.enumerated().map { index, line in
            LyricLine(index: index, time: line.time, text: line.text)
        }
    }
}
