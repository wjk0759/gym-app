/* FitAI Web Preview page module: workout-compose */

/* ---------------- Custom workout compose ---------------- */

function setupComposeDrag() {
  const list = document.querySelector(".compose-list");
  if (!list || list.dataset.dragReady === "1") return;
  list.dataset.dragReady = "1";
  let drag = null;

  const clearTarget = () => {
    list.querySelectorAll(".compose-exercise.drop-target").forEach((card) => {
      card.classList.remove("drop-target");
    });
  };

  list.addEventListener("pointerdown", (event) => {
    const handle = event.target.closest("[data-compose-drag]");
    if (!handle) return;
    const card = handle.closest(".compose-exercise");
    if (!card) return;
    event.preventDefault();
    drag = {
      pointerId: event.pointerId,
      source: Number(card.dataset.composeIndex),
      target: Number(card.dataset.composeIndex),
      card
    };
    card.classList.add("dragging");
    handle.setPointerCapture?.(event.pointerId);
  });

  list.addEventListener("pointermove", (event) => {
    if (!drag || event.pointerId !== drag.pointerId) return;
    const scroller = list.closest(".compose-scroll");
    const bounds = scroller?.getBoundingClientRect();
    if (scroller && bounds) {
      if (event.clientY < bounds.top + 56) scroller.scrollTop -= 12;
      else if (event.clientY > bounds.bottom - 56) scroller.scrollTop += 12;
    }
    const target = document.elementFromPoint(event.clientX, event.clientY)?.closest(".compose-exercise");
    clearTarget();
    if (!target) return;
    const targetIndex = Number(target.dataset.composeIndex);
    if (Number.isInteger(targetIndex)) {
      drag.target = targetIndex;
      if (targetIndex !== drag.source) target.classList.add("drop-target");
    }
  });

  const finish = (event) => {
    if (!drag || event.pointerId !== drag.pointerId) return;
    const { source, target, card } = drag;
    drag = null;
    clearTarget();
    card.classList.remove("dragging");
    if (source !== target) app.workoutDraftMoveTo(source, target);
  };

  list.addEventListener("pointerup", finish);
  list.addEventListener("pointercancel", finish);
}

function renderKeepingComposeScroll() {
  const scrollTop = document.querySelector(".compose-scroll")?.scrollTop || 0;
  render();
  requestAnimationFrame(() => {
    const scroller = document.querySelector(".compose-scroll");
    if (scroller) scroller.scrollTop = scrollTop;
  });
}

function workoutComposeTotals(draft) {
  const exercises = Array.isArray(draft?.exercises) ? draft.exercises : [];
  const sets = exercises.reduce((sum, item) => sum + (Number(item.sets) || 0), 0);
  const restMinutes = exercises.reduce(
    (sum, item) => sum + (Number(item.sets) || 0) * (Number(item.rest) || 0) / 60,
    0
  );
  return {
    exercises: exercises.length,
    sets,
    minutes: Math.max(15, Math.round(restMinutes + exercises.length * 3))
  };
}

function updateComposeSummary() {
  const totals = workoutComposeTotals(state.workoutDraft);
  const sets = document.getElementById("compose-total-sets");
  const minutes = document.getElementById("compose-total-minutes");
  const footer = document.getElementById("compose-footer-summary");
  if (sets) sets.textContent = String(totals.sets);
  if (minutes) minutes.textContent = String(totals.minutes);
  if (footer) footer.textContent = `${totals.sets} 组 · 约 ${totals.minutes} 分钟`;
}

function workoutComposeScreen() {
  const draft = state.workoutDraft;
  if (!draft || !Array.isArray(draft.exercises)) return equipmentPickerScreen();
  const totals = workoutComposeTotals(draft);
  const isPlan = draft.source === "plan";
  const isPlanEdit = draft.source === "planEdit";
  const kicker = isPlan ? "今日训练" : isPlanEdit ? "训练日" : "自选训练";
  const heading = isPlan || isPlanEdit ? esc(draft.title || "训练日") : "先排顺序，再开始";
  const copy = isPlanEdit
    ? "调整动作顺序、组数和负荷；保存后直接写回训练计划。"
    : isPlan
      ? "今天的动作顺序、组数和重量都可以先调整；开始后仍可随时修改本次目标。"
      : "动作顺序、组数、次数、重量都可以先改；开始后仍可在训练页临时调整。";

  return `
    <div class="workout-compose">
      <header class="workout-topbar">
        <button class="icon-btn" onclick="app.closeWorkoutCompose()" aria-label="返回上一级">‹</button>
        <div class="workout-title">${isPlanEdit ? "编辑训练日" : "安排训练"}</div>
        <span class="workout-topbar-spacer" aria-hidden="true"></span>
      </header>

      <div class="compose-scroll">
      <section class="compose-hero">
        <div class="compose-kicker">${kicker}</div>
        <div class="h2">${heading}</div>
        <p class="small muted compose-copy">${copy}</p>
        <div class="compose-stats">
          <span><strong>${totals.exercises}</strong> 个动作</span>
          <span><strong id="compose-total-sets">${totals.sets}</strong> 组</span>
          <span>约 <strong id="compose-total-minutes">${totals.minutes}</strong> 分钟</span>
        </div>
      </section>

      <div class="compose-eyebrow">
        <span>训练顺序</span>
        <span class="tiny faint">按住左侧手柄拖动排序</span>
      </div>

      <div class="compose-list">
        ${draft.exercises.length ? draft.exercises.map((item, index) => {
          const info = EX[item.slug] || { name: item.slug, muscle: "", equip: "" };
          return `
            <article class="compose-exercise" data-compose-index="${index}">
              <div class="compose-exercise-head">
                <span class="compose-drag-handle" data-compose-drag role="button" tabindex="0" aria-label="拖动排序" title="拖动排序">
                  <svg viewBox="0 0 12 20" fill="currentColor" aria-hidden="true"><circle cx="3" cy="4" r="1.2"/><circle cx="9" cy="4" r="1.2"/><circle cx="3" cy="10" r="1.2"/><circle cx="9" cy="10" r="1.2"/><circle cx="3" cy="16" r="1.2"/><circle cx="9" cy="16" r="1.2"/></svg>
                </span>
                <span class="compose-order">${String(index + 1).padStart(2, "0")}</span>
                <div class="grow compose-exercise-name">
                  <strong>${esc(info.name)}</strong>
                  <span>${info.muscle || "动作"}${info.equip ? ` · ${info.equip}` : ""}</span>
                </div>
                <div class="compose-move-group">
                  <button class="compose-icon-btn danger" onclick="app.workoutDraftRemove(${index})" aria-label="移除 ${esc(info.name)}">×</button>
                </div>
              </div>

              <div class="compose-fields">
                <div class="compose-field">
                  <span>组数 <em>组</em></span>
                  ${pickerFieldButton({
                    value: String(Number(item.sets) || 1),
                    onclick: `app.openDraftPicker(${index}, 'sets')`,
                    label: "选择组数"
                  })}
                </div>
                <div class="compose-field">
                  <span>每组次数 <em>次</em></span>
                  ${pickerFieldButton({
                    value: String(parseReps(item.reps)),
                    onclick: `app.openDraftPicker(${index}, 'reps')`,
                    label: "选择每组次数"
                  })}
                </div>
                <div class="compose-field">
                  <span>目标重量 <em>kg</em></span>
                  <input class="weight-input" type="number" inputmode="decimal" min="0" step="0.5" value="${Number(item.weight) || 0}" onchange="app.workoutDraftWeight(${index}, this.value)" aria-label="目标重量 kg">
                </div>
                <div class="compose-field">
                  <span>组间休息 <em>秒</em></span>
                  ${pickerFieldButton({
                    value: String(Number(item.rest) || 0),
                    onclick: `app.openDraftPicker(${index}, 'rest')`,
                    label: "选择组间休息"
                  })}
                </div>
              </div>
            </article>
          `;
        }).join("") : `
          <div class="compose-empty">
            <div class="compose-empty-icon">${ICONS.dumbbell}</div>
            <strong>还没有动作</strong>
            <span>返回动作库重新选择。</span>
          </div>
        `}
      </div>

      ${isPlanEdit ? `
        <button class="btn btn-secondary compose-add-exercise" onclick="app.openPlanExercisePicker()">＋ 从动作库添加动作</button>
      ` : ""}
      </div>

      <div class="compose-footer">
        <div class="compose-footer-copy">
          <strong id="compose-footer-summary">${totals.sets} 组 · 约 ${totals.minutes} 分钟</strong>
          <span>${isPlanEdit ? "保存后立即更新当前训练日。" : "重量为 0 表示自重；开始后仍可继续调整。"}</span>
        </div>
        ${isPlanEdit
          ? `<button class="btn btn-primary" onclick="app.savePlanDayDraft()" ${draft.exercises.length ? "" : "disabled"}>保存训练日</button>`
          : `<button class="btn btn-primary" onclick="app.startWorkoutDraft()" ${draft.exercises.length ? "" : "disabled"}>开始本次训练</button>`}
      </div>
    </div>
  `;
}

function adjustedWorkoutExercises(workout, day) {
  if (!day || !Array.isArray(day.exercises)) return [];
  const adjustments = workout?.adjustments && typeof workout.adjustments === "object"
    ? workout.adjustments
    : {};
  return day.exercises.map((exercise) => ({
    ...exercise,
    ...(adjustments[exercise.id] || {})
  }));
}

function workoutAdjustSheet() {
  const workout = state.workout;
  const day = workoutDay(workout);
  const draft = state.workoutAdjustDraft;
  if (!workout || !day || !draft) return "";
  const base = day.exercises[workout.index];
  const info = base ? EX[base.slug] : null;
  const done = (Array.isArray(workout.logs) ? workout.logs : [])
    .filter((log) => base && log.slug === base.slug).length;

  return `
    <div class="workout-adjust-backdrop no-drag" onclick="app.closeWorkoutAdjust()">
      <section class="workout-adjust-sheet no-drag" role="dialog" aria-modal="true" aria-label="调整本次训练" onclick="event.stopPropagation()">
        <div class="sheet-grabber" aria-hidden="true"></div>
        <div class="between">
          <div>
            <div class="compose-kicker">本次训练</div>
            <div class="h3">${info ? esc(info.name) : "调整当前动作"}</div>
          </div>
          <button class="compose-icon-btn" onclick="app.closeWorkoutAdjust()" aria-label="关闭调整">×</button>
        </div>
        <p class="small muted workout-adjust-copy">只调整这次训练的目标，不会改动长期计划。已完成 ${done} 组，降低目标组数会自动进入下一个动作。</p>

        <div class="compose-fields workout-adjust-fields">
          <div class="compose-field">
            <span>目标组数 <em>组</em></span>
            ${pickerFieldButton({
              value: String(draft.sets),
              onclick: "app.openAdjustPicker('sets')",
              label: "选择目标组数"
            })}
          </div>
          <div class="compose-field">
            <span>每组次数 <em>次</em></span>
            ${pickerFieldButton({
              value: String(parseReps(draft.reps)),
              onclick: "app.openAdjustPicker('reps')",
              label: "选择每组次数"
            })}
          </div>
          <div class="compose-field">
            <span>目标重量 <em>kg</em></span>
            <input class="weight-input" type="number" inputmode="decimal" min="0" step="0.5" value="${Number(draft.weight) || 0}" onchange="app.workoutAdjustWeight(this.value)" aria-label="目标重量 kg">
          </div>
          <div class="compose-field">
            <span>组间休息 <em>秒</em></span>
            ${pickerFieldButton({
              value: String(draft.rest),
              onclick: "app.openAdjustPicker('rest')",
              label: "选择组间休息"
            })}
          </div>
        </div>

        <button class="btn btn-primary" style="margin-top:16px" onclick="app.saveWorkoutAdjust()">保存调整</button>
      </section>
    </div>
  `;
}

/* ---------------- Workout ---------------- */

