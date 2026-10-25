import Foundation

struct FoodItem: Identifiable, Hashable {
    var id: String { name }

    let name: String
    let category: String
    /// 每 100g（或 100ml）估算值
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
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
        FoodItem(name: "包子", category: "主食", kcal: 220, protein: 8.0, carbs: 30.0, fat: 7.0),
        FoodItem(name: "饺子", category: "主食", kcal: 240, protein: 9.0, carbs: 30.0, fat: 9.0),
        FoodItem(name: "炒饭", category: "主食", kcal: 180, protein: 5.0, carbs: 28.0, fat: 6.0),
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
        FoodItem(name: "拿铁", category: "饮品", kcal: 60, protein: 3.0, carbs: 5.0, fat: 3.0),
        FoodItem(name: "可乐", category: "饮品", kcal: 42, protein: 0.0, carbs: 10.6, fat: 0.0),
        FoodItem(name: "牛肉面", category: "外食", kcal: 110, protein: 6.0, carbs: 16.0, fat: 3.0),
        FoodItem(name: "麻辣烫", category: "外食", kcal: 120, protein: 6.0, carbs: 10.0, fat: 6.0)
    ]

    static func search(_ text: String) -> [FoodItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.name.contains(trimmed)
                || $0.category.contains(trimmed)
        }
    }
}
