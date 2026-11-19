import Foundation

/// AuthStore 的头像写入扩展：上传后更新本地 profile。
@MainActor
extension AuthStore {
    func uploadAvatar(_ jpegData: Data) async throws {
        let response = try await APIClient.shared.uploadAvatar(jpegData)
        avatarURL = AppConfig.resolveMediaURL(response.avatarURL)
    }

    func removeAvatar() async throws {
        _ = try await APIClient.shared.removeAvatar()
        avatarURL = nil
    }
}
