import Foundation
import CoreGraphics
import QuickPoseCore

// MARK: - Exercise Analysis Types
enum ExercisePhase {
    case preparation
    case starting
    case lowering
    case bottom
    case raising
    case top
    case finished
}

enum FeedbackType {
    case correct
    case warning
    case error
}

struct ExerciseFeedback {
    let type: FeedbackType
    let message: String
    let priority: Int // Higher number = higher priority
    let timestamp: Date // Add timestamp for persistence
}

// MARK: - Dumbbell BentOverRow Analyzer
class DumbbellBentOverRowAnalyzer: ObservableObject {
    @Published var currentPhase: ExercisePhase = .preparation
    @Published var feedback: [ExerciseFeedback] = []
    @Published var repCount: Int = 0
    @Published var isExerciseActive: Bool = false
    
    private var frameCount = 0
    private var lastPhase: ExercisePhase = .preparation
    private var phaseStartTime: Date = Date()
    private var minimumPhaseTime: TimeInterval = 0.3 // Minimum time in each phase
    
    // Key pose landmarks for bent over row
    struct PoseLandmarks {
        let leftShoulder: CGPoint?
        let rightShoulder: CGPoint?
        let leftElbow: CGPoint?
        let rightElbow: CGPoint?
        let leftWrist: CGPoint?
        let rightWrist: CGPoint?
        let leftHip: CGPoint?
        let rightHip: CGPoint?
        let nose: CGPoint?
        let leftKnee: CGPoint?
        let rightKnee: CGPoint?
        let leftAnkle: CGPoint?
        let rightAnkle: CGPoint?
    }
    
    func analyzePose(landmarks: [String: CGPoint]) -> [ExerciseFeedback] {
        frameCount += 1
        
        // Debug logging for landmark keys
        if frameCount % 120 == 0 { // Log every 120 frames to avoid spam
            print("DEBUG: Available landmark keys: \(landmarks.keys.sorted())")
        }
        
        let pose = extractPoseLandmarks(from: landmarks)
        
        // Debug logging for landmarks
        if frameCount % 30 == 0 { // Log every 30 frames to avoid spam
            print("DEBUG: Frame \(frameCount) - Landmarks received: \(landmarks.count)")
            print("DEBUG: Left elbow: \(pose.leftElbow.map { "(\($0.x), \($0.y))" } ?? "nil"), Right elbow: \(pose.rightElbow.map { "(\($0.x), \($0.y))" } ?? "nil")")
            print("DEBUG: Left shoulder: \(pose.leftShoulder.map { "(\($0.x), \($0.y))" } ?? "nil"), Right shoulder: \(pose.rightShoulder.map { "(\($0.x), \($0.y))" } ?? "nil")")
        }
        
        // Clear previous feedback
        feedback.removeAll()
        
        // Only analyze every 15 frames to reduce feedback frequency (about 2x per second at 30fps)
        if frameCount % 15 == 0 {
            // Analyze pose and generate feedback
            analyzeBodyPosition(pose: pose)
            analyzeExerciseMovement(pose: pose)
        }
        
        // Update phase if needed (check every frame for responsiveness)
        updateExercisePhase(pose: pose)
        
        // Periodic status logging
        if frameCount % 60 == 0 { // Log every 2 seconds at 30fps
            print("DEBUG: Status - Phase: \(currentPhase), Reps: \(repCount), Active: \(isExerciseActive)")
        }
        
        return feedback
    }
    
    private func extractPoseLandmarks(from landmarks: [String: CGPoint]) -> PoseLandmarks {
        let pose = PoseLandmarks(
            leftShoulder: landmarks["left_shoulder"],
            rightShoulder: landmarks["right_shoulder"],
            leftElbow: landmarks["left_elbow"],
            rightElbow: landmarks["right_elbow"],
            leftWrist: landmarks["left_wrist"],
            rightWrist: landmarks["right_wrist"],
            leftHip: landmarks["left_hip"],
            rightHip: landmarks["right_hip"],
            nose: landmarks["nose"],
            leftKnee: landmarks["left_knee"],
            rightKnee: landmarks["right_knee"],
            leftAnkle: landmarks["left_ankle"],
            rightAnkle: landmarks["right_ankle"]
        )
        
        // Debug logging for key landmarks
        if frameCount % 60 == 0 { // Log every 60 frames to avoid spam
            print("DEBUG: Extracted landmarks - Left Elbow: \(pose.leftElbow != nil ? "✓" : "✗"), Right Elbow: \(pose.rightElbow != nil ? "✓" : "✗")")
            print("DEBUG: Left Shoulder: \(pose.leftShoulder != nil ? "✓" : "✗"), Right Shoulder: \(pose.rightShoulder != nil ? "✓" : "✗")")
        }
        
        return pose
    }
    
    private func analyzeBodyPosition(pose: PoseLandmarks) {
        // Check torso angle (should be bent forward 45-90 degrees)
        analyzeTorsoAngle(pose: pose)
        
        // Check knee position (slight bend, stable)
        analyzeKneePosition(pose: pose)
        
        // Check foot position (stable, shoulder-width apart)
        analyzeFootPosition(pose: pose)
        
        // Check back straightness
        analyzeBackPosition(pose: pose)
    }
    
    private func analyzeTorsoAngle(pose: PoseLandmarks) {
        guard let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder,
              let leftHip = pose.leftHip,
              let rightHip = pose.rightHip else { return }
        
        // Calculate average shoulder and hip points
        let shoulderCenter = CGPoint(
            x: (leftShoulder.x + rightShoulder.x) / 2,
            y: (leftShoulder.y + rightShoulder.y) / 2
        )
        let hipCenter = CGPoint(
            x: (leftHip.x + rightHip.x) / 2,
            y: (leftHip.y + rightHip.y) / 2
        )
        
        // Calculate torso angle relative to vertical
        let torsoAngle = atan2(abs(shoulderCenter.x - hipCenter.x), abs(shoulderCenter.y - hipCenter.y)) * 180 / .pi
        
        // More practical ranges for bent-over row position
        if torsoAngle < 30 {
            addFeedback(.error, "Bend forward more - keep your back at 45° angle for proper form", priority: 6)
        } else if torsoAngle > 80 {
            addFeedback(.warning, "Don't bend too far forward - maintain control at about 45°", priority: 7)
        } else if torsoAngle >= 35 && torsoAngle <= 70 {
            addFeedback(.correct, "Perfect bent-over position for rows", priority: 1)
        }
    }
    
    private func analyzeKneePosition(pose: PoseLandmarks) {
        guard let leftKnee = pose.leftKnee,
              let rightKnee = pose.rightKnee,
              let leftHip = pose.leftHip,
              let rightHip = pose.rightHip,
              let leftAnkle = pose.leftAnkle,
              let rightAnkle = pose.rightAnkle else { return }
        
        // Check if knees are slightly bent (not locked)
        let leftKneeAngle = calculateAngle(point1: leftHip, vertex: leftKnee, point2: leftAnkle)
        let rightKneeAngle = calculateAngle(point1: rightHip, vertex: rightKnee, point2: rightAnkle)
        
        let avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2
        
        // More forgiving knee position requirements
        if avgKneeAngle > 175 {
            addFeedback(.warning, "Consider bending knees slightly for better stability", priority: 3)
        } else if avgKneeAngle >= 140 && avgKneeAngle <= 175 {
            addFeedback(.correct, "Good knee position", priority: 1)
        } else if avgKneeAngle < 120 {
            addFeedback(.warning, "Try not to squat too much - focus on upper body", priority: 5)
        }
    }
    
    private func analyzeFootPosition(pose: PoseLandmarks) {
        guard let leftAnkle = pose.leftAnkle,
              let rightAnkle = pose.rightAnkle,
              let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder else { return }
        
        let footWidth = abs(leftAnkle.x - rightAnkle.x)
        let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
        
        let widthRatio = footWidth / shoulderWidth
        
        // Much more flexible stance requirements
        if widthRatio < 0.5 {
            addFeedback(.warning, "Consider widening your stance for better balance", priority: 3)
        } else if widthRatio > 2.0 {
            addFeedback(.warning, "Very wide stance - try bringing feet closer", priority: 3)
        } else {
            addFeedback(.correct, "Good stance", priority: 1)
        }
    }
    
    private func analyzeBackPosition(pose: PoseLandmarks) {
        guard let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder,
              let leftHip = pose.leftHip,
              let rightHip = pose.rightHip else { return }
        
        // Check if back is straight (shoulders and hips aligned)
        let shoulderSlope = (rightShoulder.y - leftShoulder.y) / (rightShoulder.x - leftShoulder.x)
        let hipSlope = (rightHip.y - leftHip.y) / (rightHip.x - leftHip.x)
        
        let slopeDifference = abs(shoulderSlope - hipSlope)
        
        // More lenient back alignment requirements
        if slopeDifference > 0.6 {
            addFeedback(.warning, "Try to maintain balanced posture", priority: 4)
        } else {
            addFeedback(.correct, "Good posture", priority: 1)
        }
    }
    
    private func analyzeExerciseMovement(pose: PoseLandmarks) {
        guard let leftElbow = pose.leftElbow,
              let rightElbow = pose.rightElbow,
              let leftWrist = pose.leftWrist,
              let rightWrist = pose.rightWrist,
              let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder else { return }
        
        // Analyze elbow movement pattern
        analyzeElbowMovement(pose: pose)
        
        // Check wrist position
        analyzeWristPosition(pose: pose)
        
        // Check range of motion
        analyzeRangeOfMotion(pose: pose)
    }
    
    private func analyzeElbowMovement(pose: PoseLandmarks) {
        guard let leftElbow = pose.leftElbow,
              let rightElbow = pose.rightElbow,
              let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder else { return }
        
        // Elbows should move close to the body during the pull
        let leftElbowToShoulder = distance(point1: leftElbow, point2: leftShoulder)
        let rightElbowToShoulder = distance(point1: rightElbow, point2: rightShoulder)
        
        let avgElbowDistance = (leftElbowToShoulder + rightElbowToShoulder) / 2
        
        // More relaxed elbow position requirements (adjusted for normalized coordinates)
        if avgElbowDistance > 0.25 {
            addFeedback(.warning, "Try bringing elbows closer to body for better form", priority: 4)
        } else if avgElbowDistance < 0.15 {
            addFeedback(.correct, "Good elbow control", priority: 1)
        }
    }
    
    private func analyzeWristPosition(pose: PoseLandmarks) {
        guard let leftWrist = pose.leftWrist,
              let rightWrist = pose.rightWrist,
              let leftElbow = pose.leftElbow,
              let rightElbow = pose.rightElbow else { return }
        
        // Wrists should be in line with forearms (adjusted for normalized coordinates)
        let leftWristAngle = calculateAngle(point1: leftElbow, vertex: leftWrist, point2: CGPoint(x: leftWrist.x, y: leftWrist.y + 0.1))
        let rightWristAngle = calculateAngle(point1: rightElbow, vertex: rightWrist, point2: CGPoint(x: rightWrist.x, y: rightWrist.y + 0.1))
        
        // More lenient wrist position requirements
        if abs(leftWristAngle - 180) > 45 || abs(rightWristAngle - 180) > 45 {
            addFeedback(.warning, "Try to keep wrists neutral for comfort", priority: 2)
        }
    }
    
    private func analyzeRangeOfMotion(pose: PoseLandmarks) {
        guard let leftElbow = pose.leftElbow,
              let rightElbow = pose.rightElbow,
              let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder,
              let leftWrist = pose.leftWrist,
              let rightWrist = pose.rightWrist else { return }
        
        // Calculate arm angles to check range of motion
        let leftArmAngle = calculateAngle(point1: leftShoulder, vertex: leftElbow, point2: leftWrist)
        let rightArmAngle = calculateAngle(point1: rightShoulder, vertex: rightElbow, point2: rightWrist)
        
        let avgArmAngle = (leftArmAngle + rightArmAngle) / 2
        
        // More practical range of motion feedback for wrist-based detection
        if currentPhase == .raising && avgArmAngle > 160 {
            addFeedback(.warning, "Keep elbows close to body while raising", priority: 5)
        } else if currentPhase == .top && avgArmAngle >= 70 && avgArmAngle <= 140 {
            addFeedback(.correct, "Good wrist position at the top", priority: 2)
        } else if currentPhase == .bottom && avgArmAngle < 100 {
            addFeedback(.correct, "Wrists properly positioned for lowering", priority: 2)
        }
    }
    
    private func updateExercisePhase(pose: PoseLandmarks) {
        // First check if upper body is properly bent forward
        guard let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder,
              let leftHip = pose.leftHip,
              let rightHip = pose.rightHip,
              let leftWrist = pose.leftWrist,
              let rightWrist = pose.rightWrist,
              let leftAnkle = pose.leftAnkle,
              let rightAnkle = pose.rightAnkle else {
            print("DEBUG: Missing required landmarks for phase detection")
            return
        }
        
        // Check if upper body is bent forward (torso angle check)
        let shoulderCenter = CGPoint(x: (leftShoulder.x + rightShoulder.x) / 2, y: (leftShoulder.y + rightShoulder.y) / 2)
        let hipCenter = CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
        let torsoAngle = atan2(abs(shoulderCenter.x - hipCenter.x), abs(shoulderCenter.y - hipCenter.y)) * 180 / .pi
        
        // Require proper bent-over position (torso angle between 30-80 degrees)
        if torsoAngle < 30 || torsoAngle > 80 {
            print("DEBUG: Upper body not properly bent forward - TorsoAngle: \(String(format: "%.1f", torsoAngle))°")
            // Don't update phase if not in proper position
            return
        }
        
        // Focus on wrist position for dumbbell detection
        let leftWristHeight = leftWrist.y - leftShoulder.y  // Negative = above shoulder, Positive = below shoulder
        let rightWristHeight = rightWrist.y - rightShoulder.y
        let avgWristHeight = (leftWristHeight + rightWristHeight) / 2
        
        // Calculate ankle reference point for lowered position
        let ankleCenter = CGPoint(x: (leftAnkle.x + rightAnkle.x) / 2, y: (leftAnkle.y + rightAnkle.y) / 2)
        let shoulderToAnkleDistance = abs(shoulderCenter.y - ankleCenter.y)
        
        let newPhase: ExercisePhase
        
        // Debug coordinate values
        if frameCount % 30 == 0 {
            print("DEBUG: TorsoAngle: \(String(format: "%.1f", torsoAngle))°, AvgWristHeight: \(String(format: "%.3f", avgWristHeight))")
            print("DEBUG: ShoulderToAnkleDistance: \(String(format: "%.3f", shoulderToAnkleDistance))")
        }
        
        // Wrist-based phase detection
        if avgWristHeight < -0.1 { // Wrists above shoulders = dumbbells raised
            newPhase = .top
            print("DEBUG: DUMBBELLS RAISED - WristHeight: \(String(format: "%.3f", avgWristHeight))")
        } else if avgWristHeight > 0.8 { // Wrists near ankles = dumbbells lowered
            newPhase = .bottom
            print("DEBUG: DUMBBELLS LOWERED - WristHeight: \(String(format: "%.3f", avgWristHeight))")
        } else if currentPhase == .bottom || currentPhase == .lowering {
            newPhase = .raising
            print("DEBUG: RAISING DUMBBELLS - WristHeight: \(String(format: "%.3f", avgWristHeight))")
        } else if currentPhase == .preparation {
            // Start with lowering phase if wrists are in middle position
            newPhase = .lowering
            print("DEBUG: STARTING EXERCISE - WristHeight: \(String(format: "%.3f", avgWristHeight))")
        } else {
            newPhase = .lowering
            print("DEBUG: LOWERING DUMBBELLS - WristHeight: \(String(format: "%.3f", avgWristHeight))")
        }
        
        let timeSinceLastPhase = Date().timeIntervalSince(phaseStartTime)
        let adjustedMinimumTime = minimumPhaseTime
        
        // Add more detailed logging for rep counting conditions
        if newPhase == .top && currentPhase == .raising {
            print("DEBUG: REP CONDITION MET - Dumbbells fully raised, completing cycle")
        }
        
        if newPhase != currentPhase && timeSinceLastPhase > adjustedMinimumTime {
            print("DEBUG: Phase transition from \(currentPhase) to \(newPhase)")
            lastPhase = currentPhase
            currentPhase = newPhase
            phaseStartTime = Date()
            
            // Count reps when completing the full up-down cycle (raising to top)
            if currentPhase == .top && lastPhase == .raising {
                print("DEBUG: REP COUNTED! Completed full up-down cycle")
                print("DEBUG: Rep count before increment: \(repCount)")
                repCount += 1
                isExerciseActive = true
                print("DEBUG: Rep count after increment: \(repCount)")
                
                // Add feedback for completed rep
                addFeedback(.correct, "Great rep! Now lower the dumbbells", priority: 1)
            } else if currentPhase == .bottom && lastPhase == .lowering {
                // Dumbbells are fully lowered - notify to raise
                addFeedback(.correct, "Dumbbells lowered - now raise them up", priority: 2)
                print("DEBUG: Dumbbells fully lowered - user should raise")
            } else if currentPhase == .top && lastPhase != .raising {
                // Dumbbells are raised but not from raising phase - notify to lower
                addFeedback(.correct, "Dumbbells raised - now lower them down", priority: 2)
                print("DEBUG: Dumbbells raised - user should lower")
            } else {
                print("DEBUG: No rep counted - Current: \(currentPhase), Last: \(lastPhase)")
            }
        } else if newPhase != currentPhase {
            print("DEBUG: Phase change blocked - time since last phase: \(String(format: "%.2f", timeSinceLastPhase))s (minimum: \(String(format: "%.2f", adjustedMinimumTime))s)")
        } else {
            print("DEBUG: No phase change needed - staying in \(currentPhase)")
        }
    }
    
    private func addFeedback(_ type: FeedbackType, _ message: String, priority: Int) {
        feedback.append(ExerciseFeedback(type: type, message: message, priority: priority, timestamp: Date()))
    }
    
    // MARK: - Helper Functions
    private func calculateAngle(point1: CGPoint, vertex: CGPoint, point2: CGPoint) -> Double {
        let vector1 = CGPoint(x: point1.x - vertex.x, y: point1.y - vertex.y)
        let vector2 = CGPoint(x: point2.x - vertex.x, y: point2.y - vertex.y)
        
        let dotProduct = vector1.x * vector2.x + vector1.y * vector2.y
        let magnitude1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let magnitude2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)
        
        let cosAngle = dotProduct / (magnitude1 * magnitude2)
        let angle = acos(max(-1, min(1, cosAngle))) * 180 / .pi
        
        return angle
    }
    
    private func distance(point1: CGPoint, point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    func reset() {
        print("DEBUG: Reset called - Previous rep count: \(repCount), Previous phase: \(currentPhase)")
        currentPhase = .preparation
        feedback.removeAll()
        repCount = 0
        isExerciseActive = false
        frameCount = 0
        lastPhase = .preparation
        phaseStartTime = Date()
        print("DEBUG: Reset completed - New rep count: \(repCount), New phase: \(currentPhase)")
    }
}
