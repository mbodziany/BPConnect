import SwiftUI

@main
struct KostkaApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(model)
        }
    }
}
