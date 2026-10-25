import Foundation

/// 本地饮食照片估算。
///
/// 当前没有接入真实视觉模型时，用图片内容做确定性模拟，保证离线也能演示完整流程。
/// 接入远程模式后，优先使用后端 `/diet/analyze`，失败时回退到这里。
enum FoodVisionService {
    static let disclaimer = "识别结果为估算，热量与营养素可能有偏差。过敏原、疾病饮食与特殊人群需求请以包装标签、商家信息或医生/营养师意见为准。"

    private static let combos: [[(String, Double)]] = [
        [("米饭", 150), ("鸡胸肉", 150), ("西兰花", 150)],
        [("燕麦（干）", 60), ("鸡蛋", 100), ("牛奶", 250), ("香蕉", 100)],
        [("糙米饭", 150), ("三文鱼", 120), ("生菜", 100), ("番茄", 80)],
        [("全麦面包", 80), ("鸡蛋", 100), ("牛油果", 80)],
        [("米饭", 180), ("豆腐", 150), ("西兰花", 180)]
    ]

    static func analyze(imageData: Data) -> FoodRecognitionResult {
        let seed = imageData.reduce(0) { partial, byte in
            (partial &* 31 &+ Int(byte)) & 0x7fff_ffff
        }
        let combo = combos[seed % combos.count]

        var items: [FoodRecognitionItem] = []
        for (index, entry) in combo.enumerated() {
            let (name, grams) = entry
            guard let food = FoodLibrary.all.first(where: { $0.name == name }) else {
                continue
            }
            items.append(
                FoodRecognitionItem(
                    name: food.name,
                    grams: grams,
                    kcalPer100g: food.kcal,
                    proteinPer100g: food.protein,
                    carbsPer100g: food.carbs,
                    fatPer100g: food.fat,
                    confidence: max(0.55, 0.91 - Double(index) * 0.07)
                )
            )
        }

        let confidence = items.isEmpty
            ? 0
            : items.reduce(0) { $0 + $1.confidence } / Double(items.count)

        return FoodRecognitionResult(
            items: items,
            confidence: confidence,
            disclaimer: disclaimer,
            model: "local-mock"
        )
    }
}
