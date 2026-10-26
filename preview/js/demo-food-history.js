/* FitAI Web Preview module: demo nutrition history for the review report. */

function demoFoodHistory() {
  const now = new Date();
  const logs = [];
  const add = (daysAgo, meal, name, grams, suffix) => {
    const food = FOODS.find((item) => item.name === name);
    if (!food) return;
    const factor = grams / 100;
    const date = localDateInputValue(addDays(now, -daysAgo));
    logs.push({
      id: `fh-${daysAgo}-${suffix}`,
      date,
      meal,
      name,
      grams,
      kcal: Math.round(food.kcal * factor),
      p: Math.round(food.p * factor * 10) / 10,
      c: Math.round(food.c * factor * 10) / 10,
      f: Math.round(food.f * factor * 10) / 10,
      fiber: Math.round((food.fiber || 0) * factor * 10) / 10
    });
  };
  const addDay = (daysAgo) => {
    const shift = (daysAgo % 3) * 10;
    add(daysAgo, "早餐", "燕麦（干）", 70, "a");
    add(daysAgo, "早餐", "鸡蛋", 100, "b");
    add(daysAgo, "早餐", "牛奶", 250, "c");
    add(daysAgo, "早餐", "香蕉", 150, "d");
    add(daysAgo, "午餐", "米饭", 220 + shift, "e");
    add(daysAgo, "午餐", "鸡胸肉", 180, "f");
    add(daysAgo, "午餐", "西兰花", 150, "g");
    add(daysAgo, "午餐", "橄榄油", 12, "h");
    add(daysAgo, "午餐", "坚果", 20, "i");
    add(daysAgo, "晚餐", "红薯", 300, "j");
    add(daysAgo, "晚餐", "三文鱼", 150, "k");
    add(daysAgo, "晚餐", "菠菜", 150, "l");
    add(daysAgo, "晚餐", "全麦面包", 60, "m");
    add(daysAgo, "晚餐", "无糖酸奶", 150, "n");
    add(daysAgo, "加餐", "苹果", 150, "o");
  };
  for (let daysAgo = 1; daysAgo <= 75; daysAgo += 1) addDay(daysAgo);
  [400, 430, 460, 490, 520, 550, 580, 610, 640, 670, 700].forEach(addDay);
  return logs;
}
