/* FitAI preview actions: nutrition */
Object.assign(window.app, {
  closeNutrition() {
    app.back();
  },

  openFoodAdd(meal, dateKey = state.nutritionDateKey || todayKey()) {
    state.foodDraft = { meal, dateKey, query: "", selected: null, grams: 100 };
    pushRoute("foodAdd");
    save();
    render();
  },

  foodMeal(meal) {
    state.foodDraft.meal = meal;
    save();
    render();
  },

  foodQuery(query) {
    state.foodDraft.query = String(query || "").slice(0, 60);
    const box = document.getElementById("food-results");
    if (box) box.innerHTML = foodResults(query);
    save();
  },

  selectFood(name) {
    const food = allFoods().find((item) => item.name === name);
    state.foodDraft.selected = name;
    state.foodDraft.grams = food && food.serving ? food.serving : 100;
    save();
    render();
  },

  clearFoodSelection() {
    state.foodDraft.selected = null;
    save();
    render();
  },

  foodGrams(value) {
    const grams = Number(value);
    state.foodDraft.grams = grams;
    const food = allFoods().find((item) => item.name === state.foodDraft.selected);
    const label = document.getElementById("food-grams-label");
    const kcal = document.getElementById("food-kcal");
    const protein = document.getElementById("food-p");
    const carbs = document.getElementById("food-c");
    const fat = document.getElementById("food-f");
    const fiber = document.getElementById("food-fiber");
    if (label) label.textContent = `${grams} g`;
    if (food && kcal) kcal.textContent = Math.round(food.kcal * grams / 100);
    if (food && protein) protein.textContent = `${Math.round(food.p * grams / 100)}g`;
    if (food && carbs) carbs.textContent = `${Math.round(food.c * grams / 100)}g`;
    if (food && fat) fat.textContent = `${Math.round(food.f * grams / 100)}g`;
    if (food && fiber) fiber.textContent = `${Math.round((food.fiber || 0) * grams / 100 * 10) / 10}g`;
    save();
  },

  addFood() {
    const draft = state.foodDraft;
    const food = allFoods().find((item) => item.name === draft.selected);
    if (!food) return toast("先选择一个食物");
    const factor = draft.grams / 100;
    state.foodLogs.push({
      id: `f${Date.now()}`,
      date: draft.dateKey || state.nutritionDateKey || todayKey(),
      meal: draft.meal,
      name: food.name,
      grams: draft.grams,
      kcal: Math.round(food.kcal * factor),
      p: Math.round(food.p * factor * 10) / 10,
      c: Math.round(food.c * factor * 10) / 10,
      f: Math.round(food.f * factor * 10) / 10,
      fiber: Math.round((food.fiber || 0) * factor * 10) / 10
    });
    popRoute();
    save();
    render();
    toast("已添加饮食记录");
  },

  deleteFood(id) {
    if (!confirm("确认删除这条饮食记录？")) return;
    state.foodLogs = state.foodLogs.filter((item) => item.id !== id);
    save();
    render();
    toast("已删除记录");
  },

  openFoodCustom() {
    state.foodCustomDraft = {
      name: state.foodDraft.query.trim(),
      portion: "100",
      kcal: "",
      p: "",
      c: "",
      f: "",
      fiber: ""
    };
    pushRoute("foodCustom");
    save();
    render();
  },

  closeFoodCustom() {
    state.foodCustomDraft = null;
    app.back();
  },

  foodCustomInput(key, value) {
    if (!state.foodCustomDraft) return;
    state.foodCustomDraft[key] = String(value || "").slice(0, key === "name" ? 30 : 10);
    save();
  },

  saveFoodCustom() {
    const draft = state.foodCustomDraft;
    if (!draft) return;
    const name = String(draft.name || "").trim().slice(0, 30);
    const portion = Number(String(draft.portion).replace(",", "."));
    const kcalText = String(draft.kcal || "").trim();
    const kcal = Number(kcalText.replace(",", "."));
    if (!name) return toast("先填写食物名称");
    if (!Number.isFinite(portion) || portion <= 0) return toast("填写这一份的重量");
    if (!kcalText || !Number.isFinite(kcal) || kcal < 0) return toast("先填写这一份的热量，估算也可以");

    const factor = 100 / portion;
    const food = {
      name,
      cat: "自定义",
      kcal: kcal * factor,
      p: (Number(draft.p) || 0) * factor,
      c: (Number(draft.c) || 0) * factor,
      f: (Number(draft.f) || 0) * factor,
      fiber: (Number(draft.fiber) || 0) * factor,
      serving: portion
    };
    state.customFoods = [food, ...(state.customFoods || []).filter((item) => item.name !== name)];
    state.foodDraft.query = name;
    state.foodDraft.selected = name;
    state.foodDraft.grams = portion;
    state.foodCustomDraft = null;
    popRoute();
    save();
    render();
    toast("已保存，下次可以直接搜索这个食物");
  },

  openFoodPhoto(dateKey) {
    if (dateKey) state.nutritionDateKey = dateKey;
    state.foodPhotoImage = false;
    state.foodPhotoItems = [];
    state.foodPhotoConfidence = 0;
    state.foodPhotoModel = "";
    state.foodPhotoCameraFrom = "nutrition";
    pushRoute("foodPhotoCamera", { foodPhotoCameraFrom: "nutrition" });
    save();
    render();
  },

  openFoodPhotoCamera(from = "foodPhoto") {
    state.foodPhotoCameraFrom = from === "nutrition" ? "nutrition" : "foodPhoto";
    pushRoute("foodPhotoCamera", { foodPhotoCameraFrom: state.foodPhotoCameraFrom });
    save();
    render();
  },

  closeFoodPhotoCamera() {
    app.back();
  },

  foodPhotoCapture() {
    state.foodPhotoImage = true;
    state.foodPhotoItems = [];
    state.foodPhotoConfidence = 0;
    state.foodPhotoModel = "";
    settleCameraRoute("foodPhoto");
    save();
    render();
    toast("已选择照片（预览模拟）");
  },

  foodPhotoTake() {
    state.foodPhotoImage = true;
    state.foodPhotoItems = [];
    save();
    render();
    toast("已选择照片（预览模拟）");
  },

  foodPhotoMeal(meal) {
    state.foodPhotoMeal = meal;
    save();
    render();
  },

  foodPhotoAnalyze() {
    if (!state.foodPhotoImage) return toast("先拍照或选择照片");
    state.foodPhotoItems = foodPhotoMockItems();
    state.foodPhotoConfidence = state.foodPhotoItems.reduce((sum, item) => sum + item.confidence, 0) / state.foodPhotoItems.length;
    state.foodPhotoModel = "local-mock";
    save();
    render();
    toast("识别完成，可以修改份量和勾选");
  },

  foodPhotoToggle(index, checked) {
    const item = state.foodPhotoItems[index];
    if (!item) return;
    item.selected = checked;
    save();
    render();
  },

  foodPhotoGrams(index, value) {
    const item = state.foodPhotoItems[index];
    if (!item) return;
    item.grams = Math.max(10, Number(value) || 10);
    const factor = item.grams / 100;
    const kcal = Math.round(item.kcalPer100g * factor);
    const p = Math.round(item.pPer100g * factor);
    const c = Math.round(item.cPer100g * factor);
    const f = Math.round(item.fPer100g * factor);
    const gramsLabel = document.getElementById(`food-photo-grams-${index}`);
    const kcalLabel = document.getElementById(`food-photo-kcal-${index}`);
    const macroLabel = document.getElementById(`food-photo-macros-${index}`);
    if (gramsLabel) gramsLabel.textContent = `${item.grams} g`;
    if (kcalLabel) kcalLabel.textContent = `${kcal} kcal`;
    if (macroLabel) macroLabel.textContent = `P ${p}g · C ${c}g · F ${f}g · 纤维 ${Math.round((item.fiberPer100g || 0) * item.grams / 100 * 10) / 10}g`;

    const totals = foodPhotoTotals();
    const totalLabel = document.getElementById("food-photo-total");
    const addLabel = document.getElementById("food-photo-add-kcal");
    const proteinLabel = document.getElementById("food-photo-p");
    const carbLabel = document.getElementById("food-photo-c");
    const fatLabel = document.getElementById("food-photo-f");
    const fiberLabel = document.getElementById("food-photo-fiber");
    if (totalLabel) totalLabel.textContent = `${Math.round(totals.kcal)} kcal`;
    if (addLabel) addLabel.textContent = Math.round(totals.kcal);
    if (proteinLabel) proteinLabel.textContent = Math.round(totals.p);
    if (carbLabel) carbLabel.textContent = Math.round(totals.c);
    if (fatLabel) fatLabel.textContent = Math.round(totals.f);
    if (fiberLabel) fiberLabel.textContent = Math.round(totals.fiber);
    save();
  },

  foodPhotoAdd() {
    const selected = state.foodPhotoItems.filter((item) => item.selected);
    if (!selected.length) return toast("至少勾选一种食物");
    const meal = state.foodPhotoMeal;
    selected.forEach((item, index) => {
      const factor = item.grams / 100;
      state.foodLogs.push({
        id: `fp-log-${Date.now()}-${index}`,
        date: state.nutritionDateKey || todayKey(),
        meal,
        name: item.name,
        grams: item.grams,
        kcal: Math.round(item.kcalPer100g * factor),
        p: Math.round(item.pPer100g * factor * 10) / 10,
        c: Math.round(item.cPer100g * factor * 10) / 10,
        f: Math.round(item.fPer100g * factor * 10) / 10,
        fiber: Math.round((item.fiberPer100g || 0) * factor * 10) / 10
      });
    });
    const total = Math.round(foodPhotoTotals(selected).kcal);
    state.foodPhotoImage = false;
    state.foodPhotoItems = [];
    popRoute();
    save();
    render();
    toast(`${meal}已加入 ${total} kcal`);
  },
});
