/* FitAI Web Preview module: wheel number picker + picker field button. */

function workoutRepOptions(current) {
  const options = Array.from({ length: 30 }, (_, index) => String(index + 1));
  const normalized = String(parseReps(current));
  return options.includes(normalized) ? options : [normalized, ...options];
}

function workoutRestOptions(current) {
  const options = [0, 30, 45, 60, 75, 90, 120, 150, 180];
  const normalized = Number(current) || 0;
  return options.includes(normalized) ? options : [...options, normalized].sort((a, b) => a - b);
}

function workoutPickerOptions(key, current) {
  if (key === "sets") {
    return Array.from({ length: 10 }, (_, index) => ({
      value: String(index + 1),
      label: String(index + 1)
    }));
  }
  if (key === "reps") {
    return workoutRepOptions(current).map((value) => ({ value, label: value }));
  }
  return workoutRestOptions(current).map((value) => ({
    value: String(value),
    label: String(value)
  }));
}

function workoutPickerTitle(key) {
  return {
    sets: "组数 · 组",
    reps: "每组次数 · 次",
    rest: "组间休息 · 秒"
  }[key] || "选择数值";
}

function pickerFieldButton({ value, onclick, label }) {
  return `
    <button class="picker-field" type="button" onclick="${onclick}" aria-label="${label}">
      <span>${value}</span>
      <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true">
        <path d="m5 6 3-3 3 3M5 10l3 3 3-3"/>
      </svg>
    </button>
  `;
}

function numberPickerSheet() {
  const picker = state.numberPicker;
  if (!picker) return "";
  const selectedIndex = Math.max(0, picker.options.findIndex((option) => String(option.value) === String(picker.value)));
  const selected = picker.options[selectedIndex] || picker.options[0];

  return `
    <div class="number-picker-backdrop no-drag" onclick="app.closeNumberPicker()">
      <section class="number-picker-sheet no-drag" role="dialog" aria-modal="true" aria-label="${picker.title}" onclick="event.stopPropagation()">
        <header class="number-picker-head">
          <button class="number-picker-cancel" onclick="app.closeNumberPicker()">取消</button>
          <div class="number-picker-heading">
            <span>${picker.title}</span>
            <strong id="number-picker-current">${selected?.label || ""}</strong>
          </div>
          <button class="number-picker-confirm" onclick="app.confirmNumberPicker()">确认</button>
        </header>
        <div class="number-picker-wheel-wrap">
          <div class="number-picker-center" aria-hidden="true"></div>
          <div class="number-picker-wheel" id="number-picker-wheel">
            <div class="number-picker-spacer" aria-hidden="true"></div>
            ${picker.options.map((option, index) => `
              <button class="number-picker-option ${index === selectedIndex ? "selected" : ""}" data-index="${index}" data-value="${option.value}" onclick="app.scrollNumberPicker(${index})">${option.label}</button>
            `).join("")}
            <div class="number-picker-spacer" aria-hidden="true"></div>
          </div>
        </div>
      </section>
    </div>
  `;
}

function setupNumberPicker() {
  const picker = state.numberPicker;
  const wheel = document.getElementById("number-picker-wheel");
  if (!picker || !wheel) return;

  const itemHeight = 46;
  const options = picker.options;
  const currentIndex = Math.max(0, options.findIndex((option) => String(option.value) === String(picker.value)));
  let selectedIndex = currentIndex;

  const updateSelection = (index) => {
    const bounded = Math.max(0, Math.min(options.length - 1, index));
    selectedIndex = bounded;
    state.numberPicker.value = options[bounded].value;
    wheel.querySelectorAll(".number-picker-option").forEach((option, optionIndex) => {
      option.classList.toggle("selected", optionIndex === bounded);
    });
    const current = document.getElementById("number-picker-current");
    if (current) current.textContent = options[bounded].label;
  };

  wheel.scrollTop = currentIndex * itemHeight;
  wheel.addEventListener("scroll", () => {
    updateSelection(Math.round(wheel.scrollTop / itemHeight));
  }, { passive: true });

  // Let the browser lay out the sheet before positioning the wheel.
  requestAnimationFrame(() => {
    wheel.scrollTop = currentIndex * itemHeight;
    updateSelection(currentIndex);
  });
}
