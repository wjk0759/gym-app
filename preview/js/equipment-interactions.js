/* FitAI Web Preview module: equipment page scroll/layout and swipe interactions. */

let equipmentScrollFrame = 0;
let equipmentToolsObserver = null;
let equipmentScrollLock = null;

function syncEquipmentLayout() {
  const root = document.getElementById("app");
  if (!root) return;
  const tools = root.querySelector(".equipment-sticky-tools");
  if (!tools) {
    root.style.removeProperty("--equipment-tools-height");
    return;
  }
  root.style.setProperty("--equipment-tools-height", `${tools.offsetHeight}px`);
}

function setupEquipmentLayout() {
  syncEquipmentLayout();
  const tools = document.querySelector(".equipment-sticky-tools");
  if (!tools) return;
  if (typeof ResizeObserver === "undefined") return;
  if (equipmentToolsObserver) equipmentToolsObserver.disconnect();
  equipmentToolsObserver = new ResizeObserver(() => syncEquipmentLayout());
  equipmentToolsObserver.observe(tools);
}

function syncEquipmentScrollState() {
  const root = document.getElementById("app");
  if (!root) return;
  const onEquipment = (state.screen === "tabs" && state.tab === "equipment")
    || state.screen === "planExercisePicker";
  const selectionOpen = onEquipment && state.equipSelectionOpen;

  // 锁定底层滚动位置：即使浏览器/触摸事件漏到底层，也不会带着页面移动。
  if (selectionOpen) {
    if (equipmentScrollLock === null) equipmentScrollLock = root.scrollTop;
    if (root.scrollTop !== equipmentScrollLock) root.scrollTop = equipmentScrollLock;
  } else {
    equipmentScrollLock = null;
  }

  const wasScrolled = root.classList.contains("equipment-scrolled");
  const shouldBeScrolled = onEquipment && (wasScrolled ? root.scrollTop > 2 : root.scrollTop > 18);
  root.classList.toggle("equipment-scrolled", shouldBeScrolled);
}

function setupEquipmentScrollState() {
  const root = document.getElementById("app");
  if (!root || root.dataset.equipmentScrollReady === "1") return;
  root.dataset.equipmentScrollReady = "1";
  root.addEventListener("scroll", () => {
    if (equipmentScrollFrame) return;
    equipmentScrollFrame = requestAnimationFrame(() => {
      equipmentScrollFrame = 0;
      syncEquipmentScrollState();
    });
  }, { passive: true });
  syncEquipmentScrollState();
}

function setupLibrarySwipeRows() {
  document.querySelectorAll(".library-swipe-row").forEach((row) => {
    if (row.dataset.swipeReady === "1") return;
    row.dataset.swipeReady = "1";

    const content = row.querySelector(".library-row");
    if (!content) return;

    let startX = 0;
    let startY = 0;
    let offset = 0;
    let horizontal = false;
    let dragging = false;

    const setOffset = (value) => {
      offset = Math.max(-84, Math.min(0, value));
      content.style.transform = `translateX(${offset}px)`;
    };

    const settle = (open) => {
      row.classList.toggle("is-open", open);
      content.style.transition = "transform 200ms cubic-bezier(0.22, 0.8, 0.24, 1)";
      setOffset(open ? -84 : 0);
      setTimeout(() => {
        content.style.transition = "";
      }, 220);
    };

    content.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return;
      startX = event.clientX;
      startY = event.clientY;
      offset = row.classList.contains("is-open") ? -84 : 0;
      horizontal = false;
      dragging = true;
      content.style.transition = "";
      if (event.pointerType !== "touch") {
        content.setPointerCapture?.(event.pointerId);
      }
    });

    content.addEventListener("pointermove", (event) => {
      if (!dragging) return;
      const dx = event.clientX - startX;
      const dy = event.clientY - startY;

      if (!horizontal) {
        if (Math.abs(dx) < 7 && Math.abs(dy) < 7) return;
        if (Math.abs(dx) <= Math.abs(dy)) {
          dragging = false;
          return;
        }
        horizontal = true;
      }

      event.preventDefault();
      setOffset((row.classList.contains("is-open") ? -84 : 0) + dx);
    }, { passive: false });

    const finish = () => {
      if (!dragging) return;
      dragging = false;

      if (!horizontal) {
        // 已展开时点一下整行先收起，不直接进入详情。
        if (row.classList.contains("is-open")) {
          settle(false);
          row.dataset.suppressClick = "1";
          setTimeout(() => {
            row.dataset.suppressClick = "0";
          }, 220);
        }
        return;
      }

      const open = offset < -34;
      if (open) {
        document.querySelectorAll(".library-swipe-row.is-open").forEach((other) => {
          if (other === row) return;
          other.classList.remove("is-open");
          const otherContent = other.querySelector(".library-row");
          if (otherContent) {
            otherContent.style.transition = "transform 180ms ease";
            otherContent.style.transform = "translateX(0)";
            setTimeout(() => {
              otherContent.style.transition = "";
            }, 200);
          }
        });
      }

      settle(open);
      row.dataset.suppressClick = "1";
      setTimeout(() => {
        row.dataset.suppressClick = "0";
      }, 220);
    };

    content.addEventListener("pointerup", finish);
    content.addEventListener("pointercancel", finish);
    content.addEventListener("click", (event) => {
      if (row.dataset.suppressClick === "1" || row.classList.contains("is-open")) {
        event.preventDefault();
        event.stopImmediatePropagation();
        if (row.classList.contains("is-open") && row.dataset.suppressClick !== "1") {
          settle(false);
        }
      }
    }, true);
  });
}

function containSelectionListScroll() {
  const list = document.querySelector(".equipment-selection-list");
  if (!list || list.dataset.scrollContained === "1") return;
  list.dataset.scrollContained = "1";

  list.addEventListener("wheel", (event) => {
    const atTop = list.scrollTop <= 0 && event.deltaY < 0;
    const atBottom = event.deltaY > 0
      && list.scrollTop + list.clientHeight >= list.scrollHeight - 1;
    const cannotScroll = list.scrollHeight <= list.clientHeight + 1;
    if (cannotScroll || atTop || atBottom) {
      event.preventDefault();
    }
  }, { passive: false });

  let touchStartY = 0;
  list.addEventListener("touchstart", (event) => {
    touchStartY = event.touches[0]?.clientY ?? 0;
  }, { passive: true });

  list.addEventListener("touchmove", (event) => {
    const y = event.touches[0]?.clientY ?? touchStartY;
    const pullingDown = y > touchStartY;
    const atTop = list.scrollTop <= 0;
    const atBottom = list.scrollTop + list.clientHeight >= list.scrollHeight - 1;
    const cannotScroll = list.scrollHeight <= list.clientHeight + 1;
    if (cannotScroll || (atTop && pullingDown) || (atBottom && !pullingDown)) {
      event.preventDefault();
    }
  }, { passive: false });
}

document.addEventListener("wheel", (event) => {
  if (!document.querySelector(".equipment-selection-popover")) return;
  if (!event.target.closest(".equipment-selection-list")) {
    event.preventDefault();
  }
}, { passive: false });

document.addEventListener("touchmove", (event) => {
  if (!document.querySelector(".equipment-selection-popover")) return;
  if (!event.target.closest(".equipment-selection-list")) {
    event.preventDefault();
  }
}, { passive: false });

