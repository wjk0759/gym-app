/* FitAI Web Preview module: pointer drag-to-scroll helper for desktop preview. */

/* ---------------- drag to scroll (desktop preview) ---------------- */

let dragClickSuppressedUntil = 0;

window.addEventListener("click", (event) => {
  if (performance.now() >= dragClickSuppressedUntil) return;
  event.preventDefault();
  event.stopPropagation();
  dragClickSuppressedUntil = 0;
}, true);

function suppressPreviewClick() {
  // 只吞掉拖拽结束后的那一次 click，避免影响下一次正常点击。
  dragClickSuppressedUntil = performance.now() + 120;
}

function enableDragScroll(container) {
  if (!container || container.dataset.dragScrollReady === "1") return;
  container.dataset.dragScrollReady = "1";

  container.addEventListener("pointerdown", (event) => {
    if (event.pointerType !== "mouse" && event.pointerType !== "pen") return;
    if (event.button !== 0) return;
    if (event.target.closest("input, textarea, select, [contenteditable='true'], .no-drag")) return;
    // 已选动作层打开时，底层页面不再响应拖拽，避免短列表拖拽穿透。
    if (container.id === "app" && document.querySelector(".equipment-selection-popover")) return;
    if (
      container.scrollHeight <= container.clientHeight + 1
      && container.scrollWidth <= container.clientWidth + 1
    ) {
      return;
    }

    const startX = event.clientX;
    const startY = event.clientY;
    const startTop = container.scrollTop;
    const startLeft = container.scrollLeft;
    const pointerId = event.pointerId;
    let moved = false;

    const move = (moveEvent) => {
      if (moveEvent.pointerId !== pointerId) return;
      const dx = moveEvent.clientX - startX;
      const dy = moveEvent.clientY - startY;
      if (!moved && Math.abs(dx) + Math.abs(dy) < 4) return;
      moved = true;
      moveEvent.preventDefault();
      container.scrollTop = startTop - dy;
      container.scrollLeft = startLeft - dx;
      document.body.classList.add("dragging-scroll");
    };

    const end = (endEvent) => {
      if (endEvent.pointerId !== pointerId) return;
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", end);
      window.removeEventListener("pointercancel", end);
      document.body.classList.remove("dragging-scroll");
      if (moved) suppressPreviewClick();
    };

    window.addEventListener("pointermove", move, { passive: false });
    window.addEventListener("pointerup", end);
    window.addEventListener("pointercancel", end);
    event.stopPropagation();
  }, { passive: true });
}

