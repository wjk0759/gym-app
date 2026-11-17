import Foundation
import SwiftUI

/// A locally staged image. It deliberately keeps both the display image and
/// the already-compressed upload data so the draft bar never re-encodes.
struct CoachDraftImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let data: Data
}

enum CoachImagePurpose: String, CaseIterable, Identifiable {
    case review
    case food

    var id: String { rawValue }

    var title: String {
        switch self {
        case .review: return "教练点评"
        case .food: return "记录饮食"
        }
    }
}
