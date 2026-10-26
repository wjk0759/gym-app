/* FitAI Web Preview page module: equipment-library */

function filteredEquipmentLibraryItems() {
  const query = String(state.equipLibraryQuery || "").trim().toLowerCase();
  const items = !query
    ? state.equipmentLibrary
    : state.equipmentLibrary.filter((item) => {
        return [item.name, item.muscle, item.equip]
          .some((value) => String(value || "").toLowerCase().includes(query));
      });
  const pinned = new Set(state.pinnedEquipIds || []);
  return [...items].sort((a, b) => Number(pinned.has(b.id)) - Number(pinned.has(a.id)));
}

function equipmentLibraryRowMarkup(item) {
  const pinned = (state.pinnedEquipIds || []).includes(item.id);
  return `
    <div class="library-swipe-row" data-library-id="${item.id}">
      <div class="library-swipe-action">
        <button onclick="app.deleteEquipItem('${item.id}')">删除</button>
      </div>
      <button class="library-row no-drag" onclick="app.openEquipItem('${item.id}')">
        <span class="library-thumb">${exercisePickIcon(item)}</span>
        <span class="library-row-copy">
          <span class="library-row-name">${esc(item.name)}</span>
          <span class="library-row-meta">${item.muscle} · ${item.equip}</span>
        </span>
        ${pinned ? `<span class="library-pin" title="已置顶">${ICONS.pin}</span>` : ""}
        <span class="library-video ${item.video ? "ready" : ""}">
          ${item.video ? "教学视频" : "视频准备中"}
        </span>
        <span class="library-chevron">›</span>
      </button>
    </div>
  `;
}

function equipmentLibraryResultsMarkup(items) {
  if (!state.equipmentLibrary.length) {
    return `
      <div class="library-empty">
        <div class="library-empty-icon">${ICONS.dumbbell}</div>
        <div class="library-empty-title">器械库还是空的</div>
        <div class="library-empty-copy">拍照或从相册识别第一件器械，AI 生成计划时会优先使用它。</div>
        <button class="btn btn-primary" style="margin-top:14px" onclick="app.equipmentRecognitionOpen()">添加第一件器械</button>
      </div>
    `;
  }

  if (!items.length) {
    return `
      <div class="library-empty">
        <div class="library-empty-icon">${ICONS.search}</div>
        <div class="library-empty-title">没有匹配的器械</div>
        <div class="library-empty-copy">换个名称、肌群或器械类型试试。</div>
        <button class="btn btn-secondary" style="margin-top:14px" onclick="app.equipmentLibraryClearQuery()">清空搜索</button>
      </div>
    `;
  }

  return `
    <div class="library-list">
      ${items.map(equipmentLibraryRowMarkup).join("")}
    </div>
  `;
}

function equipmentLibraryScreen() {
  const items = state.equipmentLibrary;
  const filtered = filteredEquipmentLibraryItems();
  const query = String(state.equipLibraryQuery || "");
  const backAction = state.equipLibraryFromProfile ? "app.backTo('profile')" : "app.equipmentTabOpen()";

  return `
    <div class="stack equipment-library-screen">
      <div class="page-header">
        <div class="row between">
          <button class="icon-btn" onclick="${backAction}" aria-label="返回">‹</button>
          <div class="h3">器械库</div>
          <span class="header-spacer" aria-hidden="true"></span>
        </div>
      </div>

      <section class="library-overview">
        <div class="library-overview-main">
          <div class="library-overview-icon">${ICONS.dumbbell}</div>
          <div class="grow">
            <div class="library-overview-label">我的器械</div>
            <div class="library-overview-value"><span>${items.length}</span><span>件</span></div>
            <div class="library-overview-note">教学视频与 AI 计划会优先读取这里</div>
          </div>
        </div>

        <div class="library-plan-row">
          <div class="grow">
            <div class="library-plan-title">计划优先使用</div>
            <div class="library-plan-note">${state.useEquipLibrary ? "生成计划时优先匹配我的器械" : "已关闭，按档案器械生成"}</div>
          </div>
          <button
            class="library-switch ${state.useEquipLibrary ? "active" : ""}"
            role="switch"
            aria-checked="${state.useEquipLibrary}"
            onclick="app.toggleEquipLibrary()"
          >
            <span></span>
          </button>
        </div>
      </section>

      <div class="library-tools">
        <div class="library-search">
          <span class="library-search-icon">${ICONS.search}</span>
          <input
            id="library-search"
            type="text"
            maxlength="60"
            placeholder="搜索我的器械"
            value="${esc(query)}"
            oninput="app.equipmentLibraryQuery(this.value)"
          >
          <button
            id="library-search-clear"
            class="library-search-clear"
            onclick="app.equipmentLibraryClearQuery()"
            aria-label="清空搜索"
            ${query.trim() ? "" : "hidden"}
          >×</button>
        </div>
        <button class="library-add-btn" onclick="app.equipmentRecognitionOpen()" aria-label="添加器械">
          ${ICONS.camera}
        </button>
      </div>

      <div class="library-section-head">
        <span>器械清单</span>
        <span><span id="library-list-count">${filtered.length} 件</span><span class="library-swipe-hint"> · 左滑删除</span></span>
      </div>

      <div id="library-list-root">
        ${equipmentLibraryResultsMarkup(filtered)}
      </div>

      <div class="library-note">器械库会作为 AI 生成计划的可用来源。删除器械不会影响历史训练记录。</div>
    </div>
  `;
}

