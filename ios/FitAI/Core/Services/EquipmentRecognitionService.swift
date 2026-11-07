import Foundation

enum EquipmentRecognitionError: Error {
    case proRequired
    case unavailable(String)
}

/// 器械识别统一入口：远程视觉模型 + 器械目录匹配。
///
/// 不再回退到“按图片哈希随机抽三个动作”的本地 mock。视觉不可用时必须明确
/// 告诉用户，让用户重试或手动添加，避免把随机结果伪装成 AI 识别。
enum EquipmentRecognitionService {
    static func recognize(
        imageData: Data,
        preferRemote: Bool,
        ocrText: String = "",
        idempotencyKey: String? = nil
    ) async throws -> EquipmentScanResult {
        guard preferRemote else {
            throw EquipmentRecognitionError.unavailable(
                "器械识别需要开启远程 AI。请在设置中打开 AI 模式后重试。"
            )
        }

        do {
            return try await APIClient.shared.scanEquipment(
                imageData: imageData,
                ocrText: ocrText,
                idempotencyKey: idempotencyKey
            )
        } catch let error as APIError where error.isProRequired {
            throw EquipmentRecognitionError.proRequired
        } catch let error as APIError
            where error.statusCode == nil || (error.statusCode ?? 0) >= 500 {
            throw EquipmentRecognitionError.unavailable(
                "识别服务暂时不可用，请检查网络后重试。"
            )
        } catch {
            throw error
        }
    }
}
