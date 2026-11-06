import SwiftUI

struct QueueSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    private var upNext: [Song] {
        guard player.currentIndex + 1 < player.queue.count else { return [] }
        return Array(player.queue.dropFirst(player.currentIndex + 1))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 10) {
                        Button {
                            player.setShuffle(!player.shuffle)
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .font(MochyFont.semibold(12))
                                .foregroundStyle(player.shuffle ? palette.accentText : palette.text)
                                .padding(.horizontal, 14)
                                .frame(height: 38)
                                .background(
                                    Capsule().fill(player.shuffle ? palette.accent : Color.white.opacity(0.07))
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            player.cycleRepeatMode()
                        } label: {
                            Label(repeatLabel, systemImage: repeatIcon)
                                .font(MochyFont.semibold(12))
                                .foregroundStyle(player.repeatMode == .off ? palette.text : palette.accentText)
                                .padding(.horizontal, 14)
                                .frame(height: 38)
                                .background(
                                    Capsule().fill(player.repeatMode == .off ? Color.white.opacity(0.07) : palette.accent)
                                )
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 18)

                    if let current = player.currentSong {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("NOW PLAYING")
                                .font(MochyFont.semibold(10))
                                .tracking(1.3)
                                .foregroundStyle(palette.tertiaryText)
                            queueRow(current, isCurrent: true, index: nil)
                        }
                        .padding(.horizontal, 18)
                    }

                    if upNext.isEmpty {
                        EmptyStateView(
                            icon: "text.line.last.and.arrowtriangle.forward",
                            title: "Nothing up next",
                            message: "Add songs to your queue from any track menu."
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("UP NEXT")
                                    .font(MochyFont.semibold(10))
                                    .tracking(1.3)
                                    .foregroundStyle(palette.tertiaryText)
                                Spacer()
                                Text("\(upNext.count) songs")
                                    .font(MochyFont.medium(10))
                                    .foregroundStyle(palette.tertiaryText)
                            }
                            ForEach(Array(upNext.enumerated()), id: \.element.id) { offset, song in
                                queueRow(song, isCurrent: false, index: player.currentIndex + 1 + offset)
                            }
                        }
                        .padding(.horizontal, 18)
                    }

                    if player.queue.count > 0 {
                        Button(role: .destructive) {
                            player.removeFromQueue(at: IndexSet(integersIn: 0..<player.queue.count))
                        } label: {
                            Text("Clear queue")
                                .font(MochyFont.semibold(13))
                                .foregroundStyle(Color(hex: "#F06A6A"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color.white.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(palette.background)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.text)
                    }
                }
            }
        }
    }

    private func queueRow(_ song: Song, isCurrent: Bool, index: Int?) -> some View {
        HStack(spacing: 12) {
            RemoteArtwork(url: song.thumbnail, cornerRadius: 9)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(MochyFont.semibold(14))
                    .foregroundStyle(isCurrent ? palette.accent : palette.text)
                    .lineLimit(1)
                Text(song.artistLine)
                    .font(MochyFont.regular(11))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.accent)
            } else if let index {
                Button {
                    player.jumpToQueueItem(index)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var repeatLabel: String {
        switch player.repeatMode {
        case .off: return "Repeat"
        case .all: return "Repeat all"
        case .one: return "Repeat one"
        }
    }

    private var repeatIcon: String {
        player.repeatMode == .one ? "repeat.1" : "repeat"
    }
}
