/* FitAI Web Preview page module: profile overview */

/* ---------------- Profile ---------------- */

function profileScreen() {
  const p = state.profile;
  return `
    <div class="stack">
      <div class="profile-page-head">
        <div>
          <div class="section-kicker" style="margin-bottom:4px">账户与会员</div>
          <div class="h1">我的</div>
        </div>
        ${settingsButton()}
      </div>

      <div class="card" style="padding:0">
        <div class="list-row" style="padding:16px;cursor:pointer;align-items:center" onclick="app.openProfileEdit()">
          <div class="nutrition-icon" style="font-size:18px">${esc(p.name.slice(0, 1))}</div>
          <div class="grow">
            <div class="h3">${esc(p.name)}</div>
            <div class="tiny muted" style="margin-top:3px">${p.goal} · ${p.experience} · 每周 ${p.weeklyDays} 练</div>
          </div>
          <div class="row gap6" style="flex-shrink:0;white-space:nowrap">
            <span class="tiny accent strong">编辑资料</span>
            <span class="faint">›</span>
          </div>
        </div>

        <div style="height:1px;background:var(--stroke);margin:0 16px"></div>

        <div class="list-row" style="padding:14px 16px;cursor:pointer;align-items:center" onclick="app.openPaywall()">
          <div class="nutrition-icon" style="color:var(--warning);background:rgba(250,184,77,.12)">${ICONS.crown}</div>
          <div class="grow">
            <div class="small strong">练途 Pro</div>
            <div class="tiny muted" style="margin-top:2px">${state.pro ? "已订阅 · 所有功能已解锁" : "AI 计划、教练与器械识别"}</div>
          </div>
          <div class="accent small">${state.pro ? "管理会员" : "开通会员"} ›</div>
        </div>
      </div>

      <div class="section-kicker">身体与目标</div>

      <div class="card">
        <div class="row gap8">
          <div class="metric"><div class="value">${p.weight} kg</div><div class="label">体重</div></div>
          <div class="metric"><div class="value">${bmiText(p).split(" · ")[0]}</div><div class="label">BMI</div></div>
        </div>
        <div class="row gap8" style="margin-top:8px">
          <div class="metric"><div class="value">${p.waist} cm</div><div class="label">腰围</div></div>
          <div class="metric"><div class="value">${p.height} cm</div><div class="label">身高</div></div>
        </div>
        <div class="row gap8" style="margin-top:8px">
          <div class="metric"><div class="value">${state.sessions.length} 次</div><div class="label">累计训练</div></div>
          <div class="metric"><div class="value">${Math.round(state.sessions.reduce((sum, session) => sum + Number(session.volume || 0), 0)).toLocaleString()} kg</div><div class="label">总容量</div></div>
        </div>
      </div>

      <div class="card">
        <div class="between"><div class="h3">当前目标</div><span class="badge">${p.goal}</span></div>
        <div class="between" style="margin-top:10px"><span class="small muted">目标体重</span><span class="small strong">${p.targetWeight} kg</span></div>
        <div class="between" style="margin-top:7px"><span class="small muted">目标腰围</span><span class="small strong">${p.targetWaist} cm</span></div>
        <div class="tiny faint" style="margin-top:8px">减重建议不超过 0.5kg/周，不追求极端速度。</div>
      </div>

      <div class="section-kicker">训练工具</div>

      <div class="card" onclick="app.bodyAnalysisOpen()" style="cursor:pointer">
        <div class="between">
          <div>
            <div class="h3">体型照片分析</div>
            <div class="tiny muted" style="margin-top:3px">AI 给训练重点建议</div>
          </div>
          <span class="accent">›</span>
        </div>
        ${state.bodyAnalysis
          ? `<div class="tiny muted" style="margin-top:8px">${state.bodyAnalysis.summary}</div>
             <div class="chips" style="margin-top:6px">${state.bodyAnalysis.focus.map((item) => `<span class="chip active">${item}</span>`).join("")}</div>`
          : `<div class="tiny faint" style="margin-top:8px">照片只用于本次分析，不写入训练记录。</div>`}
      </div>

      <div class="card" onclick="app.equipmentLibraryOpen('profile')" style="cursor:pointer">
        <div class="between">
          <div>
            <div class="h3">我的器械库</div>
            <div class="tiny muted" style="margin-top:3px">已录入 ${state.equipmentLibrary.length} 件 · 教学视频与计划</div>
          </div>
          <span class="accent">›</span>
        </div>
      </div>

    </div>
  `;
}

