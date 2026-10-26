/* ---------------- rest timer ---------------- */

let restTimer = null;

function startRestTimer() {
  stopRestTimer();
  if (!state.workout || state.workout.rest <= 0) return;
  restTimer = setInterval(() => {
    if (!state.workout) {
      stopRestTimer();
      return;
    }
    state.workout.rest = Math.max(0, state.workout.rest - 1);
    const label = document.getElementById("rest-text");
    if (label) label.textContent = `休息 ${state.workout.rest}s`;
    if (state.workout.rest <= 0) {
      stopRestTimer();
      save();
      render();
    }
  }, 1000);
}

function stopRestTimer() {
  if (restTimer) {
    clearInterval(restTimer);
    restTimer = null;
  }
}

