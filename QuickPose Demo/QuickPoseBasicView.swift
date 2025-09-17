import SwiftUI
import QuickPoseCore
import QuickPoseSwiftUI

// Legacy view kept for backwards compatibility. Use DetectionView instead.
struct QuickPoseBasicView: View {
    private var quickPose = QuickPose(sdkKey: "01K54BP0PZRR42DFPDHMDYQ8WV")
    @State private var overlayImage: UIImage?
    var body: some View {
        DetectionView() // forwards to new structured view
    }
}

