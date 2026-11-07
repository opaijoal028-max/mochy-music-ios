import SwiftUI
import UIKit

struct PlayerScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mochyPalette) private var palette

    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var showAddToPlaylist = false
    @State private var showSleepTimer = false

    var body: some View {
        ZStack {
            background

            if let song = player.currentSong {
                VStack(spacing: 0) {
                    topBar(song)
                    if let message = player.errorMessage {
                        errorBanner(message)
                    }
                    content(song)
                }
            } else {
                VStack(spacing: 20) {
                    Text("Nothing playing")
                        .font(MochyFont.bold(22))
                        .foregroundStyle(palette.text)
                    Button("Close") { dismiss() }
                        .foregroundStyle(palette.secondaryText)
                }
            }
        }
        .environment(\.mochyPalette, palette)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLyrics) {
            if let song = player.currentSong {
                LyricsView(song: song)
                    .environmentObject(store)
                    .environmentObject(player)
                    .environment(\.mochyPalette, palette)
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet()
                .environmentObject(store)
                .environmentObject(player)
                .environment(\.mochyPalette, palette)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            if let song = player.currentSong {
                AddToPlaylistSheet(song: song)
                    .environmentObject(store)
                    .environment(\.mochyPalette, palette)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerSheet()
                .environmentObject(player)
                .environment(\.mochyPalette, palette)
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
        }
        .navigationDestination(item: $store.playerRoute) { route in
            RouteDestination(route: route)
        }
        .navigationDestination(for: AppRoute.self) { route in
            RouteDestination(route: route)
        }
    }

    // MARK: - Chrome

    private var background: some View {
        ZStack {
            palette.background
            if let image = player.artworkImage, store.settings.blurEnabled {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 70)
                    .opacity(store.settings.progressiveBlur ? 0.4 : 0.25)
                    .ignoresSafeArea()
                LinearGradient(
                    colors: [palette.background.opacity(0.35), palette.background.opacity(0.82), palette.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            if let color = player.artworkColor {
                RadialGradient(
                    colors: [color.opacity(0.28), .clear],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 520
                )
                .ignoresSafeArea()
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "#F2D35C"))
            Text(message)
                .font(MochyFont.medium(11))
                .foregroundStyle(palette.text.opacity(0.86))
                .lineLimit(2)
            Spacer(minLength: 6)
            Button {
                player.retry()
            } label: {
                Text("Retry")
                    .font(MochyFont.semibold(11))
                    .foregroundStyle(palette.accentText)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(palette.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(hex: "#F2D35C").opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(hex: "#F2D35C").opacity(0.22), lineWidth: 0.6)
        )
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private func topBar(_ song: Song) -> some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.text)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text("PLAYING FROM")
                    .font(MochyFont.semibold(8))
                    .tracking(1.3)
                    .foregroundStyle(palette.secondaryText)
                Text(song.albumTitle ?? "Mochy")
                    .font(MochyFont.semibold(12))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Menu {
                Button {
                    showAddToPlaylist = true
                } label: {
                    Label("Add to playlist", systemImage: "music.note.list")
                }
                Button {
                    if store.isDownloaded(song) {
                        if let download = store.downloads.first(where: { $0.song.id == song.id }) {
                            store.deleteDownload(download)
                        }
                    } else {
                        store.download(song)
                    }
                } label: {
                    Label(store.isDownloaded(song) ? "Remove download" : "Download", systemImage: store.isDownloaded(song) ? "trash" : "arrow.down.circle")
                }
                Button {
                    store.toggleLike(song)
                } label: {
                    Label(store.isLiked(song) ? "Remove from liked" : "Like", systemImage: store.isLiked(song) ? "heart.fill" : "heart")
                }
                Button {
                    showSleepTimer = true
                } label: {
                    Label("Sleep timer", systemImage: "moon.zzz")
                }
                Divider()
                Button {
                    showQueue = true
                } label: {
                    Label("Queue", systemImage: "list.bullet")
                }
                if let albumId = song.albumId {
                    Divider()
                    Button {
                        store.playerRoute = .album(id: albumId, playlistId: song.playlistId)
                    } label: {
                        Label("Go to album", systemImage: "square.stack")
                    }
                }
                if let artist = song.artists.first, let id = artist.id {
                    Button {
                        store.playerRoute = .artist(id: id)
                    } label: {
                        Label("Go to artist", systemImage: "person")
                    }
                }
                if let url = song.shareURL {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.text)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if store.settings.playerSwipeDown,
                       value.translation.height > 90,
                       abs(value.translation.width) < 90 {
                        dismiss()
                    }
                }
        )
    }

    @ViewBuilder
    private func content(_ song: Song) -> some View {
        switch store.settings.playerStyle {
        case .flagship:
            flagship(song)
        case .classic:
            classic(song)
        case .turntable:
            turntable(song)
        case .video:
            video(song)
        case .ipod:
            ipod(song)
        case .poster:
            poster(song)
        case .timeline:
            timeline(song)
        case .lyrics:
            lyrics(song)
        case .bedside:
            bedside(song)
        }
    }

    // MARK: - Flagship

    private func flagship(_ song: Song) -> some View {
        GeometryReader { proxy in
            let artworkSize = min(proxy.size.width - 56, 332)
            VStack(spacing: 20) {
                Spacer(minLength: 8)
                artwork(song, size: artworkSize, radius: 26)
                titleBlock(song, alignment: .center)
                seekBar
                TransportControls()
                actionRow(song)
                Spacer(minLength: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Classic

    private func classic(_ song: Song) -> some View {
        GeometryReader { proxy in
            let artworkSize = min(proxy.size.width - 96, 270)
            VStack(spacing: 18) {
                Spacer(minLength: 16)
                artwork(song, size: artworkSize, radius: 18)
                titleBlock(song, alignment: .center, titleSize: 20)
                seekBar
                TransportControls(compact: false)
                Spacer(minLength: 6)
                actionRow(song, labels: false)
                Spacer(minLength: 10)
            }
            .padding(.horizontal, 26)
        }
    }

    // MARK: - Turntable

    private func turntable(_ song: Song) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)
            ZStack {
                Circle()
                    .fill(Color.black)
                    .overlay(
                        ForEach(1..<6) { ring in
                            Circle()
                                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.6)
                                .padding(CGFloat(ring) * 14)
                        }
                    )
                    .frame(width: 300, height: 300)
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 16)

                RemoteArtwork(url: song.thumbnail, cornerRadius: 90, symbol: "music.note", aspectRatio: nil, isCircle: true)
                    .frame(width: 188, height: 188)

                Circle()
                    .fill(palette.background)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))

                Capsule()
                    .fill(Color(hex: "#C9C9C9"))
                    .frame(width: 5, height: 134)
                    .overlay(Circle().fill(Color(hex: "#E7E7E7")).frame(width: 16, height: 16), alignment: .top)
                    .rotationEffect(.degrees(24), anchor: .top)
                    .offset(x: 128, y: -48)
                    .shadow(color: .black.opacity(0.4), radius: 7, y: 4)
            }
            .padding(.top, 12)

            titleBlock(song, alignment: .center)
            seekBar.padding(.horizontal, 6)
            TransportControls()
            actionRow(song, labels: false)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 26)
    }

    // MARK: - Video

    private func video(_ song: Song) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if let image = player.artworkImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    RemoteArtwork(url: song.thumbnail, cornerRadius: 0, aspectRatio: nil)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                LinearGradient(
                    colors: [.clear, .black.opacity(0.15), .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(spacing: 13) {
                    titleBlock(song, alignment: .leading)
                    seekBar
                    TransportControls()
                    actionRow(song, labels: false)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
    }

    // MARK: - iPod

    private struct IpodColors {
        var body: [Color]
        var screen: Color
        var ink: Color
        var wheel: Color
    }

    private func ipodColors(_ theme: IpodTheme) -> IpodColors {
        switch theme {
        case .silver:
            return IpodColors(
                body: [Color(hex: "#F4F2EC"), Color(hex: "#C9C6BC")],
                screen: Color(hex: "#D9D7CF"),
                ink: .black,
                wheel: Color(hex: "#EEECE5")
            )
        case .black:
            return IpodColors(
                body: [Color(hex: "#2B2B2E"), Color(hex: "#0C0C0E")],
                screen: Color(hex: "#D9D7CF"),
                ink: .black,
                wheel: Color(hex: "#171719")
            )
        case .u2:
            return IpodColors(
                body: [Color(hex: "#242426"), Color(hex: "#050506")],
                screen: Color(hex: "#D9D7CF"),
                ink: .black,
                wheel: Color(hex: "#8E2D2D")
            )
        case .trueDark:
            return IpodColors(
                body: [Color(hex: "#0E0E10"), Color.black],
                screen: Color(hex: "#101012"),
                ink: Color.white.opacity(0.88),
                wheel: Color(hex: "#101012")
            )
        }
    }

    private func ipodWheelColor(theme: IpodTheme) -> Color {
        switch store.settings.ipodWheelColor {
        case .theme: return ipodColors(theme).wheel
        case .white: return Color(hex: "#EEECE5")
        case .black: return Color(hex: "#171719")
        case .red: return Color(hex: "#8E2D2D")
        }
    }

    private func isDarkColor(_ color: Color) -> Bool {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) < 0.4
    }

    private func ipod(_ song: Song) -> some View {
        GeometryReader { proxy in
            let scale = min(1, proxy.size.height / 590)
            let theme = store.settings.ipodTheme
            let colors = ipodColors(theme)
            let bodyColors = colors.body
            let screenColor = colors.screen
            let ink = colors.ink
            let wheel = ipodWheelColor(theme: theme)
            let wheelIsDark = isDarkColor(wheel)
            let wheelInk = wheelIsDark ? Color.white.opacity(0.68) : Color.black.opacity(0.6)
            let centerColor = wheelIsDark
                ? (store.settings.ipodWheelColor == .red || theme == .u2 ? Color(hex: "#1A1A1C") : Color(hex: "#252528"))
                : Color(hex: "#F7F5EE")
            let secondaryInk = ink.opacity(0.62)

            VStack {
                Spacer(minLength: 0)
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(screenColor)
                            .aspectRatio(1.35, contentMode: .fit)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(ink.opacity(0.2), lineWidth: 1)
                            )
                        HStack(spacing: 12) {
                            RemoteArtwork(url: song.thumbnail, cornerRadius: 4)
                                .frame(width: 94, height: 94)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(song.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(ink)
                                    .lineLimit(2)
                                Text(song.artistLine)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(secondaryInk)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(TimeFormat.clock(player.currentTime)) / \(TimeFormat.clock(player.duration))")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(ink.opacity(0.55))
                                ProgressView(value: player.duration > 0 ? min(player.currentTime / player.duration, 1) : 0)
                                    .tint(ink.opacity(0.7))
                            }
                        }
                        .padding(14)
                    }
                    .frame(width: 286, height: 212)

                    ZStack {
                        Circle()
                            .fill(wheel)
                        Circle()
                            .strokeBorder(ink.opacity(0.12), lineWidth: 1)
                        Text("MENU")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(wheelInk)
                            .offset(y: -74)
                        Button { player.previous() } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(wheelInk)
                                .offset(x: -74)
                        }
                        .buttonStyle(.plain)
                        Button { player.next() } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(wheelInk)
                                .offset(x: 74)
                        }
                        .buttonStyle(.plain)
                        Button { player.togglePlayPause() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(wheelInk)
                                .offset(y: 74)
                        }
                        .buttonStyle(.plain)
                        Button {
                            player.togglePlayPause()
                        } label: {
                            Circle()
                                .fill(centerColor)
                                .frame(width: 74, height: 74)
                                .overlay(Circle().strokeBorder(ink.opacity(0.12), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 220, height: 220)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: bodyColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .strokeBorder(
                                    theme == .trueDark || theme == .black || theme == .u2
                                        ? Color.white.opacity(0.12) : Color.white.opacity(0.3),
                                    lineWidth: 0.6
                                )
                        )
                        .shadow(color: .black.opacity(0.4), radius: 24, y: 14)
                )
                .scaleEffect(scale)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Poster

    private func poster(_ song: Song) -> some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 16) {
                Spacer(minLength: 6)
                VStack(alignment: .leading, spacing: 5) {
                    Text("NOW PLAYING")
                        .font(MochyFont.semibold(9))
                        .tracking(1.8)
                        .foregroundStyle(palette.secondaryText)
                    Text(song.title)
                        .font(MochyFont.black(38))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(song.artistLine)
                        .font(MochyFont.medium(14))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                artwork(song, size: min(proxy.size.width - 36, 330), radius: 2)
                    .rotationEffect(.degrees(-1.2))
                    .shadow(color: .black.opacity(0.4), radius: 30, y: 18)
                Spacer(minLength: 6)
                seekBar
                TransportControls()
                actionRow(song, labels: false)
                Spacer(minLength: 6)
            }
            .padding(.horizontal, 22)
        }
    }

    // MARK: - Timeline

    private func timeline(_ song: Song) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 10)
            HStack(spacing: 14) {
                RemoteArtwork(url: song.thumbnail, cornerRadius: 12)
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(MochyFont.bold(20))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                    Text(song.artistLine)
                        .font(MochyFont.medium(12))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
            }

            Spacer(minLength: 8)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(TimeFormat.clock(player.currentTime))
                    .font(MochyFont.bold(62))
                    .foregroundStyle(palette.text)
                    .monospacedDigit()
                Text("/ \(TimeFormat.clock(player.duration))")
                    .font(MochyFont.medium(13))
                    .foregroundStyle(palette.secondaryText)
            }

            timelineTrack
            TransportControls()
            actionRow(song)
            Spacer(minLength: 6)
        }
        .padding(.horizontal, 24)
    }

    private var timelineTrack: some View {
        GeometryReader { proxy in
            let fraction = player.duration > 0 ? min(max(player.currentTime / player.duration, 0), 1) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                Capsule().fill(palette.accent).frame(width: proxy.size.width * fraction, height: 4)
                Circle()
                    .fill(palette.accent)
                    .frame(width: 12, height: 12)
                    .offset(x: max(0, proxy.size.width * fraction - 6))
            }
            .frame(height: 14)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let fraction = min(max(value.location.x / proxy.size.width, 0), 1)
                        player.seek(to: player.duration * fraction)
                    }
            )
        }
        .frame(height: 14)
    }

    // MARK: - Lyrics style

    private func lyrics(_ song: Song) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)
            RemoteArtwork(url: song.thumbnail, cornerRadius: 14)
                .frame(width: 84, height: 84)
            Spacer(minLength: 6)
            LyricsStageView(song: song)
                .padding(.horizontal, 22)
            Spacer(minLength: 6)
            seekBar
            TransportControls()
            Spacer(minLength: 10)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Bedside

    private func bedside(_ song: Song) -> some View {
        VStack(spacing: 20) {
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 4) {
                    Text(context.date, style: .time)
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.text.opacity(0.9))
                        .monospacedDigit()
                    Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(MochyFont.medium(13))
                        .foregroundStyle(palette.secondaryText)
                }
            }
            Spacer()
            RemoteArtwork(url: song.thumbnail, cornerRadius: 8)
                .frame(width: 58, height: 58)
                .opacity(0.7)
            Text(song.title)
                .font(MochyFont.semibold(15))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
            seekBar
            TransportControls(compact: true)
            Button {
                showSleepTimer = true
            } label: {
                Label("Sleep timer", systemImage: "moon.zzz")
                    .font(MochyFont.medium(11))
                    .foregroundStyle(palette.tertiaryText)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Shared pieces

    @ViewBuilder
    private func artwork(_ song: Song, size: CGFloat, radius: CGFloat) -> some View {
        Group {
            if store.settings.hidePlayerThumbnail {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [palette.elevated, palette.surface, palette.background],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("M")
                        .font(MochyFont.black(size * 0.28))
                        .foregroundStyle(palette.text.opacity(0.16))
                }
            } else {
                RemoteArtwork(
                    url: song.thumbnail,
                    cornerRadius: radius,
                    aspectRatio: nil,
                    crop: store.settings.cropAlbumArt
                )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.4), radius: 30, y: 18)
        .overlay {
            if player.isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.black.opacity(0.25))
                    LoadingDots()
                }
            }
        }
    }

    private func titleBlock(_ song: Song, alignment: HorizontalAlignment, titleSize: CGFloat = 25) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(song.title)
                .font(MochyFont.bold(titleSize))
                .foregroundStyle(palette.text)
                .lineLimit(2)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
            Text(song.artistLine)
                .font(MochyFont.medium(13))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }

    private var seekBar: some View {
        SeekBar()
    }

    private func actionRow(_ song: Song, labels: Bool = true) -> some View {
        HStack(spacing: 0) {
            PlayerActionButton(icon: "quote.bubble", label: "Lyrics", active: false) {
                showLyrics = true
            }
            PlayerActionButton(icon: "list.bullet", label: "Queue", active: false) {
                showQueue = true
            }
            PlayerActionButton(
                icon: store.isLiked(song) ? "heart.fill" : "heart",
                label: "Like",
                active: store.isLiked(song)
            ) {
                store.toggleLike(song)
            }
            PlayerActionButton(
                icon: store.isDownloaded(song) ? "arrow.down.circle.fill" : "arrow.down.circle",
                label: "Download",
                active: store.isDownloaded(song)
            ) {
                if store.isDownloaded(song) {
                    if let download = store.downloads.first(where: { $0.song.id == song.id }) {
                        store.deleteDownload(download)
                    }
                } else {
                    store.download(song)
                }
            }
            PlayerActionButton(icon: "ellipsis", label: "More", active: false) {
                showAddToPlaylist = true
            }
        }
        .opacity(labels ? 1 : 0.95)
    }
}

// MARK: - Transport

struct TransportControls: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette

    var compact = false

    var body: some View {
        HStack(spacing: compact ? 14 : 20) {
            Button {
                player.setShuffle(!player.shuffle)
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: compact ? 12 : 15, weight: .semibold))
                    .foregroundStyle(player.shuffle ? palette.accent : palette.secondaryText)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: compact ? 17 : 23, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(palette.text)
                        .frame(width: compact ? 52 : 68, height: compact ? 52 : 68)
                    if player.isBuffering || player.isLoading {
                        ProgressView()
                            .tint(palette.background)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: compact ? 20 : 26, weight: .bold))
                            .foregroundStyle(palette.background)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: compact ? 17 : 23, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)

            Button {
                player.cycleRepeatMode()
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: compact ? 12 : 15, weight: .semibold))
                    .foregroundStyle(player.repeatMode == .off ? palette.secondaryText : palette.accent)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Seek bar

struct SeekBar: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette

    @State private var dragging = false
    @State private var dragValue = 0.0

    private var shownTime: Double {
        dragging ? dragValue : player.currentTime
    }

    private var total: Double {
        max(player.duration, 1)
    }

    var body: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { dragging ? dragValue : min(player.currentTime, total) },
                    set: { dragValue = $0 }
                ),
                in: 0...total,
                onEditingChanged: { editing in
                    if editing {
                        dragging = true
                        dragValue = player.currentTime
                    } else {
                        player.seek(to: dragValue)
                        dragging = false
                    }
                }
            )
            .tint(palette.accent)

            HStack {
                Text(TimeFormat.clock(shownTime))
                    .font(MochyFont.medium(10))
                    .foregroundStyle(palette.secondaryText)
                    .monospacedDigit()
                Spacer()
                Text("-\(TimeFormat.clock(max(0, player.duration - shownTime)))")
                    .font(MochyFont.medium(10))
                    .foregroundStyle(palette.secondaryText)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Action button

struct PlayerActionButton: View {
    @Environment(\.mochyPalette) private var palette
    var icon: String
    var label: String
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(active ? palette.accent : palette.secondaryText)
                Text(label)
                    .font(MochyFont.medium(9))
                    .foregroundStyle(active ? palette.accent : palette.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
