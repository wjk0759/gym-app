/* FitAI Web Preview component: reusable exercise training analytics (stats + actual-date chart). */

function analyticsSessionTimestamp(session) {
  if (Number.isFinite(Number(session.timestamp)) && Number(session.timestamp) > 0) {
    return Number(session.timestamp);
  }
  const raw = String(session.date || "").trim();
  if (!raw) return Number.NaN;
  if (raw.includes("刚刚")) return Date.now();
  const match = raw.match(/(\d{1,2})月(\d{1,2})日(?:\s*(\d{1,2}):(\d{2}))?/);
  if (!match) return Number.NaN;
  const now = new Date();
  const date = new Date(
    now.getFullYear(),
    Number(match[1]) - 1,
    Number(match[2]),
    Number(match[3] || 12),
    Number(match[4] || 0),
    0,
    0
  );
  if (date.getTime() > now.getTime() + 86400000) {
    date.setFullYear(now.getFullYear() - 1);
  }
  return date.getTime();
}

function analyticsParseDateInput(value, endOfDay = false) {
  const match = String(value || "").match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return null;
  const date = new Date(
    Number(match[1]),
    Number(match[2]) - 1,
    Number(match[3]),
    endOfDay ? 23 : 0,
    endOfDay ? 59 : 0,
    endOfDay ? 59 : 0,
    endOfDay ? 999 : 0
  );
  return Number.isNaN(date.getTime()) ? null : date.getTime();
}

function exerciseAnalyticsPoints(item) {
  const names = new Set([item.name, item.slug ? EX[item.slug]?.name : null].filter(Boolean));
  const points = [];

  state.sessions.forEach((session) => {
    const matching = (session.items || []).filter((entry) => names.has(entry.name));
    if (!matching.length) return;

    const timestamp = analyticsSessionTimestamp(session);
    if (!Number.isFinite(timestamp)) return;

    const volume = matching.reduce((sum, entry) => {
      return sum + (Number(entry.weight) || 0) * (Number(entry.reps) || 0) * (Number(entry.sets) || 0);
    }, 0);
    const sets = matching.reduce((sum, entry) => sum + (Number(entry.sets) || 0), 0);
    const maxWeight = matching.reduce((max, entry) => {
      return Math.max(max, Number(entry.weight) || 0);
    }, 0);
    const estimated1RM = matching.reduce((max, entry) => {
      const weight = Number(entry.weight) || 0;
      const reps = Number(entry.reps) || 0;
      const estimate = weight > 0 && reps > 0 ? weight * (1 + reps / 30) : 0;
      return Math.max(max, estimate);
    }, 0);

    points.push({
      timestamp,
      date: session.date,
      volume,
      sets,
      maxWeight,
      estimated1RM
    });
  });

  return points.sort((a, b) => a.timestamp - b.timestamp);
}

function exerciseAnalyticsWindow() {
  const period = state.equipmentStatsPeriod || "90";
  const now = Date.now();

  if (period === "all") {
    return { start: null, end: null, label: "全部" };
  }

  if (period === "custom") {
    const start = analyticsParseDateInput(state.equipmentStatsCustomStart, false);
    const end = analyticsParseDateInput(state.equipmentStatsCustomEnd, true);
    return {
      start,
      end,
      label: "自定义",
      invalid: start == null || end == null || start > end
    };
  }

  const days = Number(period) || 90;
  return {
    start: now - days * 86400000,
    end: now + 1,
    label: `${days} 天`
  };
}

function exerciseAnalyticsStats(item) {
  const all = exerciseAnalyticsPoints(item);
  const window = exerciseAnalyticsWindow();
  const points = window.invalid
    ? []
    : all.filter((point) => {
        if (window.start != null && point.timestamp < window.start) return false;
        if (window.end != null && point.timestamp > window.end) return false;
        return true;
      });

  return {
    all,
    points,
    window,
    sessions: points.length,
    sets: points.reduce((sum, point) => sum + point.sets, 0),
    volume: points.reduce((sum, point) => sum + point.volume, 0),
    maxWeight: points.reduce((max, point) => Math.max(max, point.maxWeight), 0),
    best1RM: points.reduce((max, point) => Math.max(max, point.estimated1RM), 0),
    last: points[points.length - 1]?.date || null
  };
}

function exerciseAnalyticsMetricMeta(metric) {
  return {
    volume: { label: "容量", unit: "kg" },
    sets: { label: "组数", unit: "组" },
    maxWeight: { label: "最大重量", unit: "kg" },
    oneRepMax: { label: "1RM 预测", unit: "kg" }
  }[metric] || { label: "容量", unit: "kg" };
}

function exerciseAnalyticsMetricValue(point, metric) {
  if (metric === "sets") return point.sets;
  if (metric === "maxWeight") return point.maxWeight;
  if (metric === "oneRepMax") return point.estimated1RM;
  return point.volume;
}

function exerciseAnalyticsFormatWeight(value) {
  const number = Number(value) || 0;
  if (number === 0) return "—";
  return Number.isInteger(number) ? number.toLocaleString() : number.toFixed(1);
}

function exerciseAnalyticsFormatAxis(value, metric) {
  const number = Number(value) || 0;
  if (number >= 1000) return `${(number / 1000).toFixed(number >= 10000 ? 0 : 1)}k`;
  return String(Math.round(number));
}

function exerciseAnalyticsDate(timestamp, includeYear = false) {
  const date = new Date(timestamp);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return includeYear
    ? `${date.getFullYear()}/${month}/${day}`
    : `${month}/${day}`;
}

function exerciseAnalyticsChart(stats, itemName = "这个动作") {
  if (!stats.points.length) {
    return `
      <div class="detail-chart-empty">
        <span class="detail-chart-empty-icon">${ICONS.chart}</span>
        <strong>这个周期还没有训练记录</strong>
        <span>换一个周期，或完成一次 ${esc(itemName)} 训练。</span>
      </div>
    `;
  }

  const metric = state.equipmentStatsMetric || "volume";
  const meta = exerciseAnalyticsMetricMeta(metric);
  const width = 320;
  const height = 190;
  const padding = { top: 18, right: 12, bottom: 30, left: 37 };
  const plotWidth = width - padding.left - padding.right;
  const plotHeight = height - padding.top - padding.bottom;

  let domainStart = stats.window.start;
  let domainEnd = stats.window.end;
  if (domainStart == null) domainStart = stats.points[0].timestamp;
  if (domainEnd == null) domainEnd = stats.points[stats.points.length - 1].timestamp;
  if (domainEnd <= domainStart) {
    domainStart -= 86400000;
    domainEnd += 86400000;
  }

  const values = stats.points.map((point) => exerciseAnalyticsMetricValue(point, metric));
  const maxValue = Math.max(0, ...values);
  const yMax = maxValue > 0 ? maxValue * 1.12 : 1;

  const xFor = (timestamp) => {
    return padding.left + Math.max(0, Math.min(1, (timestamp - domainStart) / (domainEnd - domainStart))) * plotWidth;
  };
  const yFor = (value) => {
    return padding.top + plotHeight - Math.max(0, Math.min(1, value / yMax)) * plotHeight;
  };

  const points = stats.points.map((point, index) => {
    const value = exerciseAnalyticsMetricValue(point, metric);
    return {
      ...point,
      index,
      value,
      x: xFor(point.timestamp),
      y: yFor(value)
    };
  });

  const linePath = points.map((point, index) => `${index === 0 ? "M" : "L"} ${point.x.toFixed(1)} ${point.y.toFixed(1)}`).join(" ");
  const first = points[0];
  const last = points[points.length - 1];
  const areaPath = `M ${first.x.toFixed(1)} ${(padding.top + plotHeight).toFixed(1)} ${linePath.replace(/^M /, "L ")} L ${last.x.toFixed(1)} ${(padding.top + plotHeight).toFixed(1)} Z`;

  const gridMarkup = [0, 0.5, 1].map((ratio) => {
    const y = padding.top + plotHeight - ratio * plotHeight;
    return `
      <line class="detail-line-grid" x1="${padding.left}" y1="${y.toFixed(1)}" x2="${width - padding.right}" y2="${y.toFixed(1)}" />
      <text class="detail-line-y-label" x="${padding.left - 7}" y="${(y + 3).toFixed(1)}" text-anchor="end">${exerciseAnalyticsFormatAxis(yMax * ratio, metric)}</text>
    `;
  }).join("");

  const spanDays = (domainEnd - domainStart) / 86400000;
  const includeYear = spanDays > 300;
  const labelPoints = [points[0], points[points.length - 1]];
  if (points.length >= 5) {
    const middle = points[Math.floor((points.length - 1) / 2)];
    if (middle.x - points[0].x > 62 && points[points.length - 1].x - middle.x > 62) {
      labelPoints.splice(1, 0, middle);
    }
  }
  const xLabels = labelPoints.map((point, index) => {
    const anchor = index === 0
      ? "start"
      : index === labelPoints.length - 1
        ? "end"
        : "middle";
    return `<text class="detail-line-x-label" x="${point.x.toFixed(1)}" y="${height - 8}" text-anchor="${anchor}">${exerciseAnalyticsDate(point.timestamp, includeYear)}</text>`;
  }).join("");

  const dots = points.map((point) => `
    <g class="detail-line-point-group">
      <circle class="detail-line-point-halo" cx="${point.x.toFixed(1)}" cy="${point.y.toFixed(1)}" r="7" />
      <circle class="detail-line-point" cx="${point.x.toFixed(1)}" cy="${point.y.toFixed(1)}" r="3.2">
        <title>${esc(point.date)} · ${meta.label} ${exerciseAnalyticsFormatWeight(point.value)} ${meta.unit}</title>
      </circle>
    </g>
  `).join("");

  return `
    <div class="detail-line-chart-wrap">
      <svg class="detail-line-chart" viewBox="0 0 ${width} ${height}" role="img" aria-label="${meta.label}趋势折线图">
        <defs>
          <linearGradient id="detailLineGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#30d158" stop-opacity="0.34" />
            <stop offset="100%" stop-color="#30d158" stop-opacity="0" />
          </linearGradient>
        </defs>
        ${gridMarkup}
        ${xLabels}
        <path class="detail-line-area" d="${areaPath}" fill="url(#detailLineGradient)" />
        <path class="detail-line-stroke" d="${linePath}" />
        ${dots}
      </svg>
      <div class="detail-line-chart-last">
        <strong>${exerciseAnalyticsFormatWeight(last.value)}</strong>
        <span>${meta.unit}</span>
      </div>
    </div>
    <div class="detail-line-chart-caption">
      <span>${meta.label}趋势</span>
      <span>${stats.points.length} 次记录 · 每个点代表一次训练</span>
    </div>
  `;
}


function exerciseAnalyticsItem(slug) {
  const exercise = EX[slug];
  if (!exercise) return null;
  return {
    id: `preview-${slug}`,
    name: exercise.name,
    slug,
    muscle: exercise.muscle,
    equip: exercise.equip,
    video: false,
    notes: ""
  };
}

function exerciseAnalyticsPanel(item, options = {}) {
  const stats = exerciseAnalyticsStats(item);
  const period = state.equipmentStatsPeriod || "90";
  const metric = state.equipmentStatsMetric || "volume";
  const metricMeta = exerciseAnalyticsMetricMeta(metric);
  const todayValue = localDateInputValue(new Date());
  const periodOptions = [
    { key: "7", label: "7天" },
    { key: "30", label: "30天" },
    { key: "90", label: "90天" },
    { key: "all", label: "全部" },
    { key: "custom", label: "自定义" }
  ];
  const metricOptions = [
    { key: "volume", label: "容量" },
    { key: "sets", label: "组数" },
    { key: "maxWeight", label: "最大重量" },
    { key: "oneRepMax", label: "1RM 预测" }
  ];
  const showHeader = options.showHeader !== false;
  const lead = stats.window.invalid
    ? "开始日期不能晚于结束日期。"
    : stats.sessions
      ? `${stats.window.label} · ${stats.sessions} 次训练 / ${stats.sets} 组${stats.last ? `，最近一次 ${stats.last}` : ""}。`
      : "所选周期还没有这个动作的训练记录。";

  return `
    <section class="exercise-analytics-panel">
      ${showHeader ? `
        <div class="exercise-analytics-heading">
          <div>
            <div class="compose-kicker">当前动作</div>
            <h2>${esc(item.name)}</h2>
            <p>${lead}</p>
          </div>
          <span class="exercise-analytics-icon">${ICONS.chart}</span>
        </div>
      ` : ""}
      <div class="detail-stat-grid detail-stat-records">
        <div>
          <span>容量记录</span>
          <strong>${stats.sessions ? stats.volume.toLocaleString() : "—"}</strong>
          <small>kg · 累计</small>
        </div>
        <div>
          <span>重量记录</span>
          <strong>${stats.sessions ? (stats.maxWeight > 0 ? exerciseAnalyticsFormatWeight(stats.maxWeight) : "自重") : "—"}</strong>
          <small>kg · 单组最重</small>
        </div>
        <div>
          <span>1RM 预测</span>
          <strong>${stats.sessions && stats.best1RM > 0 ? exerciseAnalyticsFormatWeight(stats.best1RM) : "—"}</strong>
          <small>kg · Epley</small>
        </div>
      </div>

      <div class="detail-chart-heading">
        <div>
          <span>记录趋势</span>
          <strong>${metricMeta.label}</strong>
        </div>
        <span class="detail-chart-current">${stats.points.length ? exerciseAnalyticsFormatWeight(exerciseAnalyticsMetricValue(stats.points[stats.points.length - 1], metric)) : "—"} ${metricMeta.unit}</span>
      </div>

      <div class="detail-period-label">统计周期</div>
      <div class="detail-period-tabs">
        ${periodOptions.map((option) => `
          <button class="${period === option.key ? "active" : ""}" onclick="app.trainingDataPeriod('${option.key}')">${option.label}</button>
        `).join("")}
      </div>
      ${period === "custom" ? `
        <div class="detail-custom-range">
          <label>开始<input type="date" value="${state.equipmentStatsCustomStart}" max="${todayValue}" onchange="app.trainingDataCustomStart(this.value)"></label>
          <span>—</span>
          <label>结束<input type="date" value="${state.equipmentStatsCustomEnd}" max="${todayValue}" onchange="app.trainingDataCustomEnd(this.value)"></label>
        </div>
        ${stats.window.invalid ? `<div class="detail-period-error">开始日期不能晚于结束日期。</div>` : ""}
      ` : ""}
      <div class="detail-metric-tabs">
        ${metricOptions.map((option) => `
          <button class="${metric === option.key ? "active" : ""}" onclick="app.trainingDataMetric('${option.key}')">${option.label}</button>
        `).join("")}
      </div>
      ${exerciseAnalyticsChart(stats, item.name)}
      <div class="detail-chart-note">每个点代表一次有该动作的训练记录。1RM 为 Epley 公式估算，仅用于趋势对比，不等于实测极限。</div>
    </section>
  `;
}


