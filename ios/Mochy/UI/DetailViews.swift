import SwiftUI

// MARK: - Router

struct RouteDestination: View {
    var route: AppRoute

    var body: some View {
        switch route {
        case .album(let id, let playlistId):
            AlbumDetailView(browseId: id, playlistId: playlistId)
        case .playlist(let id):
            PlaylistDetailView(playlistId: id)
        case .artist(let id):
            ArtistDetailView(artistId: id)
        case .localPlaylist(let id):
            LocalPlaylistDetailView(playlistId: id)
        case .likedSongs:
            LikedSongsView()
        case .downloads:
            DownloadsManageView()
        case .history:
            HistoryView()
        case .stats:
            StatsView()
        case .profile:
            ProfileView()
        case .songs(let title, let songs):
            SongsListView(title: title, songs: songs)
        }
    }
}

// MARK: - Collection header

struct CollectionHeader: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette

    var eyebrow: String
    var title: String
    var subtitle: String
    var description: String?
    var artwork: String?
    var isCircle = false
    var songs: [Song]
    var extraMenu: AnyView?

    var body: some View {
        VStack(spacing: 14) {
            RemoteArtwork(
                url: artwork,
                cornerRadius: 22,
                aspectRatio: nil,
                isCircle: isCircle
            )
            .frame(width: 218, height: 218)
            .shadow(color: .black.opacity(0.35), radius: 28, y: 16)

            VStack(spacing: 5) {
                Text(eyebrow.uppercased())
                    .font(MochyFont.semibold(9))
                    .tracking(1.5)
                    .foregroundStyle(palette.secondaryText)
                Text(title)
                    .font(MochyFont.bold(26))
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(subtitle)
                    .font(MochyFont.medium(12))
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let description, !description.isEmpty {
                Text(description)
                    .font(MochyFont.regular(12))
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
            }

            HStack(spacing: 10) {
                Button {
                    guard !songs.isEmpty else { return }
                    store.player.setShuffle(false)
                    store.play(songs, startingAt: 0)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Play")
                            .font(MochyFont.semibold(14))
                    }
                    .foregroundStyle(palette.accentText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(palette.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(songs.isEmpty)
                .opacity(songs.isEmpty ? 0.45 : 1)

                Button {
                    guard !songs.isEmpty else { return }
                    store.player.setShuffle(true)
                    store.play(songs, startingAt: Int.random(in: 0..<songs.count))
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13, weight: .bold))
                        Text("Shuffle")
                            .font(MochyFont.semibold(14))
                    }
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6))
                }
                .buttonStyle(.plain)
                .disabled(songs.isEmpty)
                .opacity(songs.isEmpty ? 0.45 : 1)

                if let extraMenu {
                    Menu {
                        extraMenu
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Album

struct AlbumDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var browseId: String
    var playlistId: String?

    @State private var detail: AlbumDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var songs: [Song] { detail?.songs ?? [] }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView().tint(palette.accent).padding(.top, 120)
                } else if let errorMessage {
                    EmptyStateView(
                        icon: "exclamationmark.circle",
                        title: "Couldn't load album",
                        message: errorMessage,
                        actionTitle: "Retry"
                    ) {
                        Task { await load() }
                    }
                } else if let detail {
                    CollectionHeader(
                        eyebrow: "Album",
                        title: detail.album.title,
                        subtitle: subtitle(detail.album),
                        description: detail.description,
                        artwork: detail.album.thumbnail,
                        songs: detail.songs,
                        extraMenu: AnyView(downloadMenu(songs: detail.songs))
                    )
                    .padding(.bottom, 4)

                    LazyVStack(spacing: 1) {
                        ForEach(Array(detail.songs.enumerated()), id: \.element.id) { index, song in
                            SongRow(
                                song: song,
                                index: index,
                                showDuration: true,
                                contextSongs: detail.songs
                            )
                            Divider().overlay(palette.separator).padding(.leading, 62)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.background, for: .navigationBar)
        .task { await load() }
    }

    private func subtitle(_ album: Album) -> String {
        var pieces: [String] = []
        if !album.artistLine.isEmpty { pieces.append(album.artistLine) }
        if let year = album.year { pieces.append(String(year)) }
        pieces.append("\(songs.count) songs")
        return pieces.joined(separator: " · ")
    }

    private func downloadMenu(songs: [Song]) -> some View {
        Group {
            Button {
                for song in songs where !store.isDownloaded(song) {
                    store.download(song)
                }
            } label: {
                Label("Download album", systemImage: "arrow.down.circle")
            }
            if let album = detail?.album, let id = album.artists.first?.id {
                NavigationLink(value: AppRoute.artist(id: id)) {
                    Label("Go to artist", systemImage: "person")
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await InnerTubeAPI.shared.album(browseId: browseId, playlistId: playlistId)
            detail = result
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Playlist

struct PlaylistDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var playlistId: String

    @State private var detail: PlaylistDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView().tint(palette.accent).padding(.top, 120)
                } else if let errorMessage {
                    EmptyStateView(
                        icon: "exclamationmark.circle",
                        title: "Couldn't load playlist",
                        message: errorMessage,
                        actionTitle: "Retry"
                    ) {
                        Task { await load() }
                    }
                } else if let detail {
                    CollectionHeader(
                        eyebrow: "Playlist",
                        title: detail.playlist.title,
                        subtitle: subtitle(detail),
                        description: detail.description,
                        artwork: detail.playlist.thumbnail,
                        songs: detail.songs,
                        extraMenu: AnyView(downloadMenu(songs: detail.songs))
                    )
                    .padding(.bottom, 4)

                    LazyVStack(spacing: 1) {
                        ForEach(Array(detail.songs.enumerated()), id: \.element.id) { index, song in
                            SongRow(
                                song: song,
                                index: index,
                                showDuration: true,
                                contextSongs: detail.songs
                            )
                            Divider().overlay(palette.separator).padding(.leading, 62)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.background, for: .navigationBar)
        .task { await load() }
    }

    private func subtitle(_ detail: PlaylistDetail) -> String {
        var pieces = [detail.playlist.author]
        if !detail.songs.isEmpty { pieces.append("\(detail.songs.count) songs") }
        return pieces.joined(separator: " · ")
    }

    private func downloadMenu(songs: [Song]) -> some View {
        Button {
            for song in songs where !store.isDownloaded(song) {
                store.download(song)
            }
        } label: {
            Label("Download playlist", systemImage: "arrow.down.circle")
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await InnerTubeAPI.shared.playlist(id: playlistId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Artist

struct ArtistDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette

    var artistId: String

    @State private var detail: ArtistDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var allSongs: [Song] {
        detail?.sections.flatMap { $0.items.compactMap(\.song) } ?? []
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                if isLoading {
                    ProgressView().tint(palette.accent).padding(.top, 120)
                } else if let errorMessage {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.exclamationmark",
                        title: "Couldn't load artist",
                        message: errorMessage,
                        actionTitle: "Retry"
                    ) {
                        Task { await load() }
                    }
                } else if let detail {
                    CollectionHeader(
                        eyebrow: "Artist",
                        title: detail.artist.name,
                        subtitle: detail.artist.subscriberCount ?? "Artist",
                        description: detail.description,
                        artwork: detail.artist.thumbnail,
                        isCircle: true,
                        songs: allSongs
                    )

                    ForEach(detail.sections) { section in
                        if let songs = sectionSongs(section), !songs.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                SectionHeader(title: section.title)
                                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                                    SongRow(song: song, index: index, contextSongs: songs)
                                }
                            }
                        } else if !section.items.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: section.title, subtitle: section.subtitle)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .top, spacing: 14) {
                                        ForEach(section.items) { item in
                                            MediaCard(item: item, width: 142, contextSongs: section.items.compactMap(\.song))
                                        }
                                    }
                                }
                                .padding(.horizontal, -18)
                                .contentMargins(.horizontal, 18)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.background, for: .navigationBar)
        .task { await load() }
    }

    private func sectionSongs(_ section: HomeSection) -> [Song]? {
        let songs = section.items.compactMap(\.song)
        return songs.isEmpty ? nil : songs
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await InnerTubeAPI.shared.artist(id: artistId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Local playlist

struct LocalPlaylistDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var playlistId: String

    @State private var showRename = false
    @State private var showDelete = false
    @State private var newName = ""

    private var playlist: UserPlaylist? {
        store.playlist(id: playlistId)
    }

    var body: some View {
        Group {
            if let playlist {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        CollectionHeader(
                            eyebrow: "Your playlist",
                            title: playlist.name,
                            subtitle: "\(playlist.songs.count) songs",
                            description: playlist.description.isEmpty ? nil : playlist.description,
                            artwork: playlist.thumbnail,
                            songs: playlist.songs,
                            extraMenu: AnyView(menu(playlist))
                        )

                        if playlist.songs.isEmpty {
                            EmptyStateView(
                                icon: "music.note",
                                title: "This playlist is empty",
                                message: "Add songs from any track's menu."
                            )
                        } else {
                            LazyVStack(spacing: 1) {
                                ForEach(Array(playlist.songs.enumerated()), id: \.element.id) { index, song in
                                    SongRow(song: song, index: index, contextSongs: playlist.songs)
                                        .contextMenu {
                                            Button("Remove from playlist", role: .destructive) {
                                                store.remove(song, from: playlist)
                                            }
                                        }
                                    Divider().overlay(palette.separator).padding(.leading, 62)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .background(palette.background)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(palette.background, for: .navigationBar)
                .alert("Rename playlist", isPresented: $showRename) {
                    TextField("Playlist name", text: $newName)
                    Button("Save") {
                        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { store.renamePlaylist(playlist, name: trimmed) }
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .confirmationDialog("Delete this playlist?", isPresented: $showDelete, titleVisibility: .visible) {
                    Button("Delete playlist", role: .destructive) {
                        store.deletePlaylist(playlist)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } else {
                EmptyStateView(icon: "questionmark.folder", title: "Playlist not found", message: "It may have been deleted.")
                    .background(palette.background)
            }
        }
    }

    private func menu(_ playlist: UserPlaylist) -> some View {
        Group {
            Button {
                newName = playlist.name
                showRename = true
            } label: {
                Label("Rename playlist", systemImage: "pencil")
            }
            Button {
                for song in playlist.songs where !store.isDownloaded(song) {
                    store.download(song)
                }
            } label: {
                Label("Download playlist", systemImage: "arrow.down.circle")
            }
            Button(role: .destructive) {
                showDelete = true
            } label: {
                Label("Delete playlist", systemImage: "trash")
            }
        }
    }
}

// MARK: - Special collections

struct LikedSongsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#F06A6A"), Color(hex: "#8E3A67")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 214, height: 214)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 74, weight: .bold))
                            .foregroundStyle(.white.opacity(0.94))
                    }
                    .shadow(color: .black.opacity(0.3), radius: 24, y: 14)

                    VStack(spacing: 5) {
                        Text("COLLECTION")
                            .font(MochyFont.semibold(9))
                            .tracking(1.5)
                            .foregroundStyle(palette.secondaryText)
                        Text("Liked songs")
                            .font(MochyFont.bold(27))
                            .foregroundStyle(palette.text)
                        Text("\(store.likedSongs.count) songs")
                            .font(MochyFont.medium(12))
                            .foregroundStyle(palette.secondaryText)
                    }

                    HStack(spacing: 10) {
                        Button {
                            guard !store.likedSongs.isEmpty else { return }
                            store.player.setShuffle(false)
                            store.play(store.likedSongs, startingAt: 0)
                        } label: {
                            Label("Play", systemImage: "play.fill")
                                .font(MochyFont.semibold(14))
                                .foregroundStyle(palette.accentText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(palette.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Button {
                            guard !store.likedSongs.isEmpty else { return }
                            store.player.setShuffle(true)
                            store.play(store.likedSongs, startingAt: Int.random(in: 0..<store.likedSongs.count))
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .font(MochyFont.semibold(14))
                                .foregroundStyle(palette.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6)
                }

                if store.likedSongs.isEmpty {
                    EmptyStateView(
                        icon: "heart",
                        title: "No liked songs",
                        message: "Tap the heart on a track to save it here."
                    )
                } else {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(store.likedSongs.enumerated()), id: \.element.id) { index, song in
                            SongRow(song: song, index: index, contextSongs: store.likedSongs)
                            Divider().overlay(palette.separator).padding(.leading, 62)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.background, for: .navigationBar)
    }
}

struct DownloadsManageView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette

    @State private var confirmDeleteAll = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent.opacity(0.8), palette.accent.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .frame(width: 78, height: 78)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Downloads")
                            .font(MochyFont.bold(24))
                            .foregroundStyle(palette.text)
                        Text("\(store.downloads.count) songs · \(store.downloadBytesText)")
                            .font(MochyFont.medium(12))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                }
                .mochyCard(radius: 18, padding: 14)

                if !store.downloads.isEmpty {
                    HStack(spacing: 10) {
                        Button {
                            store.play(store.downloads.map(\.song), startingAt: 0)
                        } label: {
                            Label("Play all", systemImage: "play.fill")
                                .font(MochyFont.semibold(13))
                                .foregroundStyle(palette.accentText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(palette.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Button {
                            confirmDeleteAll = true
                        } label: {
                            Label("Delete all", systemImage: "trash")
                                .font(MochyFont.semibold(13))
                                .foregroundStyle(Color(hex: "#F06A6A"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color.white.opacity(0.07), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if store.downloads.isEmpty {
                    EmptyStateView(
                        icon: "arrow.down.circle",
                        title: "No downloads yet",
                        message: "Downloaded songs are available offline and play automatically."
                    )
                } else {
                    LazyVStack(spacing: 1) {
                        ForEach(store.downloads) { download in
                            SongRow(song: download.song, contextSongs: store.downloads.map(\.song))
                                .contextMenu {
                                    Button("Remove download", role: .destructive) {
                                        store.deleteDownload(download)
                                    }
                                }
                            Divider().overlay(palette.separator).padding(.leading, 62)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(palette.background)
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.background, for: .navigationBar)
        .confirmationDialog("Delete all downloads?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) {
                store.deleteAllDownloads()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette

    @State private var confirmClear = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    PageHeader(
                        eyebrow: "Listening",
                        title: "History",
                        subtitle: "\(store.recentlyPlayed.count) recent plays"
                    )
                    Spacer()
                }
                if store.recentlyPlayed.isEmpty {
                    EmptyStateView(icon: "clock", title: "No history yet", message: "Songs you play will show up here.")
                } else {
                    HStack {
                        Button {
                            store.play(store.recentSongs, startingAt: 0)
                        } label: {
                            Label("Play recent", systemImage: "play.fill")
                                .font(MochyFont.semibold(13))
                                .foregroundStyle(palette.accentText)
                                .padding(.horizontal, 16)
                                .frame(height: 40)
                                .background(palette.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button("Clear") { confirmClear = true }
                            .font(MochyFont.medium(12))
                            .foregroundStyle(palette.secondaryText)
                    }

                    LazyVStack(spacing: 1) {
                        ForEach(store.recentlyPlayed) { entry in
                            HStack {
                                SongRow(song: entry.song, contextSongs: store.recentSongs)
                                Text(TimeFormat.relative(entry.playedAt))
                                    .font(MochyFont.medium(10))
                                    .foregroundStyle(palette.tertiaryText)
                                    .frame(width: 58, alignment: .trailing)
                            }
                            Divider().overlay(palette.separator).padding(.leading, 62)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(palette.background)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.background, for: .navigationBar)
        .confirmationDialog("Clear listening history?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear history", role: .destructive) { store.clearHistory() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Stats

struct StatsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette

    private var hours: String {
        let minutes = store.totalListeningSeconds / 60
        if minutes >= 60 {
            return String(format: "%d", minutes / 60)
        }
        return String(format: "%.1f", Double(minutes) / 60)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(eyebrow: "Your recap", title: "Listening stats", subtitle: "All time with Mochy")

                HStack(spacing: 12) {
                    statCard(value: hours, label: "hours listened", icon: "clock.fill")
                    statCard(value: "\(store.totalPlays)", label: "total plays", icon: "play.fill")
                }

                if !store.topArtists.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Top artists")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(Array(store.topArtists.prefix(10))) { artist in
                                    VStack(spacing: 8) {
                                        RemoteArtwork(url: artist.artwork, cornerRadius: 34, symbol: "person.fill", isCircle: true)
                                            .frame(width: 104, height: 104)
                                        Text(artist.name)
                                            .font(MochyFont.semibold(12))
                                            .foregroundStyle(palette.text)
                                            .lineLimit(1)
                                        Text("\(artist.plays) plays")
                                            .font(MochyFont.medium(10))
                                            .foregroundStyle(palette.secondaryText)
                                    }
                                    .frame(width: 108)
                                }
                            }
                        }
                        .padding(.horizontal, -18)
                        .contentMargins(.horizontal, 18)
                    }
                }

                if !store.topSongs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "On repeat")
                        ForEach(Array(store.topSongs.prefix(8).enumerated()), id: \.element.id) { index, stat in
                            SongRow(song: stat.song, index: index, contextSongs: store.topSongs.map(\.song))
                                .overlay(alignment: .trailing) {
                                    Text("\(stat.plays)")
                                        .font(MochyFont.semibold(11))
                                        .foregroundStyle(palette.accent)
                                        .padding(.trailing, 34)
                                }
                        }
                    }
                }

                if store.topSongs.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: "No listening data",
                        message: "Play a few songs to build your recap."
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(palette.background)
        .navigationTitle("Recap")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.background, for: .navigationBar)
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.accent)
            Text(value)
                .font(MochyFont.bold(30))
                .foregroundStyle(palette.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(MochyFont.medium(11))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mochyCard(radius: 18, padding: 15)
    }
}

// MARK: - Profile

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.accent.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text(String(store.settings.profileName.prefix(1)).uppercased())
                            .font(MochyFont.black(42))
                            .foregroundStyle(palette.accentText)
                    }
                    .frame(width: 112, height: 112)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: palette.accent.opacity(0.25), radius: 26, y: 10)

                    TextField("Your name", text: $store.settings.profileName)
                        .font(MochyFont.bold(22))
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                    Text("Mochy listener")
                        .font(MochyFont.medium(11))
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(.top, 10)

                HStack(spacing: 12) {
                    NavigationLink(value: AppRoute.stats) {
                        profileTile(value: "\(store.totalPlays)", label: "plays", icon: "play.fill")
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: AppRoute.history) {
                        profileTile(value: "\(store.recentlyPlayed.count)", label: "recent", icon: "clock.fill")
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: AppRoute.likedSongs) {
                        profileTile(value: "\(store.likedSongs.count)", label: "liked", icon: "heart.fill")
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Your music")
                    profileLink(title: "Liked songs", icon: "heart.fill", route: .likedSongs)
                    profileLink(title: "Playlists", icon: "music.note.list", route: nil)
                    profileLink(title: "Downloads", icon: "arrow.down.circle.fill", route: .downloads)
                    profileLink(title: "Listening recap", icon: "chart.bar.fill", route: .stats)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(palette.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.background, for: .navigationBar)
    }

    private func profileTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.accent)
            Text(value)
                .font(MochyFont.bold(20))
                .foregroundStyle(palette.text)
            Text(label)
                .font(MochyFont.medium(10))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func profileLink(title: String, icon: String, route: AppRoute?) -> some View {
        if let route {
            NavigationLink(value: route) {
                profileLinkLabel(title: title, icon: icon)
            }
            .buttonStyle(.plain)
        } else {
            profileLinkLabel(title: title, icon: icon)
        }
    }

    private func profileLinkLabel(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 24)
            Text(title)
                .font(MochyFont.medium(14))
                .foregroundStyle(palette.text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.tertiaryText)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

// MARK: - Generic songs list

struct SongsListView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette

    var title: String
    var songs: [Song]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(title: title, subtitle: "\(songs.count) songs")
                Button {
                    store.player.setShuffle(false)
                    store.play(songs, startingAt: 0)
                } label: {
                    Label("Play all", systemImage: "play.fill")
                        .font(MochyFont.semibold(13))
                        .foregroundStyle(palette.accentText)
                        .padding(.horizontal, 18)
                        .frame(height: 40)
                        .background(palette.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                LazyVStack(spacing: 1) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        SongRow(song: song, index: index, contextSongs: songs)
                        Divider().overlay(palette.separator).padding(.leading, 62)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(palette.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.background, for: .navigationBar)
    }
}
