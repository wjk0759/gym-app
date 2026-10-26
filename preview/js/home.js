/* ---------------- Home ---------------- */

function homeNextMeal() {
  const hour = new Date().getHours();
  if (hour < 10) return { name: "早餐", split: 0.25, suggestion: "燕麦 · 鸡蛋 · 牛奶" };
  if (hour < 15) return { name: "午餐", split: 0.35, suggestion: "米饭 · 鸡胸/鱼 · 蔬菜" };
  if (hour < 17) return { name: "加餐", split: 0.10, suggestion: "酸奶 · 水果 · 坚果" };
  if (hour < 21) return { name: "晚餐", split: 0.30, suggestion: "红薯 · 蛋白 · 蔬菜" };
  return { name: "加餐", split: 0.10, suggestion: "酸奶 · 水果 · 坚果" };
}

function homeTodayCard(day, targets) {
  const period = periodForDate(todayKey());
  if (!day) {
    return `
      <div class="card home-rest-card">
        <div class="today-head">
          <div>
            <div class="badge">${period ? `经期 · 第 ${period.day} 天` : "今日休息"}</div>
            <h2 class="today-title" style="margin-top:9px">恢复日</h2>
            <div class="today-focus">今天没有安排训练</div>
          </div>
          <div class="tiny faint">第 ${currentPlanWeekNumber()} 周</div>
        </div>
        <div class="small muted" style="margin-top:10px;line-height:1.6">今天把恢复和饮食做好。蛋白质吃够，下一次训练状态会更好。</div>
        ${period ? `<div class="period-training-note">经期第 ${period.day} 天 · 优先休息、补铁和蛋白质，不硬撑训练。</div>` : ""}
        <div class="home-rest-tips">
          <span>睡眠 7–9h</span>
          <span>散步 / 拉伸</span>
          <span>蛋白质 ${targets.protein}g</span>
        </div>
      </div>
    `;
  }
  return `
    <div class="card">
      <div class="today-head">
        <div>
          <div class="badge">${period ? `经期 · 第 ${period.day} 天` : "今日训练"}</div>
          <h2 class="today-title" style="margin-top:9px">${day.title}</h2>
          <div class="today-focus">${day.focus.join(" · ")}</div>
        </div>
        <div class="tiny faint">第 ${currentPlanWeekNumber()} 周</div>
      </div>
      ${period ? `<div class="period-training-note">经期轻量版：自动少 1 组、负重约 80%；腹痛明显时改为散步或休息。</div>` : ""}

      <div class="row gap12" style="margin:14px 0 10px;align-items:flex-end">
        <div class="grow"><div class="small strong">${day.exercises.length} 个</div><div class="tiny faint">动作</div></div>
        <div class="grow"><div class="small strong">${estimatedMinutes(day)} 分钟</div><div class="tiny faint">预计</div></div>
      </div>

      <div>
        ${day.exercises.slice(0, 3).map((item) => `
          <div class="exercise-line">
            <span class="dot"></span>
            <span class="name grow">${EX[item.slug].name}</span>
            <span class="target">${period ? Math.max(2, Number(item.sets) - 1) : item.sets} 组 × ${item.reps}</span>
          </div>
        `).join("")}
        ${day.exercises.length > 3 ? `<div class="tiny faint" style="padding-left:15px">还有 ${day.exercises.length - 3} 个动作</div>` : ""}
      </div>

      <button class="btn btn-primary" style="margin-top:14px" onclick="app.startWorkout()">${period ? "开始经期轻量训练" : "开始训练"}</button>
      <div class="tiny faint center" style="margin-top:7px">下一步可调整顺序和负荷</div>
    </div>
  `;
}

function homeNutritionCard({ targets, totals, day }) {
  const ratio = Math.min(100, Math.round((totals.kcal / Math.max(1, targets.kcal)) * 100));
  const calorieDelta = Math.round(targets.kcal - totals.kcal);
  const remainingProtein = Math.max(0, targets.protein - Math.round(totals.p));
  const nextMeal = homeNextMeal();
  return `
    <section class="card home-nutrition-plan">
      <div class="between home-nutrition-head">
        <div class="grow">
          <div class="badge">今日饮食计划</div>
          <h2 class="today-title" style="margin-top:9px">${state.profile.goal}饮食</h2>
          <div class="today-focus">${day ? `${day.title} · 补足蛋白质` : "休息日 · 饮食调整优先"}</div>
        </div>
        <div class="home-nutrition-balance">
          <strong>${Math.abs(calorieDelta)}</strong>
          <span>${calorieDelta >= 0 ? "kcal 剩余" : "kcal 超出"}</span>
        </div>
      </div>

      <div class="bar home-calorie-bar"><span style="width:${ratio}%"></span></div>
      <div class="between tiny faint home-calorie-meta">
        <span>${Math.round(totals.kcal)} / ${targets.kcal} kcal</span>
        <span>蛋白还差 ${remainingProtein}g</span>
      </div>

      <div class="home-macro-grid">
        <div class="home-macro"><span>蛋白质</span><strong>${Math.round(totals.p)}<i>/${targets.protein}g</i></strong></div>
        <div class="home-macro"><span>碳水</span><strong>${Math.round(totals.c)}<i>/${targets.carbs}g</i></strong></div>
        <div class="home-macro"><span>脂肪</span><strong>${Math.round(totals.f)}<i>/${targets.fat}g</i></strong></div>
        <div class="home-macro"><span>纤维</span><strong>${Math.round(totals.fiber)}<i>/${targets.fiber}g</i></strong></div>
      </div>

      <div class="home-meal-note">
        <span>下一餐 · ${nextMeal.name}</span>
        <strong>${nextMeal.suggestion}</strong>
        <small>约 ${Math.round(targets.kcal * nextMeal.split)} kcal</small>
      </div>

      <div class="home-nutrition-actions">
        <button class="btn btn-secondary" onclick="app.openNutritionDate(todayKey(), 'home')">记录饮食</button>
        <button class="btn btn-primary" onclick="app.startNutritionCoach('home')">调整饮食</button>
      </div>
    </section>
  `;
}

function homeAiCard({ weekSessions, weeklyTarget, remainingSessions, preview, ratio, currentWeek, day }) {
  const headline = weekSessions
    ? (remainingSessions ? `本周还差 ${remainingSessions} 次训练` : "本周目标已完成")
    : day ? "先完成本周第一次训练" : "今天休息，训练进度保持";
  return `
    <div class="card home-ai-card">
      <div class="between">
        <div>
          <div class="tiny accent strong">AI 教练 · 本周进度</div>
          <div class="h3" style="margin-top:4px">${headline}</div>
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
        <span>调整训练计划</span><span>→</span>
      </button>
    </div>
  `;
}

function homeGoalData() {
  const p = state.profile;
  const metrics = (state.bodyMetrics || [])
    .filter((entry) => Number(entry.weight) > 0)
    .sort((left, right) => Number(right.timestamp) - Number(left.timestamp));
  const startWeight = Number(p.goalStartWeight) || Number(metrics[metrics.length - 1]?.weight) || Number(p.weight) || 0;
  const currentWeight = Number(metrics[0]?.weight) || Number(p.weight) || 0;
  const targetWeight = Number(p.targetWeight) || 0;
  const denominator = targetWeight - startWeight;
  let progress = 0;
  if (Math.abs(denominator) < 0.05) {
    progress = Math.abs(currentWeight - targetWeight) < 0.05 ? 100 : 0;
  } else {
    progress = ((currentWeight - startWeight) / denominator) * 100;
  }
  progress = Math.max(0, Math.min(100, Math.round(progress)));
  const distance = targetWeight ? Math.abs(targetWeight - currentWeight) : null;
  const targetDate = /^\d{4}-\d{2}-\d{2}$/.test(p.goalTargetDate || "") ? parseDateKey(p.goalTargetDate) : null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const daysLeft = targetDate ? Math.ceil((targetDate.getTime() - today.getTime()) / 86400000) : null;
  const targetDateText = targetDate ? `${targetDate.getFullYear()}/${targetDate.getMonth() + 1}/${targetDate.getDate()}` : "未设置";
  const dateStatus = daysLeft == null ? "设置目标日期" : daysLeft > 0 ? `还有 ${daysLeft} 天` : daysLeft === 0 ? "今天到期" : "已到期";
  const todayMetric = metrics.some((entry) => entry.date === todayKey());
  const waistTarget = Number(p.targetWaist) || 0;
  const currentBodyFat = Number(metrics[0]?.bodyFat) || Number(p.bodyFat) || 0;
  const targetBodyFat = Number(p.targetBodyFat) || 0;
  const formatWeight = (value) => Number(value).toFixed(1).replace(/\.0$/, "");
  return {
    p,
    startWeight,
    currentWeight,
    targetWeight,
    progress,
    distance,
    targetDateText,
    dateStatus,
    daysLeft,
    todayMetric,
    waistTarget,
    currentBodyFat,
    targetBodyFat,
    distanceText: targetWeight
      ? distance < 0.05 ? "目标体重已达成" : `还差 ${formatWeight(distance)} kg`
      : "设置目标体重",
    formatWeight
  };
}

function homeGoalCard() {
  const goal = homeGoalData();
  const { p } = goal;
  const targetParts = [];
  if (goal.waistTarget && p.goal !== "提升体能") {
    targetParts.push(`腰围 ${goal.formatWeight(p.waist)} → ${goal.formatWeight(goal.waistTarget)} cm`);
  }
  if (goal.targetBodyFat && p.goal !== "提升体能") {
    targetParts.push(`体脂 ${goal.formatWeight(goal.currentBodyFat)} → ${goal.formatWeight(goal.targetBodyFat)}%`);
  }
  const targetText = targetParts.join(" · ");
  return `
    <section class="card home-goal-card">
      <div class="between home-goal-head">
        <div class="grow">
          <div class="badge">当前目标 · ${p.goal}</div>
          <div class="home-goal-distance">${goal.distanceText}</div>
          <button class="home-goal-date" onclick="app.openGoalEditor()">
            目标日期 ${goal.targetDateText} · ${goal.dateStatus} <span>›</span>
          </button>
        </div>
        <div class="home-goal-percent">
          <strong>${goal.progress}%</strong>
          <span>完成</span>
        </div>
      </div>

      <div class="bar home-goal-bar"><span style="width:${goal.progress}%"></span></div>
      <div class="between home-goal-scale">
        <span>起始 ${goal.formatWeight(goal.startWeight)}</span>
        <span>当前 ${goal.formatWeight(goal.currentWeight)}</span>
        <span>目标 ${goal.targetWeight ? goal.formatWeight(goal.targetWeight) : "—"}</span>
      </div>
      ${targetText ? `<div class="home-goal-waist">${targetText}</div>` : ""}

      <div class="between home-goal-foot">
        <span class="home-goal-checkin ${goal.todayMetric ? "done" : ""}">${goal.todayMetric ? "今日已打卡 · 进度已更新" : "今天记录一次，进度自动更新"}</span>
        <button class="btn btn-secondary home-goal-checkin-btn" onclick="app.openBodyCheckIn()">记录今日数据</button>
      </div>
    </section>
  `;
}

function goalDateSheet() {
  const p = state.profile;
  const fallback = localDateInputValue(addDays(new Date(), 84));
  const value = /^\d{4}-\d{2}-\d{2}$/.test(p.goalTargetDate || "") ? p.goalTargetDate : fallback;
  return `
    <div class="body-checkin-backdrop" onclick="app.closeGoalEditor()">
      <section class="body-checkin-sheet goal-date-sheet no-drag" role="dialog" aria-modal="true" aria-label="设定目标日期" onclick="event.stopPropagation()">
        <div class="between">
          <div>
            <div class="compose-kicker">目标计划</div>
            <div class="h2">设定目标日期</div>
          </div>
          <button class="icon-btn" onclick="app.closeGoalEditor()" aria-label="关闭">×</button>
        </div>
        <p class="body-checkin-copy">目标日期会显示在首页；进度仍按每日体重记录更新。</p>
        <label class="goal-date-field">
          <span>目标日期</span>
          <input id="goal-target-date" type="date" min="${todayKey()}" value="${value}">
        </label>
        <button class="btn btn-primary" style="margin-top:12px" onclick="app.saveGoalDate()">保存目标日期</button>
        <button class="btn btn-ghost" onclick="app.closeGoalEditor()">取消</button>
      </section>
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
  const trainingCard = homeTodayCard(day, targets);
  const nutritionCard = homeNutritionCard({ targets, totals, day });

  return `
    <div class="stack">
      <div class="greeting">
        <div class="h3">${greetingText()}，${esc(state.profile.name)}</div>
        <div class="date">${dateLabel(todayKey())}</div>
      </div>

      ${homeGoalCard()}

      ${day ? `${trainingCard}${nutritionCard}` : `${nutritionCard}${trainingCard}`}

      ${homeAiCard({ weekSessions, weeklyTarget, remainingSessions, preview, ratio, currentWeek, day })}
    </div>
  `;
}
