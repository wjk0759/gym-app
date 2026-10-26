/* FitAI preview actions: plan */
Object.assign(window.app, {
  changeCalendarMonth(delta) {
    const current = parseDateKey(`${state.calendarMonth}-01`);
    const next = new Date(current.getFullYear(), current.getMonth() + delta, 1);
    state.calendarMonth = monthKey(next);
    if ((state.calendarDateKey || "").slice(0, 7) !== state.calendarMonth) {
      state.calendarDateKey = localDateInputValue(next);
    }
    save();
    render();
  },

  openCalendarDate(key) {
    state.calendarDateKey = key;
    state.calendarMonth = key.slice(0, 7);
    save();
    render();
  },

  editPlanDay(id) {
    const day = state.plan.days.find((item) => item.id === id);
    if (!day) return;
    state.workoutDraft = {
      source: "planEdit",
      planDayId: id,
      title: day.title,
      createdAt: Date.now(),
      exercises: day.exercises.map((item, index) => ({
        ...item,
        id: item.id || `plan-edit-${Date.now()}-${index}`,
        sets: Number(item.sets) || 3,
        reps: String(parseReps(item.reps)),
        weight: Math.max(0, Number(item.weight) || 0),
        rest: Math.max(0, Number(item.rest) || 0),
        rpe: Number(item.rpe) || 7.5
      }))
    };
    state.equipSearchQuery = "";
    state.equipMuscle = "全部";
    state.equipFilter = "全部";
    pushRoute("workoutCompose");
    save();
    render();
  },

  savePlanDayDraft() {
    const draft = state.workoutDraft;
    if (!draft || draft.source !== "planEdit") return;
    const day = state.plan.days.find((item) => item.id === draft.planDayId);
    if (!day) return;
    const exercises = draft.exercises
      .map((item, index) => {
        const info = EX[item.slug];
        if (!info) return null;
        return {
          id: item.id || `plan-ex-${Date.now()}-${index}`,
          slug: item.slug,
          sets: Math.max(1, Math.min(10, Number(item.sets) || 3)),
          reps: String(Math.max(1, Math.min(30, parseReps(item.reps)))),
          weight: Math.max(0, Number(item.weight) || 0),
          rest: Math.max(0, Math.min(300, Number(item.rest) || 0)),
          rpe: Number(item.rpe) || 7.5
        };
      })
      .filter(Boolean);
    if (!exercises.length) return toast("至少保留一个动作");
    day.exercises = exercises;
    day.focus = [...new Set(exercises.map((item) => EX[item.slug].muscle))];
    state.workoutDraft = null;
    popRoute();
    save();
    render();
    toast("训练日已更新");
  },

  goTodayInCalendar() {
    const key = todayKey();
    state.calendarDateKey = key;
    state.calendarMonth = key.slice(0, 7);
    save();
    render();
  },

  openPlanReview() {
    pushRoute("planReview");
    save();
    render();
  },

  setReviewPeriod(period) {
    if (!["week", "month", "year"].includes(period)) return;
    state.reviewPeriod = period;
    save();
    render();
  },

  openPlanExercisePicker() {
    if (!state.workoutDraft || state.workoutDraft.source !== "planEdit") return;
    state.equipSearchQuery = "";
    state.equipMuscle = "全部";
    state.equipFilter = "全部";
    state.equipSelectionOpen = false;
    pushRoute("planExercisePicker");
    save();
    render();
  },

  closePlanExercisePicker() {
    state.equipSearchQuery = "";
    state.equipMuscle = "全部";
    state.equipFilter = "全部";
    app.back();
  },

  addPlanExercise(slug) {
    const draft = state.workoutDraft;
    const info = EX[slug];
    if (!draft || draft.source !== "planEdit" || !info) return;
    if (draft.exercises.some((item) => item.slug === slug)) {
      toast("这个动作已经在训练日里");
      popRoute();
      save();
      render();
      return;
    }
    draft.exercises.push({
      id: `plan-edit-${Date.now()}`,
      slug,
      sets: 3,
      reps: String(parseReps(info.fixedReps || "10")),
      weight: Number(info.base) || 0,
      rest: 60,
      rpe: 7.5
    });
    state.disliked = state.disliked.filter((item) => item !== slug);
    popRoute();
    save();
    render();
    toast("已添加动作");
  },

  regeneratePlan() {
    state.plan = applyEquipmentLibrary(buildPlan(state.profile));
    state.plan.version += 1;
    save();
    render();
    toast("已重新生成计划");
  },

  openPeriodSchedule() {
    if (state.profile.sex !== "女") return toast("经期安排仅适用于女性用户");
    state.periodDraftStart = state.periodRangeStart || null;
    state.periodDraftEnd = state.periodRangeEnd || state.periodRangeStart || null;
    state.periodDraftMode = state.periodTrainingMode || "light";
    state.periodMonth = state.periodDraftStart
      ? state.periodDraftStart.slice(0, 7)
      : monthKey(new Date());
    pushRoute("periodSchedule");
    save();
    render();
  },

  periodMonthMove(delta) {
    const current = parseDateKey(`${state.periodMonth || monthKey(new Date())}-01`);
    const next = new Date(current.getFullYear(), current.getMonth() + Number(delta || 0), 1);
    state.periodMonth = monthKey(next);
    save();
    render();
  },

  selectPeriodRangeDate(dateKey) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateKey || "")) return;
    if (!state.periodDraftStart || (state.periodDraftStart && state.periodDraftEnd)) {
      state.periodDraftStart = dateKey;
      state.periodDraftEnd = null;
    } else if (dateKey < state.periodDraftStart) {
      state.periodDraftEnd = state.periodDraftStart;
      state.periodDraftStart = dateKey;
    } else {
      state.periodDraftEnd = dateKey;
    }
    save();
    render();
  },

  setPeriodTrainingMode(mode) {
    if (!["light", "rest"].includes(mode)) return;
    state.periodDraftMode = mode;
    save();
    render();
  },

  clearPeriodDraft() {
    state.periodDraftStart = null;
    state.periodDraftEnd = null;
    render();
  },

  savePeriodSchedule() {
    const start = state.periodDraftStart;
    if (!start) return toast("请选择经期开始日期");
    const end = state.periodDraftEnd || start;
    const rangeStart = start <= end ? start : end;
    const rangeEnd = start <= end ? end : start;
    const dates = [];
    let cursor = parseDateKey(rangeStart);
    const last = parseDateKey(rangeEnd);
    let guard = 0;
    while (cursor <= last && guard < 90) {
      dates.push(localDateInputValue(cursor));
      cursor = addDays(cursor, 1);
      guard += 1;
    }
    if (guard >= 90) return toast("经期区间过长，请重新选择");
    state.periodDates = dates;
    state.periodRangeStart = rangeStart;
    state.periodRangeEnd = rangeEnd;
    state.periodTrainingMode = state.periodDraftMode === "rest" ? "rest" : "light";
    state.periodDraftStart = null;
    state.periodDraftEnd = null;
    state.periodDraftMode = null;
    popRoute();
    save();
    render();
    toast("经期区间已保存");
  },

  closePeriodSchedule() {
    state.periodDraftStart = null;
    state.periodDraftEnd = null;
    state.periodDraftMode = null;
    app.back();
  },

  adjustPlan() {
    this.startPlanAdjustment("plan");
  },
});
