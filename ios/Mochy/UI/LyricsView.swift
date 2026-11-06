import SwiftUI

struct LyricsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var song: Song

    @State private var lyrics: Lyrics?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var activeIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(palette.separator)
            content
        }
        .background(
            ZStack {
                palette.background
                if let color = player.artworkColor {
                    RadialGradient(
                        colors: [color.opacity(0.22), .clear],
                        center: .top,
                        startRadius: 20,
                        endRadius: 500
                    )
                }
            }
            .ignoresSafeArea()
        )
        .task(id: song.id) {
            await load()
        }
        .onChange(of: player.currentTime) { _, time in
            updateActiveIndex(time)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.text)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)

            RemoteArtwork(url: song.thumbnail, cornerRadius: 8)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(MochyFont.semibold(14))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Text(song.artistLine)
                    .font(MochyFont.regular(11))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Spacer()
            LoadingDots()
            Spacer()
        } else if let errorMessage {
            Spacer()
            EmptyStateView(
                icon: "quote.bubble",
                title: "Couldn't load lyrics",
                message: errorMessage,
                actionTitle: "Retry"
            ) {
                Task { await load() }
            }
            Spacer()
        } else if let lyrics {
            if let synced = lyrics.synced, !synced.isEmpty {
                syncedView(synced)
            } else {
                plainView(lyrics.plain)
            }
        } else {
            Spacer()
            EmptyStateView(
                icon: "quote.bubble",
                title: "No lyrics found",
                message: "Lyrics aren't available for this track yet."
            )
            Spacer()
        }
    }

    private func syncedView(_ lines: [LyricLine]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Color.clear.frame(height: 70)
                    ForEach(lines) { line in
                        Text(line.text)
                            .font(line.index == activeIndex ? MochyFont.bold(28) : MochyFont.semibold(21))
                            .foregroundStyle(
                                line.index == activeIndex
                                    ? palette.text
                                    : palette.secondaryText.opacity(0.48)
                            )
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scaleEffect(glowScale(line), anchor: .leading)
                            .shadow(
                                color: line.index == activeIndex && store.settings.lyricsAnimation == .glow
                                    ? palette.accent.opacity(0.5) : .clear,
                                radius: 22
                            )
                            .blur(radius: focusBlur(line))
                            .offset(y: waveOffset(line))
                            .id(line.index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.seek(to: line.time)
                            }
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: activeIndex)
                    }
                    Color.clear.frame(height: 160)
                }
                .padding(.horizontal, 26)
            }
            .onAppear {
                proxy.scrollTo(activeIndex, anchor: .center)
            }
            .onChange(of: activeIndex) { _, index in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private func plainView(_ text: String) -> some View {
        ScrollView(showsIndicators: false) {
            Text(text)
                .font(MochyFont.medium(17))
                .foregroundStyle(palette.text.opacity(0.86))
                .lineSpacing(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 80)
        }
    }

    private func glowScale(_ line: LyricLine) -> CGFloat {
        guard store.settings.lyricsAnimation == .glow else { return 1 }
        return line.index == activeIndex ? 1.035 : 1
    }

    private func focusBlur(_ line: LyricLine) -> CGFloat {
        guard store.settings.lyricsAnimation == .focus else { return 0 }
        return line.index == activeIndex ? 0 : 0.7
    }

    private func waveOffset(_ line: LyricLine) -> CGFloat {
        guard store.settings.lyricsAnimation == .wave else { return 0 }
        return line.index == activeIndex ? -3 : 0
    }

    private func updateActiveIndex(_ time: Double) {
        guard let lines = lyrics?.synced, !lines.isEmpty else { return }
        var index = 0
        for (offset, line) in lines.enumerated() where line.time <= time + 0.15 {
            index = offset
        }
        if index != activeIndex {
            activeIndex = index
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let found = try await InnerTubeAPI.shared.lyrics(
                title: song.title,
                artist: song.artistLine,
                album: song.albumTitle,
                duration: song.duration
            )
            lyrics = found
            activeIndex = 0
            updateActiveIndex(player.currentTime)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Compact lyrics stage used by the lyrics player style

struct LyricsStageView: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette

    var song: Song

    @State private var lyrics: Lyrics?
    @State private var isLoading = true

    private var activeLine: String? {
        guard let lines = lyrics?.synced, !lines.isEmpty else { return nil }
        var current: LyricLine?
        for line in lines where line.time <= player.currentTime + 0.15 {
            current = line
        }
        return current?.text
    }

    private var nextLines: [LyricLine] {
        guard let lines = lyrics?.synced else { return [] }
        guard let current = lines.last(where: { $0.time <= player.currentTime + 0.15 }) else {
            return Array(lines.prefix(2))
        }
        let index = current.index
        return Array(lines.dropFirst(index + 1).prefix(2))
    }

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                LoadingDots()
            } else if let activeLine {
                Text(activeLine)
                    .font(MochyFont.bold(27))
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.center)
                    .shadow(color: palette.accent.opacity(0.35), radius: 20)
                    .transition(.opacity)
                ForEach(nextLines) { line in
                    Text(line.text)
                        .font(MochyFont.medium(16))
                        .foregroundStyle(palette.secondaryText.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
            } else if let plain = lyrics?.plain {
                Text(plain.components(separatedBy: .newlines).prefix(5).joined(separator: "\n"))
                    .font(MochyFont.medium(16))
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
            } else {
                Text("No lyrics found")
                    .font(MochyFont.medium(14))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: activeLine)
        .task(id: song.id) {
            isLoading = true
            lyrics = try? await InnerTubeAPI.shared.lyrics(
                title: song.title,
                artist: song.artistLine,
                album: song.albumTitle,
                duration: song.duration
            )
            isLoading = false
        }
    }
}
