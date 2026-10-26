/* FitAI Web Preview page module: onboarding */

/* ---------------- Onboarding ---------------- */

function onboarding() {
  const p = state.profile;
  return `
    <div class="stack">
      <div class="hero">
        <div class="badge hero-badge">✦ AI 健身教练</div>
        <h1 class="hero-title">先花 2 分钟<br>让计划适合你</h1>
        <p class="hero-sub">根据目标、器械和可用时间编排训练，并随着记录持续调整。</p>
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:3px">基础信息</div>
        <div class="tiny muted" style="margin-bottom:14px">用于计算热量与训练负荷</div>
        <div class="form-label">怎么称呼你</div>
        <input type="text" maxlength="30" value="${esc(p.name)}" placeholder="例如：小林" oninput="app.field('name', this.value)">
        <div class="form-label" style="margin-top:14px">性别</div>
        ${segmented("sex", ["男", "女"], p.sex)}
        ${rangeRow("age", "年龄", "岁", 18, 60, 1)}
        ${rangeRow("height", "身高", "cm", 140, 210, 1)}
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:3px">身体数据</div>
        <div class="tiny muted" style="margin-bottom:14px">三围选填，用于追踪体型变化</div>
        ${rangeRow("weight", "体重", "kg", 40, 150, 0.5)}
        ${rangeRow("waist", "腰围", "cm", 50, 150, 1)}
        ${rangeRow("chest", "胸围", "cm", 60, 150, 1)}
        ${rangeRow("hip", "臀围", "cm", 60, 150, 1)}
        <div class="row between" style="margin-top:12px">
          <span class="small muted">BMI</span>
          <span class="small strong">${bmiText(p)}</span>
        </div>
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:3px">可用器械</div>
        <div class="tiny muted" style="margin-bottom:12px">只安排你能用上的动作</div>
        <div class="chips">
          ${["徒手", "哑铃", "杠铃", "固定器械", "绳索", "弹力带", "壶铃"].map((item) => `
            <button class="chip ${p.equipment.includes(item) ? "active" : ""}" onclick="app.toggleEquip('${item}')">${item}</button>
          `).join("")}
        </div>
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:3px">训练安排</div>
        <div class="tiny muted" style="margin-bottom:12px">之后可以随时调整</div>
        <div class="form-label">每周训练</div>
        ${segmented("weeklyDays", [1, 2, 3, 4, 5], String(p.weeklyDays), true)}
        <div class="form-label" style="margin-top:14px">训练分化</div>
        ${segmented("split", ["1分化", "2分化", "3分化", "4分化"], p.split)}
        <div class="tiny faint" style="margin-top:6px;line-height:1.55">1分化=全身，2分化=上下肢，3分化=推/拉/腿，4分化=胸肩/背/腿/手臂。AI 生成计划会按这个分化编排。</div>
        <div class="form-label" style="margin-top:14px">单次时长</div>
        ${segmented("minutes", [30, 45, 60, 90], String(p.minutes), true)}
        <div class="form-label" style="margin-top:14px">训练经验</div>
        ${segmented("experience", ["新手", "有基础", "进阶"], p.experience)}
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:3px">你的目标</div>
        <div class="tiny muted" style="margin-bottom:12px">计划会围绕目标调整组次与负荷</div>
        <div class="goal-grid">
          ${[
            ["减脂", "控制热量，保留肌肉"],
            ["增肌", "渐进超负荷，稳定增重"],
            ["重塑体型", "体重变化不大，改善围度"],
            ["提升体能", "提高心肺与耐力"]
          ].map(([goal, desc]) => `
            <button class="goal ${p.goal === goal ? "active" : ""}" onclick="app.setGoal('${goal}')">
              <strong>${goal}</strong><span>${desc}</span>
            </button>
          `).join("")}
        </div>
        ${p.goal !== "提升体能" ? `
          ${rangeRow("targetWeight", "目标体重", "kg", 40, 120, 0.5)}
          ${rangeRow("targetWaist", "目标腰围", "cm", 50, 120, 1)}
        ` : ""}
      </div>

      <div class="card tight">
        <div class="row gap10" style="align-items:flex-start">
          <span style="color:var(--accent)">✚</span>
          <div class="tiny muted">本产品不提供医疗诊断。孕期、术后、心血管疾病或关节急性疼痛，请先咨询医生。</div>
        </div>
      </div>

      <button id="gen-btn" class="btn btn-primary" onclick="app.generatePlan()">生成我的计划</button>
      <button class="btn btn-ghost" onclick="app.skipOnboarding()">直接看已建好的示例 →</button>
      <div class="tiny faint center" style="padding-bottom:8px">当前为 Web 预览，数据只保存在浏览器本地。</div>
    </div>
  `;
}

function segmented(key, options, current, numeric = false) {
  return `<div class="seg">${options.map((option) => {
    const value = String(option);
    const active = String(current) === value ? "active" : "";
    const arg = numeric ? value : `'${value}'`;
    return `<button class="${active}" onclick="app.seg('${key}', ${arg})">${value}</button>`;
  }).join("")}</div>`;
}

function rangeRow(key, label, unit, min, max, step) {
  const value = state.profile[key];
  return `
    <div class="slider-row">
      <div class="between">
        <span class="small muted">${label}</span>
        <span class="small strong" id="val-${key}">${value}${unit}</span>
      </div>
      <input type="range" min="${min}" max="${max}" step="${step}" value="${value}"
        oninput="app.range('${key}', this.value, '${unit}')">
    </div>
  `;
}

function bmiText(profile) {
  const h = Number(profile.height) / 100;
  const value = h > 0 ? Number(profile.weight) / (h * h) : 0;
  const label = value < 18.5 ? "偏瘦" : value < 24 ? "正常" : value < 28 ? "偏高" : "肥胖";
  return `${value.toFixed(1)} · ${label}`;
}

function profileDraftRangeRow(key, label, unit, min, max, step) {
  const draft = state.profileDraft;
  if (!draft) return "";
  const value = draft[key] ?? min;
  const shown = step < 1 ? Number(value).toFixed(1) : String(Math.round(value));
  return `
    <div class="slider-row">
      <div class="between">
        <span class="small muted">${label}</span>
        <span class="small strong" id="draft-val-${key}">${shown}${unit}</span>
      </div>
      <input type="range" min="${min}" max="${max}" step="${step}" value="${value}"
        oninput="app.profileDraftNumber('${key}', this.value)">
    </div>
  `;
}

/* ---------------- Login ---------------- */

