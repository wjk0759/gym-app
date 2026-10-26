/* FitAI Web Preview actions: body measurement check-in and reminder settings. */

Object.assign(window.app, {
  openBodyCheckIn() {
    state.goalEditorOpen = false;
    state.bodyCheckInOpen = true;
    render();
  },

  saveBodyCheckIn() {
    const weightInput = document.getElementById("body-checkin-weight");
    const fatInput = document.getElementById("body-checkin-fat");
    const armInput = document.getElementById("body-checkin-arm");
    const thighInput = document.getElementById("body-checkin-thigh");
    const weight = Number(String(weightInput?.value || "").replace(",", "."));
    const bodyFat = Number(String(fatInput?.value || "").replace(",", "."));
    const arm = Number(String(armInput?.value || "").replace(",", "."));
    const thigh = Number(String(thighInput?.value || "").replace(",", "."));
    if (!Number.isFinite(weight) || weight < 30 || weight > 300) {
      return toast("体重填写 30–300 kg");
    }
    if (!Number.isFinite(bodyFat) || bodyFat < 3 || bodyFat > 60) {
      return toast("体脂填写 3–60%");
    }
    if (!Number.isFinite(arm) || arm < 20 || arm > 60) {
      return toast("臂围填写 20–60 cm");
    }
    if (!Number.isFinite(thigh) || thigh < 35 || thigh > 90) {
      return toast("大腿围填写 35–90 cm");
    }
    const date = todayKey();
    const metric = {
      id: `bm-${date}`,
      date,
      timestamp: Date.now(),
      weight: Math.round(weight * 10) / 10,
      bodyFat: Math.round(bodyFat * 10) / 10,
      arm: Math.round(arm * 10) / 10,
      thigh: Math.round(thigh * 10) / 10
    };
    state.profile.weight = metric.weight;
    state.profile.bodyFat = metric.bodyFat;
    state.profile.arm = metric.arm;
    state.profile.thigh = metric.thigh;
    state.bodyMetrics = [metric, ...(state.bodyMetrics || []).filter((entry) => entry.date !== date)]
      .sort((left, right) => Number(right.timestamp) - Number(left.timestamp));
    state.bodyCheckInDismissedDate = date;
    state.bodyCheckInOpen = false;
    save();
    render();
    toast("身体数据已更新");
  },

  hideBodyCheckIn() {
    state.bodyCheckInDismissedDate = todayKey();
    state.bodyCheckInOpen = false;
    save();
    render();
  },

  disableBodyCheckIn() {
    state.bodyCheckInFrequency = "off";
    state.bodyCheckInDismissedDate = todayKey();
    state.bodyCheckInOpen = false;
    save();
    render();
    toast("已关闭身体数据提醒");
  },

  setBodyCheckInFrequency(frequency) {
    if (!["off", "weekly", "biweekly", "monthly"].includes(frequency)) return;
    state.bodyCheckInFrequency = frequency;
    state.bodyCheckInAnchor = bodyCheckInNextWeekdayKey(state.bodyCheckInWeekday);
    state.bodyCheckInDismissedDate = null;
    save();
    render();
  },

  setBodyCheckInWeekday(day) {
    const weekday = Number(day);
    if (!Number.isInteger(weekday) || weekday < 1 || weekday > 7) return;
    state.bodyCheckInWeekday = weekday;
    state.bodyCheckInAnchor = bodyCheckInNextWeekdayKey(weekday);
    state.bodyCheckInDismissedDate = null;
    save();
    render();
  },

  setBodyCheckInDay(value) {
    const day = Number(value);
    if (!Number.isInteger(day) || day < 1 || day > 28) return;
    state.bodyCheckInDay = day;
    state.bodyCheckInDismissedDate = null;
    save();
    render();
  }
});
