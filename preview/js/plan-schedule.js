/* FitAI Web Preview page module: select actual training dates for the next four weeks. */

const PLAN_WEEKDAY_LABELS = ["一", "二", "三", "四", "五", "六", "日"];

function planScheduleBlocks(draft) {
  const start = parseDateKey(draft.startKey || todayKey());
  return Array.from({ length: 4 }, (_, index) => {
    const blockStart = addDays(start, index * 7);
    const dates = Array.from({ length: 7 }, (_, offset) => {
      const date = addDays(blockStart, offset);
      return {
        key: localDateInputValue(date),
        date,
        weekday: date.getDay() || 7
      };
    });
    return {
      index,
      start: blockStart,
      end: addDays(blockStart, 6),
      dates
    };
  });
}

function planScheduleScreen() {
  const draft = state.planScheduleDraft;
  if (!draft) {
    return `
      <div class="stack">
        ${headerBack("调整训练日期")}
        <div class="calendar-empty-line">当前计划没有可调整的训练日期。</div>
      </div>
    `;
  }
  const blocks = planScheduleBlocks(draft);
  const selected = new Set(draft.selectedDates);
  const counts = blocks.map((block) => block.dates.filter((date) => selected.has(date.key)).length);
  const complete = counts.every((count) => count === draft.daysPerWeek);
  const remaining = counts.reduce((sum, count) => sum + Math.max(0, draft.daysPerWeek - count), 0);
  return `
    <div class="stack plan-schedule-screen">
      ${headerBack("调整训练日期")}

      <section class="plan-schedule-intro">
        <div class="compose-kicker">未来 4 周 · 每周 ${draft.daysPerWeek} 练 · ${state.plan.split || state.profile.split}</div>
        <div class="h1">选训练日期</div>
        <p>从今天起选择未来 4 周的具体训练日期。每周需要选 ${draft.daysPerWeek} 天，训练内容会按日期顺序自动排入。</p>
      </section>

      ${blocks.map((block, index) => {
        const count = counts[index];
        return `
          <section class="schedule-week-card">
            <div class="between schedule-week-head">
              <div>
                <div class="compose-kicker">第 ${index + 1} 周</div>
                <div class="small strong">${reviewCompactDate(block.start)}–${reviewCompactDate(block.end)}</div>
              </div>
              <span class="${count === draft.daysPerWeek ? "schedule-count done" : "schedule-count"}">${count}/${draft.daysPerWeek} 天</span>
            </div>
            <div class="schedule-date-grid">
              ${block.dates.map((date) => {
                const active = selected.has(date.key);
                const today = date.key === todayKey();
                return `
                  <button class="schedule-date ${active ? "active" : ""} ${today ? "today" : ""}"
                    onclick="app.planScheduleToggleDate('${date.key}')"
                    aria-pressed="${active}"
                    aria-label="${date.key} 周${PLAN_WEEKDAY_LABELS[date.weekday - 1]}">
                    <span>${PLAN_WEEKDAY_LABELS[date.weekday - 1]}</span>
                    <strong>${date.date.getDate()}</strong>
                  </button>
                `;
              }).join("")}
            </div>
          </section>
        `;
      }).join("")}

      <div class="plan-schedule-note">
        <strong>${complete ? `已选满 ${draft.daysPerWeek * 4} 个训练日` : `还差 ${remaining} 个训练日`}</strong>
        <span>只调整训练日期，不改变动作、组数、次数和负重；历史训练记录不会修改。每周次数和分化在「我的 → 编辑资料」修改，重新生成后应用。</span>
      </div>

      <button class="btn btn-primary" onclick="app.savePlanSchedule()" ${complete ? "" : "disabled"}>保存训练日期</button>
      <button class="btn btn-ghost" onclick="app.closePlanSchedule()">取消并返回</button>
    </div>
  `;
}
