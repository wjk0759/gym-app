/* FitAI Web Preview actions: equipment selection, recognition, detail and body analysis */
Object.assign(window.app, {
  equipmentSelectionAddToLibrary() {
    const selected = state.equipSelected
      .map((slug) => ({ slug, ...EX[slug] }))
      .filter((item) => item.name);
    if (!selected.length) return;

    const existing = new Set(state.equipmentLibrary.map((item) => item.slug).filter(Boolean));
    let added = 0;
    selected.forEach((item) => {
      if (existing.has(item.slug)) return;
      existing.add(item.slug);
      state.equipmentLibrary.push({
        id: `e${Date.now()}-${added}`,
        name: item.name,
        slug: item.slug,
        muscle: item.muscle,
        equip: item.equip,
        video: false,
        notes: "从已选动作加入"
      });
      added += 1;
    });

    state.equipSelected = [];
    state.equipSelectionOpen = false;
    save();
    render();
    toast(added > 0 ? `已加入器械库 ${added} 个动作` : "这些动作已经在器械库");
  },

  equipmentPickerMuscle(value) {
    state.equipMuscle = value;
    state.equipSearchQuery = "";
    save();
    render();
  },

  equipmentPickerFilter(value) {
    state.equipFilter = value;
    state.equipSearchQuery = "";
    save();
    render();
  },

  equipmentPickerQuery(value) {
    state.equipSearchQuery = String(value || "").slice(0, 60);
    const searching = !!String(value || "").trim();
    const grid = document.getElementById("equipment-picker-grid");
    if (grid) grid.innerHTML = equipmentPickerGrid();
    const count = document.getElementById("equipment-grid-count");
    if (count) count.textContent = equipmentPickerExercises().length;
    const scope = document.getElementById("equipment-search-scope");
    if (scope) scope.hidden = !searching;
    const clear = document.getElementById("equipment-search-clear");
    if (clear) clear.hidden = !searching;
    document.getElementById("equipment-picker-root")?.classList.toggle("searching", searching);
    document.querySelectorAll(".muscle-side-item").forEach((button) => {
      const active = !searching && button.textContent.trim() === state.equipMuscle;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    document.querySelectorAll(".equipment-filter").forEach((button) => {
      const active = !searching && button.textContent.trim() === state.equipFilter;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    requestAnimationFrame(syncEquipmentLayout);
    save();
  },

  equipmentPickerClearQuery() {
    state.equipSearchQuery = "";
    save();
    render();
    requestAnimationFrame(() => document.getElementById("equipment-picker-search")?.focus());
  },

  equipmentRecognitionOpen() {
    state.equipRecognitionPhoto = false;
    state.equipSelectionOpen = false;
    state.equipRecognitionCandidates = [];
    pushRoute("equipmentCamera");
    save();
    render();
  },

  equipmentCapturePhoto() {
    state.equipRecognitionPhoto = true;
    state.equipRecognitionCandidates = [];
    settleCameraRoute("equipmentRecognition");
    save();
    render();
  },

  equipmentRecognitionPhoto() {
    state.equipRecognitionPhoto = false;
    state.equipRecognitionCandidates = [];
    pushRoute("equipmentCamera");
    save();
    render();
  },

  equipmentRecognitionScan() {
    if (!state.equipRecognitionPhoto) return toast("先拍一张器械照片");
    state.equipRecognitionCandidates = [
      { slug: "lat_pulldown", confidence: 0.91 },
      { slug: "seated_row", confidence: 0.64 },
      { slug: "face_pull", confidence: 0.48 }
    ];
    save();
    render();
  },

  equipmentRecognitionSave(slug) {
    if (!state.equipmentLibrary.some((entry) => entry.slug === slug)) {
      const ex = EX[slug];
      state.equipmentLibrary.push({
        id: `e${Date.now()}`,
        name: ex.name,
        slug,
        muscle: ex.muscle,
        equip: ex.equip,
        video: false,
        notes: "来自器械识别"
      });
    }
    if (!state.equipSelected.includes(slug)) {
      state.equipSelected.push(slug);
    }
    save();
    render();
    toast("已加入已选动作");
  },

  openEquipItem(id) {
    pushRoute("equipmentItem", { equipmentItemId: id, selectedExercise: null });
    save();
    render();
  },

  equipmentDetailScroll(id) {
    const app = document.getElementById("app");
    const target = document.getElementById(id);
    if (!app || !target) return;
    const top = app.scrollTop + target.getBoundingClientRect().top - app.getBoundingClientRect().top - 120;
    app.scrollTo({ top, behavior: "smooth" });
  },

  equipmentDetailPin(id) {
    const pinned = new Set(state.pinnedEquipIds || []);
    if (pinned.has(id)) {
      pinned.delete(id);
      toast("已取消置顶");
    } else {
      pinned.add(id);
      toast("已置顶这件器械");
    }
    state.pinnedEquipIds = [...pinned];
    save();
    render();
  },

  addDemoEquipment() {
    const pool = ["seated_row", "treadmill", "face_pull", "leg_press", "biceps_curl"];
    const slug = pool.find((item) => !state.equipmentLibrary.some((entry) => entry.slug === item));
    if (!slug) return toast("示例器械已全部添加");
    const ex = EX[slug];
    state.equipmentLibrary.push({
      id: `e${Date.now()}`,
      name: ex.name,
      slug,
      muscle: ex.muscle,
      equip: ex.equip,
      video: false,
      notes: "手动添加"
    });
    save();
    render();
    toast(`已添加 ${ex.name}`);
  },

  toggleEquipLibrary() {
    state.useEquipLibrary = !state.useEquipLibrary;
    save();
    render();
    toast(state.useEquipLibrary ? "已启用器械库优先" : "已关闭器械库优先");
  },

  deleteEquipItem(id) {
    if (!confirm("从器械库删除这件器械？")) return;
    state.equipmentLibrary = state.equipmentLibrary.filter((item) => item.id !== id);
    state.equipmentItemId = null;
    popRoute();
    save();
    render();
    toast("已从器械库删除");
  },

  regenerateWithLibrary() {
    state.useEquipLibrary = true;
    state.plan = applyEquipmentLibrary(buildPlan(state.profile));
    state.plan.version += 1;
    resetToTab("plan");
    save();
    render();
    toast("已按器械库生成新计划");
  },

  bodyAnalysisOpen() {
    pushRoute("bodyAnalysis");
    save();
    render();
  },

  bodyMockPhoto() {
    state.bodyPhoto = true;
    save();
    render();
    toast("已模拟选择体型照片");
  },

  bodyConsentToggle() {
    state.bodyConsent = !state.bodyConsent;
    render();
  },

  bodyAnalyze() {
    if (!state.bodyPhoto) return toast("先拍一张照片");
    if (!state.bodyConsent) return toast("请先同意用于本次分析");
    const variant = BODY_VARIANTS[Math.floor(Math.random() * BODY_VARIANTS.length)];
    state.bodyAnalysis = { ...variant, applied: false };
    save();
    render();
    toast("分析完成，仅作训练重点参考");
  },

  applyBodyAnalysis() {
    const analysis = state.bodyAnalysis;
    if (!analysis) return;
    state.plan.version += 1;
    state.plan.days.forEach((day) => {
      day.exercises.forEach((exercise) => {
        const muscle = EX[exercise.slug] ? EX[exercise.slug].muscle : "";
        if (analysis.focus.includes(muscle)) {
          exercise.sets = Math.min(6, exercise.sets + 1);
        }
      });
    });
    analysis.applied = true;
    popRoute();
    save();
    render();
    toast("已应用体型分析：重点部位增加训练量");
  },

  mockHealth() {
    toast("预览版不接 HealthKit；真实 App 会读取体重并写入训练");
  },

  saveReminder() {
    const input = document.getElementById("reminder-time");
    state.reminder = input ? input.value : "19:00";
    save();
    toast(`已设置 ${state.reminder} 训练提醒`);
  },

  clearPreferences() {
    state.disliked = [];
    save();
    render();
    toast("已清除训练偏好");
  },
});
