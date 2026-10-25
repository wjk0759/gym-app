import Foundation

enum EquipmentService {
    /// 本地 Mock：用图片内容做确定性偏移，保证同一张图结果稳定。
    /// 接真实服务时，把这里替换为 `POST /equipment/scan` 上传图片。
    static func recognize(imageData: Data) -> [EquipmentCandidate] {
        let pool = ExerciseLibrary.all.filter {
            [.machine, .cable, .barbell, .dumbbell, .kettlebell].contains($0.equipment)
        }
        guard !pool.isEmpty else { return [] }

        let seed = imageData.reduce(0) { partial, byte in
            (partial + Int(byte)) % 100_000
        }
        let start = seed % pool.count
        let rotated = Array(pool[start...]) + Array(pool[..<start])
        let confidences = [0.91, 0.64, 0.48]

        return zip(rotated.prefix(3), confidences).map { item, confidence in
            EquipmentCandidate(exercise: item, confidence: confidence)
        }
    }
}
