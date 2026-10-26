/* FitAI Web Preview actions: select actual training dates for the next four weeks. */

const PLAN_SCHEDULE_OFFSETS = {
  1: [0],
  2: [0, 3],
  3: [0, 2, 4],
  4: [0, 1, 3, 5],
  5: [0, 1, 2, 4, 5],
  6: [0, 1, 2, 3, 4, 5],
  7: [0, 1, 2, 3, 4, 5, 6]
};

function planScheduleDateKeyInBlock(dateKey, startKey, blockIndex) {
  const date = parseDateKey(dateKey);
  const start = parseDateKey(startKey);
  const diff = Math.round((date.getTime() - start.getTime()) / 86400000);
  return Math.floor(diff / 7) === blockIndex;
}

Object.assign(window.app, {
  openPlanSchedule() {
    const days = Array.isArray(state.plan?.days) ? state.plan.days : [];
    if (!days.length) return toast("当前计划没有训练日");
    const weeks = Math.max(1, Number(state.plan?.weeks) || 4);
    const daysPerWeek = Math.max(1, Math.min(7, Math.round(days.length / weeks)));
    const startKey = todayKey();
    const selectedDates = [];
    const existingByBlock = Array.from({ length: weeks }, () => []);
    days.forEach((day) => {
      const dateKey = planDayDateKey(day);
      const block = Math.floor(
        (parseDateKey(dateKey).getTime() - parseDateKey(startKey).getTime()) / 604800000
      );
      if (block >= 0 && block < weeks && !existingByBlock[block].includes(dateKey)) {
        existingByBlock[block].push(dateKey);
      }
    });
    const offsets = PLAN_SCHEDULE_OFFSETS[daysPerWeek] || PLAN_SCHEDULE_OFFSETS[3];
    for (let block = 0; block < weeks; block += 1) {
      const chosen = existingByBlock[block].sort().slice(0, daysPerWeek);
      offsets.forEach((offset) => {
        if (chosen.length >= daysPerWeek) return;
        const dateKey = localDateInputValue(addDays(parseDateKey(startKey), block * 7 + offset));
        if (!chosen.includes(dateKey)) chosen.push(dateKey);
      });
      chosen.sort().forEach((dateKey) => selectedDates.push(dateKey));
    }
    state.planScheduleDraft = {
      startKey,
      daysPerWeek,
      selectedDates
    };
    pushRoute("planSchedule");
    save();
    render();
  },

  planScheduleToggleDate(dateKey) {
    const draft = state.planScheduleDraft;
    if (!draft) return;
    if (!planScheduleDateKeyInBlock(dateKey, draft.startKey, 0)
      && !planScheduleDateKeyInBlock(dateKey, draft.startKey, 1)
      && !planScheduleDateKeyInBlock(dateKey, draft.startKey, 2)
      && !planScheduleDateKeyInBlock(dateKey, draft.startKey, 3)) return;
    const selected = new Set(draft.selectedDates);
    if (selected.has(dateKey)) {
      selected.delete(dateKey);
    } else {
      const block = [0, 1, 2, 3].find((index) => planScheduleDateKeyInBlock(dateKey, draft.startKey, index));
      const count = draft.selectedDates.filter((key) => planScheduleDateKeyInBlock(key, draft.startKey, block)).length;
      if (count >= draft.daysPerWeek) {
        return toast(`这周已选满 ${draft.daysPerWeek} 天，先取消一个日期`);
      }
      selected.add(dateKey);
    }
    draft.selectedDates = [...selected].sort();
    save();
    render();
  },

  savePlanSchedule() {
    const draft = state.planScheduleDraft;
    if (!draft) return;
    const blocks = [0, 1, 2, 3];
    const counts = blocks.map((index) => draft.selectedDates.filter((key) => planScheduleDateKeyInBlock(key, draft.startKey, index)).length);
    if (counts.some((count) => count !== draft.daysPerWeek)) {
      return toast(`每周需要选 ${draft.daysPerWeek} 天`);
    }
    const planWeeks = Math.max(1, Number(state.plan?.weeks) || 4);
    blocks.forEach((blockIndex) => {
      if (blockIndex >= planWeeks) return;
      const weekDays = state.plan.days
        .filter((day) => Number(day.week) === blockIndex + 1)
        .sort((left, right) => Number(left.slot) - Number(right.slot));
      const dates = draft.selectedDates
        .filter((key) => planScheduleDateKeyInBlock(key, draft.startKey, blockIndex))
        .sort();
      weekDays.forEach((day, index) => {
        const dateKey = dates[index];
        if (!dateKey) return;
        const date = parseDateKey(dateKey);
        day.dateKey = dateKey;
        day.weekday = date.getDay() || 7;
      });
    });
    state.plan.days.sort((left, right) => {
      if (left.week !== right.week) return left.week - right.week;
      return Number(left.slot) - Number(right.slot);
    });
    state.plan.version += 1;
    state.plan.updatedAt = Date.now();
    state.planScheduleDraft = null;
    popRoute();
    save();
    render();
    toast("训练日期已更新");
  },

  closePlanSchedule() {
    state.planScheduleDraft = null;
    app.back();
  }
});
