import Foundation

/// 器械照片上传 API。只负责 multipart 请求，器械库写入由 AppStore 处理。
extension APIClient {
    func uploadEquipmentPhoto(clientID: UUID, imageData: Data) async throws -> EquipmentPhotoResponse {
        let data = try await upload(
            path: "equipment/items/\(clientID.uuidString)/photo",
            imageData: imageData,
            filename: "equipment.jpg"
        )
        return try decode(EquipmentPhotoResponse.self, from: data)
    }
}
