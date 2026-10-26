/* FitAI Web Preview page module: food-photo */

function foodPhotoMockItems() {
  const combo = FOOD_PHOTO_COMBOS[state.foodPhotoItems.length % FOOD_PHOTO_COMBOS.length];
  return combo.map(([name, grams], index) => {
    const food = FOODS.find((item) => item.name === name) || FOODS[0];
    return {
      id: `fp-${Date.now()}-${index}`,
      name: food.name,
      grams,
      kcalPer100g: food.kcal,
      pPer100g: food.p,
      cPer100g: food.c,
      fPer100g: food.f,
      fiberPer100g: food.fiber || 0,
      confidence: Math.max(0.55, 0.91 - index * 0.07),
      selected: true
    };
  });
}

function foodPhotoTotals(items = state.foodPhotoItems) {
  return items.filter((item) => item.selected).reduce((total, item) => {
    const factor = item.grams / 100;
    total.kcal += item.kcalPer100g * factor;
    total.p += item.pPer100g * factor;
    total.c += item.cPer100g * factor;
    total.f += item.fPer100g * factor;
    total.fiber += (item.fiberPer100g || 0) * factor;
    return total;
  }, { kcal: 0, p: 0, c: 0, f: 0, fiber: 0 });
}

function foodPhotoScreen() {
  const items = state.foodPhotoItems;
  const totals = foodPhotoTotals(items);
  const meals = ["早餐", "午餐", "晚餐", "加餐"];

  return `
    <div class="stack">
      ${headerBack("拍照识别饮食")}

      <div class="card">
        <div class="h2">拍一张这餐的照片</div>
        <div class="tiny muted" style="margin-top:6px;line-height:1.6">
          自动估算热量和营养。照片只用于本次识别，不保存；结果可以修改后加入今日饮食。
        </div>
        <div class="tiny accent" style="margin-top:6px;line-height:1.6">
          螺蛳粉、火锅、奶茶也可以识别。这里只估算热量，不评价食物好坏。
        </div>
      </div>

      ${state.foodPhotoImage ? `
        <div class="card" style="padding:0;overflow:hidden">
          <div style="height:220px;background:linear-gradient(145deg,#5b4632 0%,#2d392e 55%,#151b16 100%);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px">
            <div class="photo-sim-icon">${ICONS.utensils}</div>
            <div class="tiny muted">已选择照片（预览模拟）</div>
          </div>
        </div>
      ` : `
        <div style="height:220px;border:1px dashed var(--stroke);border-radius:18px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;background:var(--surface)">
          <div class="photo-empty-icon">${ICONS.utensils}</div>
          <div class="small strong">拍照或选择一张餐食照片</div>
          <div class="tiny faint">尽量俯拍，让食物完整进入画面</div>
        </div>
      `}

      <div class="row gap8">
        <button class="btn btn-secondary grow" onclick="app.openFoodPhotoCamera('foodPhoto')"><span class="btn-icon">${ICONS.camera}</span>重拍</button>
        <button class="btn btn-secondary grow" onclick="app.openFoodPhotoCamera('foodPhoto')"><span class="btn-icon">${ICONS.image}</span>相册</button>
      </div>

      <div class="card">
        <div class="tiny muted">这是哪一餐？</div>
        <div class="seg" style="margin-top:8px">
          ${meals.map((meal) => `
            <button class="${state.foodPhotoMeal === meal ? "active" : ""}" onclick="app.foodPhotoMeal('${meal}')">${meal}</button>
          `).join("")}
        </div>
      </div>

      <button class="btn btn-primary" onclick="app.foodPhotoAnalyze()" ${state.foodPhotoImage ? "" : "disabled"}>
        识别这餐并计算热量
      </button>

      ${items.length ? `
        <div class="card">
          <div class="between">
            <div>
              <div class="h3">识别结果</div>
              <div class="tiny faint">勾选实际吃下的食物，拖动份量</div>
            </div>
            <div class="tiny accent">参考置信度 ${Math.round(state.foodPhotoConfidence * 100)}%</div>
          </div>

          ${items.map((item, index) => {
            const kcal = Math.round(item.grams * item.kcalPer100g / 100);
            const p = Math.round(item.grams * item.pPer100g / 100);
            const c = Math.round(item.grams * item.cPer100g / 100);
            const f = Math.round(item.grams * item.fPer100g / 100);
            const fiber = Math.round((item.fiberPer100g || 0) * item.grams / 100 * 10) / 10;
            return `
              <div class="card tight" style="margin-top:10px;opacity:${item.selected ? 1 : 0.45}">
                <div class="between">
                  <label class="row gap8" style="cursor:pointer">
                    <input type="checkbox" ${item.selected ? "checked" : ""} onchange="app.foodPhotoToggle(${index}, this.checked)">
                    <span class="small strong">${item.name}</span>
                  </label>
                  <span class="tiny accent" id="food-photo-kcal-${index}">${kcal} kcal</span>
                </div>
                <div class="row gap8" style="margin-top:8px">
                  <input type="range" min="10" max="2000" step="10" value="${item.grams}" oninput="app.foodPhotoGrams(${index}, this.value)" style="flex:1;accent-color:var(--accent)">
                  <span class="tiny" id="food-photo-grams-${index}" style="width:52px;text-align:right">${item.grams} g</span>
                </div>
                <div class="tiny faint" id="food-photo-macros-${index}">P ${p}g · C ${c}g · F ${f}g · 纤维 ${fiber}g</div>
              </div>
            `;
          }).join("")}

          <div class="card tight" style="margin-top:10px">
            <div class="between">
              <span class="small strong">合计</span>
              <span class="h3 accent" id="food-photo-total">${Math.round(totals.kcal)} kcal</span>
            </div>
            <div class="row gap8" style="margin-top:8px;flex-wrap:wrap">
              <span class="tiny muted">蛋白质 <span id="food-photo-p">${Math.round(totals.p)}</span>g</span>
              <span class="tiny muted">碳水 <span id="food-photo-c">${Math.round(totals.c)}</span>g</span>
              <span class="tiny muted">脂肪 <span id="food-photo-f">${Math.round(totals.f)}</span>g</span>
              <span class="tiny muted">膳食纤维 <span id="food-photo-fiber">${Math.round(totals.fiber)}</span>g</span>
            </div>
          </div>

          <div class="tiny faint" style="margin-top:10px">${state.foodPhotoModel.startsWith("local") ? "当前为本地估算模式，结果仅用于演示流程。" : "结果来自远程识别服务，照片未保存。"}</div>
          <div class="tiny faint" style="margin-top:6px;line-height:1.6">识别结果为估算，热量与营养素可能有偏差。过敏原、疾病饮食与特殊人群需求请以包装标签、商家信息或医生/营养师意见为准。</div>

          <button class="btn btn-primary" style="margin-top:12px" onclick="app.foodPhotoAdd()" ${totals.kcal > 0 ? "" : "disabled"}>
            加入${state.foodPhotoMeal} · <span id="food-photo-add-kcal">${Math.round(totals.kcal)}</span> kcal
          </button>
        </div>
      ` : ""}

      <div class="tiny faint" style="line-height:1.6">拍照识别只能做估算，不能保证份量、烹饪油和隐藏配料完全准确。对花生、海鲜、乳制品等过敏原，请以包装标签或商家确认为准。</div>
    </div>
  `;
}

