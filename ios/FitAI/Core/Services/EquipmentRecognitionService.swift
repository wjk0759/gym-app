import Foundation

/// 器械识别统一入口：优先远程视觉模型，失败或无结果时回退本地规则。
/// 识别页、器械库、器械选择器都复用这一个服务。
enum EquipmentRecognitionService {
    static func recognize(
        imageData: Data,
        preferRemote: Bool
    ) async -> [EquipmentCandidate] {
        if preferRemote {
            do {
                let remote = try await APIClient.shared.scanEquipment(imageData: imageData)
                if !remote.isEmpty {
                    return remote
                }
            } catch {
                // 远程失败不弹错，直接回退本地识别，避免阻断用户操作。
            }
        }
        return EquipmentService.recognize(imageData: imageData)
    }
}
