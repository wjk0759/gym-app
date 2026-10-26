/* FitAI Web Preview page module: equipment-detail */

function equipmentDetailExercise(item) {
  return item.slug ? EX[item.slug] : null;
}

function equipmentDetailPoints(item) {
  const exercise = equipmentDetailExercise(item);
  const fromLibrary = exercise?.cues || "";
  const points = fromLibrary
    .split(/[。；;]/)
    .map((point) => point.trim())
    .filter(Boolean);

  const general = [
    "先调整座位、靠垫或把手高度，确认起始位置稳定，再开始发力。",
    "全程保持核心收紧、呼吸自然；最后几次也不要靠惯性甩动。",
    "如果出现关节刺痛、麻木或明显代偿，降低重量或停止动作。"
  ];

  general.forEach((point) => {
    if (points.length < 3 && !points.includes(point)) points.push(point);
  });

  return points.slice(0, 5);
}

function equipmentDetailSupport(item) {
  const map = {
    "胸": ["肩", "手臂"],
    "背": ["手臂", "核心"],
    "腿": ["臀", "核心"],
    "臀": ["腿", "核心"],
    "肩": ["手臂", "核心"],
    "手臂": ["肩", "核心"],
    "核心": ["背", "臀"],
    "有氧": ["腿", "核心"]
  };
  return map[item.muscle] || ["核心", "稳定"];
}

function equipmentSessionTimestamp(session) {
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

function equipmentParseDateInput(value, endOfDay = false) {
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

function equipmentDetailAllPoints(item) {
  const names = new Set([item.name, item.slug ? EX[item.slug]?.name : null].filter(Boolean));
  const points = [];

  state.sessions.forEach((session) => {
    const matching = (session.items || []).filter((entry) => names.has(entry.name));
    if (!matching.length) return;

    const timestamp = equipmentSessionTimestamp(session);
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

function equipmentDetailPeriodWindow() {
  const period = state.equipmentStatsPeriod || "90";
  const now = Date.now();

  if (period === "all") {
    return { start: null, end: null, label: "全部" };
  }

  if (period === "custom") {
    const start = equipmentParseDateInput(state.equipmentStatsCustomStart, false);
    const end = equipmentParseDateInput(state.equipmentStatsCustomEnd, true);
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

function equipmentDetailStats(item) {
  const all = equipmentDetailAllPoints(item);
  const window = equipmentDetailPeriodWindow();
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

function equipmentDetailMetricMeta(metric) {
  return {
    volume: { label: "容量", unit: "kg" },
    sets: { label: "组数", unit: "组" },
    maxWeight: { label: "最大重量", unit: "kg" },
    oneRepMax: { label: "1RM 预测", unit: "kg" }
  }[metric] || { label: "容量", unit: "kg" };
}

function equipmentDetailMetricValue(point, metric) {
  if (metric === "sets") return point.sets;
  if (metric === "maxWeight") return point.maxWeight;
  if (metric === "oneRepMax") return point.estimated1RM;
  return point.volume;
}

function equipmentFormatWeight(value) {
  const number = Number(value) || 0;
  if (number === 0) return "—";
  return Number.isInteger(number) ? number.toLocaleString() : number.toFixed(1);
}

function equipmentFormatAxis(value, metric) {
  const number = Number(value) || 0;
  if (number >= 1000) return `${(number / 1000).toFixed(number >= 10000 ? 0 : 1)}k`;
  return String(Math.round(number));
}

function equipmentChartDate(timestamp, includeYear = false) {
  const date = new Date(timestamp);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return includeYear
    ? `${date.getFullYear()}/${month}/${day}`
    : `${month}/${day}`;
}

function equipmentDetailLineChart(stats) {
  if (!stats.points.length) {
    return `
      <div class="detail-chart-empty">
        <span class="detail-chart-empty-icon">${ICONS.chart}</span>
        <strong>这个周期还没有训练记录</strong>
        <span>换一个周期，或完成一次 ${esc(state.equipmentLibrary.find((entry) => entry.id === state.equipmentItemId)?.name || "这个动作")} 训练。</span>
      </div>
    `;
  }

  const metric = state.equipmentStatsMetric || "volume";
  const meta = equipmentDetailMetricMeta(metric);
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

  const values = stats.points.map((point) => equipmentDetailMetricValue(point, metric));
  const maxValue = Math.max(0, ...values);
  const yMax = maxValue > 0 ? maxValue * 1.12 : 1;

  const xFor = (timestamp) => {
    return padding.left + Math.max(0, Math.min(1, (timestamp - domainStart) / (domainEnd - domainStart))) * plotWidth;
  };
  const yFor = (value) => {
    return padding.top + plotHeight - Math.max(0, Math.min(1, value / yMax)) * plotHeight;
  };

  const points = stats.points.map((point, index) => {
    const value = equipmentDetailMetricValue(point, metric);
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
      <text class="detail-line-y-label" x="${padding.left - 7}" y="${(y + 3).toFixed(1)}" text-anchor="end">${equipmentFormatAxis(yMax * ratio, metric)}</text>
    `;
  }).join("");

  const spanDays = (domainEnd - domainStart) / 86400000;
  const includeYear = spanDays > 300;
  const labelPoints = points.length <= 3
    ? points
    : [points[0], points[Math.floor((points.length - 1) / 2)], points[points.length - 1]];
  const xLabels = labelPoints.map((point, index) => {
    const anchor = index === 0
      ? "start"
      : index === labelPoints.length - 1
        ? "end"
        : "middle";
    return `<text class="detail-line-x-label" x="${point.x.toFixed(1)}" y="${height - 8}" text-anchor="${anchor}">${equipmentChartDate(point.timestamp, includeYear)}</text>`;
  }).join("");

  const dots = points.map((point) => `
    <g class="detail-line-point-group">
      <circle class="detail-line-point-halo" cx="${point.x.toFixed(1)}" cy="${point.y.toFixed(1)}" r="7" />
      <circle class="detail-line-point" cx="${point.x.toFixed(1)}" cy="${point.y.toFixed(1)}" r="3.2">
        <title>${esc(point.date)} · ${meta.label} ${equipmentFormatWeight(point.value)} ${meta.unit}</title>
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
        <strong>${equipmentFormatWeight(last.value)}</strong>
        <span>${meta.unit}</span>
      </div>
    </div>
    <div class="detail-line-chart-caption">
      <span>${meta.label}趋势</span>
      <span>${stats.points.length} 次记录 · 每个点代表一次训练</span>
    </div>
  `;
}

function equipmentDetailMuscleMap(item) {
  const muscle = item.muscle || "全身";
  const support = equipmentDetailSupport(item);
  const key = {
    "胸": "chest",
    "背": "back",
    "腿": "legs",
    "臀": "glutes",
    "肩": "shoulders",
    "手臂": "arms",
    "核心": "core",
    "有氧": "cardio"
  }[muscle] || "cardio";

  return `
    <div class="detail-muscle-title">人体肌肉的部位训练概况</div>
    <div class="detail-muscle-figure">
      <img
        class="detail-muscle-anatomy"
        src="assets/muscles/${key}@2x.png"
        alt="人体正面与背面肌肉示意图，重点训练 ${esc(muscle)}，辅助 ${esc(support.join("、"))}"
        loading="lazy"
      >
    </div>
    <div class="detail-muscle-caption">
      <span>重点 <strong>${esc(muscle)}</strong> · 辅助 ${esc(support.join(" · "))}</span>
      <span class="detail-muscle-credit">OpenStax / Nefronus · CC BY-SA 4.0</span>
    </div>
  `;
}

function equipmentDetailSection(index, title, lead, body, id = "") {
  return `
    <section class="detail-section" ${id ? `id="${id}"` : ""}>
      <div class="detail-section-index">${index}</div>
      <h2>${title}</h2>
      <p class="detail-section-lead">${lead}</p>
      ${body}
    </section>
  `;
}

function exerciseEquipmentItem(slug) {
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

function equipmentItemScreen() {
  const libraryItem = state.equipmentLibrary.find((entry) => entry.id === state.equipmentItemId);
  const previewItem = !libraryItem && state.selectedExercise
    ? exerciseEquipmentItem(state.selectedExercise)
    : null;
  const item = libraryItem || previewItem;
  if (!item) return equipmentLibraryScreen();
  const isPreview = !!previewItem;

  const exercise = equipmentDetailExercise(item);
  const points = equipmentDetailPoints(item);
  const support = equipmentDetailSupport(item);
  const stats = equipmentDetailStats(item);
  const pinned = !isPreview && (state.pinnedEquipIds || []).includes(item.id);
  const muscle = item.muscle || "全身";
  const description = exercise?.cues
    || item.notes
    || "先用稳定、可控的轨迹完成动作，再逐步增加重量和训练量。";
  const period = state.equipmentStatsPeriod || "90";
  const metric = state.equipmentStatsMetric || "volume";
  const metricMeta = equipmentDetailMetricMeta(metric);
  const todayValue = localDateInputValue(new Date());
  const periodLabel = stats.window.label;

  const pointsMarkup = points.map((point, index) => `
    <div class="detail-point">
      <span class="detail-point-index">${index + 1}</span>
      <p>${esc(point)}</p>
    </div>
  `).join("");

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

  const periodControls = `
    <div class="detail-period-label">统计周期</div>
    <div class="detail-period-tabs">
      ${periodOptions.map((option) => `
        <button class="${period === option.key ? "active" : ""}" onclick="app.equipmentDetailPeriod('${option.key}')">${option.label}</button>
      `).join("")}
    </div>
    ${period === "custom" ? `
      <div class="detail-custom-range">
        <label>开始<input type="date" value="${state.equipmentStatsCustomStart}" max="${todayValue}" onchange="app.equipmentDetailCustomStart(this.value)"></label>
        <span>—</span>
        <label>结束<input type="date" value="${state.equipmentStatsCustomEnd}" max="${todayValue}" onchange="app.equipmentDetailCustomEnd(this.value)"></label>
      </div>
      ${stats.window.invalid ? `<div class="detail-period-error">开始日期不能晚于结束日期。</div>` : ""}
    ` : ""}
  `;

  const metricControls = `
    <div class="detail-metric-tabs">
      ${metricOptions.map((option) => `
        <button class="${metric === option.key ? "active" : ""}" onclick="app.equipmentDetailMetric('${option.key}')">${option.label}</button>
      `).join("")}
    </div>
  `;

  const chartMarkup = equipmentDetailLineChart(stats);

  const summaryMarkup = `
    <div class="detail-stat-grid detail-stat-records">
      <div>
        <span>容量记录</span>
        <strong>${stats.sessions ? stats.volume.toLocaleString() : "—"}</strong>
        <small>kg · 累计</small>
      </div>
      <div>
        <span>重量记录</span>
        <strong>${stats.sessions ? (stats.maxWeight > 0 ? equipmentFormatWeight(stats.maxWeight) : "自重") : "—"}</strong>
        <small>kg · 单组最重</small>
      </div>
      <div>
        <span>1RM 预测</span>
        <strong>${stats.sessions && stats.best1RM > 0 ? equipmentFormatWeight(stats.best1RM) : "—"}</strong>
        <small>kg · Epley</small>
      </div>
    </div>
  `;

  return `
    <div class="stack equipment-detail-screen">
      ${headerBack(
        isPreview ? "动作详情" : "器械详情",
        isPreview ? "app.backTo('equipment')" : "app.equipmentLibraryOpen()"
      )}

      <div class="detail-quick-card">
        <div class="detail-quick-title">
          <span class="detail-quick-glyph">${equipGlyph(item)}</span>
          <span>${esc(item.name)}</span>
        </div>
        <div class="detail-quick-actions">
          <button onclick="app.equipmentDetailScroll('detail-points')" aria-label="动作要点">
            ${ICONS.checklist}<span>要点</span>
          </button>
          <button onclick="app.equipmentDetailScroll('detail-stats')" aria-label="训练历史">
            ${ICONS.clock}<span>历史</span>
          </button>
          <button onclick="app.equipmentDetailScroll('detail-stats')" aria-label="训练图表">
            ${ICONS.chart}<span>图表</span>
          </button>
          ${isPreview ? "" : `
            <button id="detail-pin" class="${pinned ? "active" : ""}" onclick="app.equipmentDetailPin('${item.id}')" aria-label="${pinned ? "取消置顶" : "置顶器械"}">
              ${ICONS.pin}<span>置顶</span>
            </button>
          `}
        </div>
      </div>

      <div class="detail-hero">
        <div class="detail-eyebrow">动作学习预览</div>
        <h1 class="detail-title">${esc(item.name)}</h1>
        <p class="detail-description">${esc(description)}</p>
        <div class="detail-tags">
          <span>${muscle}</span>
          <span>${item.equip}</span>
          ${item.video ? "<span class=\"ready\">教学视频</span>" : "<span>视频准备中</span>"}
        </div>
      </div>

      ${equipmentDetailSection(
        "01",
        "视频讲解",
        "先看动作讲解，再看后面要点，会更容易抓住发力顺序。",
        `<div class="detail-video-card ${item.video ? "ready" : ""}">
          <div class="detail-video-glyph">${equipGlyph(item)}</div>
          <div class="detail-video-play">▶</div>
          <div class="detail-video-copy">
            <strong>${item.video ? "点一下播放动作讲解" : "教学视频准备中"}</strong>
            <span>${item.video ? "先看讲解，再开始今天的训练。" : (isPreview ? "这个动作的官方示范视频还在准备中。" : "这件器械的官方示范视频还在准备中。")}</span>
          </div>
          <span class="detail-video-badge">${item.video ? "官方教学视频" : "视频待上线"}</span>
        </div>`
      )}

      ${equipmentDetailSection(
        "02",
        "动作轨迹",
        "先用轨迹示意建立动作路径，再在训练中把速度放慢。",
        `<div class="detail-motion-board">
          <span class="detail-motion-line line-one"></span>
          <span class="detail-motion-line line-two"></span>
          <span class="detail-motion-line line-three"></span>
          <div class="detail-motion-glyph">${equipGlyph(item)}</div>
          <div class="detail-motion-copy">
            <strong>保持轨迹稳定</strong>
            <span>起始位置、发力方向和还原速度，比盲目加重量更重要。</span>
          </div>
          <span class="detail-motion-expand">↗</span>
        </div>`
      )}

      ${equipmentDetailSection(
        "03",
        "多角度示范",
        "示范素材准备中。先用要点确认起始位置和身体角度。",
        `<div class="detail-angle-grid">
          ${["正面", "侧面", "发力", "细节"].map((label, index) => `
            <div class="detail-angle ${index > 1 ? "locked" : ""}">
              <div class="detail-angle-art">${index > 1 ? "◌" : equipGlyph(item)}</div>
              <span>${label}</span>
            </div>
          `).join("")}
        </div>
        <div class="detail-mini-note">示范素材准备中；先用下面的动作要点确认起始位置和发力顺序。</div>`
      )}

      ${equipmentDetailSection(
        "04",
        "动作要点",
        "下面的要点来自动作库和你的器械备注。",
        `<div class="detail-point-list">${pointsMarkup}</div>
         <div class="detail-tip">${item.notes ? `器械备注：${esc(item.notes)}` : "先用轻重量确认动作路线，再逐步接近目标负荷。"}</div>`,
        "detail-points"
      )}

      ${equipmentDetailSection(
        "05",
        "训练肌群",
        `主要训练 ${muscle}，协同稳定由 ${support.join("、")} 参与。`,
        `${equipmentDetailMuscleMap(item)}`
      )}

      ${equipmentDetailSection(
        "06",
        "训练数据",
        stats.window.invalid
          ? "开始日期不能晚于结束日期。"
          : stats.sessions
            ? `${periodLabel} · ${stats.sessions} 次训练 / ${stats.sets} 组${stats.last ? `，最近一次 ${stats.last}` : ""}。`
            : "所选周期还没有这个动作的训练记录。",
        `${summaryMarkup}
        <div class="detail-chart-heading">
          <div>
            <span>记录趋势</span>
            <strong>${metricMeta.label}</strong>
          </div>
          <span class="detail-chart-current">${stats.points.length ? equipmentFormatWeight(equipmentDetailMetricValue(stats.points[stats.points.length - 1], metric)) : "—"} ${metricMeta.unit}</span>
        </div>
        ${periodControls}
        ${metricControls}
        ${chartMarkup}
        <div class="detail-chart-note">每个点代表一次有该动作的训练记录。1RM 为 Epley 公式估算，仅用于趋势对比，不等于实测极限。</div>`,
        "detail-stats"
      )}

      <div class="detail-coach-card">
        <div class="detail-coach-avatar">AI</div>
        <div class="grow">
          <div class="detail-coach-title">动作细节还不确定？</div>
          <div class="detail-coach-copy">让教练结合你的计划，解释起始位置、发力顺序和替代动作。</div>
        </div>
        <button class="detail-coach-action" onclick="${item.slug ? `app.askCoach('${item.slug}')` : "app.tab('coach')"}">问教练</button>
      </div>

      ${isPreview ? "" : `<button class="detail-delete" onclick="app.deleteEquipItem('${item.id}')">从器械库删除</button>`}
      <div class="detail-disclaimer">出现关节刺痛、麻木或肿胀时请停止动作并咨询专业人士。教学视频和示范素材由官方动作库提供。</div>
    </div>
  `;
}

const BODY_VARIANTS = [
  {
    summary: "整体比例比较均衡，建议把训练重点放在背部与臀部，配合核心稳定，减少只练胸和手臂的倾向。",
    focus: ["背", "臀", "核心"],
    recommendations: [
      "每周增加 1 次背部训练，优先高位下拉、坐姿划船",
      "臀部训练加入臀推或臀桥，每周 2 次",
      "核心稳定加入平板支撑，每次训练收尾 2 组"
    ],
    confidence: 0.82
  },
  {
    summary: "下肢与核心可以承担更多训练量，建议采用上下肢分化，先把深蹲和髋伸动作做扎实。",
    focus: ["腿", "臀", "核心"],
    recommendations: [
      "保留深蹲或腿举作为下肢主项",
      "加入罗马尼亚硬拉，强化后链",
      "每周至少 2 次核心稳定训练"
    ],
    confidence: 0.76
  },
  {
    summary: "上肢推拉比例可以更平衡，建议增加划船类动作，同时控制卧推总量，避免肩部过度疲劳。",
    focus: ["背", "肩", "核心"],
    recommendations: [
      "推拉比例调整为 1:1.5",
      "加入面拉，改善肩胛稳定",
      "推日最后减少 1 组卧推，改为划船"
    ],
    confidence: 0.71
  }
];

