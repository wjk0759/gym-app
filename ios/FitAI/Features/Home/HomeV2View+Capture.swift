import SwiftUI

extension HomeV2View {
    // MARK: - Capture routing

    @ViewBuilder
    func captureDestination(_ kind: CaptureKind) -> some View {
        switch kind {
        case .food:
            FoodPhotoAnalysisView()
        case .body:
            BodyPhotoAnalysisView()
        case .equipment:
            NavigationStack {
                EquipmentRecognitionView(
                    onSaved: { item in
                        store.toast = "已加入器械库：\(item.name)"
                    },
                    onRecognized: { result in
                        store.coachEquipmentResult = result
                    }
                )
            }
        case .action:
            VideoReviewView()
        }
    }
}
