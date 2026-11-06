import SwiftUI

struct CreatePlaylistSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mochyPalette) private var palette

    @State private var name = ""
    @State private var description = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("New playlist")
                    .font(MochyFont.bold(22))
                    .foregroundStyle(palette.text)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 12) {
                TextField("Playlist name", text: $name)
                    .font(MochyFont.medium(15))
                    .foregroundStyle(palette.text)
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                TextField("Description (optional)", text: $description, axis: .vertical)
                    .font(MochyFont.medium(14))
                    .foregroundStyle(palette.text)
                    .lineLimit(2...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                store.createPlaylist(name: name, description: description)
                dismiss()
            } label: {
                Text("Create playlist")
                    .font(MochyFont.semibold(15))
                    .foregroundStyle(palette.accentText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(palette.accent, in: Capsule())
                    .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(20)
        .background(palette.background)
        .onAppear { focused = true }
    }
}

struct AddToPlaylistSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mochyPalette) private var palette

    var song: Song

    @State private var newName = ""
    @State private var creating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        RemoteArtwork(url: song.thumbnail, cornerRadius: 9)
                            .frame(width: 50, height: 50)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.title)
                                .font(MochyFont.semibold(15))
                                .foregroundStyle(palette.text)
                                .lineLimit(1)
                            Text(song.artistLine)
                                .font(MochyFont.regular(12))
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .padding(.bottom, 12)

                    if store.playlists.isEmpty {
                        Text("No playlists yet. Create one below.")
                            .font(MochyFont.regular(13))
                            .foregroundStyle(palette.secondaryText)
                            .padding(.vertical, 18)
                    } else {
                        ForEach(store.playlists) { playlist in
                            Button {
                                store.add(song, to: playlist)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [palette.accent.opacity(0.6), palette.elevated],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.85))
                                    }
                                    .frame(width: 46, height: 46)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(playlist.name)
                                            .font(MochyFont.semibold(14))
                                            .foregroundStyle(palette.text)
                                            .lineLimit(1)
                                        Text("\(playlist.songs.count) songs")
                                            .font(MochyFont.regular(11))
                                            .foregroundStyle(palette.secondaryText)
                                    }
                                    Spacer()
                                    if playlist.songs.contains(where: { $0.id == song.id }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(palette.accent)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(palette.secondaryText)
                                    }
                                }
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider().overlay(palette.separator).padding(.vertical, 8)

                    if creating {
                        HStack(spacing: 8) {
                            TextField("New playlist name", text: $newName)
                                .font(MochyFont.medium(14))
                                .foregroundStyle(palette.text)
                                .padding(.horizontal, 12)
                                .frame(height: 42)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Button("Create") {
                                let playlist = store.createPlaylist(name: newName)
                                store.add(song, to: playlist)
                                dismiss()
                            }
                            .font(MochyFont.semibold(13))
                            .foregroundStyle(palette.accentText)
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                            .background(palette.accent, in: Capsule())
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        Button {
                            creating = true
                        } label: {
                            Label("New playlist", systemImage: "plus")
                                .font(MochyFont.semibold(14))
                                .foregroundStyle(palette.text)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
            .background(palette.background)
            .navigationTitle("Add to playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(MochyFont.semibold(13))
                        .foregroundStyle(palette.text)
                }
            }
        }
    }
}

struct SleepTimerSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mochyPalette) private var palette

    private let options = [5, 10, 15, 30, 45, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sleep timer")
                        .font(MochyFont.bold(22))
                        .foregroundStyle(palette.text)
                    Text(player.sleepTimerEnds == nil ? "Playback will keep going" : "Playback will pause automatically")
                        .font(MochyFont.medium(11))
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(options, id: \.self) { minutes in
                    Button {
                        player.setSleepTimer(minutes: minutes)
                        dismiss()
                    } label: {
                        Text("\(minutes) min")
                            .font(MochyFont.semibold(13))
                            .foregroundStyle(palette.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if player.sleepTimerEnds != nil {
                Button {
                    player.setSleepTimer(minutes: nil)
                    dismiss()
                } label: {
                    Text("Turn off timer")
                        .font(MochyFont.semibold(14))
                        .foregroundStyle(Color(hex: "#F06A6A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(palette.background)
    }
}
