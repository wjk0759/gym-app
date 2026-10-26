/* FitAI Web Preview page module: nutrition overview */

/* ---------------- Nutrition ---------------- */

function suggestedMealName() {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 11) return "早餐";
  if (hour >= 11 && hour < 15) return "午餐";
  if (hour >= 17 && hour < 21) return "晚餐";
  return "加餐";
}

function nutritionScreen() {
  const key = state.nutritionDateKey || todayKey();
  const isToday = key === todayKey();
  const targets = nutritionTargets();
  const totals = nutritionTotals(key);
  const dayLogs = foodLogsForDateKey(key);
  const ratio = Math.min(100, Math.round((totals.kcal / Math.max(1, targets.kcal)) * 100));
  const remainingKcal = Math.max(0, targets.kcal - Math.round(totals.kcal));
  const remainingProtein = Math.max(0, targets.protein - Math.round(totals.p));
  const meals = ["早餐", "午餐", "晚餐", "加餐"];

  return `
    <div class="stack">
      ${headerBack(isToday ? "今日饮食" : "饮食记录", "app.closeNutrition()")}
      <div class="card">
        <div class="tiny accent">${dateLabel(key)}</div>
        <div class="tiny muted" style="margin-top:3px">${isToday ? "今日热量目标" : "当天热量目标"}</div>
        <div class="kcal-hero" style="margin-top:4px"><span class="num">${targets.kcal}</span><span class="unit">kcal</span></div>
        <div class="tiny accent" style="margin-top:6px;font-weight:600">${remainingKcal > 0 ? `还可摄入 ${remainingKcal} kcal · 蛋白质还差 ${remainingProtein}g` : `已达到今日热量目标 · 蛋白质还差 ${remainingProtein}g`}</div>
        <div class="tiny faint" style="margin-top:4px">按${state.profile.goal}目标与每周 ${state.profile.weeklyDays} 练估算，结果是区间。</div>
      </div>

      <div class="card nutrition-card" onclick="app.openFoodPhoto('${key}')">
        <div class="nutrition-icon">${ICONS.camera}</div>
        <div class="grow">
          <div class="small strong">拍照识别饮食</div>
          <div class="tiny muted" style="margin-top:3px">拍一餐，估算热量与营养</div>
        </div>
        <div class="tiny accent">›</div>
      </div>

      <div class="card">
        <div class="between">
          <div class="h3">${isToday ? "今日记录" : "当天记录"}</div>
          <div class="tiny muted">${totals.kcal} / ${targets.kcal} kcal</div>
        </div>
        <div class="bar" style="margin-top:9px"><span style="width:${ratio}%"></span></div>

        ${meals.map((meal) => {
          const logs = dayLogs.filter((item) => item.meal === meal);
          if (!logs.length) return "";
          return `
            <div class="meal-head">
              <div class="small strong">${meal}</div>
              <div class="row gap8">
                <span class="tiny muted">${logs.reduce((sum, item) => sum + item.kcal, 0)} kcal</span>
                <button class="add-btn" onclick="app.openFoodAdd('${meal}', '${key}')">＋</button>
              </div>
            </div>
            ${logs.map((log) => `
              <div class="food-row">
                <div class="grow">
                  <div class="small">${log.name}</div>
                  <div class="tiny faint">${log.grams} g</div>
                </div>
                <div class="tiny muted">${log.kcal} kcal</div>
                <button class="trash-btn" onclick="app.deleteFood('${log.id}')" aria-label="删除${log.name}">${ICONS.trash}</button>
              </div>
            `).join("")}
          `;
        }).join("")}

        ${dayLogs.length === 0 ? `<div class="tiny muted" style="margin-top:10px">还没有记录。吃了什么就记什么，奶茶、火锅、螺蛳粉都可以。</div>` : ""}
        <button class="btn btn-secondary" style="margin-top:12px" onclick="app.openFoodAdd('${suggestedMealName()}', '${key}')">＋ 添加食物</button>
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:10px">宏量营养素</div>
        <div class="macro-grid">
          <div class="macro"><div class="label">蛋白质</div><div class="value">${Math.round(totals.p)} / ${targets.protein}g</div></div>
          <div class="macro"><div class="label">碳水</div><div class="value">${Math.round(totals.c)} / ${targets.carbs}g</div></div>
          <div class="macro"><div class="label">脂肪</div><div class="value">${Math.round(totals.f)} / ${targets.fat}g</div></div>
        </div>
        <div class="tiny faint" style="margin-top:9px">BMR ${targets.bmr} kcal · 维持热量约 ${targets.tdee} kcal</div>
      </div>

      <div class="h3" style="padding-top:4px">建议餐单</div>
      <div class="tiny faint" style="line-height:1.6;margin-top:-4px">只是参考，不是必须照着吃；外食也可以正常记录。</div>
      ${[
        ["早餐", "燕麦 50g · 鸡蛋 2 个 · 无糖酸奶 150g", Math.round(targets.kcal * 0.25)],
        ["午餐", "糙米饭 150g · 鸡胸肉 150g · 西兰花 200g", Math.round(targets.kcal * 0.35)],
        ["晚餐", "红薯 150g · 三文鱼或豆腐 150g · 混合蔬菜", Math.round(targets.kcal * 0.30)],
        ["加餐", "牛奶 200ml · 坚果 15g", Math.round(targets.kcal * 0.10)]
      ].map(([meal, items, kcal]) => `
        <div class="card tight">
          <div class="between"><div class="small strong">${meal}</div><div class="tiny accent">约 ${kcal} kcal</div></div>
          <div class="tiny muted" style="margin-top:5px">${items}</div>
        </div>
      `).join("")}

      <div class="card">
        <div class="h3">附近外卖</div>
        <div class="tiny muted" style="margin-top:6px">美团联盟只提供活动/搜索跳转，不提供菜品营养数据。</div>
        <button class="btn btn-secondary" style="margin-top:10px" onclick="app.mockMeituan()">在美团找外卖 ↗</button>
      </div>

      <div class="tiny faint" style="line-height:1.6">饮食建议为估算，不构成医疗或疾病饮食处方。孕期、术后、糖尿病、肾病等请咨询医生或营养师。</div>
    </div>
  `;
}

const FOOD_PHOTO_COMBOS = [
  [["米饭", 150], ["鸡胸肉", 150], ["西兰花", 150]],
  [["燕麦（干）", 60], ["鸡蛋", 100], ["牛奶", 250], ["香蕉", 100]],
  [["糙米饭", 150], ["三文鱼", 120], ["番茄", 80]],
  [["全麦面包", 80], ["鸡蛋", 100], ["香蕉", 100]],
  [["米饭", 180], ["豆腐", 150], ["西兰花", 180]],
  [["螺蛳粉", 600], ["奶茶", 500]],
  [["炸鸡", 200], ["可乐", 500]],
  [["麻辣香锅", 400], ["米饭", 150]]
];

