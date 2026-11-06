import SwiftUI
import UIKit

struct SearchView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette

    @State private var query = ""
    @State private var filter: SearchFilter = .all
    @State private var results: [MediaItem] = []
    @State private var suggestions: [String] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var recentSearches: [String] = []
    @State private var hasSearched = false
    @State private var submittedQuery = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchBar
                filterBar
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if query.isEmpty {
                            recentAndBrowse
                        } else if focused && !suggestions.isEmpty && !hasSearched {
                            suggestionList
                        } else {
                            resultContent
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(palette.background)
            .navigationDestination(for: AppRoute.self) { route in
                RouteDestination(route: route)
            }
            .task(id: query) {
                await queryChanged()
            }
            .task(id: filter) {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    await runSearch()
                }
            }
            .onAppear {
                recentSearches = UserDefaults.standard.stringArray(forKey: "mochy.recentSearches") ?? []
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                TextField("Songs, albums, artists...", text: $query)
                    .font(MochyFont.medium(15))
                    .foregroundStyle(palette.text)
                    .tint(palette.accent)
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit {
                        saveRecent(query)
                        hasSearched = true
                        focused = false
                        Task { await runSearch() }
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                        suggestions = []
                        hasSearched = false
                        submittedQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(palette.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 44)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )

            if focused || !query.isEmpty {
                Button("Cancel") {
                    query = ""
                    results = []
                    suggestions = []
                    hasSearched = false
                    submittedQuery = ""
                    focused = false
                }
                .font(MochyFont.semibold(13))
                .foregroundStyle(palette.text)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.2), value: focused)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchFilter.allCases) { option in
                    Button {
                        filter = option
                    } label: {
                        Text(option.title)
                            .font(MochyFont.semibold(12))
                            .foregroundStyle(filter == option ? palette.accentText : palette.secondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(filter == option ? palette.accent : Color.white.opacity(0.055))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private var recentAndBrowse: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !recentSearches.isEmpty {
                HStack {
                    Text("Recent searches")
                        .font(MochyFont.bold(19))
                        .foregroundStyle(palette.text)
                    Spacer()
                    Button("Clear") {
                        recentSearches = []
                        UserDefaults.standard.removeObject(forKey: "mochy.recentSearches")
                    }
                    .font(MochyFont.medium(12))
                    .foregroundStyle(palette.secondaryText)
                }
                VStack(spacing: 2) {
                    ForEach(recentSearches, id: \.self) { recent in
                        Button {
                            query = recent
                            focused = false
                            hasSearched = true
                            Task { await runSearch() }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 15))
                                    .foregroundStyle(palette.tertiaryText)
                                Text(recent)
                                    .font(MochyFont.medium(14))
                                    .foregroundStyle(palette.text)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(palette.tertiaryText)
                            }
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 13) {
                Text("Find your sound")
                    .font(MochyFont.bold(22))
                    .foregroundStyle(palette.text)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    browseTile(title: "New releases", icon: "sparkles", colors: [palette.accent, palette.accent.opacity(0.35)], term: "new music")
                    browseTile(title: "Chill", icon: "moon.stars.fill", colors: [Color(hex: "#4B6CB7"), Color(hex: "#182848")], term: "chill")
                    browseTile(title: "Energy", icon: "bolt.fill", colors: [Color(hex: "#F2994A"), Color(hex: "#F2C94C")], term: "energy")
                    browseTile(title: "Focus", icon: "scope", colors: [Color(hex: "#11998E"), Color(hex: "#38EF7D")], term: "focus")
                }
            }
        }
    }

    private func browseTile(title: String, icon: String, colors: [Color], term: String) -> some View {
        Button {
            query = term
            hasSearched = true
            focused = false
            Task { await runSearch() }
        } label: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: icon)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.16))
                    .offset(x: 86, y: -24)
                Text(title)
                    .font(MochyFont.bold(15))
                    .foregroundStyle(.white)
                    .padding(14)
            }
            .frame(height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    query = suggestion
                    focused = false
                    hasSearched = true
                    saveRecent(suggestion)
                    Task { await runSearch() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.tertiaryText)
                        Text(suggestion)
                            .font(MochyFont.medium(14))
                            .foregroundStyle(palette.text)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.tertiaryText)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().overlay(palette.separator)
            }
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if isSearching && results.isEmpty {
            HStack {
                Spacer()
                LoadingDots()
                Spacer()
            }
            .padding(.top, 60)
        } else if let errorMessage {
            EmptyStateView(
                icon: "exclamationmark.magnifyingglass",
                title: "Search failed",
                message: errorMessage,
                actionTitle: "Retry"
            ) {
                Task { await runSearch() }
            }
        } else if results.isEmpty && hasSearched {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No results",
                message: "Try a different spelling or another filter."
            )
        } else {
            switch filter {
            case .all:
                allResults
            case .songs, .videos:
                songResults
            case .albums:
                albumResults
            case .artists:
                artistResults
            case .playlists:
                playlistResults
            }
        }
    }

    private var allResults: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let first = results.first {
                SectionHeader(title: "Top result")
                topResultCard(first)
            }
            if !songs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "Songs")
                    ForEach(Array(songs.prefix(4))) { item in
                        if let song = item.song {
                            SongRow(song: song, contextSongs: results.compactMap(\.song))
                        }
                    }
                }
            }
            if !videos.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "Videos")
                    ForEach(Array(videos.prefix(3))) { item in
                        if let song = item.song {
                            SongRow(song: song, contextSongs: results.compactMap(\.song))
                        }
                    }
                }
            }
            if !albums.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Albums")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(albums) { item in
                                MediaCard(item: item, width: 148)
                            }
                        }
                    }
                    .padding(.horizontal, -18)
                    .contentMargins(.horizontal, 18)
                }
            }
            if !artists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Artists")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(artists) { item in
                                MediaCard(item: item, width: 118)
                            }
                        }
                    }
                    .padding(.horizontal, -18)
                    .contentMargins(.horizontal, 18)
                }
            }
            if !playlists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Playlists")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(playlists) { item in
                                MediaCard(item: item, width: 148)
                            }
                        }
                    }
                    .padding(.horizontal, -18)
                    .contentMargins(.horizontal, 18)
                }
            }
        }
    }

    private func topResultCard(_ item: MediaItem) -> some View {
        Group {
            if let song = item.song {
                Button {
                    store.play(song, queue: results.compactMap(\.song))
                } label: {
                    topCardContent(item)
                }
                .buttonStyle(.plain)
            } else if let route = item.route {
                NavigationLink(value: route) {
                    topCardContent(item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func topCardContent(_ item: MediaItem) -> some View {
        HStack(spacing: 14) {
            RemoteArtwork(url: item.thumbnail, cornerRadius: item.artist == nil ? 12 : 28)
                .frame(width: 76, height: 76)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(MochyFont.bold(18))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                Text(item.subtitle)
                    .font(MochyFont.medium(12))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.tertiaryText)
                .padding(.trailing, 4)
        }
        .mochyCard(radius: 18, padding: 14)
    }

    private var songResults: some View {
        let items = filter == .videos ? videos : songs
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: filter == .videos ? "Videos" : "Songs")
            ForEach(items) { item in
                if let song = item.song {
                    SongRow(song: song, contextSongs: items.compactMap(\.song))
                }
            }
        }
    }

    private var albumResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Albums")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 20) {
                ForEach(albums) { item in
                    MediaCard(item: item, width: (UIScreen.main.bounds.width - 50) / 2)
                }
            }
        }
    }

    private var artistResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Artists")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 20) {
                ForEach(artists) { item in
                    MediaCard(item: item, width: (UIScreen.main.bounds.width - 50) / 2)
                }
            }
        }
    }

    private var playlistResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Playlists")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 20) {
                ForEach(playlists) { item in
                    MediaCard(item: item, width: (UIScreen.main.bounds.width - 50) / 2)
                }
            }
        }
    }

    private var songs: [MediaItem] { results.filter { $0.song != nil && $0.song?.isVideoSong != true } }
    private var videos: [MediaItem] { results.filter { $0.song?.isVideoSong == true } }
    private var albums: [MediaItem] { results.filter { $0.album != nil } }
    private var artists: [MediaItem] { results.filter { $0.artist != nil } }
    private var playlists: [MediaItem] { results.filter { $0.playlist != nil } }

    private func queryChanged() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            results = []
            hasSearched = false
            submittedQuery = ""
            return
        }
        if hasSearched {
            guard trimmed != submittedQuery else { return }
            hasSearched = false
        }
        try? await Task.sleep(nanoseconds: 260_000_000)
        guard !Task.isCancelled else { return }
        if let found = try? await InnerTubeAPI.shared.searchSuggestions(query: trimmed) {
            guard !Task.isCancelled, query.trimmingCharacters(in: .whitespaces) == trimmed else { return }
            suggestions = Array(found.prefix(8))
        }
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        hasSearched = true
        submittedQuery = trimmed
        do {
            let found = try await InnerTubeAPI.shared.search(query: trimmed, filter: filter)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                results = found
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    private func saveRecent(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var items = recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        items.insert(trimmed, at: 0)
        recentSearches = Array(items.prefix(8))
        UserDefaults.standard.set(recentSearches, forKey: "mochy.recentSearches")
    }
}
