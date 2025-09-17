import SwiftUI
import AVFoundation

struct HomeView: View {
    @State private var showDetection = false
    @State private var cameraPermissionGranted: Bool? = nil
    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.large) {
                Spacer()
                VStack(spacing: AppTheme.Spacing.medium) {
                    Text("QuickPose Demo")
                        .font(AppTheme.FontStyle.title)
                        .multilineTextAlignment(.center)
                    Text("Explore real‑time pose overlay and detection.")
                        .font(AppTheme.FontStyle.subtitle)
                        .foregroundColor(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
                VStack(spacing: AppTheme.Spacing.medium) {
                    Button(action: {
                        requestCameraIfNeeded { granted in
                            if granted { showDetection = true } else { showingPermissionAlert = true }
                        }
                    }) {
                        Label("Start Detection", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppTheme.ButtonStylePrimary())
                    .padding(.horizontal, AppTheme.Spacing.large)
                }
                Spacer()
            }
            .padding(.vertical)
            .background(AppTheme.backgroundColor.gradient.opacity(0.9))
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.backgroundColor, for: .navigationBar)
            .navigationDestination(isPresented: $showDetection) {
                DetectionView()
            }
            .alert("Camera Access Needed", isPresented: $showingPermissionAlert, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text("Please enable camera access in Settings to use detection.")
            })
            .onAppear {
                // Pre-fetch permission state
                if cameraPermissionGranted == nil {
                    cameraPermissionGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
                }
            }
        }
    }

    private func requestCameraIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
