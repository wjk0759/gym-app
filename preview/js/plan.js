/* ---------------- Plan ---------------- */

function calendarCells(month) {
  const [year, monthNumber] = month.split("-").map(Number);
  const first = new Date(year, monthNumber - 1, 1);
  const start = startOfWeekMonday(first);
  return Array.from({ length: 42 }, (_, index) => addDays(start, index));
}

function calendarOverview(month) {
  const cells = calendarCells(month);
  return `
    <section class="calendar-card">
      <div class="calendar-toolbar">
        <button class="icon-btn" onclick="app.changeCalendarMonth(-1)" aria-label="上个月">‹</button>
        <div class="calendar-month">
          <div class="h2">${monthLabel(month)}</div>
          <div class="tiny faint">训练 · 饮食 · 计划</div>
        </div>
        <button class="icon-btn" onclick="app.changeCalendarMonth(1)" aria-label="下个月">›</button>
      </div>

      <div class="calendar-weekdays">
        ${["一", "二", "三", "四", "五", "六", "日"].map((label) => `<span>${label}</span>`).join("")}
      </div>

      <div class="calendar-grid">
        ${cells.map((date) => {
          const key = localDateInputValue(date);
          const inMonth = monthKey(date) === month;
          const sessions = sessionsForDateKey(key);
          const planDay = planDayForDateKey(key);
          const foodLogs = foodLogsForDateKey(key);
          const selected = state.calendarDateKey === key;
          const isToday = key === todayKey();
          return `
            <button class="calendar-day ${inMonth ? "" : "outside"} ${selected ? "selected" : ""} ${isToday ? "today" : ""}" onclick="app.openCalendarDate('${key}')" aria-label="${dateLabel(key)}${sessions.length ? `，${sessions.length} 次训练` : ""}${planDay ? "，有训练计划" : ""}${foodLogs.length ? "，有饮食记录" : ""}">
              <span class="calendar-day-number">${date.getDate()}</span>
              <span class="calendar-day-dots" aria-hidden="true">
                ${sessions.length ? `<i class="calendar-dot workout"></i>` : ""}
                ${planDay ? `<i class="calendar-dot plan"></i>` : ""}
                ${foodLogs.length ? `<i class="calendar-dot food"></i>` : ""}
              </span>
            </button>
          `;
        }).join("")}
      </div>

      <div class="calendar-legend">
        <span><i class="calendar-dot workout"></i>完成训练</span>
        <span><i class="calendar-dot plan"></i>训练计划</span>
        <span><i class="calendar-dot food"></i>饮食记录</span>
      </div>
    </section>
  `;
}

function calendarDayPanel(key) {
  const day = planDayForDateKey(key);
  const sessions = sessionsForDateKey(key);
  const logs = foodLogsForDateKey(key);
  const foodTotals = nutritionTotals(key);

  return `
    <section class="calendar-day-panel">
      <div class="between">
        <div>
          <div class="calendar-day-title">${dateLabel(key)}</div>
          <div class="tiny faint">${sessions.length ? `完成 ${sessions.length} 次训练` : day ? "计划训练日" : "休息日"}</div>
        </div>
        <button class="link" onclick="app.openNutritionDate('${key}')">饮食 ›</button>
      </div>

      <div class="calendar-day-section">
        <div class="calendar-section-label">训练</div>
        ${sessions.length ? sessions.map((session) => `
          <button class="calendar-session-row" onclick="app.openSession('${session.id}', 'plan')">
            <span class="calendar-session-check">✓</span>
            <span class="grow">
              <strong>${esc(String(session.title || "").slice(0, 40))}</strong>
              <small>${session.items?.length || 0} 个动作 · ${session.duration} 分钟 · ${session.volume.toLocaleString()} kg</small>
            </span>
            <span class="faint">›</span>
          </button>
        `).join("") : ""}

        ${day ? `
          <div class="calendar-plan-row">
            <div class="grow">
              <div class="tiny accent">计划 · 第 ${day.week} 周</div>
              <div class="small strong">${esc(day.title)}</div>
              <div class="tiny faint">${day.focus.join(" · ")} · ${day.exercises.length} 个动作</div>
            </div>
            <div class="calendar-plan-actions">
              <button class="link" onclick="app.editPlanDay('${day.id}')">编辑内容 ›</button>
            </div>
          </div>
          <div class="calendar-exercise-dots">
            ${day.exercises.slice(0, 4).map((item) => `<span>${esc(EX[item.slug]?.name || item.slug)}</span>`).join("")}
            ${day.exercises.length > 4 ? `<span>+${day.exercises.length - 4}</span>` : ""}
          </div>
        ` : ""}

        ${!sessions.length && !day ? `<div class="calendar-empty-line">这天没有训练安排，可以休息，也可以补录一次训练。</div>` : ""}

        ${key <= todayKey() ? `
          <button class="btn btn-secondary calendar-record-training" onclick="app.openCalendarTraining()">
            ＋ ${sessions.length ? "补记一次训练" : "记录这天的训练"}
          </button>
        ` : `<div class="calendar-empty-line">未来日期：可先编辑计划，训练当天再记录。</div>`}
      </div>

      <div class="calendar-day-section">
        <div class="between">
          <div class="calendar-section-label">饮食</div>
          <div class="tiny faint">${foodTotals.kcal} kcal · 蛋白 ${Math.round(foodTotals.p)}g</div>
        </div>
        ${logs.length ? logs.slice(0, 3).map((log) => `
          <div class="calendar-food-row">
            <span class="grow">${esc(log.name)} <small>${log.meal} · ${log.grams}g</small></span>
            <span class="tiny muted">${log.kcal} kcal</span>
          </div>
        `).join("") : `<div class="calendar-empty-line">还没有饮食记录。</div>`}
        <button class="btn btn-secondary calendar-add-food" onclick="app.openNutritionDate('${key}')">${logs.length ? "查看 / 修改饮食" : "记录这天的饮食"}</button>
      </div>
    </section>
  `;
}

function planScreen() {
  const month = state.calendarMonth || monthKey(new Date());
  const selected = state.calendarDateKey || todayKey();
  const preview = planAdjustmentPreview();
  const review = planReviewData();
  const planWeeklyDays = Math.max(1, Math.round(state.plan.days.length / Math.max(1, state.plan.weeks || 4)));

  return `
    <div class="stack plan-calendar-screen">
      <div class="plan-calendar-head">
        <div>
          <div class="compose-kicker">训练与饮食</div>
          <div class="h1">日历</div>
        </div>
        <div class="plan-calendar-head-actions">
          <button class="plan-head-action accent" onclick="app.openPlanSchedule()">训练日期 <span aria-hidden="true">›</span></button>
          <button class="plan-head-action" onclick="app.goTodayInCalendar()">回到今天</button>
        </div>
      </div>

      <button class="plan-data-strip" onclick="app.openPlanReview()">
        <span class="plan-data-strip-icon" aria-hidden="true">▥</span>
        <span class="grow">
          <strong>数据复盘 · ${review.label}</strong>
          <small>${review.current.sessions.length} 次训练 · ${review.current.loggedDays} 天饮食记录</small>
        </span>
        <span class="plan-data-strip-link">查看报告 ›</span>
      </button>

      ${calendarOverview(month)}
      ${calendarDayPanel(selected)}

      <section class="plan-summary-card">
        <div class="between plan-summary-head">
          <div>
            <div class="tiny accent">当前计划</div>
            <div class="h3" style="margin-top:3px">${esc(state.plan.title)}</div>
            <div class="tiny faint" style="margin-top:3px">第 ${state.plan.version} 版 · ${state.plan.days.length} 个训练日 · 本周完成 ${preview.completed}/${planWeeklyDays}</div>
          </div>
          <div class="plan-summary-head-actions">
            <button class="link" onclick="app.openPlanSchedule()">调整训练日期</button>
            <button class="link" onclick="app.regeneratePlan()">重新生成</button>
          </div>
        </div>
        <div class="tiny muted" style="margin-top:8px;line-height:1.6">调整计划前，教练会先问清最近训练中的时间、恢复、疼痛或负荷问题，再按你的诉求生成方案。</div>
        <button class="btn btn-secondary" style="margin-top:10px" onclick="app.startPlanAdjustment('plan')">✦ 和教练聊聊，再调整计划</button>
      </section>
    </div>
  `;
}

