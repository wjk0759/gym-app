/* ---------------- Home ---------------- */

function home() {
  const day = todayDay();
  const targets = nutritionTargets();
  const totals = nutritionTotals();
  const currentWeek = currentWeekSessions();
  const weekSessions = currentWeek.length;
  const ratio = Math.min(100, Math.round((weekSessions / Math.max(1, state.profile.weeklyDays)) * 100));
  const preview = planAdjustmentPreview();
  const remainingKcal = Math.max(0, targets.kcal - Math.round(totals.kcal));
  const remainingProtein = Math.max(0, targets.protein - Math.round(totals.p));
  const totalVolume = state.sessions.reduce((sum, session) => sum + Number(session.volume || 0), 0);

  return `
    <div class="stack">
      <div class="greeting">
        <div class="h3">${greetingText()}，${esc(state.profile.name)}</div>
        <div class="date">${dateLabel(todayKey())}</div>
      </div>

      <div class="card">
        <div class="today-head">
          <div>
            <div class="badge">今日训练</div>
            <h2 class="today-title" style="margin-top:9px">${day.title}</h2>
            <div class="today-focus">${day.focus.join(" · ")}</div>
          </div>
          <div class="tiny faint">第 ${currentPlanWeekNumber()} 周</div>
        </div>

        <div class="row gap12" style="margin:14px 0 10px;align-items:flex-end">
          <div class="grow"><div class="small strong">${day.exercises.length} 个</div><div class="tiny faint">动作</div></div>
          <div class="grow"><div class="small strong">${estimatedMinutes(day)} 分钟</div><div class="tiny faint">预计</div></div>
        </div>

        <div>
          ${day.exercises.slice(0, 3).map((item) => `
            <div class="exercise-line">
              <span class="dot"></span>
              <span class="name grow">${EX[item.slug].name}</span>
              <span class="target">${item.sets} 组 × ${item.reps}</span>
            </div>
          `).join("")}
          ${day.exercises.length > 3 ? `<div class="tiny faint" style="padding-left:15px">还有 ${day.exercises.length - 3} 个动作</div>` : ""}
        </div>

        <button class="btn btn-primary" style="margin-top:14px" onclick="app.startWorkout()">开始训练</button>
        <div class="tiny faint center" style="margin-top:7px">下一步可调整顺序和负荷</div>
      </div>

      <div class="card">
        <div class="between">
          <div>
            <div class="tiny accent strong">AI 复盘</div>
            <div class="h3" style="margin-top:3px">${state.plan.title}</div>
            <div class="tiny muted" style="margin-top:3px">第 ${state.plan.version} 版 · ${state.plan.days.length} 个训练日</div>
          </div>
          <span class="accent">↗</span>
        </div>
        <div class="row gap8" style="margin-top:10px">
          <div class="review-metric"><div class="tiny faint">本周完成</div><div class="small strong">${weekSessions}/${Math.max(1, state.profile.weeklyDays)} 次</div></div>
          <div class="review-metric"><div class="tiny faint">平均 RPE</div><div class="small strong">${preview.averageRPE ? preview.averageRPE.toFixed(1) : "—"}</div></div>
          <div class="review-metric"><div class="tiny faint">训练容量</div><div class="small strong">${currentWeek.reduce((sum, s) => sum + s.volume, 0).toLocaleString()} kg</div></div>
        </div>
        <div class="small strong" style="margin-top:10px">${weekSessions ? `这次复盘：${preview.headline}` : "先记录一次训练，复盘才有数据。"}</div>
        <div class="tiny muted" style="margin-top:4px;line-height:1.6">${weekSessions ? preview.detail : "完成率、平均 RPE 与训练容量会一起参与判断。"}</div>
        <button class="link" style="margin-top:10px" onclick="app.adjustPlan()">✦ 让 AI 复盘并调整 →</button>
      </div>

      <div class="card">
        <div class="between" style="margin-bottom:10px">
          <div class="h3">本周完成</div>
          <div class="small muted">${weekSessions}/${state.profile.weeklyDays} 次</div>
        </div>
        <div class="bar"><span style="width:${ratio}%"></span></div>
        <div class="row gap12" style="margin-top:12px">
          <div class="grow"><div class="h3">${state.sessions.length}</div><div class="tiny faint">累计训练</div></div>
          <div class="grow"><div class="h3">${Math.round(totalVolume).toLocaleString()}</div><div class="tiny faint">总容量 kg</div></div>
          <div class="grow"><div class="h3">${weekSessions}</div><div class="tiny faint">本周</div></div>
        </div>
      </div>

      <div class="card nutrition-card" onclick="app.openNutritionDate(todayKey(), 'home')">
        <div class="nutrition-icon">🍽</div>
        <div class="grow">
          <div class="h3">今日饮食</div>
          <div class="tiny muted" style="margin-top:3px">${remainingKcal > 0 ? `还可摄入 ${remainingKcal} kcal · 蛋白质还差 ${remainingProtein}g` : `已达到今日热量目标 · 蛋白质还差 ${remainingProtein}g`}</div>
        </div>
        <div class="faint">›</div>
      </div>
    </div>
  `;
}

