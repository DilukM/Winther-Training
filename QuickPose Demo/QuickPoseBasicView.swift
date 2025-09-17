

import SwiftUI
import QuickPoseCore
import QuickPoseSwiftUI

struct QuickPoseBasicView: View {

    private var quickPose = QuickPose(sdkKey: "01K54BP0PZRR42DFPDHMDYQ8WV") 
    @State private var overlayImage: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                if ProcessInfo.processInfo.isiOSAppOnMac, let url = Bundle.main.url(forResource: "happy-dance", withExtension: "mov") {
                    QuickPoseSimulatedCameraView(useFrontCamera: false, delegate: quickPose, video: url)
                } else {
                    QuickPoseCameraView(useFrontCamera: false, delegate: quickPose)
                }
                QuickPoseOverlayView(overlayImage: $overlayImage)
            }
            .frame(width: geometry.size.width)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                quickPose.start(features: [.overlay(.wholeBody)], onFrame: { status, image, features, feedback, landmarks in
                    overlayImage = image
                    if case .success = status {
                        
                    } else {
                        // show error feedback
                    }
                })
            }.onDisappear {
                quickPose.stop()
            }
            
            
        }
    }
}

