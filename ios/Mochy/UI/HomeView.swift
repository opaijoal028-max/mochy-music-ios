import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette

    @State private var selectedChip: String?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 26) {
                    header
                    if let page = store.home, !page.chips.isEmpty {
                        chipRow(page.chips)
                    }
                    content
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background(palette.background)
            .refreshable {
                await store.refreshHome()
            }
            .navigationDestination(for: AppRoute.self) { route in
                RouteDestination(route: route)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("MOCHY")
                    .font(MochyFont.black(29))
                    .tracking(-0.5)
                    .foregroundStyle(palette.text)
                Text("\(greeting), \(store.settings.profileName)")
                    .font(MochyFont.medium(12))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            NavigationLink(value: AppRoute.profile) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent.opacity(0.85), palette.accent.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(String(store.settings.profileName.prefix(1)).uppercased())
                        .font(MochyFont.bold(18))
                        .foregroundStyle(palette.accentText)
                }
                .frame(width: 42, height: 42)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
    }

    private func chipRow(_ chips: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedChip = selectedChip == chip ? nil : chip
                        }
                    } label: {
                        Text(chip)
                            .font(MochyFont.semibold(12))
                            .foregroundStyle(selectedChip == chip ? palette.accentText : palette.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule().fill(
                                    selectedChip == chip ? palette.accent : Color.white.opacity(0.07)
                                )
                            )
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, -18)
        .contentMargins(.horizontal, 18)
    }

    @ViewBuilder
    private var content: some View {
        if store.homeLoading && store.home == nil {
            loadingView
        } else if let error = store.homeError, store.home == nil {
            EmptyStateView(
                icon: "wifi.exclamationmark",
                title: "Can't reach YouTube Music",
                message: error,
                actionTitle: "Try again"
            ) {
                Task { await store.refreshHome() }
            }
        } else if let page = store.home {
            if page.sections.isEmpty {
                EmptyStateView(
                    icon: "music.note",
                    title: "Nothing here yet",
                    message: "Pull down to refresh your home feed."
                )
            } else {
                sections(page.sections)
            }
        } else {
            loadingView
        }
    }

    @ViewBuilder
    private func sections(_ sections: [HomeSection]) -> some View {
        switch store.settings.homeStyle {
        case .mochyy:
            if let hero = sections.first {
                heroSection(hero)
            }
            ForEach(Array(sections.dropFirst())) { section in
                carouselSection(section)
            }
        case .listenNow:
            if let first = sections.first {
                SectionHeader(title: "Listen now", subtitle: first.subtitle)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 18) {
                    ForEach(Array(first.items.prefix(6))) { item in
                        MediaCard(item: item, width: (UIScreen.main.bounds.width - 48) / 2, contextSongs: first.items.compactMap(\.song))
                    }
                }
            }
            ForEach(Array(sections.dropFirst())) { section in
                carouselSection(section)
            }
        case .hopIn:
            ForEach(sections) { section in
                compactSection(section)
            }
        }
    }

    private func heroSection(_ section: HomeSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: section.title, subtitle: section.subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(section.items.prefix(5)) { item in
                        heroCard(item, songs: section.items.compactMap(\.song))
                    }
                }
            }
            .padding(.horizontal, -18)
            .contentMargins(.horizontal, 18)
        }
    }

    @ViewBuilder
    private func heroCard(_ item: MediaItem, songs: [Song]) -> some View {
        let content = ZStack(alignment: .bottomLeading) {
            RemoteArtwork(url: item.thumbnail, cornerRadius: 22, aspectRatio: nil)
                .frame(width: 282, height: 330)
            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(MochyFont.bold(22))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(item.subtitle)
                    .font(MochyFont.medium(12))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .padding(18)
            .frame(width: 282, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
        )

        if let route = item.route {
            NavigationLink(value: route) { content }
                .buttonStyle(.plain)
        } else if let song = item.song {
            Button {
                store.play(song, queue: songs)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func carouselSection(_ section: HomeSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: section.title, subtitle: section.subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(section.items) { item in
                        MediaCard(item: item, width: 148, contextSongs: section.items.compactMap(\.song))
                    }
                }
            }
            .padding(.horizontal, -18)
            .contentMargins(.horizontal, 18)
        }
    }

    private func compactSection(_ section: HomeSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: section.title, subtitle: section.subtitle)
            VStack(spacing: 2) {
                ForEach(Array(section.items.prefix(5))) { item in
                    if let song = item.song {
                        SongRow(song: song, showArtwork: true, contextSongs: section.items.compactMap(\.song))
                    } else if let route = item.route {
                        NavigationLink(value: route) {
                            HStack(spacing: 12) {
                                RemoteArtwork(url: item.thumbnail, cornerRadius: 9, symbol: "square.stack")
                                    .frame(width: 48, height: 48)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(MochyFont.semibold(14))
                                        .foregroundStyle(palette.text)
                                        .lineLimit(1)
                                    Text(item.subtitle)
                                        .font(MochyFont.regular(11))
                                        .foregroundStyle(palette.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(palette.tertiaryText)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                ForEach(0..<2) { _ in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.055))
                        .frame(width: 160, height: 220)
                }
            }
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 72)
            }
        }
        .redacted(reason: .placeholder)
        .padding(.top, 10)
    }
}
