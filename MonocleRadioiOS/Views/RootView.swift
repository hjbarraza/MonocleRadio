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

    var body: some View {
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
            if viewModel.currentShow != nil {
                MiniPlayerBar(viewModel: viewModel) { showNowPlaying = true }
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView(viewModel: viewModel)
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
