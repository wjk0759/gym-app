/* FitAI Web Preview module: monthly training + nutrition review for Plan. */

function planReviewData() {
  const month = state.calendarMonth || monthKey(new Date());
  const [year, monthNumber] = month.split("-").map(Number);
  const start = new Date(year, monthNumber - 1, 1);
  const end = new Date(year, monthNumber, 1);
  const sessions = state.sessions.filter((session) => {
    const timestamp = Number(session.timestamp);
    if (!Number.isFinite(timestamp) || timestamp <= 0) return false;
    return new Date(timestamp) >= start && new Date(timestamp) < end;
  }).sort((left, right) => Number(right.timestamp || 0) - Number(left.timestamp || 0));
  const foodLogs = state.foodLogs.filter((log) => String(log.date || todayKey()).slice(0, 7) === month);
  const foodDays = new Set(foodLogs.map((log) => log.date || todayKey()));
  const nutrition = foodLogs.reduce((total, log) => {
    total.kcal += Number(log.kcal) || 0;
    total.p += Number(log.p) || 0;
    total.c += Number(log.c) || 0;
    total.f += Number(log.f) || 0;
    total.fiber += Number(log.fiber) || 0;
    return total;
  }, { kcal: 0, p: 0, c: 0, f: 0, fiber: 0 });
  const loggedDays = foodDays.size;
  const average = (value) => loggedDays ? Math.round(value / loggedDays) : 0;
  const volume = sessions.reduce((sum, session) => sum + Number(session.volume || 0), 0);
  const minutes = sessions.reduce((sum, session) => sum + Number(session.duration || 0), 0);
  const sets = sessions.reduce((sum, session) => sum + (session.items || []).reduce((partial, item) => partial + Number(item.sets || 0), 0), 0);
  const trainingDays = new Set(sessions.map(sessionDateKey)).size;
  const targets = nutritionTargets();

  const weekBars = [];
  let cursor = startOfWeekMonday(start);
  while (cursor < end) {
    const weekEnd = addDays(cursor, 7);
    const value = sessions
      .filter((session) => {
        const timestamp = Number(session.timestamp);
        return timestamp >= Math.max(start.getTime(), cursor.getTime())
          && timestamp < Math.min(end.getTime(), weekEnd.getTime());
      })
      .reduce((sum, session) => sum + Number(session.volume || 0), 0);
    weekBars.push({
      label: `第${weekBars.length + 1}周`,
      value
    });
    cursor = weekEnd;
  }
  const maxBar = Math.max(1, ...weekBars.map((bar) => bar.value));
  return {
    month,
    monthLabel: monthLabel(month),
    sessions,
    volume,
    minutes,
    sets,
    trainingDays,
    foodLogs,
    loggedDays,
    nutrition,
    averages: {
      kcal: average(nutrition.kcal),
      p: average(nutrition.p),
      c: average(nutrition.c),
      f: average(nutrition.f),
      fiber: average(nutrition.fiber)
    },
    targets,
    weekBars,
    maxBar
  };
}

function dataReviewPanel() {
  const review = planReviewData();
  const hasNutrition = review.loggedDays > 0;
  return `
    <section class="data-review-panel" id="plan-data-review">
      <div class="between data-review-head">
        <div>
          <div class="compose-kicker">数据复盘</div>
          <div class="h2">${review.monthLabel}</div>
          <div class="tiny muted">${review.sessions.length} 次训练 · ${review.loggedDays} 天饮食记录</div>
        </div>
        <button class="link" onclick="app.openHistory()">全部训练 ›</button>
      </div>

      <div class="data-review-block">
        <div class="between data-review-block-head">
          <div class="calendar-section-label">训练</div>
          <span class="tiny faint">${review.trainingDays} 个训练日</span>
        </div>
        <div class="training-metric-grid">
          <div class="training-metric"><strong>${review.sessions.length}</strong><span>完成训练</span></div>
          <div class="training-metric"><strong>${Math.round(review.volume).toLocaleString()}</strong><span>总容量 kg</span></div>
          <div class="training-metric"><strong>${review.sets}</strong><span>总组数</span></div>
          <div class="training-metric"><strong>${review.sessions.length ? Math.round(review.minutes / review.sessions.length) : 0}</strong><span>平均分钟</span></div>
        </div>
        <div class="training-bars">
          ${review.weekBars.map((bar) => `
            <div class="training-bar-column">
              <div class="training-bar-track"><span style="height:${Math.max(4, Math.round(bar.value / review.maxBar * 100))}%"></span></div>
              <small>${bar.label}</small>
            </div>
          `).join("")}
        </div>
        <div class="tiny faint" style="margin-top:8px">按实际训练日期统计，容量只计算有记录的组数。</div>
      </div>

      <div class="data-review-block">
        <div class="between data-review-block-head">
          <div class="calendar-section-label">饮食营养</div>
          <span class="tiny faint">${hasNutrition ? "有记录日均值" : "本月暂无记录"}</span>
        </div>
        <div class="review-macro-grid">
          <div class="review-macro"><span>热量</span><strong>${hasNutrition ? review.averages.kcal : "—"}</strong><small>目标 ${review.targets.kcal} kcal</small></div>
          <div class="review-macro"><span>蛋白质</span><strong>${hasNutrition ? review.averages.p : "—"}<i>g</i></strong><small>目标 ${review.targets.protein}g</small></div>
          <div class="review-macro"><span>碳水</span><strong>${hasNutrition ? review.averages.c : "—"}<i>g</i></strong><small>目标 ${review.targets.carbs}g</small></div>
          <div class="review-macro"><span>脂肪</span><strong>${hasNutrition ? review.averages.f : "—"}<i>g</i></strong><small>目标 ${review.targets.fat}g</small></div>
          <div class="review-macro"><span>膳食纤维</span><strong>${hasNutrition ? review.averages.fiber : "—"}<i>g</i></strong><small>目标 ${review.targets.fiber}g</small></div>
        </div>
        <button class="btn btn-secondary data-review-food-cta" onclick="app.openNutritionDate(todayKey(), 'plan')">${hasNutrition ? "查看今日饮食 ›" : "记录饮食，开始复盘 ›"}</button>
      </div>

      <div class="data-review-insight">
        <div class="tiny accent">本月复盘</div>
        <div class="small" style="margin-top:5px;line-height:1.6">${review.sessions.length
          ? `完成 ${review.sessions.length} 次训练，累计 ${Math.round(review.volume).toLocaleString()} kg。`
          : "本月还没有训练记录。"}${hasNutrition
          ? `饮食有 ${review.loggedDays} 天记录，日均蛋白 ${review.averages.p}g、纤维 ${review.averages.fiber}g；未记录的天不计入均值。`
          : "饮食还没有记录，营养趋势暂时为空。"}</div>
      </div>

      <div class="training-recent-list data-review-recent">
        <div class="calendar-section-label">本月训练记录</div>
        ${review.sessions.length
          ? review.sessions.slice(0, 3).map((session) => sessionListRow(session, "plan")).join("")
          : `<div class="calendar-empty-line">本月还没有训练记录，可以在日历中补录。</div>`}
      </div>
    </section>
  `;
}
