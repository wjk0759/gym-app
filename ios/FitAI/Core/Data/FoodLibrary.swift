import Foundation

struct FoodItem: Identifiable, Hashable, Codable {
    var id: String { name }

    let name: String
    let category: String
    /// 每 100g（或 100ml）估算值
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    /// 每 100g 膳食纤维；旧自定义食物没有该字段时按碳水估算。
    var fiber: Double? = nil
    /// 常用份量，例如一碗螺蛳粉约 600g；自定义食物可以带入自己的份量。
    var defaultGrams: Double?

    init(
        name: String,
        category: String,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double? = nil,
        defaultGrams: Double? = nil
    ) {
        self.name = name
        self.category = category
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.defaultGrams = defaultGrams
    }

    var fiberPer100g: Double {
        fiber ?? max(0, carbs * 0.05)
    }

    var servingGrams: Double {
        defaultGrams ?? 100
    }
}

enum FoodLibrary {
    static let all: [FoodItem] = [
        FoodItem(name: "米饭", category: "主食", kcal: 116, protein: 2.6, carbs: 25.9, fat: 0.3),
        FoodItem(name: "糙米饭", category: "主食", kcal: 111, protein: 2.6, carbs: 23.0, fat: 0.9),
        FoodItem(name: "燕麦（干）", category: "主食", kcal: 367, protein: 15.0, carbs: 61.0, fat: 6.7),
        FoodItem(name: "全麦面包", category: "主食", kcal: 247, protein: 13.0, carbs: 41.0, fat: 3.4),
        FoodItem(name: "红薯", category: "主食", kcal: 86, protein: 1.6, carbs: 20.1, fat: 0.1),
        FoodItem(name: "土豆", category: "主食", kcal: 77, protein: 2.0, carbs: 17.0, fat: 0.1),
        FoodItem(name: "玉米", category: "主食", kcal: 112, protein: 4.0, carbs: 22.8, fat: 1.2),
        FoodItem(name: "挂面（干）", category: "主食", kcal: 348, protein: 11.0, carbs: 74.0, fat: 1.5),
        FoodItem(name: "包子", category: "主食", kcal: 220, protein: 8.0, carbs: 30.0, fat: 7.0, defaultGrams: 100),
        FoodItem(name: "饺子", category: "主食", kcal: 240, protein: 9.0, carbs: 30.0, fat: 9.0, defaultGrams: 200),
        FoodItem(name: "炒饭", category: "主食", kcal: 180, protein: 5.0, carbs: 28.0, fat: 6.0, defaultGrams: 300),
        FoodItem(name: "便利店饭团", category: "主食", kcal: 180, protein: 6.0, carbs: 30.0, fat: 4.0, defaultGrams: 120),
        FoodItem(name: "粥", category: "主食", kcal: 46, protein: 1.5, carbs: 9.0, fat: 0.4, defaultGrams: 300),
        FoodItem(name: "鸡胸肉", category: "蛋白质", kcal: 133, protein: 24.0, carbs: 0.0, fat: 5.0),
        FoodItem(name: "鸡腿肉", category: "蛋白质", kcal: 181, protein: 24.0, carbs: 0.0, fat: 9.0),
        FoodItem(name: "牛肉", category: "蛋白质", kcal: 125, protein: 20.0, carbs: 0.0, fat: 5.0),
        FoodItem(name: "猪里脊", category: "蛋白质", kcal: 143, protein: 20.0, carbs: 0.0, fat: 6.0),
        FoodItem(name: "三文鱼", category: "蛋白质", kcal: 208, protein: 20.0, carbs: 0.0, fat: 13.0),
        FoodItem(name: "虾", category: "蛋白质", kcal: 93, protein: 18.0, carbs: 0.0, fat: 2.0),
        FoodItem(name: "鸡蛋", category: "蛋白质", kcal: 143, protein: 13.0, carbs: 1.0, fat: 10.0),
        FoodItem(name: "豆腐", category: "蛋白质", kcal: 76, protein: 8.0, carbs: 2.0, fat: 5.0),
        FoodItem(name: "牛奶", category: "蛋白质", kcal: 54, protein: 3.0, carbs: 5.0, fat: 3.0),
        FoodItem(name: "无糖酸奶", category: "蛋白质", kcal: 63, protein: 4.0, carbs: 5.0, fat: 3.0),
        FoodItem(name: "乳清蛋白粉", category: "蛋白质", kcal: 400, protein: 75.0, carbs: 10.0, fat: 6.0),
        FoodItem(name: "西兰花", category: "蔬菜", kcal: 34, protein: 2.8, carbs: 7.0, fat: 0.4),
        FoodItem(name: "菠菜", category: "蔬菜", kcal: 23, protein: 2.9, carbs: 3.6, fat: 0.4),
        FoodItem(name: "生菜", category: "蔬菜", kcal: 15, protein: 1.4, carbs: 2.9, fat: 0.2),
        FoodItem(name: "番茄", category: "蔬菜", kcal: 18, protein: 0.9, carbs: 3.9, fat: 0.2),
        FoodItem(name: "黄瓜", category: "蔬菜", kcal: 15, protein: 0.7, carbs: 3.6, fat: 0.1),
        FoodItem(name: "胡萝卜", category: "蔬菜", kcal: 41, protein: 0.9, carbs: 10.0, fat: 0.2),
        FoodItem(name: "苹果", category: "水果", kcal: 52, protein: 0.3, carbs: 14.0, fat: 0.2),
        FoodItem(name: "香蕉", category: "水果", kcal: 89, protein: 1.1, carbs: 23.0, fat: 0.3),
        FoodItem(name: "蓝莓", category: "水果", kcal: 57, protein: 0.7, carbs: 14.0, fat: 0.3),
        FoodItem(name: "橙子", category: "水果", kcal: 47, protein: 0.9, carbs: 12.0, fat: 0.1),
        FoodItem(name: "牛油果", category: "水果", kcal: 160, protein: 2.0, carbs: 9.0, fat: 15.0),
        FoodItem(name: "坚果", category: "脂肪", kcal: 600, protein: 20.0, carbs: 20.0, fat: 50.0),
        FoodItem(name: "花生酱", category: "脂肪", kcal: 588, protein: 25.0, carbs: 20.0, fat: 50.0),
        FoodItem(name: "橄榄油", category: "脂肪", kcal: 884, protein: 0.0, carbs: 0.0, fat: 100.0),
        FoodItem(name: "拿铁", category: "饮品", kcal: 60, protein: 3.0, carbs: 5.0, fat: 3.0, defaultGrams: 350),
        FoodItem(name: "可乐", category: "饮品", kcal: 42, protein: 0.0, carbs: 10.6, fat: 0.0, defaultGrams: 500),
        FoodItem(name: "奶茶", category: "饮品", kcal: 70, protein: 1.0, carbs: 12.0, fat: 2.3, defaultGrams: 500),
        FoodItem(name: "螺蛳粉", category: "外食", kcal: 125, protein: 5.5, carbs: 18.5, fat: 3.5, defaultGrams: 600),
        FoodItem(name: "桂林米粉", category: "外食", kcal: 130, protein: 6.0, carbs: 20.0, fat: 3.5, defaultGrams: 500),
        FoodItem(name: "兰州拉面", category: "外食", kcal: 110, protein: 5.0, carbs: 18.0, fat: 2.5, defaultGrams: 550),
        FoodItem(name: "酸辣粉", category: "外食", kcal: 140, protein: 4.0, carbs: 22.0, fat: 4.5, defaultGrams: 500),
        FoodItem(name: "凉皮", category: "外食", kcal: 150, protein: 4.0, carbs: 25.0, fat: 4.0, defaultGrams: 350),
        FoodItem(name: "牛肉面", category: "外食", kcal: 110, protein: 6.0, carbs: 16.0, fat: 3.0, defaultGrams: 550),
        FoodItem(name: "麻辣烫", category: "外食", kcal: 120, protein: 6.0, carbs: 10.0, fat: 6.0, defaultGrams: 500),
        FoodItem(name: "麻辣香锅", category: "外食", kcal: 180, protein: 8.0, carbs: 10.0, fat: 12.0, defaultGrams: 400),
        FoodItem(name: "火锅", category: "外食", kcal: 160, protein: 9.0, carbs: 8.0, fat: 10.0, defaultGrams: 500),
        FoodItem(name: "烧烤", category: "外食", kcal: 250, protein: 18.0, carbs: 2.0, fat: 19.0, defaultGrams: 300),
        FoodItem(name: "炸鸡", category: "外食", kcal: 280, protein: 18.0, carbs: 10.0, fat: 18.0, defaultGrams: 200),
        FoodItem(name: "汉堡", category: "外食", kcal: 250, protein: 12.0, carbs: 26.0, fat: 11.0, defaultGrams: 220),
        FoodItem(name: "薯条", category: "外食", kcal: 312, protein: 3.4, carbs: 41.0, fat: 15.0, defaultGrams: 120),
        FoodItem(name: "煎饼果子", category: "外食", kcal: 220, protein: 8.0, carbs: 28.0, fat: 8.0, defaultGrams: 250),
        FoodItem(name: "肉夹馍", category: "外食", kcal: 260, protein: 12.0, carbs: 27.0, fat: 11.0, defaultGrams: 200),
        FoodItem(name: "小笼包", category: "外食", kcal: 230, protein: 10.0, carbs: 25.0, fat: 10.0, defaultGrams: 180),
        FoodItem(name: "蛋糕", category: "甜点", kcal: 350, protein: 5.0, carbs: 45.0, fat: 17.0, defaultGrams: 100)
    ]

    static func search(_ text: String, custom: [FoodItem] = []) -> [FoodItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        var result: [FoodItem] = []
        for food in custom + all {
            guard seen.insert(food.name).inserted else { continue }
            if !trimmed.isEmpty,
               !food.name.contains(trimmed),
               !food.category.contains(trimmed) {
                continue
            }
            result.append(food)
        }
        return result
    }
}
