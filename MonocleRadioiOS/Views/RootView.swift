// RootView.swift — adaptive navigation shell: split view on iPad, stack on iPhone
// Monocle Radio — iOS player for Monocle 24

import SwiftUI
import MonocleRadioKit

struct RootView: View {
    @Bindable var viewModel: RadioViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showNowPlaying = false
    @State private var audioSession: AudioSessionController?
    @State private var liveActivity = LiveActivityController()
    @Namespace private var playerNamespace

    /// The player expansion spring — snappy up, settled landing.
    static let expand = Animation.spring(response: 0.42, dampingFraction: 0.86)

    var body: some View {
        ZStack {
            NavigationSplitView {
                ShowListView(viewModel: viewModel)
            } detail: {
                if let show = viewModel.selectedShow {
                    if show.isLive {
                        LiveDetailView(viewModel: viewModel, show: show)
                    } else {
                        EpisodeListView(viewModel: viewModel, show: show)
                    }
                } else {
                    ContentUnavailableView(
                        "Select a show",
                        systemImage: "radio",
                        description: Text("Live radio and on-demand episodes from Monocle 24")
                    )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.currentShow != nil && !showNowPlaying {
                    MiniPlayerBar(viewModel: viewModel, namespace: playerNamespace) {
                        Haptics.tick()
                        withAnimation(Self.expand) { showNowPlaying = true }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if showNowPlaying {
                NowPlayingView(viewModel: viewModel, namespace: playerNamespace) {
                    withAnimation(Self.expand) { showNowPlaying = false }
                }
                .zIndex(1)
                .transition(.move(edge: .bottom))
            }
        }
        .onChange(of: viewModel.selectedShow) { _, show in
            // List selection drives navigation; route it through selectShow
            // for episode loading/caching. Never auto-play on navigation —
            // audio starts only from explicit play controls.
            if let show { viewModel.selectShow(show, autoplayLive: false) }
        }
        .onChange(of: scenePhase) { _, phase in
            // Keep the resume position fresh when the app leaves the foreground
            if phase == .background || phase == .inactive {
                viewModel.saveResumeState()
            }
        }
        // Mirror playback into the Dynamic Island / lock screen
        .onChange(of: viewModel.isPlaying) { _, _ in liveActivity.sync(with: viewModel) }
        .onChange(of: viewModel.subtitle) { _, _ in liveActivity.sync(with: viewModel) }
        .onChange(of: viewModel.currentShow) { _, _ in liveActivity.sync(with: viewModel) }
        .task {
            if audioSession == nil {
                audioSession = AudioSessionController(viewModel: viewModel)
            }
            // iPad: never show an empty detail pane — land on the live
            // destination (paused; play stays an explicit action)
            if sizeClass == .regular, viewModel.selectedShow == nil {
                viewModel.selectedShow = viewModel.shows.first(where: \.isLive)
            }
        }
    }
}
