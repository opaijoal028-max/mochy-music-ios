import SwiftUI
import UIKit

// MARK: - Routes

private struct OpenRouteActionKey: EnvironmentKey {
    static let defaultValue: ((AppRoute) -> Void)? = nil
}

extension EnvironmentValues {
    var openRouteAction: ((AppRoute) -> Void)? {
        get { self[OpenRouteActionKey.self] }
        set { self[OpenRouteActionKey.self] = newValue }
    }
}

struct NavigationRequest: Hashable {
    var route: AppRoute
    var token = UUID()
}

enum AppRoute: Hashable {
    case album(id: String, playlistId: String?)
    case playlist(id: String)
    case artist(id: String)
    case localPlaylist(id: String)
    case likedSongs
    case downloads
    case history
    case stats
    case profile
    case songs(title: String, songs: [Song])
    case browse(id: String, title: String, params: String?)
}

extension MediaItem {
    var route: AppRoute? {
        switch self {
        case .song:
            return nil
        case .album(let album):
            return .album(id: album.id, playlistId: album.playlistId)
        case .artist(let artist):
            return .artist(id: artist.id)
        case .playlist(let playlist):
            return .playlist(id: playlist.id)
        }
    }
}

// MARK: - Artwork

final class ArtworkCache {
    static let shared = ArtworkCache()
    let cache = NSCache<NSString, UIImage>()
    private init() {
        cache.countLimit = 240
    }
}

struct RemoteArtwork: View {
    @Environment(\.mochyPalette) private var palette
    var url: String?
    var cornerRadius: CGFloat = 12
    var symbol: String = "music.note"
    var aspectRatio: CGFloat? = 1
    var isCircle = false
    var crop = true

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let aspectRatio {
                base.aspectRatio(aspectRatio, contentMode: .fit)
            } else {
                base
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private var base: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.elevated, palette.surface, palette.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.22))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: crop ? .fill : .fit)
                    .transition(.opacity)
            }
        }
        .clipShape(artworkShape)
        .overlay(
            artworkShape
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var artworkShape: AnyShape {
        if isCircle {
            return AnyShape(Circle())
        }
        return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func load() async {
        guard let urlString = url, let remote = URL(string: urlString) else {
            image = nil
            return
        }
        if let cached = ArtworkCache.shared.cache.object(forKey: urlString as NSString) {
            image = cached
            return
        }
        isLoading = true
        defer { isLoading = false }
        guard let (data, _) = try? await URLSession.shared.data(from: remote),
              let loaded = UIImage(data: data) else { return }
        ArtworkCache.shared.cache.setObject(loaded, forKey: urlString as NSString)
        withAnimation(.easeOut(duration: 0.2)) {
            image = loaded
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    @Environment(\.mochyPalette) private var palette
    var title: String
    var subtitle: String?
    var actionTitle: String?
    var destination: AppRoute?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MochyFont.bold(22))
                    .foregroundStyle(palette.text)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(MochyFont.medium(12))
                        .foregroundStyle(palette.secondaryText)
                }
            }
            Spacer()
            if let destination {
                NavigationLink(value: destination) {
                    Text(actionTitle ?? "More")
                        .font(MochyFont.semibold(13))
                        .foregroundStyle(palette.secondaryText)
                }
                .buttonStyle(.plain)
            } else if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(MochyFont.semibold(13))
                        .foregroundStyle(palette.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Media card

struct MediaCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette
    var item: MediaItem
    var width: CGFloat = 152
    var contextSongs: [Song]?

    var body: some View {
        Group {
            if let route = item.route {
                NavigationLink(value: route) {
                    content
                }
                .buttonStyle(.plain)
            } else if let song = item.song {
                Button {
                    store.play(song, queue: contextSongs ?? [song])
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .frame(width: width)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 9) {
            RemoteArtwork(
                url: item.thumbnail,
                cornerRadius: item.artist == nil ? (store.settings.coverRadius / 2.2) : 28,
                symbol: item.artist == nil ? "music.note" : "person.fill",
                isCircle: item.artist != nil
            )
            .frame(width: width, height: width)
            Text(item.title)
                .font(MochyFont.semibold(14))
                .foregroundStyle(palette.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(height: 38, alignment: .top)
            Text(item.subtitle)
                .font(MochyFont.medium(11))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
        }
    }
}

// MARK: - Song row

struct SongRow: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette

    var song: Song
    var index: Int?
    var showArtwork = true
    var showDuration = true
    var highlighted = false
    var contextSongs: [Song]?

    @State private var showAddToPlaylist = false
    @State private var swipeOffset: CGFloat = 0

    var body: some View {
        ZStack {
            if swipeOffset != 0 {
                swipeBackground
            }
            HStack(spacing: 12) {
                if let index {
                    Text("\(index + 1)")
                        .font(MochyFont.medium(13))
                        .foregroundStyle(palette.tertiaryText)
                        .frame(width: 24, alignment: .trailing)
                }
                if showArtwork {
                    RemoteArtwork(url: song.thumbnail, cornerRadius: 9)
                        .frame(width: 50, height: 50)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(song.title)
                            .font(MochyFont.semibold(15))
                            .foregroundStyle(highlighted ? palette.accent : palette.text)
                            .lineLimit(1)
                        if song.explicit, store.settings.showExplicit {
                            Text("E")
                                .font(MochyFont.bold(8))
                                .foregroundStyle(palette.background)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 2))
                        }
                    }
                    HStack(spacing: 5) {
                        if song.isVideoSong {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 9))
                        }
                        Text(song.artistLine.isEmpty ? "Unknown artist" : song.artistLine)
                            .lineLimit(1)
                        if store.isDownloading(song) {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(palette.accent)
                        }
                    }
                    .font(MochyFont.regular(12))
                    .foregroundStyle(palette.secondaryText)
                }
                Spacer(minLength: 6)
                if showDuration, !song.durationText.isEmpty {
                    Text(song.durationText)
                        .font(MochyFont.medium(11))
                        .foregroundStyle(palette.tertiaryText)
                }
                Menu {
                    SongActionsContent(song: song, onAddToPlaylist: { showAddToPlaylist = true })
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: 30, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .offset(x: swipeOffset)
            .onTapGesture {
                store.play(song, queue: contextSongs ?? [song])
            }
            .simultaneousGesture(swipeGesture)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(song: song)
                .environmentObject(store)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.35 else { return }
                swipeOffset = max(-126, min(126, value.translation.width))
            }
            .onEnded { _ in
                let offset = swipeOffset
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    swipeOffset = 0
                }
                guard abs(offset) > 64 else { return }
                performSwipe(offset > 0 ? store.settings.swipeRight : store.settings.swipeLeft)
            }
    }

    private func performSwipe(_ action: SwipeAction) {
        switch action {
        case .like:
            store.toggleLike(song)
        case .queue:
            store.queue(song)
        case .download:
            if store.isDownloaded(song) {
                if let download = store.downloads.first(where: { $0.song.id == song.id }) {
                    store.deleteDownload(download)
                }
            } else if store.isDownloading(song) {
                store.cancelDownload(song)
            } else {
                store.download(song)
            }
        case .playlist:
            showAddToPlaylist = true
        case .none:
            break
        }
    }

    @ViewBuilder
    private var swipeBackground: some View {
        let action = swipeOffset > 0 ? store.settings.swipeRight : store.settings.swipeLeft
        HStack(spacing: 0) {
            if swipeOffset > 0 {
                swipeBadge(action)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                swipeBadge(action)
            }
        }
        .padding(.horizontal, 6)
    }

    private func swipeBadge(_ action: SwipeAction) -> some View {
        let tint: Color
        let icon: String
        switch action {
        case .like: tint = Color(hex: "#F06A6A"); icon = store.isLiked(song) ? "heart.fill" : "heart"
        case .queue: tint = palette.accent; icon = "text.badge.plus"
        case .download: tint = Color(hex: "#6FA8FF"); icon = "arrow.down.circle"
        case .playlist: tint = Color(hex: "#77D97A"); icon = "music.note.list"
        case .none: tint = palette.elevated; icon = "minus"
        }
        return VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
            Text(action.rawValue)
                .font(MochyFont.medium(9))
                .lineLimit(1)
        }
        .foregroundStyle(action == .none ? palette.secondaryText : Color.white)
        .frame(width: 92)
        .frame(maxHeight: .infinity)
        .background(tint.opacity(action == .none ? 0.3 : 0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SongActionsContent: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openRouteAction) private var openRouteAction
    var song: Song
    var onAddToPlaylist: (() -> Void)?

    var body: some View {
        Button {
            store.toggleLike(song)
        } label: {
            Label(store.isLiked(song) ? "Remove from liked" : "Like", systemImage: store.isLiked(song) ? "heart.fill" : "heart")
        }
        Button {
            store.playNext(song)
        } label: {
            Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        Button {
            store.queue(song)
        } label: {
            Label("Add to queue", systemImage: "text.badge.plus")
        }
        if let albumId = song.albumId {
            Button {
                open(.album(id: albumId, playlistId: song.playlistId))
            } label: {
                Label("Go to album", systemImage: "square.stack")
            }
        }
        if let artist = song.artists.first, let id = artist.id {
            Button {
                open(.artist(id: id))
            } label: {
                Label("Go to artist", systemImage: "person")
            }
        }
        Button {
            if store.isDownloaded(song) {
                if let download = store.downloads.first(where: { $0.song.id == song.id }) {
                    store.deleteDownload(download)
                }
            } else if store.isDownloading(song) {
                store.cancelDownload(song)
            } else {
                store.download(song)
            }
        } label: {
            Label(
                store.isDownloaded(song) ? "Remove download" : (store.isDownloading(song) ? "Cancel download" : "Download"),
                systemImage: store.isDownloaded(song) ? "trash" : "arrow.down.circle"
            )
        }
        if let onAddToPlaylist {
            Button(action: onAddToPlaylist) {
                Label("Add to playlist", systemImage: "music.note.list")
            }
        }
        if let url = song.shareURL {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    private func open(_ route: AppRoute) {
        if let openRouteAction {
            openRouteAction(route)
        } else {
            store.openRoute(route)
        }
    }
}

// MARK: - Bottom chrome

struct MiniPlayerBar: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette

    var body: some View {
        if let song = player.currentSong {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let fraction = player.duration > 0 ? min(max(player.currentTime / player.duration, 0), 1) : 0
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.08))
                        Rectangle().fill(palette.accent).frame(width: proxy.size.width * fraction)
                    }
                }
                .frame(height: 2)

                HStack(spacing: 11) {
                    RemoteArtwork(url: song.thumbnail, cornerRadius: 8)
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(song.title)
                                .font(MochyFont.semibold(13))
                                .foregroundStyle(palette.text)
                                .lineLimit(1)
                            if player.errorMessage != nil {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color(hex: "#F2D35C"))
                            }
                        }
                        Text(player.errorMessage == nil ? song.artistLine : "Playback error · tap to retry")
                            .font(MochyFont.regular(11))
                            .foregroundStyle(player.errorMessage == nil ? palette.secondaryText : Color(hex: "#F2D35C"))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Button {
                        if player.errorMessage != nil {
                            player.retry()
                        } else {
                            player.togglePlayPause()
                        }
                    } label: {
                        Image(systemName: player.errorMessage != nil ? "arrow.clockwise" : (player.isPlaying ? "pause.fill" : "play.fill"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .frame(width: 38, height: 38)
                    }
                    Button {
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .frame(width: 36, height: 38)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(store.settings.pureBlackMiniPlayer ? Color.black : palette.surface)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                store.playerPresented = true
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        guard value.translation.height < -36,
                              abs(value.translation.height) > abs(value.translation.width) else { return }
                        store.playerPresented = true
                    }
            )
        }
    }
}

struct MainTabBar: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        store.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: store.selectedTab == tab ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .frame(height: 22)
                        Text(tab.rawValue)
                            .font(MochyFont.medium(9))
                    }
                    .foregroundStyle(store.selectedTab == tab ? palette.accent : palette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 9)
        .padding(.bottom, 4)
        .padding(.horizontal, 8)
        .background(
            (palette.isPureBlack ? Color.black : palette.surface)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)
                }
        )
    }
}

struct ToastView: View {
    @Environment(\.mochyPalette) private var palette
    var message: String

    var body: some View {
        Text(message)
            .font(MochyFont.semibold(13))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.6))
            .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
    }
}

// MARK: - States

struct EmptyStateView: View {
    @Environment(\.mochyPalette) private var palette
    var icon: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
            VStack(spacing: 5) {
                Text(title)
                    .font(MochyFont.bold(18))
                    .foregroundStyle(palette.text)
                Text(message)
                    .font(MochyFont.regular(13))
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(MochyFont.semibold(13))
                    .foregroundStyle(palette.accentText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(palette.accent, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
}

struct LoadingDots: View {
    @Environment(\.mochyPalette) private var palette
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(palette.accent)
                    .frame(width: 6, height: 6)
                    .opacity(0.35 + 0.65 * (sin(phase + Double(index) * 0.9) + 1) / 2)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Header

struct PageHeader: View {
    @Environment(\.mochyPalette) private var palette
    var eyebrow: String?
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(MochyFont.semibold(10))
                    .tracking(1.4)
                    .foregroundStyle(palette.accent)
            }
            Text(title)
                .font(MochyFont.bold(32))
                .foregroundStyle(palette.text)
                .lineLimit(2)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(MochyFont.regular(13))
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }
}

// MARK: - Rounded button

struct CircleIconButton: View {
    @Environment(\.mochyPalette) private var palette
    var icon: String
    var size: CGFloat = 38
    var active = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(active ? palette.accentText : palette.text)
                .frame(width: size, height: size)
                .background(active ? palette.accent : Color.white.opacity(0.075), in: Circle())
        }
        .buttonStyle(.plain)
    }
}
