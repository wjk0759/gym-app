/* FitAI Web Preview module: scheduled body measurement check-in. */

const BODY_CHECKIN_WEEKDAYS = ["一", "二", "三", "四", "五", "六", "日"];

function bodyCheckInWeekdayNumber(date = new Date()) {
  return date.getDay() || 7;
}

function bodyCheckInLatestMetric() {
  return (state.bodyMetrics || [])
    .slice()
    .sort((left, right) => Number(right.timestamp) - Number(left.timestamp))[0] || null;
}

function bodyCheckInDue(today = new Date()) {
  if (state.bodyCheckInFrequency === "off") return false;
  const key = localDateInputValue(today);
  if (state.bodyCheckInDismissedDate === key) return false;
  if ((state.bodyMetrics || []).some((entry) => entry.date === key)) return false;

  if (state.bodyCheckInFrequency === "monthly") {
    return today.getDate() === Number(state.bodyCheckInDay);
  }

  if (bodyCheckInWeekdayNumber(today) !== Number(state.bodyCheckInWeekday)) return false;
  if (state.bodyCheckInFrequency !== "biweekly") return true;

  const anchor = parseDateKey(state.bodyCheckInAnchor || key);
  const weeks = Math.floor(
    (startOfWeekMonday(today).getTime() - startOfWeekMonday(anchor).getTime()) / 604800000
  );
  return Math.abs(weeks) % 2 === 0;
}

function bodyCheckInNextWeekdayKey(weekday, from = new Date()) {
  const date = new Date(from);
  date.setHours(0, 0, 0, 0);
  const delta = (Number(weekday) - bodyCheckInWeekdayNumber(date) + 7) % 7;
  date.setDate(date.getDate() + delta);
  return localDateInputValue(date);
}

function bodyCheckInFrequencyLabel() {
  if (state.bodyCheckInFrequency === "weekly") return `每周${BODY_CHECKIN_WEEKDAYS[state.bodyCheckInWeekday - 1]}`;
  if (state.bodyCheckInFrequency === "biweekly") return `每两周 · 周${BODY_CHECKIN_WEEKDAYS[state.bodyCheckInWeekday - 1]}`;
  if (state.bodyCheckInFrequency === "monthly") return `每月 ${state.bodyCheckInDay} 日`;
  return "已关闭";
}

function bodyCheckInSheet(manual = false) {
  const latest = bodyCheckInLatestMetric();
  const weight = latest?.weight || state.profile.weight || "";
  const bodyFat = latest?.bodyFat || state.profile.bodyFat || "";
  const waist = latest?.waist || state.profile.waist || "";
  return `
    <div class="body-checkin-backdrop" onclick="app.hideBodyCheckIn()">
      <section class="body-checkin-sheet no-drag" role="dialog" aria-modal="true" aria-label="更新身体数据" onclick="event.stopPropagation()">
        <div class="between">
          <div>
            <div class="compose-kicker">${manual ? "今日打卡" : `身体数据 · ${bodyCheckInFrequencyLabel()}`}</div>
            <div class="h2">更新一下身体数据</div>
          </div>
          <button class="icon-btn" onclick="app.hideBodyCheckIn()" aria-label="隐藏本次提醒">×</button>
        </div>
        <p class="body-checkin-copy">建议早上空腹、同一时间测量。数据用于体重、体脂和围度趋势，不会自动改变训练计划。</p>
        <div class="body-checkin-fields">
          <label>
            <span>体重</span>
            <div><input id="body-checkin-weight" type="number" min="30" max="300" step="0.1" inputmode="decimal" value="${weight}"><i>kg</i></div>
          </label>
          <label>
            <span>体脂率</span>
            <div><input id="body-checkin-fat" type="number" min="3" max="60" step="0.1" inputmode="decimal" value="${bodyFat}"><i>%</i></div>
          </label>
          <label class="body-checkin-wide">
            <span>腰围</span>
            <div><input id="body-checkin-waist" type="number" min="50" max="150" step="0.1" inputmode="decimal" value="${waist}"><i>cm</i></div>
          </label>
        </div>
        ${latest?.date ? `<div class="tiny faint" style="margin-top:9px">上次记录：${dateLabel(latest.date)}</div>` : ""}
        <button class="btn btn-primary" style="margin-top:12px" onclick="app.saveBodyCheckIn()">保存身体数据</button>
        <div class="body-checkin-actions">
          <button class="body-checkin-action" onclick="app.hideBodyCheckIn()">今天隐藏</button>
          <button class="body-checkin-action warning" onclick="app.disableBodyCheckIn()">关闭自动提醒</button>
        </div>
      </section>
    </div>
  `;
}
