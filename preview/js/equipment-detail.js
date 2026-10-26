/* FitAI Web Preview page module: equipment-detail */

function equipmentDetailExercise(item) {
  return item.slug ? EX[item.slug] : null;
}

function equipmentDetailPoints(item) {
  const exercise = equipmentDetailExercise(item);
  const fromLibrary = exercise?.cues || "";
  const points = fromLibrary
    .split(/[。；;]/)
    .map((point) => point.trim())
    .filter(Boolean);

  const general = [
    "先调整座位、靠垫或把手高度，确认起始位置稳定，再开始发力。",
    "全程保持核心收紧、呼吸自然；最后几次也不要靠惯性甩动。",
    "如果出现关节刺痛、麻木或明显代偿，降低重量或停止动作。"
  ];

  general.forEach((point) => {
    if (points.length < 3 && !points.includes(point)) points.push(point);
  });

  return points.slice(0, 5);
}

function equipmentDetailSupport(item) {
  const map = {
    "胸": ["肩", "手臂"],
    "背": ["手臂", "核心"],
    "腿": ["臀", "核心"],
    "臀": ["腿", "核心"],
    "肩": ["手臂", "核心"],
    "手臂": ["肩", "核心"],
    "核心": ["背", "臀"],
    "有氧": ["腿", "核心"]
  };
  return map[item.muscle] || ["核心", "稳定"];
}

function equipmentDetailMuscleMap(item) {
  const muscle = item.muscle || "全身";
  const support = equipmentDetailSupport(item);
  const key = {
    "胸": "chest",
    "背": "back",
    "腿": "legs",
    "臀": "glutes",
    "肩": "shoulders",
    "手臂": "arms",
    "核心": "core",
    "有氧": "cardio"
  }[muscle] || "cardio";

  return `
    <div class="detail-muscle-title">人体肌肉的部位训练概况</div>
    <div class="detail-muscle-figure">
      <img
        class="detail-muscle-anatomy"
        src="assets/muscles/${key}@2x.png"
        alt="人体正面与背面肌肉示意图，重点训练 ${esc(muscle)}，辅助 ${esc(support.join("、"))}"
        loading="lazy"
      >
    </div>
    <div class="detail-muscle-caption">
      <span>重点 <strong>${esc(muscle)}</strong> · 辅助 ${esc(support.join(" · "))}</span>
      <span class="detail-muscle-credit">OpenStax / Nefronus · CC BY-SA 4.0</span>
    </div>
  `;
}

function equipmentDetailSection(index, title, lead, body, id = "") {
  return `
    <section class="detail-section" ${id ? `id="${id}"` : ""}>
      <div class="detail-section-index">${index}</div>
      <h2>${title}</h2>
      <p class="detail-section-lead">${lead}</p>
      ${body}
    </section>
  `;
}

function equipmentItemScreen() {
  const libraryItem = state.equipmentLibrary.find((entry) => entry.id === state.equipmentItemId);
  const previewItem = !libraryItem && state.selectedExercise
    ? exerciseAnalyticsItem(state.selectedExercise)
    : null;
  const item = libraryItem || previewItem;
  if (!item) return equipmentLibraryScreen();
  const isPreview = !!previewItem;

  const exercise = equipmentDetailExercise(item);
  const points = equipmentDetailPoints(item);
  const support = equipmentDetailSupport(item);
  const pinned = !isPreview && (state.pinnedEquipIds || []).includes(item.id);
  const muscle = item.muscle || "全身";
  const description = exercise?.cues
    || item.notes
    || "先用稳定、可控的轨迹完成动作，再逐步增加重量和训练量。";

  const pointsMarkup = points.map((point, index) => `
    <div class="detail-point">
      <span class="detail-point-index">${index + 1}</span>
      <p>${esc(point)}</p>
    </div>
  `).join("");

  return `
    <div class="stack equipment-detail-screen">
      ${headerBack(
        isPreview ? "动作详情" : "器械详情",
        isPreview ? "app.backTo('equipment')" : "app.equipmentLibraryOpen()"
      )}

      <div class="detail-quick-card">
        <div class="detail-quick-title">
          <span class="detail-quick-glyph">${equipGlyph(item)}</span>
          <span>${esc(item.name)}</span>
        </div>
        <div class="detail-quick-actions">
          <button onclick="app.equipmentDetailScroll('detail-points')" aria-label="动作要点">
            ${ICONS.checklist}<span>要点</span>
          </button>
          <button onclick="${item.slug ? `app.openTrainingData('${item.slug}')` : "app.tab('plan')"}" aria-label="训练数据">
            ${ICONS.chart}<span>数据</span>
          </button>
          ${isPreview ? "" : `
            <button id="detail-pin" class="${pinned ? "active" : ""}" onclick="app.equipmentDetailPin('${item.id}')" aria-label="${pinned ? "取消置顶" : "置顶器械"}">
              ${ICONS.pin}<span>置顶</span>
            </button>
          `}
        </div>
      </div>

      <div class="detail-hero">
        <div class="detail-eyebrow">动作学习预览</div>
        <h1 class="detail-title">${esc(item.name)}</h1>
        <p class="detail-description">${esc(description)}</p>
        <div class="detail-tags">
          <span>${muscle}</span>
          <span>${item.equip}</span>
          ${item.video ? "<span class=\"ready\">教学视频</span>" : "<span>视频准备中</span>"}
        </div>
      </div>

      ${equipmentDetailSection(
        "01",
        "视频讲解",
        "先看动作讲解，再看后面要点，会更容易抓住发力顺序。",
        `<div class="detail-video-card ${item.video ? "ready" : ""}">
          <div class="detail-video-glyph">${equipGlyph(item)}</div>
          <div class="detail-video-play">▶</div>
          <div class="detail-video-copy">
            <strong>${item.video ? "点一下播放动作讲解" : "教学视频准备中"}</strong>
            <span>${item.video ? "先看讲解，再开始今天的训练。" : (isPreview ? "这个动作的官方示范视频还在准备中。" : "这件器械的官方示范视频还在准备中。")}</span>
          </div>
          <span class="detail-video-badge">${item.video ? "官方教学视频" : "视频待上线"}</span>
        </div>`
      )}

      ${equipmentDetailSection(
        "02",
        "动作轨迹",
        "先用轨迹示意建立动作路径，再在训练中把速度放慢。",
        `<div class="detail-motion-board">
          <span class="detail-motion-line line-one"></span>
          <span class="detail-motion-line line-two"></span>
          <span class="detail-motion-line line-three"></span>
          <div class="detail-motion-glyph">${equipGlyph(item)}</div>
          <div class="detail-motion-copy">
            <strong>保持轨迹稳定</strong>
            <span>起始位置、发力方向和还原速度，比盲目加重量更重要。</span>
          </div>
          <span class="detail-motion-expand">↗</span>
        </div>`
      )}

      ${equipmentDetailSection(
        "03",
        "多角度示范",
        "示范素材准备中。先用要点确认起始位置和身体角度。",
        `<div class="detail-angle-grid">
          ${["正面", "侧面", "发力", "细节"].map((label, index) => `
            <div class="detail-angle ${index > 1 ? "locked" : ""}">
              <div class="detail-angle-art">${index > 1 ? "◌" : equipGlyph(item)}</div>
              <span>${label}</span>
            </div>
          `).join("")}
        </div>
        <div class="detail-mini-note">示范素材准备中；先用下面的动作要点确认起始位置和发力顺序。</div>`
      )}

      ${equipmentDetailSection(
        "04",
        "动作要点",
        "下面的要点来自动作库和你的器械备注。",
        `<div class="detail-point-list">${pointsMarkup}</div>
         <div class="detail-tip">${item.notes ? `器械备注：${esc(item.notes)}` : "先用轻重量确认动作路线，再逐步接近目标负荷。"}</div>`,
        "detail-points"
      )}

      ${equipmentDetailSection(
        "05",
        "训练肌群",
        `主要训练 ${muscle}，协同稳定由 ${support.join("、")} 参与。`,
        `${equipmentDetailMuscleMap(item)}`
      )}

      <div class="detail-coach-card">
        <div class="detail-coach-avatar">AI</div>
        <div class="grow">
          <div class="detail-coach-title">动作细节还不确定？</div>
          <div class="detail-coach-copy">让教练结合你的计划，解释起始位置、发力顺序和替代动作。</div>
        </div>
        <button class="detail-coach-action" onclick="${item.slug ? `app.askCoach('${item.slug}')` : "app.tab('coach')"}">问教练</button>
      </div>

      ${isPreview ? "" : `<button class="detail-delete" onclick="app.deleteEquipItem('${item.id}')">从器械库删除</button>`}
      <div class="detail-disclaimer">出现关节刺痛、麻木或肿胀时请停止动作并咨询专业人士。教学视频和示范素材由官方动作库提供。</div>
    </div>
  `;
}

const BODY_VARIANTS = [
  {
    summary: "整体比例比较均衡，建议把训练重点放在背部与臀部，配合核心稳定，减少只练胸和手臂的倾向。",
    focus: ["背", "臀", "核心"],
    recommendations: [
      "每周增加 1 次背部训练，优先高位下拉、坐姿划船",
      "臀部训练加入臀推或臀桥，每周 2 次",
      "核心稳定加入平板支撑，每次训练收尾 2 组"
    ],
    confidence: 0.82
  },
  {
    summary: "下肢与核心可以承担更多训练量，建议采用上下肢分化，先把深蹲和髋伸动作做扎实。",
    focus: ["腿", "臀", "核心"],
    recommendations: [
      "保留深蹲或腿举作为下肢主项",
      "加入罗马尼亚硬拉，强化后链",
      "每周至少 2 次核心稳定训练"
    ],
    confidence: 0.76
  },
  {
    summary: "上肢推拉比例可以更平衡，建议增加划船类动作，同时控制卧推总量，避免肩部过度疲劳。",
    focus: ["背", "肩", "核心"],
    recommendations: [
      "推拉比例调整为 1:1.5",
      "加入面拉，改善肩胛稳定",
      "推日最后减少 1 组卧推，改为划船"
    ],
    confidence: 0.71
  }
];

