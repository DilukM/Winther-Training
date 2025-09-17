import SwiftUI
import AVFoundation

@main
struct QuickPose_DemoApp: App {
    var body: some Scene {
        WindowGroup {
            #if !targetEnvironment(simulator)
            DemoAppView()
                .edgesIgnoringSafeArea(.all)
                .background(AppTheme.backgroundColor)
            #else
            Text("QuickPose.ai requires a native arm64 device to run")
                .font(.system(size: 42, weight: .semibold)).foregroundColor(.red)
            #endif
        }
    }
}

struct DemoAppView: View {
    var body: some View {
        HomeView()
    }
}

