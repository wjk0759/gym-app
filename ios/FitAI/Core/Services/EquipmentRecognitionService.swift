import Foundation

enum EquipmentRecognitionError: Error {
    case proRequired
}

/// 器械识别统一入口：优先远程视觉模型，网络/5xx 失败时回退本地规则。
/// 权限错误必须向上抛出，由页面弹出统一 Pro 付费墙。
/// 识别页、器械库、器械选择器都复用这一个服务。
enum EquipmentRecognitionService {
    static func recognize(
        imageData: Data,
        preferRemote: Bool,
        idempotencyKey: String? = nil
    ) async throws -> EquipmentScanResult {
        if preferRemote {
            do {
                let remote = try await APIClient.shared.scanEquipment(
                    imageData: imageData,
                    idempotencyKey: idempotencyKey
                )
                if !remote.candidates.isEmpty || !remote.description.isEmpty {
                    return remote
                }
            } catch let error as APIError where error.isProRequired {
                throw EquipmentRecognitionError.proRequired
            } catch let error as APIError
                where error.statusCode == nil || (error.statusCode ?? 0) >= 500 {
                // Offline or server failure: fall through to the local matcher.
            } catch {
                throw error
            }
        }
        return EquipmentScanResult(
            candidates: EquipmentService.recognize(imageData: imageData),
            description: "",
            name: "",
            notInLibrary: false
        )
    }
}
