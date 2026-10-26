/* FitAI Web Preview actions: session */
Object.assign(window.app, {
  openHistory() {
    state.screen = "history";
    save();
    render();
  },

  closeHistory() {
    state.screen = "tabs";
    state.tab = "home";
    save();
    render();
  },

  openSession(id, origin = "home") {
    state.sessionId = id;
    state.sessionOrigin = origin === "plan" ? "plan" : "home";
    state.sessionCreating = false;
    const session = state.sessions.find((item) => item.id === id);
    state.sessionDraft = session ? JSON.parse(JSON.stringify(session)) : null;
    state.sessionEditing = false;
    state.screen = "sessionDetail";
    save();
    render();
  },

  openCalendarTraining() {
    const key = state.calendarDateKey || todayKey();
    if (key > todayKey()) return toast("未来日期不能记录训练");
    const day = planDayForDateKey(key);
    const timestamp = parseDateKey(key);
    timestamp.setHours(19, 0, 0, 0);
    const items = (day?.exercises || []).map((item) => {
      const info = EX[item.slug];
      if (!info) return null;
      return {
        slug: item.slug,
        name: info.name,
        weight: Math.max(0, Number(item.weight) || 0),
        reps: Math.max(1, parseReps(item.reps)),
        sets: Math.max(1, Number(item.sets) || 3)
      };
    }).filter(Boolean);
    state.sessionId = null;
    state.sessionOrigin = "plan";
    state.sessionCreating = true;
    state.sessionEditing = true;
    state.sessionDraft = {
      id: `s${Date.now()}`,
      title: day?.title || "训练记录",
      date: sessionDateLabel(timestamp),
      timestamp: timestamp.getTime(),
      duration: day ? Math.max(20, estimatedMinutes(day)) : 45,
      feeling: 3,
      notes: "",
      thisWeek: startOfWeekMonday(timestamp).getTime() === startOfWeekMonday(new Date()).getTime(),
      items
    };
    state.screen = "sessionDetail";
    save();
    render();
  },

  sessionEdit() {
    const session = state.sessions.find((item) => item.id === state.sessionId);
    if (!session) return;
    state.sessionDraft = JSON.parse(JSON.stringify(session));
    state.sessionEditing = true;
    state.sessionCreating = false;
    render();
  },

  sessionCancel() {
    if (state.sessionCreating) {
      state.sessionCreating = false;
      state.sessionEditing = false;
      state.sessionDraft = null;
      state.screen = "tabs";
      state.tab = "plan";
      state.sessionOrigin = "home";
      save();
      render();
      return;
    }
    state.sessionEditing = false;
    state.sessionDraft = null;
    render();
  },

  sessionField(key, value) {
    if (!state.sessionDraft) return;
    if (key === "duration") {
      state.sessionDraft.duration = Math.max(1, Number(value) || 1);
    } else if (key === "title") {
      state.sessionDraft.title = String(value || "").slice(0, 40);
    } else if (key === "notes") {
      state.sessionDraft.notes = String(value || "").slice(0, 300);
    } else {
      state.sessionDraft[key] = value;
    }
  },

  sessionFeeling(value) {
    if (!state.sessionDraft) return;
    state.sessionDraft.feeling = value;
    render();
  },

  sessionItem(index, key, value) {
    if (!state.sessionDraft || !state.sessionDraft.items[index]) return;
    const number = Math.max(0, Number(value) || 0);
    state.sessionDraft.items[index][key] = key === "sets" ? Math.max(1, number) : number;
  },

  sessionAddItem() {
    if (!state.sessionDraft) return;
    state.screen = "sessionExercisePicker";
    state.equipSearchQuery = "";
    state.equipMuscle = "全部";
    state.equipFilter = "全部";
    save();
    render();
  },

  closeSessionExercisePicker() {
    state.screen = "sessionDetail";
    save();
    render();
  },

  addSessionExercise(slug) {
    const draft = state.sessionDraft;
    const exercise = EX[slug];
    if (!draft || !exercise) return;
    const exists = draft.items.some((item) => item.slug === slug || (!item.slug && item.name === exercise.name));
    if (!exists) {
      draft.items.push({
        slug,
        name: exercise.name,
        weight: Number(exercise.base) || 0,
        reps: 10,
        sets: 3
      });
      save();
      toast(`已添加 ${exercise.name}`);
    } else {
      toast("这个动作已在训练记录里");
    }
    state.screen = "sessionDetail";
    render();
  },

  sessionDeleteItem(index) {
    if (!state.sessionDraft) return;
    state.sessionDraft.items.splice(index, 1);
    render();
  },

  sessionSave() {
    if (!state.sessionDraft) return;
    const creating = !!state.sessionCreating;
    const draft = state.sessionDraft;
    draft.title = (String(draft.title || "").trim() || "训练记录").slice(0, 40);
    draft.notes = String(draft.notes || "").slice(0, 300);
    draft.duration = Math.max(1, Number(draft.duration) || 1);
    draft.feeling = Math.min(5, Math.max(1, Number(draft.feeling) || 3));
    draft.items = draft.items.map((item) => ({
      slug: item.slug,
      name: item.name,
      weight: Math.max(0, Number(item.weight) || 0),
      reps: Math.max(0, Number(item.reps) || 0),
      sets: Math.max(1, Number(item.sets) || 1)
    }));
    draft.volume = draft.items.reduce((sum, item) => sum + item.weight * item.reps * item.sets, 0);
    if (creating) {
      if (!Number.isFinite(Number(draft.timestamp))) {
        const fallback = parseDateKey(state.calendarDateKey || todayKey());
        fallback.setHours(19, 0, 0, 0);
        draft.timestamp = fallback.getTime();
      }
      draft.date = sessionDateLabel(draft.timestamp);
      draft.thisWeek = startOfWeekMonday(new Date(draft.timestamp)).getTime()
        === startOfWeekMonday(new Date()).getTime();
      state.sessions.unshift(draft);
      state.sessionId = draft.id;
      state.sessionCreating = false;
      state.sessionEditing = false;
      state.sessionDraft = null;
      state.screen = "tabs";
      state.tab = "plan";
      state.sessionOrigin = "home";
      save();
      render();
      toast("训练记录已添加到日历");
      return;
    }
    const index = state.sessions.findIndex((item) => item.id === draft.id);
    if (index >= 0) state.sessions[index] = draft;
    state.sessionEditing = false;
    state.sessionDraft = null;
    save();
    render();
    toast("训练记录已保存，首页数据已同步");
  },

  deleteSession() {
    if (!confirm("删除这条训练记录？删除后无法恢复。")) return;
    state.sessions = state.sessions.filter((item) => item.id !== state.sessionId);
    state.sessionEditing = false;
    state.sessionDraft = null;
    state.screen = "tabs";
    state.tab = state.sessionOrigin === "plan" ? "plan" : "home";
    state.sessionOrigin = "home";
    save();
    render();
    toast("已删除训练记录");
  },
});
