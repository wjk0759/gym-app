import Foundation

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
