import Foundation

/// 头像上传 API。只负责 multipart 请求，保存/删除由 AuthStore 处理。
extension APIClient {
    func uploadAvatar(_ imageData: Data) async throws -> AvatarResponse {
        let data = try await upload(
            path: "me/avatar",
            imageData: imageData,
            filename: "avatar.jpg"
        )
        return try decode(AvatarResponse.self, from: data)
    }

    func removeAvatar() async throws -> AvatarResponse {
        try await send(path: "me/avatar", method: "DELETE", body: nil)
    }
}
