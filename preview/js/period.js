/* FitAI Web Preview page module: menstrual cycle range selection. */

function periodScreen() {
  if (state.profile.sex !== "女") {
    return `
      <div class="stack">
        ${headerBack("经期安排")}
        <div class="calendar-empty-line">经期安排仅适用于女性用户。</div>
      </div>
    `;
  }
  const month = state.periodMonth || monthKey(new Date());
  const cells = calendarCells(month);
  const start = state.periodDraftStart;
  const end = state.periodDraftEnd;
  const rangeStart = start && end ? (start <= end ? start : end) : start;
  const rangeEnd = start && end ? (start <= end ? end : start) : start;
  const rangeDays = start ? Math.round((parseDateKey(rangeEnd).getTime() - parseDateKey(rangeStart).getTime()) / 86400000) + 1 : 0;
  const mode = ["light", "rest"].includes(state.periodDraftMode) ? state.periodDraftMode : "light";
  const rangeLabel = start
    ? `${reviewCompactDate(parseDateKey(rangeStart))}–${reviewCompactDate(parseDateKey(rangeEnd))}`
    : "未选择";
  return `
    <div class="stack period-screen">
      ${headerBack("经期安排")}

      <div class="period-summary">
        <div>
          <strong>选择经期区间</strong>
          <span>先点开始日期，再点结束日期</span>
        </div>
        <span class="period-count">${start ? `${rangeDays} 天` : "未选择"}</span>
      </div>
      <div class="period-range-line">
        <span>${start ? `${rangeLabel}${end ? "" : " · 再点结束日期"}` : "点选开始日期"}</span>
        ${start ? `<button class="link" onclick="app.clearPeriodDraft()">重新选择</button>` : ""}
      </div>

      <div class="period-mode-block">
        <div class="form-label">经期训练安排</div>
        <div class="period-mode-grid">
          <button class="period-mode-option ${mode === "light" ? "active" : ""}" onclick="app.setPeriodTrainingMode('light')">
            <strong>轻重量训练</strong>
            <span>自动少 1 组，负重约 80%</span>
          </button>
          <button class="period-mode-option ${mode === "rest" ? "active" : ""}" onclick="app.setPeriodTrainingMode('rest')">
            <strong>直接休息</strong>
            <span>经期不安排力量训练</span>
          </button>
        </div>
      </div>

      <section class="calendar-card period-calendar">
        <div class="calendar-toolbar">
          <button class="icon-btn" onclick="app.periodMonthMove(-1)" aria-label="上个月">‹</button>
          <div class="calendar-month">
            <div class="h2">${monthLabel(month)}</div>
            <div class="tiny faint">点选经期区间</div>
          </div>
          <button class="icon-btn" onclick="app.periodMonthMove(1)" aria-label="下个月">›</button>
        </div>

        <div class="calendar-weekdays">
          ${["一", "二", "三", "四", "五", "六", "日"].map((label) => `<span>${label}</span>`).join("")}
        </div>

        <div class="calendar-grid">
          ${cells.map((date) => {
            const key = localDateInputValue(date);
            const inMonth = monthKey(date) === month;
            const inRange = !!start && key >= rangeStart && key <= rangeEnd;
            const isBoundary = key === rangeStart || key === rangeEnd;
            const isToday = key === todayKey();
            return `
              <button class="calendar-day period-picker-day ${inMonth ? "" : "outside"} ${inRange ? "period-selected" : ""} ${isBoundary ? "period-boundary" : ""} ${isToday ? "today" : ""}"
                onclick="app.selectPeriodRangeDate('${key}')"
                aria-pressed="${inRange}"
                aria-label="${dateLabel(key)}${inRange ? "，已选经期" : ""}">
                <span class="calendar-day-number">${date.getDate()}</span>
              </button>
            `;
          }).join("")}
        </div>
      </section>

      <div class="period-tip">${mode === "rest" ? "已选区间会按休息日处理；训练计划保留，但不会要求打卡。" : "已选区间训练会自动少 1 组、负重约 80%；腹痛明显时改为散步或休息。"}</div>
      <button class="btn btn-primary" onclick="app.savePeriodSchedule()" ${start ? "" : "disabled"}>保存经期区间</button>
      <button class="btn btn-ghost" onclick="app.closePeriodSchedule()">取消并返回</button>
    </div>
  `;
}
