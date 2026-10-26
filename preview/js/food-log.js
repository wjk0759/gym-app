/* FitAI Web Preview page module: food-log */

function foodAddScreen() {
  const draft = state.foodDraft;
  const selected = draft.selected ? allFoods().find((food) => food.name === draft.selected) : null;
  const manualLabel = draft.query.trim()
    ? `找不到？手动添加「${esc(draft.query.trim())}」`
    : "找不到？手动添加食物";
  return `
    <div class="stack">
      ${headerBack("记录食物")}
      <div class="seg">
        ${["早餐", "午餐", "晚餐", "加餐"].map((meal) => `
          <button class="${draft.meal === meal ? "active" : ""}" onclick="app.foodMeal('${meal}')">${meal}</button>
        `).join("")}
      </div>

      <input type="text" id="food-search" maxlength="60" placeholder="搜索食物，例如：螺蛳粉、奶茶、鸡胸肉" value="${esc(draft.query)}" oninput="app.foodQuery(this.value)">
      <div class="tiny faint" style="line-height:1.6">记录是为了了解，不是为了给食物打分。奶茶、火锅、螺蛳粉都可以记。</div>

      ${selected ? `
        <div class="card">
          <div class="between">
            <div>
              <div class="h3">${esc(selected.name)}</div>
              <div class="tiny muted">${selected.serving ? `常用份量约 ${selected.serving}g · ` : ""}每 100g · ${selected.kcal} kcal</div>
            </div>
            <button class="link" onclick="app.clearFoodSelection()">重新选择</button>
          </div>
          <div class="slider-row" style="margin-top:12px">
            <div class="between">
              <span class="small muted">份量</span>
              <span class="small strong" id="food-grams-label">${draft.grams} g</span>
            </div>
            <input type="range" min="10" max="2000" step="10" value="${draft.grams}" oninput="app.foodGrams(this.value)">
          </div>
          <div class="macro-grid food-detail-macros" style="margin-top:10px">
            <div class="macro"><div class="label">热量</div><div class="value" id="food-kcal">${Math.round(selected.kcal * draft.grams / 100)}</div></div>
            <div class="macro"><div class="label">蛋白质</div><div class="value" id="food-p">${Math.round(selected.p * draft.grams / 100)}g</div></div>
            <div class="macro"><div class="label">碳水</div><div class="value" id="food-c">${Math.round(selected.c * draft.grams / 100)}g</div></div>
            <div class="macro"><div class="label">脂肪</div><div class="value" id="food-f">${Math.round(selected.f * draft.grams / 100)}g</div></div>
            <div class="macro"><div class="label">膳食纤维</div><div class="value" id="food-fiber">${Math.round((selected.fiber || 0) * draft.grams / 100 * 10) / 10}g</div></div>
          </div>
          <button class="btn btn-primary" style="margin-top:12px" onclick="app.addFood()">添加到${draft.meal}</button>
        </div>
      ` : `
        <div id="food-results">
          ${foodResults(draft.query)}
        </div>
        <button class="btn btn-secondary" onclick="app.openFoodCustom()">${manualLabel}</button>
      `}
    </div>
  `;
}

function foodCustomScreen() {
  const draft = state.foodCustomDraft;
  if (!draft) return foodAddScreen();
  return `
    <div class="stack">
      ${headerBack("手动添加食物")}
      <div class="card">
        <div class="h3">按你实际吃的一份填写</div>
        <div class="tiny muted" style="margin-top:6px;line-height:1.6">不知道蛋白质、碳水、脂肪或膳食纤维可以留空。先记下热量也可以，之后还能补充。</div>
      </div>

      <div class="card">
        <div class="form-label">食物名称</div>
        <input type="text" maxlength="30" value="${esc(draft.name)}" placeholder="例如：螺蛳粉" oninput="app.foodCustomInput('name', this.value)">

        <div class="form-label" style="margin-top:14px">这一份重量（g）</div>
        <input type="text" inputmode="decimal" maxlength="10" value="${esc(draft.portion)}" placeholder="例如：600" oninput="app.foodCustomInput('portion', this.value)">
        <div class="tiny faint" style="margin-top:6px">如果吃的是一整碗/一整份，填整份重量。螺蛳粉通常约 500–700g。</div>
      </div>

      <div class="card">
        <div class="between">
          <div class="h3">这一份的营养素</div>
          <div class="tiny faint">可选</div>
        </div>
        <div class="form-label" style="margin-top:12px">热量（kcal）</div>
        <input type="text" inputmode="decimal" maxlength="10" value="${esc(draft.kcal)}" placeholder="例如：750" oninput="app.foodCustomInput('kcal', this.value)">
        <div class="form-label" style="margin-top:12px">蛋白质（g）</div>
        <input type="text" inputmode="decimal" maxlength="10" value="${esc(draft.p)}" placeholder="可选" oninput="app.foodCustomInput('p', this.value)">
        <div class="row gap8" style="margin-top:12px">
          <div style="flex:1"><div class="form-label">碳水（g）</div><input type="text" inputmode="decimal" maxlength="10" value="${esc(draft.c)}" placeholder="可选" oninput="app.foodCustomInput('c', this.value)"></div>
          <div style="flex:1"><div class="form-label">脂肪（g）</div><input type="text" inputmode="decimal" maxlength="10" value="${esc(draft.f)}" placeholder="可选" oninput="app.foodCustomInput('f', this.value)"></div>
        </div>
        <div class="form-label" style="margin-top:12px">膳食纤维（g）</div>
        <input type="text" inputmode="decimal" maxlength="10" value="${esc(draft.fiber || "")}" placeholder="可选" oninput="app.foodCustomInput('fiber', this.value)">
        <div class="tiny faint" style="margin-top:8px">会按“这一份”换算成每 100g 保存，下次搜索时可以直接复用。</div>
      </div>

      <button class="btn btn-primary" onclick="app.saveFoodCustom()">保存并选择</button>
      <div class="tiny faint center" style="line-height:1.6">没有“好食物/坏食物”。记录只是帮你了解今天吃了什么。</div>
    </div>
  `;
}

function foodResults(query) {
  const list = allFoods()
    .filter((food) => !query || food.name.includes(query) || food.cat.includes(query))
    .slice(0, 30);
  if (!list.length) {
    return `<div class="tiny muted" style="padding:22px 12px;text-align:center">没有匹配的食物，直接手动添加就好。</div>`;
  }
  return list.map((food) => `
    <button class="food-item" onclick="app.selectFood(decodeURIComponent('${encodeURIComponent(food.name)}'))">
      <div>
        <div class="small strong">${esc(food.name)}</div>
        <div class="tiny faint">${food.cat} · ${food.serving ? `常用 ${food.serving}g · ` : ""}每 100g</div>
      </div>
      <div style="text-align:right">
        <div class="tiny accent">${food.kcal} kcal</div>
        <div class="tiny faint">P${Math.round(food.p)} C${Math.round(food.c)} F${Math.round(food.f)}</div>
      </div>
    </button>
  `).join("");
}

