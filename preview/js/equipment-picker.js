/* FitAI Web Preview page module: equipment-picker */

/* ---------------- Equipment ---------------- */

function exercisePickIcon(item) {
  const muscle = item.muscle || "";
  if (muscle.includes("有氧")) return ICONS.cardio;
  if (muscle.includes("手臂")) return ICONS.muscleArms;
  if (muscle.includes("核心")) return ICONS.muscleCore;
  if (muscle.includes("肩")) return ICONS.muscleShoulder;
  if (muscle.includes("胸")) return ICONS.muscleChest;
  if (muscle.includes("背")) return ICONS.muscleBack;
  if (muscle.includes("臀")) return ICONS.muscleGlutes;
  if (muscle.includes("腿")) return ICONS.muscleLegs;
  const map = {
    "固定器械": ICONS.machine,
    "哑铃": ICONS.dumbbell,
    "杠铃": ICONS.barbell,
    "绳索": ICONS.cable,
    "徒手": ICONS.bodyweight,
    "壶铃": ICONS.kettlebell,
    "弹力带": ICONS.band
  };
  return map[item.equip] || ICONS.dumbbell;
}

function equipmentPickerExercises() {
  const query = String(state.equipSearchQuery || "").trim();
  const planning = state.screen === "planExercisePicker";
  const planDraft = planning ? state.workoutDraft : null;

  return Object.keys(EX).filter((slug) => {
    const item = EX[slug];

    if (planning && planDraft?.exercises?.some((exercise) => exercise.slug === slug)) {
      return false;
    }

    const searchMatch = !query
      || item.name.includes(query)
      || item.muscle.includes(query)
      || item.equip.includes(query);

    // 搜索时跨全部动作查找，不受肌群、器械和“已添加”分类限制。
    if (query) return searchMatch;

    const muscleMatch = state.equipMuscle === "全部" || item.muscle === state.equipMuscle;
    const savedMatch = state.equipFilter !== "已添加"
      || state.equipmentLibrary.some((entry) => entry.slug === slug);
    const equipmentMatch = state.equipFilter === "全部"
      || state.equipFilter === "已添加"
      || item.equip === state.equipFilter;
    return searchMatch && muscleMatch && savedMatch && equipmentMatch;
  }).sort((a, b) => {
    const aSaved = state.equipmentLibrary.some((entry) => entry.slug === a);
    const bSaved = state.equipmentLibrary.some((entry) => entry.slug === b);
    if (aSaved !== bSaved) return aSaved ? -1 : 1;
    return EX[a].name.localeCompare(EX[b].name, "zh-CN");
  });
}

function equipmentPickerGrid() {
  const planning = state.screen === "planExercisePicker";
  const sessionPicking = state.screen === "sessionExercisePicker";
  const addMode = planning || sessionPicking;
  const list = equipmentPickerExercises();
  if (!list.length) {
    return `
      <div class="exercise-grid-empty">
        <span class="exercise-grid-empty-icon">${ICONS.search}</span>
        <strong>没有匹配的动作</strong>
        <span>换个肌群或器械试试</span>
      </div>
    `;
  }

  return list.map((slug) => {
    const item = EX[slug];
    const selected = !addMode && state.equipSelected.includes(slug);
    const action = planning
      ? `app.addPlanExercise('${slug}')`
      : sessionPicking
        ? `app.addSessionExercise('${slug}')`
        : `app.openExercise('${slug}')`;
    const label = planning ? "添加到当前训练日" : sessionPicking ? "添加到训练记录" : "查看详情";
    return `
      <div class="exercise-pick-card ${selected ? "selected" : ""}">
        <button class="exercise-pick-main" onclick="${action}" aria-label="${label}：${esc(item.name)}">
          <div class="exercise-pick-art">
            <span class="exercise-pick-glyph" aria-hidden="true">${exercisePickIcon(item)}</span>
            ${item.video !== false ? `<span class="exercise-pick-badge"><span class="exercise-pick-badge-icon" aria-hidden="true">${ICONS.play}</span>讲解</span>` : ""}
            ${addMode ? `<span class="exercise-pick-check">＋</span>` : ""}
          </div>
          <div class="exercise-pick-name">${esc(item.name)}</div>
          <div class="exercise-pick-meta-row">
            <span class="exercise-pick-meta">${item.muscle} · ${item.equip}</span>
            ${addMode ? "" : `<span class="exercise-pick-chevron" aria-hidden="true">›</span>`}
          </div>
        </button>
        ${addMode ? "" : `
          <button
            class="exercise-pick-select ${selected ? "active" : ""}"
            type="button"
            onclick="app.equipmentPickerToggle('${slug}')"
            aria-label="${selected ? "取消选择" : "选择"}：${esc(item.name)}"
            aria-pressed="${selected}"
          >${selected ? "✓" : "+"}</button>
        `}
      </div>
    `;
  }).join("");
}

function equipmentPickerScreen() {
  const planning = state.screen === "planExercisePicker";
  const sessionPicking = state.screen === "sessionExercisePicker";
  const picking = planning || sessionPicking;
  const muscles = ["全部", "胸", "背", "腿", "臀", "肩", "手臂", "核心", "有氧"];
  const equipment = picking
    ? ["全部", ...new Set(Object.values(EX).map((item) => item.equip))]
    : ["全部", "已添加", ...new Set(Object.values(EX).map((item) => item.equip))];
  const selected = picking
    ? []
    : state.equipSelected.map((slug) => ({ slug, ...EX[slug] })).filter((item) => item.name);
  const searching = String(state.equipSearchQuery || "").trim().length > 0;
  const resultCount = equipmentPickerExercises().length;

  return `
    <div class="stack equipment-picker ${picking ? "plan-picker" : ""}" id="equipment-picker-root">
      ${planning ? headerBack("添加动作", "app.closePlanExercisePicker()") : sessionPicking ? headerBack("添加动作", "app.closeSessionExercisePicker()") : ""}

      <div class="equipment-sticky-tools">
        <div class="equipment-search-line">
          <div class="equipment-search-row">
            <span class="equipment-search-icon">${ICONS.search}</span>
            <input id="equipment-picker-search" type="text" maxlength="60" placeholder="搜索动作、肌群或器械" value="${esc(state.equipSearchQuery)}" oninput="app.equipmentPickerQuery(this.value)">
            <button id="equipment-search-clear" class="equipment-search-clear" type="button" onclick="app.equipmentPickerClearQuery()" aria-label="清空搜索" ${state.equipSearchQuery ? "" : "hidden"}>×</button>
            ${picking ? "" : `
              <button class="equipment-scan-btn" onclick="app.equipmentRecognitionOpen()" aria-label="拍照识别器械" title="拍照识别">
                ${ICONS.camera}
              </button>
            `}
          </div>
          ${picking ? "" : `
            <button class="equipment-library-btn" onclick="app.equipmentLibraryOpen()" aria-label="器械库" title="器械库">
              ${ICONS.library}
            </button>
          `}
        </div>

        <div id="equipment-search-scope" class="equipment-search-scope" ${searching ? "" : "hidden"}>全库搜索中 · 点分类可退出搜索</div>

        <div class="equipment-filter-scroll">
          ${equipment.map((label) => `
            <button class="equipment-filter ${state.equipFilter === label && !searching ? "active" : ""}" aria-pressed="${state.equipFilter === label && !searching}" onclick="app.equipmentPickerFilter('${label}')">${label}</button>
          `).join("")}
        </div>
      </div>

      <div class="equipment-content-head">
        <div class="equipment-content-title">
          <span>动作库</span>
          <em id="equipment-grid-count" aria-live="polite">${resultCount}</em>
        </div>
        <div class="exercise-grid-hint">${planning ? "点卡片加入训练日" : sessionPicking ? "点卡片添加到训练记录" : "点卡片看详情 · ⊕ 多选"}</div>
      </div>

      <div class="equipment-content-layout">
        <aside class="muscle-sidebar" aria-label="肌群筛选">
          ${muscles.map((label) => `
            <button class="muscle-side-item ${state.equipMuscle === label && !searching ? "active" : ""}" aria-pressed="${state.equipMuscle === label && !searching}" onclick="app.equipmentPickerMuscle('${label}')">${label}</button>
          `).join("")}
        </aside>

        <div class="exercise-pick-grid" id="equipment-picker-grid">${equipmentPickerGrid()}</div>
      </div>
    </div>

    ${picking ? "" : `
      <button class="equipment-selection-fab no-drag ${selected.length ? "has-items" : ""}" onclick="app.equipmentSelectionToggle()" aria-label="已选动作，共 ${selected.length} 个">
        ${ICONS.dumbbell}
        ${selected.length ? `<span class="equipment-selection-fab-count">${selected.length}</span>` : ""}
      </button>

      ${state.equipSelectionOpen ? equipmentSelectionPanel(selected) : ""}
    `}
  `;
}

function equipmentSelectionPanel(selected) {
  const savedSlugs = new Set(state.equipmentLibrary.map((item) => item.slug).filter(Boolean));
  const unsavedCount = selected.filter((item) => !savedSlugs.has(item.slug)).length;
  const librarySubtitle = !selected.length
    ? "先选择动作"
    : unsavedCount === 0
      ? "所选动作都在器械库里"
      : `把 ${unsavedCount} 个动作存入器械库`;

  return `
    <div class="equipment-selection-backdrop no-drag" onclick="app.equipmentSelectionClose()"></div>
    <section class="equipment-selection-popover" role="dialog" aria-label="已选动作">
      <div class="equipment-selection-arrow"></div>
      <div class="equipment-selection-head no-drag">
        <div class="grow">
          <div class="row gap6">
            <span class="h3">已选动作</span>
            <span class="accent small strong">${selected.length}</span>
          </div>
          <div class="tiny muted" style="margin-top:3px">选好后先安排顺序和负荷</div>
        </div>
        ${selected.length ? `<button class="link muted-link" onclick="app.equipmentPickerClear()">清空</button>` : ""}
      </div>

      <div class="equipment-selection-list ${selected.length ? "" : "empty"}">
        ${selected.length ? selected.map((item) => {
          const saved = savedSlugs.has(item.slug);
          return `
            <div class="equipment-selection-row">
              <span class="equipment-selection-glyph">${exercisePickIcon({ muscle: item.muscle, equip: item.equip })}</span>
              <div class="grow">
                <div class="small strong">${esc(item.name)}</div>
                <div class="tiny faint">${item.muscle} · ${item.equip}${saved ? " · 已在库" : ""}</div>
              </div>
              <button class="equipment-selection-remove" onclick="app.equipmentPickerToggle('${item.slug}')" aria-label="移除 ${esc(item.name)}">×</button>
            </div>
          `;
        }).join("") : `
          <div class="equipment-selection-empty">
            <div class="equipment-selection-empty-icon">${ICONS.dumbbell}</div>
            <div class="h3">还没有选择动作</div>
            <div class="tiny muted">在下面点选动作，再决定生成训练或存入器械库。</div>
          </div>
        `}
      </div>

      <div class="equipment-selection-actions no-drag">
        <button class="selection-action primary" onclick="app.equipmentSelectionMakePlan()" ${selected.length ? "" : "disabled"}>
          <span class="selection-action-icon">${ICONS.plan}</span>
          <span class="selection-action-copy">
            <span class="selection-action-title">制作训练计划</span>
            <span class="selection-action-sub">先排顺序和负荷，再开始训练</span>
          </span>
          <span class="selection-action-chevron">›</span>
        </button>

        <button class="selection-action secondary" onclick="app.equipmentSelectionAddToLibrary()" ${selected.length && unsavedCount ? "" : "disabled"}>
          <span class="selection-action-icon">${ICONS.equipment}</span>
          <span class="selection-action-copy">
            <span class="selection-action-title">加入我的器械库</span>
            <span class="selection-action-sub">${librarySubtitle}</span>
          </span>
          <span class="selection-action-chevron">›</span>
        </button>
      </div>
    </section>
  `;
}

