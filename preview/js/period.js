/* FitAI Web Preview page module: menstrual cycle date selection. */

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
  const draft = Array.isArray(state.periodDraft) ? state.periodDraft : (state.periodDates || []);
  const selected = new Set(draft);
  return `
    <div class="stack period-screen">
      ${headerBack("经期安排")}

      <div class="period-summary">
        <div>
          <strong>选择经期日期</strong>
          <span>训练日会自动减量，休息日保持恢复</span>
        </div>
        <span class="period-count">${selected.size} 天</span>
      </div>

      <section class="calendar-card period-calendar">
        <div class="calendar-toolbar">
          <button class="icon-btn" onclick="app.periodMonthMove(-1)" aria-label="上个月">‹</button>
          <div class="calendar-month">
            <div class="h2">${monthLabel(month)}</div>
            <div class="tiny faint">点选经期日期</div>
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
            const active = selected.has(key);
            const isToday = key === todayKey();
            return `
              <button class="calendar-day period-picker-day ${inMonth ? "" : "outside"} ${active ? "period-selected" : ""} ${isToday ? "today" : ""}"
                onclick="app.togglePeriodDate('${key}')"
                aria-pressed="${active}"
                aria-label="${dateLabel(key)}${active ? "，已选经期" : ""}">
                <span class="calendar-day-number">${date.getDate()}</span>
              </button>
            `;
          }).join("")}
        </div>
      </section>

      <div class="period-tip">经期训练会减少 1 组、负重约 80%；腹痛明显时改为散步或休息。</div>
      <button class="btn btn-primary" onclick="app.savePeriodSchedule()">保存经期安排</button>
      <button class="btn btn-ghost" onclick="app.closePeriodSchedule()">取消并返回</button>
    </div>
  `;
}
