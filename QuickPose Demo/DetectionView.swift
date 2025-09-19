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
    @StateObject private var exerciseAnalyzer = DumbbellBentOverRowAnalyzer()

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

            // Exercise feedback overlay
            VStack {
                HStack {
                    Spacer()
                    exerciseStatsView
                }
                Spacer()
                if !exerciseAnalyzer.feedback.isEmpty {
                    exerciseFeedbackView
                }
                Spacer()
            }
            .padding()

            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding()

            // Toggle and reset buttons
            VStack {
                Spacer()
                HStack {
                    Button(action: { 
                        DispatchQueue.main.async {
                            exerciseAnalyzer.reset()
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button(action: { 
                        DispatchQueue.main.async {
                            isUsingVideo.toggle()
                        }
                    }) {
                        Image(systemName: isUsingVideo ? "camera" : "video")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if videoURL == nil {
                videoURL = Bundle.main.url(forResource: "0918", withExtension: "mov") ?? Bundle.main.url(forResource: "happy-dance", withExtension: "mov")
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
            DispatchQueue.main.async {
                if newValue {
                    player?.play()
                } else {
                    player?.pause()
                }
                quickPose.stop()
                startDetection()
            }
        }
    }

    // MARK: - Exercise UI Components
    
    private var exerciseStatsView: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 16) {
                VStack {
                    Text("Reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(exerciseAnalyzer.repCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                VStack {
                    Text("Phase")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(phaseText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(phaseColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var exerciseFeedbackView: some View {
        VStack(spacing: 8) {
            ForEach(Array(exerciseAnalyzer.feedback.sorted { $0.priority > $1.priority }.prefix(2).enumerated()), id: \.offset) { index, feedback in
                HStack {
                    Image(systemName: feedbackIcon(for: feedback.type))
                        .foregroundColor(feedbackColor(for: feedback.type))
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(feedback.message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(feedbackBackgroundColor(for: feedback.type))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal)
    }
    
    private var phaseText: String {
        switch exerciseAnalyzer.currentPhase {
        case .preparation: return "Ready"
        case .starting: return "Start"
        case .lowering: return "Lower"
        case .bottom: return "Bottom"
        case .raising: return "Pull"
        case .top: return "Top"
        case .finished: return "Done"
        }
    }
    
    private var phaseColor: Color {
        switch exerciseAnalyzer.currentPhase {
        case .preparation: return .orange
        case .starting, .lowering, .raising: return .blue
        case .bottom, .top: return .green
        case .finished: return .purple
        }
    }
    
    private func feedbackIcon(for type: FeedbackType) -> String {
        switch type {
        case .correct: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    private func feedbackColor(for type: FeedbackType) -> Color {
        switch type {
        case .correct: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    private func feedbackBackgroundColor(for type: FeedbackType) -> Color {
        switch type {
        case .correct: return .green.opacity(0.1)
        case .warning: return .orange.opacity(0.1)
        case .error: return .red.opacity(0.1)
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
        print("DEBUG: Starting QuickPose detection...")
        quickPose.start(features: [.overlay(.wholeBody)], onFrame: { status, image, features, feedback, landmarks in
            DispatchQueue.main.async {
                overlayImage = image
                
                // Process landmarks for exercise analysis on main thread
                if let landmarks = landmarks {
                    print("DEBUG: QuickPose onFrame called with landmarks received")
                    let landmarkDict = convertLandmarksToDict(landmarks)
                    print("DEBUG: Converted \(landmarkDict.count) landmarks to dictionary")
                    let exerciseFeedback = exerciseAnalyzer.analyzePose(landmarks: landmarkDict)
                    // exerciseFeedback is now available in exerciseAnalyzer.feedback
                } else {
                    print("DEBUG: QuickPose onFrame called but landmarks is nil")
                }
            }
        })
        print("DEBUG: QuickPose start() called")
    }
    
    private func convertLandmarksToDict(_ landmarks: QuickPose.Landmarks) -> [String: CGPoint] {
        var landmarkDict: [String: CGPoint] = [:]
        
        // Convert QuickPose landmarks using the correct API format: landmarks.landmark(forBody: .bodyPart(side:))
        // Note: landmarks.landmark(forBody:) returns non-optional Point3d
        let nose = landmarks.landmark(forBody: .nose)
        landmarkDict["nose"] = CGPoint(x: nose.x, y: nose.y)
        
        let leftShoulder = landmarks.landmark(forBody: .shoulder(side: .left))
        landmarkDict["left_shoulder"] = CGPoint(x: leftShoulder.x, y: leftShoulder.y)
        
        let rightShoulder = landmarks.landmark(forBody: .shoulder(side: .right))
        landmarkDict["right_shoulder"] = CGPoint(x: rightShoulder.x, y: rightShoulder.y)
        
        let leftElbow = landmarks.landmark(forBody: .elbow(side: .left))
        landmarkDict["left_elbow"] = CGPoint(x: leftElbow.x, y: leftElbow.y)
        
        let rightElbow = landmarks.landmark(forBody: .elbow(side: .right))
        landmarkDict["right_elbow"] = CGPoint(x: rightElbow.x, y: rightElbow.y)
        
        let leftWrist = landmarks.landmark(forBody: .wrist(side: .left))
        landmarkDict["left_wrist"] = CGPoint(x: leftWrist.x, y: leftWrist.y)
        
        let rightWrist = landmarks.landmark(forBody: .wrist(side: .right))
        landmarkDict["right_wrist"] = CGPoint(x: rightWrist.x, y: rightWrist.y)
        
        let leftHip = landmarks.landmark(forBody: .hip(side: .left))
        landmarkDict["left_hip"] = CGPoint(x: leftHip.x, y: leftHip.y)
        
        let rightHip = landmarks.landmark(forBody: .hip(side: .right))
        landmarkDict["right_hip"] = CGPoint(x: rightHip.x, y: rightHip.y)
        
        let leftKnee = landmarks.landmark(forBody: .knee(side: .left))
        landmarkDict["left_knee"] = CGPoint(x: leftKnee.x, y: leftKnee.y)
        
        let rightKnee = landmarks.landmark(forBody: .knee(side: .right))
        landmarkDict["right_knee"] = CGPoint(x: rightKnee.x, y: rightKnee.y)
        
        let leftAnkle = landmarks.landmark(forBody: .ankle(side: .left))
        landmarkDict["left_ankle"] = CGPoint(x: leftAnkle.x, y: leftAnkle.y)
        
        let rightAnkle = landmarks.landmark(forBody: .ankle(side: .right))
        landmarkDict["right_ankle"] = CGPoint(x: rightAnkle.x, y: rightAnkle.y)
        
        print("DEBUG: Converted \(landmarkDict.count) landmarks to dictionary")
        
        return landmarkDict
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
