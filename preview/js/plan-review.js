/* FitAI Web Preview module: weekly / monthly / yearly review with previous-period deltas. */

const REVIEW_PERIODS = {
  week: { label: "本周", previousLabel: "上周同期", short: "周" },
  month: { label: "本月", previousLabel: "上月同期", short: "月" },
  year: { label: "今年", previousLabel: "去年同期", short: "年" }
};

function reviewStartOfDay(value) {
  const date = new Date(value);
  date.setHours(0, 0, 0, 0);
  return date;
}

function reviewEndOfDay(value) {
  const date = new Date(value);
  date.setHours(23, 59, 59, 999);
  return date;
}

function reviewDaysInMonth(date) {
  return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
}

function reviewDaysInYear(year) {
  return Math.floor((new Date(year + 1, 0, 1) - new Date(year, 0, 1)) / 86400000);
}

function reviewCompactDate(date) {
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

function reviewPeriodBounds(period = state.reviewPeriod, now = new Date()) {
  const currentEnd = reviewEndOfDay(now);
  let currentStart;
  let previousStart;
  let previousEnd;
  let periodDays;
  let previousDays;

  if (period === "week") {
    currentStart = startOfWeekMonday(now);
    currentStart.setHours(0, 0, 0, 0);
    periodDays = Math.max(1, Math.min(7, Math.floor((currentEnd - currentStart) / 86400000) + 1));
    previousStart = reviewStartOfDay(addDays(currentStart, -7));
    previousDays = periodDays;
    previousEnd = reviewEndOfDay(addDays(previousStart, previousDays - 1));
  } else if (period === "year") {
    currentStart = new Date(now.getFullYear(), 0, 1);
    currentStart.setHours(0, 0, 0, 0);
    periodDays = Math.floor((currentEnd - currentStart) / 86400000) + 1;
    previousStart = new Date(now.getFullYear() - 1, 0, 1);
    previousStart.setHours(0, 0, 0, 0);
    previousDays = Math.min(periodDays, reviewDaysInYear(now.getFullYear() - 1));
    previousEnd = reviewEndOfDay(new Date(
      now.getFullYear() - 1,
      0,
      previousDays
    ));
  } else {
    currentStart = new Date(now.getFullYear(), now.getMonth(), 1);
    currentStart.setHours(0, 0, 0, 0);
    periodDays = now.getDate();
    const previousMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    previousStart = reviewStartOfDay(previousMonth);
    previousDays = Math.min(periodDays, reviewDaysInMonth(previousMonth));
    previousEnd = reviewEndOfDay(new Date(
      previousMonth.getFullYear(),
      previousMonth.getMonth(),
      previousDays
    ));
  }

  const rangeLabel = period === "year"
    ? `${currentStart.getFullYear()}/${reviewCompactDate(currentStart)}–${reviewCompactDate(currentEnd)}`
    : `${reviewCompactDate(currentStart)}–${reviewCompactDate(currentEnd)}`;
  return {
    period,
    currentStart,
    currentEnd,
    previousStart,
    previousEnd,
    periodDays,
    previousDays,
    rangeLabel
  };
}

function reviewSessionsBetween(start, end) {
  return state.sessions
    .filter((session) => {
      const timestamp = Number(session.timestamp);
      return Number.isFinite(timestamp) && timestamp > 0
        && timestamp >= start.getTime()
        && timestamp <= end.getTime();
    })
    .sort((left, right) => Number(right.timestamp || 0) - Number(left.timestamp || 0));
}

function reviewFoodLogsBetween(start, end) {
  const startKey = localDateInputValue(start);
  const endKey = localDateInputValue(end);
  return state.foodLogs.filter((log) => {
    const key = String(log.date || todayKey());
    return key >= startKey && key <= endKey;
  });
}

function reviewLatestBody(end, fallback = false) {
  const metrics = (state.bodyMetrics || [])
    .filter((entry) => Number(entry.timestamp) <= end.getTime())
    .sort((left, right) => Number(right.timestamp) - Number(left.timestamp));
  if (metrics.length) return metrics[0];
  if (!fallback) return null;
  return {
    date: null,
    weight: Number(state.profile.weight) || 0,
    bodyFat: Number(state.profile.bodyFat) || 0
  };
}

function reviewWindowData(start, end, days, fallbackBody = false) {
  const sessions = reviewSessionsBetween(start, end);
  const foodLogs = reviewFoodLogsBetween(start, end);
  const foodDays = new Set(foodLogs.map((log) => log.date || todayKey()));
  const minutes = sessions.reduce((sum, session) => sum + Number(session.duration || 0), 0);
  const volume = sessions.reduce((sum, session) => sum + Number(session.volume || 0), 0);
  const sets = sessions.reduce((sum, session) => sum + (session.items || []).reduce((partial, item) => partial + Number(item.sets || 0), 0), 0);
  const nutrition = foodLogs.reduce((total, log) => {
    total.kcal += Number(log.kcal) || 0;
    total.p += Number(log.p) || 0;
    total.c += Number(log.c) || 0;
    total.f += Number(log.f) || 0;
    total.fiber += Number(log.fiber) || 0;
    return total;
  }, { kcal: 0, p: 0, c: 0, f: 0, fiber: 0 });
  const loggedDays = foodDays.size;
  const average = (value) => loggedDays ? value / loggedDays : null;
  const averageIntake = average(nutrition.kcal);
  const targets = nutritionTargets();
  return {
    sessions,
    trainingDays: new Set(sessions.map(sessionDateKey)).size,
    minutes,
    volume,
    sets,
    averageDailyMinutes: days ? minutes / days : 0,
    averageSessionMinutes: sessions.length ? minutes / sessions.length : 0,
    foodLogs,
    loggedDays,
    periodDays: days,
    targets,
    averageIntake,
    calorieGap: averageIntake == null ? null : targets.kcal - averageIntake,
    averages: {
      kcal: average(nutrition.kcal),
      p: average(nutrition.p),
      c: average(nutrition.c),
      f: average(nutrition.f),
      fiber: average(nutrition.fiber)
    },
    body: reviewLatestBody(end, fallbackBody)
  };
}

function reviewTrend(current, previous, mode = "neutral", digits = 0, unit = "") {
  if (current == null || previous == null || !Number.isFinite(Number(current)) || !Number.isFinite(Number(previous))) {
    return { direction: "flat", tone: "muted", text: "暂无上期数据" };
  }
  const delta = Number(current) - Number(previous);
  const threshold = digits > 0 ? 0.05 : 0.5;
  if (Math.abs(delta) < threshold) {
    return { direction: "flat", tone: "flat", text: "与上期持平" };
  }
  const direction = delta > 0 ? "up" : "down";
  let tone = "neutral";
  if (mode === "higher") tone = direction === "up" ? "good" : "bad";
  if (mode === "lower") tone = direction === "down" ? "good" : "bad";
  if (mode === "goalWeight") {
    const goal = state.profile.goal;
    if (goal === "增肌") tone = direction === "up" ? "good" : "bad";
    else if (goal === "减脂" || goal === "重塑体型") tone = direction === "down" ? "good" : "bad";
    else tone = "neutral";
  }
  const sign = delta > 0 ? "+" : "-";
  const absolute = Math.abs(delta).toFixed(digits);
  return {
    direction,
    tone,
    text: `较上期 ${sign}${absolute}${unit}`
  };
}

function reviewFormatNumber(value, digits = 0) {
  if (value == null || !Number.isFinite(Number(value))) return "—";
  return digits > 0 ? Number(value).toFixed(digits) : Math.round(value).toLocaleString();
}

function reviewDeficitValue(value) {
  if (value == null || !Number.isFinite(Number(value))) return { value: "—", unit: "" };
  return value >= 0
    ? { value: Math.round(value).toLocaleString(), unit: "kcal 缺口" }
    : { value: Math.round(Math.abs(value)).toLocaleString(), unit: "kcal 盈余" };
}

function reviewKpiCard({ label, current, previous, display, previousDisplay, unit, trend, note }) {
  return `
    <article class="review-kpi tone-${trend.tone}">
      <div class="review-kpi-top">
        <span class="review-kpi-label">${label}</span>
        <span class="review-kpi-arrow">${trend.direction === "up" ? "↑" : trend.direction === "down" ? "↓" : "→"}</span>
      </div>
      <div class="review-kpi-value">${display}<i>${unit || ""}</i></div>
      <div class="review-kpi-compare">${trend.text}</div>
      <div class="review-kpi-foot">上期 ${previousDisplay}${note ? ` · ${note}` : ""}</div>
    </article>
  `;
}

function planReviewData() {
  const period = ["week", "month", "year"].includes(state.reviewPeriod) ? state.reviewPeriod : "month";
  const meta = REVIEW_PERIODS[period];
  const bounds = reviewPeriodBounds(period);
  const current = reviewWindowData(bounds.currentStart, bounds.currentEnd, bounds.periodDays, true);
  const previous = reviewWindowData(bounds.previousStart, bounds.previousEnd, bounds.previousDays, false);
  const currentDeficit = reviewDeficitValue(current.calorieGap);
  const previousDeficit = reviewDeficitValue(previous.calorieGap);
  const currentWeight = current.body?.weight ?? null;
  const previousWeight = previous.body?.weight ?? null;
  const currentBodyFat = current.body?.bodyFat ?? null;
  const previousBodyFat = previous.body?.bodyFat ?? null;

  const trends = {
    sessions: reviewTrend(current.sessions.length, previous.sessions.length, "higher", 0, " 次"),
    duration: reviewTrend(current.averageDailyMinutes, previous.averageDailyMinutes, "higher", 1, " 分钟"),
    intake: reviewTrend(current.averageIntake, previous.averageIntake, "neutral", 0, " kcal"),
    deficit: reviewTrend(current.calorieGap, previous.calorieGap, "neutral", 0, " kcal"),
    weight: reviewTrend(currentWeight, previousWeight, "goalWeight", 1, " kg"),
    bodyFat: reviewTrend(currentBodyFat, previousBodyFat, "lower", 1, "%")
  };

  const kpis = [
    {
      label: "训练次数",
      current: current.sessions.length,
      previous: previous.sessions.length,
      display: String(current.sessions.length),
      previousDisplay: `${previous.sessions.length} 次`,
      unit: "次",
      trend: trends.sessions,
      note: `本期 ${current.trainingDays} 个训练日`
    },
    {
      label: "平均每日时长",
      current: current.averageDailyMinutes,
      previous: previous.averageDailyMinutes,
      display: reviewFormatNumber(current.averageDailyMinutes, 1),
      previousDisplay: `${reviewFormatNumber(previous.averageDailyMinutes, 1)} 分钟`,
      unit: "分钟",
      trend: trends.duration,
      note: `${bounds.periodDays} 天周期`
    },
    {
      label: "日均摄入",
      current: current.averageIntake,
      previous: previous.averageIntake,
      display: reviewFormatNumber(current.averageIntake),
      previousDisplay: previous.averageIntake == null ? "—" : `${reviewFormatNumber(previous.averageIntake)} kcal`,
      unit: "kcal",
      trend: trends.intake,
      note: current.loggedDays ? `本期 ${current.loggedDays} 天记录` : "本期暂无记录"
    },
    {
      label: "热量缺口",
      current: current.calorieGap,
      previous: previous.calorieGap,
      display: currentDeficit.value,
      previousDisplay: previousDeficit.value === "—" ? "—" : `${previousDeficit.value} ${previousDeficit.unit}`,
      unit: currentDeficit.unit,
      trend: trends.deficit,
      note: "目标 - 日均"
    },
    {
      label: "体重",
      current: currentWeight,
      previous: previousWeight,
      display: reviewFormatNumber(currentWeight, 1),
      previousDisplay: previousWeight == null ? "—" : `${reviewFormatNumber(previousWeight, 1)} kg`,
      unit: "kg",
      trend: trends.weight,
      note: current.body?.date ? `最近 ${reviewCompactDate(parseDateKey(current.body.date))}` : "暂无测量"
    },
    {
      label: "体脂",
      current: currentBodyFat,
      previous: previousBodyFat,
      display: reviewFormatNumber(currentBodyFat, 1),
      previousDisplay: previousBodyFat == null ? "—" : `${reviewFormatNumber(previousBodyFat, 1)}%`,
      unit: "%",
      trend: trends.bodyFat,
      note: current.body?.date ? `最近 ${reviewCompactDate(parseDateKey(current.body.date))}` : "暂无测量"
    }
  ];

  const good = Object.values(trends).filter((trend) => trend.tone === "good").length;
  const bad = Object.values(trends).filter((trend) => trend.tone === "bad").length;
  const insufficient = Object.values(trends).filter((trend) => trend.tone === "muted").length;
  return {
    period,
    label: meta.label,
    previousLabel: meta.previousLabel,
    rangeLabel: bounds.rangeLabel,
    bounds,
    current,
    previous,
    kpis,
    trends,
    good,
    bad,
    insufficient,
    periodDays: bounds.periodDays
  };
}

function dataReviewPanel() {
  const review = planReviewData();
  const { current, previous } = review;
  const targets = current.targets;
  const hasNutrition = current.loggedDays > 0;
  return `
    <section class="data-review-panel" id="plan-data-review">
      <div class="between data-review-head">
        <div>
          <div class="compose-kicker">数据复盘</div>
          <div class="h2">${review.label}复盘</div>
          <div class="tiny muted">${review.rangeLabel} · 对比${review.previousLabel}</div>
        </div>
        <button class="link" onclick="app.openHistory()">全部训练 ›</button>
      </div>

      <div class="review-period-tabs" role="tablist" aria-label="数据复盘周期">
        ${["week", "month", "year"].map((period) => `
          <button class="${review.period === period ? "active" : ""}" onclick="app.setReviewPeriod('${period}')" role="tab" aria-selected="${review.period === period}">
            ${REVIEW_PERIODS[period].label}
          </button>
        `).join("")}
      </div>

      <div class="review-trend-summary">
        <span class="good">↑ 优于上期 ${review.good}</span>
        <span class="bad">↓ 低于上期 ${review.bad}</span>
        <span class="muted">· 数据不足 ${review.insufficient}</span>
      </div>

      <div class="review-kpi-grid">
        ${review.kpis.map(reviewKpiCard).join("")}
      </div>

      <div class="data-review-block">
        <div class="between data-review-block-head">
          <div class="calendar-section-label">训练明细</div>
          <span class="tiny faint">${current.trainingDays} 个训练日</span>
        </div>
        <div class="training-metric-grid">
          <div class="training-metric"><strong>${Math.round(current.volume).toLocaleString()}</strong><span>总容量 kg</span></div>
          <div class="training-metric"><strong>${current.sets}</strong><span>总组数</span></div>
          <div class="training-metric"><strong>${reviewFormatNumber(current.averageSessionMinutes)}</strong><span>单次分钟</span></div>
          <div class="training-metric"><strong>${current.sessions.length}</strong><span>完成训练</span></div>
        </div>
        <div class="tiny faint" style="margin-top:8px">平均每日时长 = 周期内训练总分钟 ÷ 周期天数；不是只按训练日计算。</div>
      </div>

      <div class="data-review-block">
        <div class="between data-review-block-head">
          <div class="calendar-section-label">饮食营养</div>
          <span class="tiny faint">${hasNutrition ? `有记录日均 · ${current.loggedDays}/${review.periodDays} 天` : `${review.periodDays} 天暂无记录`}</span>
        </div>
        <div class="review-macro-grid">
          <div class="review-macro"><span>热量</span><strong>${hasNutrition ? reviewFormatNumber(current.averages.kcal) : "—"}</strong><small>目标 ${targets.kcal} kcal</small></div>
          <div class="review-macro"><span>蛋白质</span><strong>${hasNutrition ? reviewFormatNumber(current.averages.p) : "—"}<i>g</i></strong><small>目标 ${targets.protein}g</small></div>
          <div class="review-macro"><span>碳水</span><strong>${hasNutrition ? reviewFormatNumber(current.averages.c) : "—"}<i>g</i></strong><small>目标 ${targets.carbs}g</small></div>
          <div class="review-macro"><span>脂肪</span><strong>${hasNutrition ? reviewFormatNumber(current.averages.f) : "—"}<i>g</i></strong><small>目标 ${targets.fat}g</small></div>
          <div class="review-macro"><span>膳食纤维</span><strong>${hasNutrition ? reviewFormatNumber(current.averages.fiber) : "—"}<i>g</i></strong><small>目标 ${targets.fiber}g</small></div>
        </div>
        <button class="btn btn-secondary data-review-food-cta" onclick="app.openNutritionDate(todayKey(), 'plan')">${hasNutrition ? "查看今日饮食 ›" : "记录饮食，开始复盘 ›"}</button>
        <div class="tiny faint" style="margin-top:8px">日均值只按有记录的天计算；未记录的天不当作 0 摄入。</div>
      </div>

      <div class="data-review-insight">
        <div class="tiny accent">本期结论</div>
        <div class="small" style="margin-top:5px;line-height:1.6">${review.good
          ? `${review.good} 项优于上期。`
          : "暂无可判断的提升项。"}${review.bad ? ` ${review.bad} 项低于上期，需要关注。` : ""}${review.insufficient ? ` ${review.insufficient} 项缺少上期数据。` : ""}</div>
        <div class="tiny faint" style="margin-top:4px">训练次数和每日时长越高越优；体重方向按你的当前目标判断；体脂下降视为改善。</div>
      </div>

      <div class="training-recent-list data-review-recent">
        <div class="calendar-section-label">本${REVIEW_PERIODS[review.period].short}训练记录</div>
        ${current.sessions.length
          ? current.sessions.slice(0, 3).map((session) => sessionListRow(session, "plan")).join("")
          : `<div class="calendar-empty-line">这个周期还没有训练记录，可以在日历中补录。</div>`}
      </div>
    </section>
  `;
}
