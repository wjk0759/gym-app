/* FitAI Web Preview page module: compact four-week training date picker. */

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
      <div class="plan-schedule-screen">
        ${headerBack("训练日期")}
        <div class="calendar-empty-line">当前计划没有可调整的训练日期。</div>
      </div>
    `;
  }

  const blocks = planScheduleBlocks(draft);
  const selected = new Set(draft.selectedDates);
  const counts = blocks.map((block) => block.dates.filter((date) => selected.has(date.key)).length);
  const selectedCount = counts.reduce((sum, count) => sum + count, 0);
  const targetCount = draft.daysPerWeek * blocks.length;
  const complete = counts.every((count) => count === draft.daysPerWeek);
  const remaining = counts.reduce((sum, count) => sum + Math.max(0, draft.daysPerWeek - count), 0);

  return `
    <div class="plan-schedule-screen">
      ${headerBack("训练日期")}

      <div class="schedule-overview">
        <div>
          <strong>未来 4 周</strong>
          <span>每周 ${draft.daysPerWeek} 练 · ${state.plan.split || state.profile.split}</span>
        </div>
        <span class="schedule-overview-count ${complete ? "done" : ""}">${selectedCount}/${targetCount}</span>
      </div>

      <section class="schedule-board" aria-label="选择未来四周训练日期">
        <div class="schedule-board-head">
          <span>周</span>
          <span class="schedule-head-days">${PLAN_WEEKDAY_LABELS.map((label) => `<i>${label}</i>`).join("")}</span>
        </div>
        ${blocks.map((block, index) => {
          const count = counts[index];
          return `
            <div class="schedule-board-row">
              <div class="schedule-week-label">
                <strong>第${index + 1}周</strong>
                <small>${reviewCompactDate(block.start)}–${reviewCompactDate(block.end)}</small>
                <span class="${count === draft.daysPerWeek ? "done" : ""}">${count}/${draft.daysPerWeek}</span>
              </div>
              <div class="schedule-days">
                ${block.dates.map((date) => {
                  const active = selected.has(date.key);
                  const isToday = date.key === todayKey();
                  return `
                    <button class="schedule-day ${active ? "active" : ""} ${isToday ? "today" : ""}"
                      onclick="app.planScheduleToggleDate('${date.key}')"
                      aria-pressed="${active}"
                      aria-label="${date.key} 周${PLAN_WEEKDAY_LABELS[date.weekday - 1]}">
                      ${date.date.getDate()}
                    </button>
                  `;
                }).join("")}
              </div>
            </div>
          `;
        }).join("")}
      </section>

      <div class="schedule-save-status ${complete ? "done" : ""}">
        ${complete ? `已选满 ${targetCount} 个训练日` : `还差 ${remaining} 个训练日`}
      </div>
      <button class="btn btn-primary" onclick="app.savePlanSchedule()" ${complete ? "" : "disabled"}>保存训练日期</button>
      <button class="link schedule-cancel" onclick="app.closePlanSchedule()">取消并返回</button>
    </div>
  `;
}
