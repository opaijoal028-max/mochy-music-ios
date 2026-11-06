import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.mochyPalette) private var palette

    @State private var page = 0
    @State private var appeared = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            MochyBackground(
                palette: palette,
                artworkColor: palette.accent,
                showGlow: true
            )

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    personalisePage.tag(1)
                    readyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: page)

                bottomBar
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 54, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#252529"), Color(hex: "#0D0D10")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 170, height: 170)
                    .overlay(
                        RoundedRectangle(cornerRadius: 54, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: palette.accent.opacity(0.25), radius: 44, y: 18)
                Text("M")
                    .font(MochyFont.black(84))
                    .foregroundStyle(.white)
            }
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("MOCHY")
                    .font(MochyFont.display(46))
                    .foregroundStyle(palette.text)
                Text("Music that moves with you.")
                    .font(MochyFont.medium(15))
                    .foregroundStyle(palette.secondaryText)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var personalisePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Make it yours")
                        .font(MochyFont.bold(32))
                        .foregroundStyle(palette.text)
                    Text("Pick an accent and tell us what to call you.")
                        .font(MochyFont.regular(14))
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(.top, 60)

                VStack(alignment: .leading, spacing: 9) {
                    Text("YOUR NAME")
                        .font(MochyFont.semibold(10))
                        .tracking(1.3)
                        .foregroundStyle(palette.tertiaryText)
                    TextField("music lover", text: $store.settings.profileName)
                        .font(MochyFont.medium(16))
                        .foregroundStyle(palette.text)
                        .tint(palette.accent)
                        .focused($nameFocused)
                        .padding(.horizontal, 15)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.6)
                        )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("ACCENT")
                        .font(MochyFont.semibold(10))
                        .tracking(1.3)
                        .foregroundStyle(palette.tertiaryText)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 14) {
                        ForEach(AccentPalette.options) { option in
                            Button {
                                store.settings.dynamicTheme = false
                                store.settings.accentHex = option.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: option.hex))
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        Circle().strokeBorder(
                                            store.settings.accentHex.uppercased() == option.hex.uppercased() ? Color.white : Color.clear,
                                            lineWidth: 2.2
                                        )
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 14) {
                    miniPreview(title: "Liked", icon: "heart.fill")
                    miniPreview(title: "Home", icon: "house.fill")
                    miniPreview(title: "Player", icon: "play.fill")
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
    }

    private func miniPreview(title: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.accentText)
                .frame(width: 42, height: 42)
                .background(palette.accent, in: Circle())
            Text(title)
                .font(MochyFont.medium(10))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.16))
                    .frame(width: 180, height: 180)
                Circle()
                    .fill(palette.accent.opacity(0.28))
                    .frame(width: 120, height: 120)
                Image(systemName: "waveform")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(palette.accent)
            }

            VStack(spacing: 8) {
                Text("You're all set")
                    .font(MochyFont.bold(30))
                    .foregroundStyle(palette.text)
                Text("Stream, search, save and download — all in one place.")
                    .font(MochyFont.regular(14))
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 14) {
                featureRow(icon: "magnifyingglass", title: "Find anything", detail: "Songs, albums, artists and playlists.")
                featureRow(icon: "heart.fill", title: "Keep favourites", detail: "Liked songs and personal playlists.")
                featureRow(icon: "arrow.down.circle.fill", title: "Listen offline", detail: "Download tracks for later.")
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)

            Spacer()
            Spacer()
        }
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 34, height: 34)
                .background(palette.accent.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MochyFont.semibold(14))
                    .foregroundStyle(palette.text)
                Text(detail)
                    .font(MochyFont.regular(11))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill(index == page ? palette.accent : Color.white.opacity(0.16))
                        .frame(width: index == page ? 22 : 6, height: 6)
                        .animation(.easeOut(duration: 0.2), value: page)
                }
            }

            HStack(spacing: 12) {
                if page > 0 {
                    Button {
                        withAnimation { page -= 1 }
                    } label: {
                        Text("Back")
                            .font(MochyFont.semibold(14))
                            .foregroundStyle(palette.text)
                            .frame(width: 86, height: 48)
                            .background(Color.white.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        store.completeOnboarding(name: store.settings.profileName, accent: nil)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(page < 2 ? "Continue" : "Start listening")
                            .font(MochyFont.semibold(15))
                        Image(systemName: page < 2 ? "arrow.right" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(palette.accentText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(palette.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 18)
        .padding(.top, 10)
    }
}
