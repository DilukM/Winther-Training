import SwiftUI
import QuickPoseCore
import QuickPoseSwiftUI
import AVKit

struct DetectionView: View {
    @Environment(\.dismiss) private var dismiss
    private var quickPose = QuickPose(sdkKey: "01K54BP0PZRR42DFPDHMDYQ8WV")
    @State private var overlayImage: UIImage?
    @State private var player: AVPlayer? = nil
    @State private var isUsingVideo = true
    @State private var videoURL: URL? = nil
    @State private var observer: NSObjectProtocol? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isUsingVideo, let url = videoURL {
                VideoPlayerView(player: player!)
                    .ignoresSafeArea()
                hiddenDetectionFeed(videoURL: url)
            } else {
                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        QuickPoseCameraView(useFrontCamera: false, delegate: quickPose)
                        QuickPoseOverlayView(overlayImage: $overlayImage)
                    }
                    .frame(width: geometry.size.width)
                    .edgesIgnoringSafeArea(.all)
                }
            }

            // Optional overlay for video mode - removed as per user request
            // if isUsingVideo, let img = overlayImage {
            //     Image(uiImage: img)
            //         .resizable()
            //         .scaledToFit()
            //         .ignoresSafeArea()
            // }

            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding()

            // Toggle button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { isUsingVideo.toggle() }) {
                        Image(systemName: isUsingVideo ? "camera" : "video")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if videoURL == nil {
                videoURL = Bundle.main.url(forResource: "20250825_104834", withExtension: "mp4") ?? Bundle.main.url(forResource: "happy-dance", withExtension: "mov")
            }
            if let url = videoURL, player == nil {
                player = AVPlayer(url: url)
                observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { _ in
                    player?.seek(to: .zero)
                    player?.play()
                }
                player?.play()
            }
            startDetection()
        }
        .onDisappear {
            if let obs = observer {
                NotificationCenter.default.removeObserver(obs)
                observer = nil
            }
            quickPose.stop()
            player?.pause()
        }
        .onChange(of: isUsingVideo) { newValue in
            if newValue {
                player?.play()
            } else {
                player?.pause()
            }
            quickPose.stop()
            startDetection()
        }
    }

    @ViewBuilder
    private func hiddenDetectionFeed(videoURL: URL) -> some View {
        QuickPoseSimulatedCameraView(useFrontCamera: false, delegate: quickPose, video: videoURL)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
    }

    private func startDetection() {
        quickPose.start(features: [.overlay(.wholeBody)], onFrame: { status, image, features, feedback, landmarks in
            overlayImage = image
        })
    }
}

struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

struct DetectionView_Previews: PreviewProvider {
    static var previews: some View {
        DetectionView()
    }
}
