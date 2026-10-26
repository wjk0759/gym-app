/* FitAI Web Preview page module: weekly plan schedule editor. */

const PLAN_WEEKDAY_LABELS = ["一", "二", "三", "四", "五", "六", "日"];

function planScheduleScreen() {
  const draft = state.planScheduleDraft;
  if (!draft) {
    return `
      <div class="stack">
        ${headerBack("调整训练日")}
        <div class="calendar-empty-line">当前计划没有可调整的训练日。</div>
      </div>
    `;
  }
  const changed = draft.filter((entry) => entry.weekday !== entry.originalWeekday).length;
  return `
    <div class="stack plan-schedule-screen">
      ${headerBack("调整训练日")}

      <section class="plan-schedule-intro">
        <div class="compose-kicker">计划 · 每周安排</div>
        <div class="h1">调整训练日</div>
        <p>训练内容不变，只调整每周练哪几天。点新的星期几会移动；如果目标日已有训练，会交换两个训练日。</p>
      </section>

      ${draft.map((entry, index) => {
        const current = PLAN_WEEKDAY_LABELS[entry.weekday - 1] || "一";
        return `
          <section class="plan-schedule-card">
            <div class="between">
              <div>
                <div class="compose-kicker">训练日 ${String(index + 1).padStart(2, "0")}</div>
                <div class="h2">${esc(entry.title || "训练日")}</div>
                <div class="tiny muted plan-schedule-focus">${entry.focus.length ? entry.focus.join(" · ") : "训练内容"}</div>
              </div>
              <span class="plan-schedule-current">周${current}</span>
            </div>
            <div class="weekday-picker">
              ${PLAN_WEEKDAY_LABELS.map((label, dayIndex) => {
                const weekday = dayIndex + 1;
                const occupant = draft.find((item, itemIndex) => itemIndex !== index && item.weekday === weekday);
                const active = entry.weekday === weekday;
                return `
                  <button class="weekday-choice ${active ? "active" : ""} ${occupant ? "occupied" : ""}"
                    onclick="app.planScheduleSelect(${index}, ${weekday})"
                    aria-pressed="${active}"
                    aria-label="周${label}${occupant ? `，已有${esc(occupant.title || "训练")}，点击交换` : ""}">
                    <span>周${label}</span>
                    ${occupant ? `<small>${esc(occupant.title || "训练").replace("全身 ", "")}</small>` : "<small></small>"}
                  </button>
                `;
              }).join("")}
            </div>
          </section>
        `;
      }).join("")}

      <div class="plan-schedule-note">
        <strong>${changed ? `已调整 ${changed} 个训练日` : "当前安排未改变"}</strong>
        <span>会同步重排 ${Number(state.plan?.weeks) || 4} 周计划；历史训练记录和已记录饮食不会被修改。</span>
      </div>

      <button class="btn btn-primary" onclick="app.savePlanSchedule()">保存训练日</button>
      <button class="btn btn-ghost" onclick="app.closePlanSchedule()">取消并返回</button>
    </div>
  `;
}
