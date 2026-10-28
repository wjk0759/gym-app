import Foundation
import SwiftUI

/// A locally staged image. It deliberately keeps both the display image and
/// the already-compressed upload data so the draft bar never re-encodes.
struct CoachDraftImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let data: Data
}
