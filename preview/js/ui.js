/* FitAI Web Preview module: shared shell and UI primitives. */

let lastTabIndex = null;

function tabbar() {
  if (!state.onboarded || state.screen !== "tabs") return "";
  const items = [
    ["home", "今日", ICONS.home],
    ["plan", "计划", ICONS.plan],
    ["coach", "教练", ICONS.coach],
    ["equipment", "器械", ICONS.equipment],
    ["profile", "我的", ICONS.user]
  ];
  const activeIndex = Math.max(0, items.findIndex(([id]) => state.tab === id));
  const fromIndex = Number.isInteger(lastTabIndex) ? lastTabIndex : activeIndex;
  lastTabIndex = activeIndex;
  return `
    <span class="tab-indicator" data-from="${fromIndex}" data-to="${activeIndex}" aria-hidden="true"></span>
    ${items.map(([id, label, icon]) => `
      <button class="tab ${state.tab === id ? "active" : ""}" onclick="app.tab('${id}')">
        ${icon}<span>${label}</span>
      </button>
    `).join("")}
  `;
}

function settleTabIndicator() {
  const bar = document.querySelector(".tabbar");
  const indicator = bar?.querySelector(".tab-indicator");
  if (!bar || !indicator) return;
  const tabs = [...bar.querySelectorAll(".tab")];
  const fromIndex = Number(indicator.dataset.from) || 0;
  const toIndex = Number(indicator.dataset.to) || 0;
  const target = tabs[toIndex];
  if (!target) return;
  const barRect = bar.getBoundingClientRect();
  const targetRect = target.getBoundingClientRect();
  if (!targetRect.width) return;
  indicator.style.width = `${targetRect.width}px`;
  indicator.style.height = `${targetRect.height}px`;
  indicator.style.top = `${targetRect.top - barRect.top - bar.clientTop}px`;
  indicator.style.left = `${targetRect.left - barRect.left - bar.clientLeft}px`;
  if (fromIndex === toIndex || !tabs[fromIndex]) {
    indicator.style.transition = "none";
    indicator.style.transform = "translateX(0)";
    return;
  }
  const fromRect = tabs[fromIndex].getBoundingClientRect();
  const offset = fromRect.left - targetRect.left;
  indicator.style.transition = "none";
  indicator.style.transform = `translateX(${offset}px)`;
  indicator.offsetWidth;
  indicator.style.transition = "";
  indicator.style.transform = "translateX(0)";
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

