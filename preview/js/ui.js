/* FitAI Web Preview module: shared shell and UI primitives. */

function tabbar() {
  if (!state.onboarded || state.screen !== "tabs") return "";
  const items = [
    ["home", "今日", ICONS.home],
    ["plan", "计划", ICONS.plan],
    ["coach", "教练", ICONS.coach],
    ["equipment", "器械", ICONS.equipment],
    ["profile", "我的", ICONS.user]
  ];
  return items.map(([id, label, icon]) => `
    <button class="tab ${state.tab === id ? "active" : ""}" onclick="app.tab('${id}')">
      ${icon}<span>${label}</span>
    </button>
  `).join("");
}

function headerBack(title, action = "app.back()") {
  return `
    <div class="page-header">
      <div class="row between">
        <button class="icon-btn" onclick="${action}" aria-label="返回上一级">‹</button>
        <div class="h3">${title}</div>
        <span class="header-spacer" aria-hidden="true"></span>
      </div>
    </div>
  `;
}

function settingsButton() {
  return `<button class="icon-btn" onclick="app.openSettings()" aria-label="设置">${ICONS.settings}</button>`;
}

