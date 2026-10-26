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

  adjustPlan() {
    this.startPlanAdjustment("plan");
  },
});
