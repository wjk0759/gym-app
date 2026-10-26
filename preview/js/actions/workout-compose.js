/* FitAI Web Preview actions: workout-compose */
Object.assign(window.app, {
  closeWorkoutCompose() {
    state.workoutDraft = null;
    app.back();
  },

  workoutDraftMoveTo(index, target) {
    const draft = state.workoutDraft;
    if (!draft || !Array.isArray(draft.exercises)) return;
    if (index === target || index < 0 || target < 0 || index >= draft.exercises.length || target >= draft.exercises.length) return;
    const next = [...draft.exercises];
    const [moved] = next.splice(index, 1);
    next.splice(target, 0, moved);
    draft.exercises = next;
    save();
    renderKeepingComposeScroll();
  },

  workoutDraftRemove(index) {
    const draft = state.workoutDraft;
    if (!draft || !Array.isArray(draft.exercises) || !draft.exercises[index]) return;
    const [removed] = draft.exercises.splice(index, 1);
    state.equipSelected = state.equipSelected.filter((slug) => slug !== removed.slug);
    save();
    renderKeepingComposeScroll();
  },

  openDraftPicker(index, key) {
    const item = state.workoutDraft?.exercises?.[index];
    if (!item) return;
    const current = key === "reps" ? parseReps(item.reps) : item[key];
    state.numberPicker = {
      context: "draft",
      index,
      key,
      title: workoutPickerTitle(key),
      options: workoutPickerOptions(key, current),
      value: String(current ?? "")
    };
    save();
    render();
  },

  openAdjustPicker(key) {
    const draft = state.workoutAdjustDraft;
    if (!draft) return;
    const current = key === "reps" ? parseReps(draft.reps) : draft[key];
    state.numberPicker = {
      context: "adjust",
      key,
      title: workoutPickerTitle(key),
      options: workoutPickerOptions(key, current),
      value: String(current ?? "")
    };
    save();
    render();
  },

  closeNumberPicker() {
    state.numberPicker = null;
    save();
    render();
  },

  scrollNumberPicker(index) {
    const wheel = document.getElementById("number-picker-wheel");
    if (!wheel) return;
    wheel.scrollTo({ top: index * 46, behavior: "smooth" });
  },

  confirmNumberPicker() {
    const picker = state.numberPicker;
    if (!picker) return;
    const value = picker.value;
    const numeric = picker.key === "sets" || picker.key === "rest";
    const parsed = numeric ? Number(value) || 0 : String(value || "").trim();

    if (picker.context === "draft") {
      const item = state.workoutDraft?.exercises?.[picker.index];
      if (item) {
        if (picker.key === "sets") item.sets = Math.max(1, Math.min(10, Math.round(parsed)));
        else if (picker.key === "reps") item.reps = String(Math.max(1, Math.min(30, Number(parsed) || 10)));
        else if (picker.key === "rest") item.rest = Math.max(0, Math.min(300, Math.round(parsed)));
      }
      state.numberPicker = null;
      save();
      updateComposeSummary();
      renderKeepingComposeScroll();
      return;
    }

    if (picker.context === "adjust" && state.workoutAdjustDraft) {
      if (picker.key === "sets") state.workoutAdjustDraft.sets = Math.max(1, Math.min(10, Math.round(parsed)));
      else if (picker.key === "reps") state.workoutAdjustDraft.reps = String(Math.max(1, Math.min(30, Number(parsed) || 10)));
      else if (picker.key === "rest") state.workoutAdjustDraft.rest = Math.max(0, Math.min(300, Math.round(parsed)));
    }
    state.numberPicker = null;
    save();
    render();
  },

  workoutDraftWeight(index, value) {
    const item = state.workoutDraft?.exercises?.[index];
    if (!item) return;
    item.weight = Math.max(0, roundHalf(Number(value) || 0));
    save();
  },

  workoutAdjustWeight(value) {
    if (!state.workoutAdjustDraft) return;
    state.workoutAdjustDraft.weight = Math.max(0, roundHalf(Number(value) || 0));
    save();
  },

  startWorkoutDraft() {
    const draft = state.workoutDraft;
    if (!draft || !Array.isArray(draft.exercises) || !draft.exercises.length) return;
    const exercises = draft.exercises
      .map((item, index) => {
        const info = EX[item.slug];
        if (!info) return null;
        return {
          id: item.id || `combo-ex-${Date.now()}-${index}`,
          slug: item.slug,
          sets: Math.max(1, Math.min(10, Number(item.sets) || 3)),
          reps: String(parseReps(item.reps)),
          weight: Math.max(0, Number(item.weight) || 0),
          rest: Math.max(0, Math.min(300, Number(item.rest) || 0)),
          rpe: Number(item.rpe) || 7.5
        };
      })
      .filter(Boolean);
    if (!exercises.length) return toast("至少保留一个动作");

    const source = draft.source || "custom";
    const day = {
      id: `session-${Date.now()}`,
      week: 1,
      weekday: 7,
      title: draft.title || (source === "plan" ? "今日训练" : "自选训练"),
      focus: [...new Set(exercises.map((item) => EX[item.slug].muscle))],
      exercises
    };
    state.workoutCustomDay = day;
    const first = day.exercises[0];
    state.workout = {
      dayId: day.id,
      index: 0,
      setIndex: 0,
      weight: first.weight,
      reps: parseReps(first.reps),
      logs: [],
      adjustments: {},
      rest: 0,
      startedAt: Date.now(),
      feeling: 4,
      notes: ""
    };
    state.workoutDraft = null;
    if (source !== "plan") {
      state.equipSelected = [];
    }
    state.equipSelectionOpen = false;
    replaceRoute("workout");
    save();
    render();
  },
});
