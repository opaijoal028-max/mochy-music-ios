import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.mochyPalette) private var palette

    @State private var showSleepTimer = false
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    playbackSection
                    appearanceSection
                    playerSection
                    downloadsSection
                    integrationsSection
                    aboutSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(palette.background)
            .navigationDestination(for: AppRoute.self) { route in
                RouteDestination(route: route)
            }
            .sheet(isPresented: $showSleepTimer) {
                SleepTimerSheet()
                    .environmentObject(store)
                    .environmentObject(player)
                    .presentationDetents([.height(330)])
                    .presentationDragIndicator(.visible)
            }
            .confirmationDialog("Reset all settings?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset settings", role: .destructive) {
                    store.resetSettings()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(MochyFont.bold(32))
                .foregroundStyle(palette.text)
            NavigationLink(value: AppRoute.profile) {
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent.opacity(0.9), palette.accent.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text(String(store.settings.profileName.prefix(1)).uppercased())
                            .font(MochyFont.bold(22))
                            .foregroundStyle(palette.accentText)
                    }
                    .frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.settings.profileName)
                            .font(MochyFont.semibold(16))
                            .foregroundStyle(palette.text)
                        Text("\(store.totalPlays) plays · \(formattedListeningTime)")
                            .font(MochyFont.medium(11))
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.tertiaryText)
                }
                .mochyCard(radius: 20, padding: 14)
            }
            .buttonStyle(.plain)
        }
    }

    private var playbackSection: some View {
        settingsGroup("Playback") {
            settingsRow("Audio quality") {
                menuPicker(selection: $store.settings.audioQuality, options: AudioQuality.allCases, label: \.rawValue)
            }
            divider
            settingsRow("Crossfade") {
                Toggle("", isOn: $store.settings.crossfade)
                    .labelsHidden()
                    .tint(palette.accent)
            }
            if store.settings.crossfade {
                divider
                settingsRow("Crossfade duration") {
                    HStack(spacing: 10) {
                        Slider(value: $store.settings.crossfadeDuration, in: 1...12, step: 1)
                            .tint(palette.accent)
                            .frame(width: 130)
                        Text("\(Int(store.settings.crossfadeDuration))s")
                            .font(MochyFont.medium(12))
                            .foregroundStyle(palette.secondaryText)
                            .frame(width: 26, alignment: .trailing)
                    }
                }
            }
            divider
            settingsRow("Skip silence") {
                Toggle("", isOn: $store.settings.skipSilence)
                    .labelsHidden()
                    .tint(palette.accent)
            }
            divider
            settingsRow("Normalize volume") {
                Toggle("", isOn: $store.settings.normalizeAudio)
                    .labelsHidden()
                    .tint(palette.accent)
            }
            divider
            settingsRow("Mix with other apps") {
                Toggle("", isOn: $store.settings.mixWithOtherApps)
                    .labelsHidden()
                    .tint(palette.accent)
            }
            divider
            settingsRow("Sleep timer") {
                Button {
                    showSleepTimer = true
                } label: {
                    Text(sleepTimerLabel)
                        .font(MochyFont.medium(12))
                        .foregroundStyle(palette.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var appearanceSection: some View {
        settingsGroup("Appearance") {
            VStack(alignment: .leading, spacing: 10) {
                Text("App icon")
                    .font(MochyFont.medium(14))
                    .foregroundStyle(palette.text)
                HStack(spacing: 12) {
                    ForEach(AppIconStyle.allCases) { style in
                        Button {
                            store.applyAppIcon(style)
                        } label: {
                            iconSwatch(style)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            divider
            VStack(alignment: .leading, spacing: 10) {
                Text("Accent")
                    .font(MochyFont.medium(14))
                    .foregroundStyle(palette.text)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                    ForEach(AccentPalette.options) { option in
                        Button {
                            store.settings.dynamicTheme = false
                            store.settings.accentHex = option.hex
                        } label: {
                            Circle()
                                .fill(Color(hex: option.hex))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().strokeBorder(
                                        store.settings.accentHex.uppercased() == option.hex.uppercased() && !store.settings.dynamicTheme
                                            ? Color.white : Color.clear,
                                        lineWidth: 2
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.name)
                    }
                }
            }
            divider
            settingsRow("Dynamic artwork color") {
                Toggle("", isOn: $store.settings.dynamicTheme)
                    .labelsHidden()
                    .tint(palette.accent)
            }
            divider
            settingsRow("Pure black") {
                Toggle("", isOn: $store.settings.pureBlack)
                    .labelsHidden()
                    .tint(palette.accent)
            }
            divider
            settingsRow("Pure black mini player") {
                Toggle("", isOn: $store.settings.pureBlackMiniPlayer)
                    .labelsHidden()
                    .tint(palette.accent)
            }
            divider
            settingsRow("Home style") {
                menuPicker(selection: $store.settings.homeStyle, options: HomeStyle.allCases, label: \.rawValue)
            }
            divider
            settingsRow("Playlist style") {
                menuPicker(selection: $store.settings.playlistStyle, options: PlaylistStyle.allCases, label: \.rawValue)
            }
            divider
            settingsRow("Player style") {
                menuPicker(selection: $store.settings.playerStyle, options: PlayerStyle.allCases, label: \.rawValue)
            }
            divider
            settingsRow("Cover corners") {
                HStack(spacing: 10) {
                    Slider(value: $store.settings.coverRadius, in: 0...40, step: 1)
                        .tint(palette.accent)
                        .frame(width: 130)
                    Text("\(Int(store.settings.coverRadius))")
                        .font(MochyFont.medium(12))
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: 24, alignment: .trailing)
                }
            }
            divider
            settingsRow("Animations") {
                Toggle("", isOn: $store.settings.animations)
                    .labelsHidden()
                    .tint(palette.accent)
            }
            divider
            settingsRow("Lyrics animation") {
                menuPicker(selection: $store.settings.lyricsAnimation, options: LyricsAnimation.allCases, label: \.rawValue)
            }
        }
    }

    private var playerSection: some View {
        settingsGroup("Player") {
            settingsRow("Default tab") {
                menuPicker(selection: $store.settings.defaultTab, options: AppTab.allCases, label: \.rawValue)
            }
            divider
            settingsRow("Swipe right") {
                menuPicker(selection: $store.settings.swipeRight, options: SwipeAction.allCases, label: \.rawValue)
            }
            divider
            settingsRow("Swipe left") {
                menuPicker(selection: $store.settings.swipeLeft, options: SwipeAction.allCases, label: \.rawValue)
            }
            divider
            settingsRow("iPod theme") {
                menuPicker(selection: $store.settings.ipodTheme, options: IpodTheme.allCases, label: \.rawValue)
            }
            divider
            settingsRow("iPod wheel") {
                menuPicker(selection: $store.settings.ipodWheelColor, options: IpodWheelColor.allCases, label: \.rawValue)
            }
        }
    }

    private var downloadsSection: some View {
        settingsGroup("Downloads") {
            settingsRow("Download quality") {
                menuPicker(selection: $store.settings.downloadQuality, options: DownloadQuality.allCases, label: \.rawValue)
            }
            divider
            NavigationLink(value: AppRoute.downloads) {
                HStack {
                    Text("Manage downloads")
                        .font(MochyFont.medium(14))
                        .foregroundStyle(palette.text)
                    Spacer()
                    Text(store.downloadBytesText)
                        .font(MochyFont.medium(12))
                        .foregroundStyle(palette.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.tertiaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var integrationsSection: some View {
        settingsGroup("Integrations") {
            settingsRow("Last.fm scrobbling") {
                Toggle("", isOn: $store.settings.scrobbleLastFM)
                    .labelsHidden()
                    .tint(palette.accent)
            }
            if store.settings.scrobbleLastFM {
                divider
                HStack {
                    Text("Last.fm username")
                        .font(MochyFont.medium(13))
                        .foregroundStyle(palette.secondaryText)
                    Spacer()
                    TextField("username", text: $store.settings.lastFMUsername)
                        .font(MochyFont.medium(13))
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(maxWidth: 160)
                }
            }
            divider
            settingsRow("Discord presence") {
                Toggle("", isOn: $store.settings.shareDiscordPresence)
                    .labelsHidden()
                    .tint(palette.accent)
            }
        }
    }

    private var aboutSection: some View {
        settingsGroup("About") {
            Button {
                store.clearHistory()
            } label: {
                HStack {
                    Text("Clear listening history")
                        .font(MochyFont.medium(14))
                        .foregroundStyle(palette.text)
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .buttonStyle(.plain)
            divider
            Button {
                showResetConfirm = true
            } label: {
                HStack {
                    Text("Reset settings")
                        .font(MochyFont.medium(14))
                        .foregroundStyle(Color(hex: "#F06A6A"))
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#F06A6A"))
                }
            }
            .buttonStyle(.plain)
            divider
            HStack {
                Text("Mochy Music")
                    .font(MochyFont.medium(14))
                    .foregroundStyle(palette.text)
                Spacer()
                Text("8.3.2 · 1225")
                    .font(MochyFont.medium(12))
                    .foregroundStyle(palette.secondaryText)
            }
            divider
            HStack {
                Text("Made with")
                    .font(MochyFont.regular(12))
                    .foregroundStyle(palette.tertiaryText)
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.accent)
                Text("for music")
                    .font(MochyFont.regular(12))
                    .foregroundStyle(palette.tertiaryText)
                Spacer()
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.separator)
            .frame(height: 0.5)
    }

    private var sleepTimerLabel: String {
        guard let end = player.sleepTimerEnds else { return "Off" }
        let remaining = max(0, Int(end.timeIntervalSinceNow / 60))
        return "\(remaining) min left"
    }

    private var formattedListeningTime: String {
        let minutes = store.totalListeningSeconds / 60
        if minutes >= 60 {
            return String(format: "%dh %dm", minutes / 60, minutes % 60)
        }
        return "\(minutes)m"
    }

    private func settingsRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(MochyFont.medium(14))
                .foregroundStyle(palette.text)
            Spacer(minLength: 12)
            content()
        }
        .frame(minHeight: 26)
    }

    private func menuPicker<T: Hashable & Identifiable>(
        selection: Binding<T>,
        options: [T],
        label: KeyPath<T, String>
    ) -> some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    if option == selection.wrappedValue {
                        Label(option[keyPath: label], systemImage: "checkmark")
                    } else {
                        Text(option[keyPath: label])
                    }
                }
            }
        } label: {
            Text(selection.wrappedValue[keyPath: label])
                .font(MochyFont.medium(12))
                .foregroundStyle(palette.secondaryText)
        }
    }

    @ViewBuilder
    private func iconSwatch(_ style: AppIconStyle) -> some View {
        let selected = store.settings.appIcon == style
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(iconGradient(style))
                Text("M")
                    .font(MochyFont.black(22))
                    .foregroundStyle(iconForeground(style))
            }
            .frame(width: 48, height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(selected ? palette.accent : Color.white.opacity(0.1), lineWidth: selected ? 2 : 0.6)
            )
            Text(style.displayName)
                .font(MochyFont.medium(8))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
        }
        .frame(width: 56)
    }

    private func iconGradient(_ style: AppIconStyle) -> LinearGradient {
        switch style {
        case .mark:
            return LinearGradient(colors: [Color(hex: "#2A2A2E"), Color(hex: "#101012")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .light:
            return LinearGradient(colors: [Color(hex: "#F4F1EA"), Color(hex: "#D8D2C4")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blue:
            return LinearGradient(colors: [Color(hex: "#79A8FF"), Color(hex: "#2C5FD9")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pink:
            return LinearGradient(colors: [Color(hex: "#F5A5C8"), Color(hex: "#C74F8A")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .green:
            return LinearGradient(colors: [Color(hex: "#8FD9A2"), Color(hex: "#2E8B57")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func iconForeground(_ style: AppIconStyle) -> Color {
        style == .light ? Color(hex: "#141416") : .white
    }
}

// MARK: - Group container

struct SettingsGroup<Content: View>: View {
    @Environment(\.mochyPalette) private var palette
    var title: String
    var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(MochyFont.semibold(10))
                .tracking(1.2)
                .foregroundStyle(palette.tertiaryText)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 13) {
                content
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
        }
    }
}

extension SettingsView {
    func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        SettingsGroup(title: title) {
            content()
        }
    }
}
