/* FitAI Web Preview page module: profile-edit */

function profileDraftSegmented(key, options) {
  const draft = state.profileDraft;
  return `<div class="seg">${options.map((option) => {
    const active = String(draft[key]) === String(option) ? "active" : "";
    return `<button class="${active}" data-draft-seg="${key}" data-value="${option}" onclick="app.profileDraftSelect('${key}', ${JSON.stringify(option)})">${option}</button>`;
  }).join("")}</div>`;
}

function profileEditScreen() {
  const draft = state.profileDraft;
  if (!draft) return profileScreen();

  return `
    <div class="stack">
      ${headerBack("编辑资料")}

      <div class="card">
        <div class="h3">基础信息</div>
        <div class="tiny muted" style="margin-top:3px;margin-bottom:14px">用于计算热量与训练负荷</div>

        <div class="form-label">怎么称呼你</div>
        <input type="text" maxlength="30" value="${esc(draft.name)}" placeholder="例如：小林" oninput="app.profileDraftInput('name', this.value)">

        <div class="form-label" style="margin-top:14px">性别</div>
        ${profileDraftSegmented("sex", ["男", "女"])}

        ${profileDraftRangeRow("age", "年龄", "岁", 18, 60, 1)}
        ${profileDraftRangeRow("height", "身高", "cm", 140, 210, 1)}
      </div>

      <div class="card">
        <div class="h3">身体数据</div>
        <div class="tiny muted" style="margin-top:3px;margin-bottom:12px">三围选填，用于追踪体型变化</div>
        ${profileDraftRangeRow("weight", "体重", "kg", 40, 150, 0.5)}
        ${profileDraftRangeRow("bodyFat", "体脂率", "%", 5, 50, 0.5)}
        ${profileDraftRangeRow("waist", "腰围", "cm", 50, 150, 1)}
        ${profileDraftRangeRow("chest", "胸围", "cm", 60, 150, 1)}
        ${profileDraftRangeRow("hip", "臀围", "cm", 60, 150, 1)}
        <div class="row between" style="margin-top:12px">
          <span class="small muted">BMI</span>
          <span class="small strong" id="draft-bmi">${bmiText(draft)}</span>
        </div>
      </div>

      <div class="card">
        <div class="h3">可用器械</div>
        <div class="tiny muted" style="margin-top:3px;margin-bottom:12px">只安排你能用上的动作</div>
        <div class="chips">
          ${["徒手", "哑铃", "杠铃", "固定器械", "绳索", "弹力带", "壶铃"].map((item) => `
            <button class="chip ${draft.equipment.includes(item) ? "active" : ""}" data-equip="${item}" onclick="app.profileDraftToggleEquip('${item}')">${item}</button>
          `).join("")}
        </div>
      </div>

      <div class="card">
        <div class="h3">训练安排</div>
        <div class="tiny muted" style="margin-top:3px;margin-bottom:12px">之后可以随时调整</div>
        <div class="form-label">每周训练</div>
        ${profileDraftSegmented("weeklyDays", [2, 3, 4, 5])}
        <div class="form-label" style="margin-top:14px">单次时长</div>
        ${profileDraftSegmented("minutes", [30, 45, 60, 90])}
        <div class="form-label" style="margin-top:14px">训练经验</div>
        ${profileDraftSegmented("experience", ["新手", "有基础", "进阶"])}
      </div>

      <div class="card">
        <div class="h3">你的目标</div>
        <div class="tiny muted" style="margin-top:3px;margin-bottom:12px">计划会围绕目标调整组次与负荷</div>
        <div class="goal-grid">
          ${[
            ["减脂", "控制热量，保留肌肉"],
            ["增肌", "渐进超负荷，稳定增重"],
            ["重塑体型", "体重变化不大，改善围度"],
            ["提升体能", "提高心肺与耐力"]
          ].map(([goal, desc]) => `
            <button class="goal ${draft.goal === goal ? "active" : ""}" data-draft-goal="${goal}" onclick="app.profileDraftSelect('goal', '${goal}')">
              <strong>${goal}</strong><span>${desc}</span>
            </button>
          `).join("")}
        </div>
        <div id="profile-target-fields" style="${draft.goal === "提升体能" ? "display:none" : ""}">
          ${profileDraftRangeRow("targetWeight", "目标体重", "kg", 40, 120, 0.5)}
          ${profileDraftRangeRow("targetWaist", "目标腰围", "cm", 50, 120, 1)}
        </div>
      </div>

      <div class="card tight">
        <div class="tiny muted" style="line-height:1.6">保存资料不会自动覆盖当前训练计划。如需让计划适配新的目标或器械，可回到「计划」页让 AI 复盘调整。</div>
      </div>

      <button class="btn btn-primary" onclick="app.saveProfileEdit()">保存资料</button>
      <button class="btn btn-ghost" onclick="app.closeProfileEdit()">取消并返回</button>
    </div>
  `;
}

/* ---------------- Settings ---------------- */

