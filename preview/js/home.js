/* ---------------- Home ---------------- */

function homeTodayCard(day) {
  if (!day) {
    return `
      <div class="card">
        <div class="between">
          <div>
            <div class="badge">今日休息</div>
            <h2 class="today-title" style="margin-top:9px">恢复日</h2>
            <div class="today-focus">今天没有安排训练</div>
          </div>
          <div class="tiny faint">第 ${currentPlanWeekNumber()} 周</div>
        </div>
        <div class="small muted" style="margin-top:12px;line-height:1.65">恢复也是计划的一部分。睡够、吃够蛋白质；如果最近疲劳明显，可以让教练根据你的恢复情况调整计划。</div>
        <button class="btn btn-secondary" style="margin-top:12px" onclick="app.startPlanAdjustment('home')">和教练聊聊恢复安排</button>
      </div>
    `;
  }
  return `
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
  `;
}

function home() {
  const day = todayDay();
  const targets = nutritionTargets();
  const totals = nutritionTotals();
  const currentWeek = currentWeekSessions();
  const weekSessions = currentWeek.length;
  const weeklyTarget = Math.max(1, state.profile.weeklyDays);
  const remainingSessions = Math.max(0, weeklyTarget - weekSessions);
  const ratio = Math.min(100, Math.round((weekSessions / weeklyTarget) * 100));
  const preview = planAdjustmentPreview();
  const remainingKcal = Math.max(0, targets.kcal - Math.round(totals.kcal));
  const remainingProtein = Math.max(0, targets.protein - Math.round(totals.p));

  return `
    <div class="stack">
      <div class="greeting">
        <div class="h3">${greetingText()}，${esc(state.profile.name)}</div>
        <div class="date">${dateLabel(todayKey())}</div>
      </div>

      ${homeTodayCard(day)}

      <div class="card home-ai-card">
        <div class="between">
          <div>
            <div class="tiny accent strong">AI 教练 · 本周进度</div>
            <div class="h3" style="margin-top:4px">${weekSessions ? (remainingSessions ? `本周还差 ${remainingSessions} 次训练` : "本周目标已完成") : "先完成本周第一次训练"}</div>
            <div class="tiny muted" style="margin-top:3px">${state.plan.title} · 第 ${state.plan.version} 版</div>
          </div>
        </div>
        <div class="row gap8" style="margin-top:10px">
          <div class="review-metric"><div class="tiny faint">本周完成</div><div class="small strong">${weekSessions}/${weeklyTarget} 次</div></div>
          <div class="review-metric"><div class="tiny faint">近期 RPE</div><div class="small strong">${preview.averageRPE ? preview.averageRPE.toFixed(1) : "—"}</div></div>
          <div class="review-metric"><div class="tiny faint">训练容量</div><div class="small strong">${currentWeek.reduce((sum, s) => sum + s.volume, 0).toLocaleString()} kg</div></div>
        </div>
        <div class="home-ai-progress">
          <div class="between tiny"><span>本周目标</span><span>${ratio}%</span></div>
          <div class="bar"><span style="width:${ratio}%"></span></div>
        </div>
        <button class="btn btn-secondary home-ai-cta" onclick="app.startPlanAdjustment('home')">
          <span>✦ 和教练聊聊，再调整计划</span><span>→</span>
        </button>
      </div>

      <div class="card nutrition-card" onclick="app.openNutritionDate(todayKey(), 'home')">
        <div class="nutrition-icon">${ICONS.utensils}</div>
        <div class="grow">
          <div class="h3">今日饮食</div>
          <div class="tiny muted" style="margin-top:3px">${remainingKcal > 0 ? `还可摄入 ${remainingKcal} kcal · 蛋白质还差 ${remainingProtein}g` : `已达到今日热量目标 · 蛋白质还差 ${remainingProtein}g`}</div>
        </div>
        <div class="faint">›</div>
      </div>
    </div>
  `;
}

