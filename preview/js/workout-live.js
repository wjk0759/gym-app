/* FitAI Web Preview page module: workout-live */

function workoutDay(workout) {
  if (!workout) return null;
  return state.plan.days.find((item) => item.id === workout.dayId)
    || (state.workoutCustomDay && state.workoutCustomDay.id === workout.dayId
      ? state.workoutCustomDay
      : null);
}

function workoutScreen() {
  const workout = state.workout;
  if (!workout) return home();
  const day = workoutDay(workout);
  if (!day || !Array.isArray(day.exercises) || day.exercises.length === 0) return home();

  // 旧版本 localStorage / 中断恢复可能留下不完整状态。先修复索引和日志，
  // 避免渲染时抛错后只剩头部和底部操作条。
  if (!Array.isArray(workout.logs)) workout.logs = [];
  if (!Number.isInteger(workout.index) || workout.index < 0) workout.index = 0;
  if (!Number.isInteger(workout.setIndex) || workout.setIndex < 0) workout.setIndex = 0;
  const exercises = adjustedWorkoutExercises(workout, day);
  if (workout.index >= exercises.length) return workoutSummary(day);

  const exercise = exercises[workout.index];
  if (!exercise) return workoutSummary(day);
  const info = EX[exercise.slug] || {
    name: exercise.slug || "当前动作",
    equip: "",
    cues: "动作资料暂时无法加载，可以继续记录本组训练。"
  };
  const logs = Array.isArray(workout.logs) ? workout.logs : [];
  const done = logs.length;
  const total = exercises.reduce((sum, item) => sum + item.sets, 0);
  const ratio = Math.min(100, Math.round((done / Math.max(1, total)) * 100));
  const setsDone = workout.setIndex >= exercise.sets;
  const actionLabel = setsDone
    ? (workout.index < day.exercises.length - 1 ? "下一个动作" : "查看训练总结")
    : `完成第 ${workout.setIndex + 1} 组`;
  const action = setsDone ? "app.nextExercise()" : "app.completeSet()";

  return `
    <div class="workout-screen">
      <header class="workout-topbar">
        <button class="icon-btn" onclick="app.exitWorkout()" aria-label="结束训练">✕</button>
        <div class="workout-title">训练中</div>
        <span class="workout-topbar-spacer" aria-hidden="true"></span>
      </header>

      <div class="workout-progress-strip">
        <div class="workout-progress"><span>${done}/${total} 组</span><span>${workout.index + 1}/${day.exercises.length} 动作</span></div>
        <div class="bar"><span style="width:${ratio}%"></span></div>
      </div>

      <div class="workout-scroll">
        <div class="workout-content">
      <div class="card">
        <div class="between">
          <div class="badge">动作 ${workout.index + 1}/${day.exercises.length}</div>
          <div class="tiny faint">${info.equip}</div>
        </div>
        <div class="h2" style="margin-top:9px">${info.name}</div>
        <div class="small accent" style="margin-top:4px">${exercise.sets} 组 × ${exercise.reps} 次${exercise.weight > 0 ? ` · ${exercise.weight} kg` : " · 自重"}</div>
        <div class="small muted workout-copy" style="margin-top:10px;line-height:1.65">${info.cues}</div>
      </div>

      ${workout.rest > 0 ? `
        <div class="rest-pill">
          <span id="rest-text">休息 ${workout.rest}s</span>
          <button class="link" onclick="app.skipRest()">跳过</button>
        </div>
      ` : ""}

      <div class="card">
        <div class="between">
          <div class="h3">第 ${Math.min(workout.setIndex + 1, exercise.sets)} 组 / 共 ${exercise.sets} 组</div>
          <div class="row gap8">
            <span class="tiny muted">RPE ${Number(exercise.rpe || 7.5).toFixed(1)}</span>
            <button class="link" onclick="app.openWorkoutAdjust()">调整</button>
          </div>
        </div>

        ${exercise.weight > 0 ? `
          <div class="row between" style="margin-top:14px">
            <span class="small muted">重量</span>
            <div class="stepper">
              <button onclick="app.workoutWeight(-2.5)">−</button>
              <span>${workout.weight} kg</span>
              <button onclick="app.workoutWeight(2.5)">＋</button>
            </div>
          </div>
        ` : ""}

        <div class="row between" style="margin-top:14px">
          <span class="small muted">次数</span>
          <div class="stepper">
            <button onclick="app.workoutReps(-1)">−</button>
            <span>${workout.reps} 次</span>
            <button onclick="app.workoutReps(1)">＋</button>
          </div>
        </div>

      </div>

      <div class="card tight">
        <div class="between">
          <div class="small strong">训练提示</div>
          <div class="tiny faint">目标 RPE 7.5</div>
        </div>
        <div class="tiny muted" style="margin-top:6px;line-height:1.6">保留 1–2 次余力；组间休息 ${exercise.rest}s，动作变形就降重量。</div>
      </div>

      ${logs.length ? `
        <div class="card">
          <div class="h3" style="margin-bottom:6px">本次已完成</div>
          ${logs.map((log) => `
            <div class="set-line">
              <span class="small muted">${EX[log.slug]?.name || log.slug} · 第 ${log.set} 组</span>
              <span class="small">${log.weight > 0 ? log.weight + "kg × " : "自重 × "}${log.reps}</span>
            </div>
          `).join("")}
        </div>
      ` : ""}
        </div>
      </div>

      <div class="workout-action-bar">
        <div class="between">
          <button class="link" style="color:var(--muted)" onclick="app.nextExercise()">跳过这个动作</button>
          <span class="tiny faint">已完成 ${done}/${total} 组</span>
        </div>
        <button class="btn btn-primary" style="margin-top:8px" onclick="${action}">${actionLabel}</button>
      </div>
    </div>
  `;
}

function workoutSummary(day) {
  const workout = state.workout;
  const volume = workout.logs.reduce((sum, log) => sum + log.weight * log.reps, 0);
  const minutes = Math.max(1, Math.round((Date.now() - workout.startedAt) / 60000));
  return `
    <div class="stack">
      <div class="page-header row between">
        <button class="icon-btn" onclick="app.exitWorkout()">✕</button>
        <div class="h3">训练总结</div>
        <span class="header-spacer" aria-hidden="true"></span>
      </div>

      <div class="card">
        <div class="h2">训练完成</div>
        <div class="tiny muted" style="margin-top:4px">${day.title}</div>
        <div class="row gap8" style="margin-top:14px">
          <div class="metric"><div class="value">${workout.logs.length}</div><div class="label">完成组数</div></div>
          <div class="metric"><div class="value">${Math.round(volume)}</div><div class="label">总容量 kg</div></div>
          <div class="metric"><div class="value">${minutes}</div><div class="label">分钟</div></div>
        </div>
      </div>

      <div class="card">
        <div class="h3">今天感觉如何？</div>
        <div class="row gap8" style="margin-top:10px">
          ${["😫", "😕", "😐", "🙂", "💪"].map((emoji, index) => `
            <button class="chip ${index === 3 ? "active" : ""}" style="flex:1;font-size:18px" onclick="app.feeling(${index + 1})">${emoji}</button>
          `).join("")}
        </div>
      </div>

      <div class="card">
        <div class="between">
          <div class="form-label">训练心得（可选）</div>
          <div class="tiny faint field-counter" id="workout-notes-count">${String(workout.notes || "").slice(0, 300).length}/300</div>
        </div>
        <textarea rows="3" maxlength="300" placeholder="今天状态、动作感受、下次注意什么…" oninput="app.workoutNote(this.value); updateFieldCounter('workout-notes-count', this.value, 300)">${esc((workout.notes || "").slice(0, 300))}</textarea>
      </div>

      <button class="btn btn-primary" onclick="app.finishWorkout()">保存并结束</button>
      <div class="tiny faint center">记录会用于下一次计划调整。</div>
    </div>
  `;
}

/* ---------------- Session detail ---------------- */

