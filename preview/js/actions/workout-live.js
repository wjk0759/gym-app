/* FitAI Web Preview actions: workout-live */
Object.assign(window.app, {
  startWorkout() {
    const day = todayDay();
    if (!day || !Array.isArray(day.exercises) || !day.exercises.length) return;
    state.workoutDraft = {
      source: "plan",
      title: day.title || "今日训练",
      createdAt: Date.now(),
      exercises: day.exercises.map((exercise, index) => ({
        ...exercise,
        id: exercise.id || `plan-ex-${Date.now()}-${index}`,
        sets: Number(exercise.sets) || 3,
        reps: String(parseReps(exercise.reps)),
        weight: Math.max(0, Number(exercise.weight) || 0),
        rest: Math.max(0, Number(exercise.rest) || 0),
        rpe: Number(exercise.rpe) || 7.5
      }))
    };
    state.workoutCustomDay = null;
    state.workoutAdjustOpen = false;
    state.workoutAdjustDraft = null;
    pushRoute("workoutCompose");
    save();
    render();
  },

  workoutWeight(delta) {
    state.workout.weight = Math.max(0, roundHalf(state.workout.weight + delta));
    save();
    render();
  },

  workoutReps(delta) {
    state.workout.reps = Math.max(1, state.workout.reps + delta);
    save();
    render();
  },

  completeSet() {
    const workout = state.workout;
    const day = workoutDay(workout);
    const exercise = adjustedWorkoutExercises(workout, day)[workout.index];
    if (!exercise) return;
    workout.logs.push({
      slug: exercise.slug,
      set: workout.setIndex + 1,
      weight: exercise.weight > 0 ? workout.weight : 0,
      reps: workout.reps
    });
    workout.setIndex += 1;
    if (workout.setIndex < exercise.sets) {
      workout.rest = exercise.rest;
      save();
      render();
      startRestTimer();
    } else {
      workout.rest = 0;
      save();
      render();
      toast("本动作完成");
    }
  },

  skipRest() {
    if (state.workout) state.workout.rest = 0;
    stopRestTimer();
    save();
    render();
  },

  nextExercise() {
    const workout = state.workout;
    const day = workoutDay(workout);
    stopRestTimer();
    workout.rest = 0;
    workout.index += 1;
    workout.setIndex = 0;
    const exercises = adjustedWorkoutExercises(workout, day);
    if (workout.index < exercises.length) {
      const next = exercises[workout.index];
      workout.weight = next.weight;
      workout.reps = parseReps(next.reps);
    }
    save();
    render();
  },

  openWorkoutAdjust() {
    const workout = state.workout;
    const day = workoutDay(workout);
    const exercise = adjustedWorkoutExercises(workout, day)[workout.index];
    if (!exercise) return;
    state.workoutAdjustDraft = {
      id: exercise.id,
      sets: Math.max(1, Number(exercise.sets) || 1),
      reps: String(parseReps(exercise.reps)),
      weight: Math.max(0, Number(exercise.weight) || 0),
      rest: Math.max(0, Number(exercise.rest) || 0)
    };
    state.workoutAdjustOpen = true;
    save();
    render();
  },

  closeWorkoutAdjust() {
    state.workoutAdjustOpen = false;
    state.workoutAdjustDraft = null;
    save();
    render();
  },

  saveWorkoutAdjust() {
    const workout = state.workout;
    const day = workoutDay(workout);
    const draft = state.workoutAdjustDraft;
    const base = day?.exercises?.[workout?.index];
    if (!workout || !day || !draft || !base) return;
    workout.adjustments = workout.adjustments || {};
    workout.adjustments[base.id] = {
      sets: Math.max(1, Math.min(10, Number(draft.sets) || base.sets)),
      reps: String(Math.max(1, Math.min(30, Number(draft.reps) || parseReps(base.reps)))),
      weight: Math.max(0, Number(draft.weight) || 0),
      rest: Math.max(0, Math.min(300, Number(draft.rest) || 0))
    };
    workout.weight = workout.adjustments[base.id].weight;
    workout.reps = parseReps(workout.adjustments[base.id].reps);
    state.workoutAdjustOpen = false;
    state.workoutAdjustDraft = null;
    save();
    render();
    toast("已保存本次训练目标");
  },

  feeling(value) {
    if (state.workout) state.workout.feeling = value;
    save();
    render();
    toast("已记录训练感受");
  },

  workoutNote(value) {
    if (state.workout) state.workout.notes = String(value || "").slice(0, 300);
    save();
  },

  finishWorkout() {
    const workout = state.workout;
    if (!workout) return;
    const day = workoutDay(workout);
    const volume = workout.logs.reduce((sum, log) => sum + log.weight * log.reps, 0);
    const exercises = adjustedWorkoutExercises(workout, day);
    const items = exercises.map((exercise) => ({
      name: EX[exercise.slug]?.name || exercise.slug,
      weight: exercise.weight,
      reps: parseReps(exercise.reps),
      sets: workout.logs.filter((log) => log.slug === exercise.slug).length || exercise.sets
    }));
    state.sessions.unshift({
      id: `s${Date.now()}`,
      title: day.title,
      date: "刚刚",
      timestamp: Date.now(),
      duration: Math.max(1, Math.round((Date.now() - workout.startedAt) / 60000)),
      volume: Math.round(volume) || 1860,
      thisWeek: true,
      notes: String(workout.notes || "").trim().slice(0, 300),
      items
    });
    state.workout = null;
    state.workoutCustomDay = null;
    stopRestTimer();
    resetToTab("home");
    save();
    render();
    toast("训练已保存");
  },

  exitWorkout() {
    if (!state.workout) return;
    if (!confirm("结束这次训练？已完成的组不会保存。")) return;
    state.workout = null;
    state.workoutCustomDay = null;
    stopRestTimer();
    app.back();
  },
});
