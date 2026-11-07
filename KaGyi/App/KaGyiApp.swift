import SwiftUI

@main
struct KaGyiApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .task { await model.load() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        switch model.loadState {
        case .ready:
            HomeView()
                .tint(Theme.primary)
        case .loading(let p):
            LoadingView(progress: p, error: nil)
        case .failed(let message):
            LoadingView(progress: 0, error: message)
        }
    }
}
