/* FitAI Web Preview actions: weekly training day schedule. */

Object.assign(window.app, {
  openPlanSchedule() {
    const days = Array.isArray(state.plan?.days) ? state.plan.days : [];
    if (!days.length) return toast("当前计划没有训练日");
    const firstWeek = Math.min(...days.map((day) => Number(day.week) || 1));
    const weekDays = days
      .filter((day) => Number(day.week) === firstWeek)
      .sort((left, right) => left.weekday - right.weekday);
    state.planScheduleDraft = weekDays.map((day, index) => ({
      slot: Number.isFinite(Number(day.slot)) ? Number(day.slot) : index,
      title: day.title || "训练日",
      focus: Array.isArray(day.focus) ? [...day.focus] : [],
      weekday: Number(day.weekday) || 1,
      originalWeekday: Number(day.weekday) || 1
    }));
    pushRoute("planSchedule");
    save();
    render();
  },

  planScheduleSelect(index, weekday) {
    const draft = state.planScheduleDraft;
    const entry = draft?.[index];
    const target = Number(weekday);
    if (!entry || target < 1 || target > 7 || entry.weekday === target) return;
    const occupant = draft.find((item, itemIndex) => itemIndex !== index && item.weekday === target);
    if (occupant) occupant.weekday = entry.weekday;
    entry.weekday = target;
    save();
    render();
  },

  savePlanSchedule() {
    const draft = state.planScheduleDraft;
    if (!Array.isArray(draft) || !draft.length) return;
    const changed = draft.some((entry) => entry.weekday !== entry.originalWeekday);
    state.plan.days.forEach((day) => {
      const entry = draft.find((item) => Number(item.slot) === Number(day.slot));
      if (entry) day.weekday = entry.weekday;
    });
    state.plan.days.sort((left, right) => {
      if (left.week !== right.week) return left.week - right.week;
      return left.weekday - right.weekday;
    });
    if (changed) {
      state.plan.version += 1;
      state.plan.updatedAt = Date.now();
    }
    state.planScheduleDraft = null;
    popRoute();
    save();
    render();
    toast(changed ? "训练日已更新" : "训练安排未改变");
  },

  closePlanSchedule() {
    state.planScheduleDraft = null;
    app.back();
  }
});
