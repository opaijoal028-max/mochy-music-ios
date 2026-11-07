import SwiftUI
import UIKit

private enum LibraryFilter: String, CaseIterable, Identifiable {
    case playlists = "Playlists"
    case songs = "Liked"
    case downloads = "Downloads"
    var id: String { rawValue }
}

struct LibraryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette

    @State private var filter: LibraryFilter = .playlists
    @State private var showCreatePlaylist = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    header
                    quickTiles
                    filterBar
                    content
                    if !store.recentSongs.isEmpty {
                        recentSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background(palette.background)
            .navigationDestination(for: AppRoute.self) { route in
                RouteDestination(route: route)
            }
            .navigationDestination(item: $store.navigationRequest) { request in
                RouteDestination(route: request.route)
            }
            .sheet(isPresented: $showCreatePlaylist) {
                CreatePlaylistSheet()
                    .environmentObject(store)
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your library")
                    .font(MochyFont.bold(32))
                    .foregroundStyle(palette.text)
                Text("\(store.likedSongs.count) liked · \(store.playlists.count) playlists · \(store.downloads.count) downloads")
                    .font(MochyFont.medium(12))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Button {
                showCreatePlaylist = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.accentText)
                    .frame(width: 40, height: 40)
                    .background(palette.accent, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var quickTiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            quickTile(
                title: "Liked songs",
                subtitle: "\(store.likedSongs.count) songs",
                icon: "heart.fill",
                tint: Color(hex: "#F06A6A"),
                route: .likedSongs
            )
            quickTile(
                title: "Downloads",
                subtitle: store.downloadBytesText,
                icon: "arrow.down.circle.fill",
                tint: palette.accent,
                route: .downloads
            )
            quickTile(
                title: "History",
                subtitle: "\(store.recentlyPlayed.count) plays",
                icon: "clock.fill",
                tint: Color(hex: "#6FA8FF"),
                route: .history
            )
            quickTile(
                title: "Your recap",
                subtitle: "\(store.totalPlays) total plays",
                icon: "chart.bar.fill",
                tint: Color(hex: "#77D97A"),
                route: .stats
            )
        }
    }

    private func quickTile(title: String, subtitle: String, icon: String, tint: Color, route: AppRoute) -> some View {
        NavigationLink(value: route) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [tint.opacity(0.55), tint.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.17))
                    .offset(x: 106, y: -28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MochyFont.bold(15))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(MochyFont.medium(10))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                .padding(13)
            }
            .frame(height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(LibraryFilter.allCases) { option in
                Button {
                    filter = option
                } label: {
                    Text(option.rawValue)
                        .font(MochyFont.semibold(12))
                        .foregroundStyle(filter == option ? palette.accentText : palette.secondaryText)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(filter == option ? palette.accent : Color.white.opacity(0.055))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch filter {
        case .playlists:
            playlistContent
        case .songs:
            likedContent
        case .downloads:
            downloadsContent
        }
    }

    private var playlistContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.playlists.isEmpty {
                EmptyStateView(
                    icon: "music.note.list",
                    title: "No playlists yet",
                    message: "Build a playlist from any song's menu.",
                    actionTitle: "Create playlist"
                ) {
                    showCreatePlaylist = true
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 20) {
                    ForEach(store.playlists) { playlist in
                        NavigationLink(value: AppRoute.localPlaylist(id: playlist.id)) {
                            localPlaylistCard(playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func localPlaylistCard(_ playlist: UserPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cover = playlist.thumbnail {
                RemoteArtwork(url: cover, cornerRadius: store.settings.coverRadius / 2.2)
                    .frame(height: (UIScreen.main.bounds.width - 50) / 2)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: store.settings.coverRadius / 2.2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [palette.accent.opacity(0.55), palette.elevated],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "music.note.list")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .aspectRatio(1, contentMode: .fit)
            }
            Text(playlist.name)
                .font(MochyFont.semibold(14))
                .foregroundStyle(palette.text)
                .lineLimit(1)
            Text("\(playlist.songs.count) songs")
                .font(MochyFont.medium(11))
                .foregroundStyle(palette.secondaryText)
        }
    }

    private var likedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.likedSongs.isEmpty {
                EmptyStateView(
                    icon: "heart",
                    title: "Nothing liked yet",
                    message: "Tap the heart on any song to keep it here."
                )
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Liked songs")
                            .font(MochyFont.bold(22))
                            .foregroundStyle(palette.text)
                        Text("\(store.likedSongs.count) songs")
                            .font(MochyFont.medium(12))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                    Button {
                        store.play(store.likedSongs, startingAt: 0)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(palette.accentText)
                            .frame(width: 42, height: 42)
                            .background(palette.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)
                ForEach(store.likedSongs) { song in
                    SongRow(song: song, contextSongs: store.likedSongs)
                }
            }
        }
    }

    private var downloadsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.downloads.isEmpty {
                EmptyStateView(
                    icon: "arrow.down.circle",
                    title: "No downloads",
                    message: "Download songs to listen without a connection.",
                    actionTitle: "Browse home"
                ) {
                    store.selectedTab = .home
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Downloads")
                            .font(MochyFont.bold(22))
                            .foregroundStyle(palette.text)
                        Text(store.downloadBytesText)
                            .font(MochyFont.medium(12))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                    Button {
                        store.play(store.downloads.map(\.song), startingAt: 0)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(palette.accentText)
                            .frame(width: 42, height: 42)
                            .background(palette.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)
                ForEach(store.downloads) { download in
                    SongRow(song: download.song, contextSongs: store.downloads.map(\.song))
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recently played")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(store.recentSongs) { song in
                        MediaCard(item: .song(song), width: 132, contextSongs: store.recentSongs)
                    }
                }
            }
            .padding(.horizontal, -18)
            .contentMargins(.horizontal, 18)
        }
    }
}
