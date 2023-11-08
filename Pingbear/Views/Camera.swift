import SwiftUI
import UIKit
import SwiftttCamera

struct CameraView: View {

    var body: some View {
        var camera: SwiftttCamera = {
            let result = SwiftttCamera()
            result.view.translatesAutoresizingMaskIntoConstraints = false
            return result
        }()
        
        
    }
}
