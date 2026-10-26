/* FitAI Web Preview page module: premium AI coach chat and guided plan adjustment. */

function scrollCoachChat() {
  setTimeout(() => {
    const chat = document.getElementById("chat-scroll");
    if (!chat) return;
    const cards = chat.querySelectorAll(".coach-proposal, .coach-applied");
    const latestCard = cards[cards.length - 1];
    if (latestCard) {
      const top = latestCard.getBoundingClientRect().top
        - chat.getBoundingClientRect().top
        + chat.scrollTop;
      chat.scrollTop = Math.max(0, top - 6);
      return;
    }
    chat.scrollTop = chat.scrollHeight;
  }, 30);
}

function coachAdjustmentStepMeta(adjustment) {
  const steps = [
    { key: "issue", label: "说明问题", number: "01" },
    { key: "detail", label: "补充细节", number: "02" },
    { key: "proposal", label: "确认方案", number: "03" }
  ];
  const current = steps.findIndex((step) => step.key === adjustment?.step);
  return { steps, current: current < 0 ? 0 : current };
}

function coachAdjustmentBanner(adjustment) {
  if (!adjustment?.active) return "";
  const { steps, current } = coachAdjustmentStepMeta(adjustment);
  const meta = steps[current];
  return `
    <section class="coach-adjust-banner">
      <div class="between">
        <span class="coach-step-pill">计划调整 · ${meta.number}</span>
        <button class="coach-banner-cancel" onclick="app.cancelPlanAdjustment()">结束调整</button>
      </div>
      <div class="coach-adjust-heading">${meta.label}</div>
      <div class="coach-step-track">
        ${steps.map((step, index) => `
          <span class="${index < current ? "done" : ""} ${index === current ? "active" : ""}">
            <i>${step.number}</i>${step.label}
          </span>
        `).join("")}
      </div>
    </section>
  `;
}

function coachProposalCard(proposal) {
  return `
    <article class="coach-proposal">
      <div class="coach-proposal-eyebrow">调整方案 · 根据你的反馈</div>
      <h3>${esc(proposal.headline)}</h3>
      <p class="coach-proposal-summary">${esc(proposal.summary)}</p>
      <div class="coach-proposal-list">
        ${proposal.changes.map((change, index) => `
          <div class="coach-proposal-item">
            <span>${String(index + 1).padStart(2, "0")}</span>
            <p>${esc(change)}</p>
          </div>
        `).join("")}
      </div>
      <div class="coach-proposal-actions">
        <button class="btn btn-primary" onclick="app.applyPlanAdjustment()">应用调整</button>
        <button class="btn btn-secondary" onclick="app.revisePlanAdjustment()">再改一点</button>
      </div>
    </article>
  `;
}

function coachAppliedCard(applied) {
  return `
    <article class="coach-applied">
      <div class="coach-proposal-eyebrow">已完成 · 第 ${applied.version} 版</div>
      <h3>计划已按你的诉求更新</h3>
      <p>${esc(applied.summary)}</p>
      <div class="coach-proposal-list">
        ${applied.changes.map((change) => `
          <div class="coach-proposal-item">
            <span>✓</span>
            <p>${esc(change)}</p>
          </div>
        `).join("")}
      </div>
      <button class="btn btn-secondary" onclick="app.openAdjustedPlan()">查看更新后的计划</button>
    </article>
  `;
}

function coachMessageMarkup(message) {
  if (message.kind === "proposal" && message.proposal) {
    return `<div class="coach-message coach-message-assistant">${coachProposalCard(message.proposal)}</div>`;
  }
  if (message.kind === "applied" && message.applied) {
    return `<div class="coach-message coach-message-assistant">${coachAppliedCard(message.applied)}</div>`;
  }
  if (message.role === "user") {
    return `<div class="coach-message coach-message-user"><div class="coach-bubble coach-bubble-user">${esc(message.text)}</div></div>`;
  }
  const safetyLabel = message.safety ? '<span class="coach-safety-label">需要专业评估</span>' : "";
  return `<div class="coach-message coach-message-assistant"><div class="coach-message-avatar">AI</div><div class="coach-message-body"><div class="coach-message-meta">AI 教练</div><div class="coach-bubble coach-bubble-assistant ${message.safety ? "safety" : ""}">${safetyLabel}${esc(message.text)}</div></div></div>`;
}

function coachQuickReplies(adjustment, suggestions) {
  if (adjustment?.step === "applied") {
    return `<button class="coach-quick-action primary" onclick="app.openAdjustedPlan()">查看更新后的计划</button>`;
  }
  if (adjustment?.step === "proposal") {
    return "";
  }
  if (adjustment?.active) {
    return (adjustment.quickReplies || []).map((text) => `
      <button class="coach-quick-action" onclick="app.sendChat('${text.replace(/'/g, "\\'")}')">${text}</button>
    `).join("");
  }
  return suggestions.map((text) => `
    <button class="coach-quick-action" onclick="app.sendChat('${text.replace(/'/g, "\\'")}')">${text}</button>
  `).join("");
}

function coachScreen() {
  const skills = {
    trainer: {
      label: "训练教练",
      icon: "◎",
      desc: "训练安排、动作替代和负荷调整",
      starters: ["今天练什么？", "没有器械怎么替代？", "训练后很酸正常吗？", "下次怎么加重量？"],
      placeholder: "说说训练、动作或计划上的问题…"
    },
    rehab: {
      label: "康复顾问",
      icon: "✚",
      desc: "疼痛分级、恢复期活动和就医提示",
      starters: ["膝盖不舒服还能练吗？", "训练后腰痛怎么恢复？", "扭伤后多久能训练？", "恢复期能做什么动作？"],
      placeholder: "描述疼痛位置、时间和程度…"
    },
    nutrition: {
      label: "营养教练",
      icon: "◇",
      desc: "热量、蛋白质和膳食结构建议",
      starters: ["每天吃多少蛋白质？", "减脂怎么安排三餐？", "训练后吃什么？", "外卖怎么选更健康？"],
      placeholder: "问问热量、蛋白质或饮食安排…"
    }
  };
  const skill = skills[state.coachSkill] || skills.trainer;
  const adjustment = state.planAdjustment;
  const activeAdjustment = !!adjustment?.active;
  const weekSessions = currentWeekSessions().length;
  const ratio = Math.min(100, Math.round((weekSessions / Math.max(1, state.profile.weeklyDays)) * 100));
  const suggestions = activeAdjustment
    ? adjustment.quickReplies || []
    : skill.starters.slice(0, 3);
  const placeholder = activeAdjustment
    ? adjustment.step === "issue"
      ? "说说最近训练最困扰你的地方…"
      : adjustment.step === "detail"
        ? "补充具体情况，越具体越好…"
        : "需要再改可以继续告诉我…"
    : skill.placeholder;

  const welcome = `
    <section class="coach-welcome">
      <div class="coach-welcome-head">
        <div class="coach-welcome-avatar">AI</div>
        <div class="grow">
          <div class="coach-eyebrow">练途 AI</div>
          <h2>${skill.label}在线</h2>
          <p>${skill.desc}。我会结合你的计划、完成率和训练记录回答，不套模板。</p>
        </div>
      </div>
      <div class="coach-welcome-status">
        <span><strong>${weekSessions}</strong> 本周完成</span>
        <span><strong>${ratio}%</strong> 周目标</span>
        <span><strong>第 ${currentPlanWeekNumber()}</strong> 计划周</span>
      </div>
      <div class="coach-starter-grid">
        ${skill.starters.map((text, index) => `
          <button class="coach-starter" onclick="app.sendChat('${text.replace(/'/g, "\\'")}')">
            <span>${String(index + 1).padStart(2, "0")}</span>
            <strong>${text}</strong>
            <i>→</i>
          </button>
        `).join("")}
      </div>
      ${state.plan ? `
        <div class="coach-plan-context">
          <div class="grow">
            <div class="coach-plan-kicker">当前计划</div>
            <strong>${esc(state.plan.title)}</strong>
            <small>第 ${state.plan.version} 版 · 本周 ${weekSessions}/${Math.max(1, state.profile.weeklyDays)} 练 · 完成率 ${ratio}%</small>
          </div>
          <button class="coach-plan-adjust" onclick="app.startPlanAdjustment('coach')">和教练调整</button>
        </div>
      ` : ""}
      ${state.pro ? "" : `
        <button class="coach-pro-note" onclick="app.openPaywall()">
          <span>想要更深入的远程 AI 分析？</span>
          <strong>了解 Pro →</strong>
        </button>
      `}
    </section>
  `;

  return `
    <div class="chat-screen coach-premium">
      <header class="coach-topbar">
        <div class="coach-identity">
          <div class="coach-avatar-lg">AI</div>
          <div class="grow">
            <div class="coach-eyebrow">练途 AI</div>
            <div class="coach-title">${activeAdjustment ? "计划调整教练" : "AI 教练"}</div>
            <div class="coach-status"><i></i>${activeAdjustment ? "正在听你说" : "在线 · 结合你的训练数据"}</div>
          </div>
        </div>
        ${state.chats.length && !activeAdjustment ? `<button class="coach-clear" onclick="app.clearCoachChat()">清空</button>` : ""}
      </header>

      ${activeAdjustment ? coachAdjustmentBanner(adjustment) : `
        <div class="coach-skill-bar coach-skill-bar-premium">
          ${Object.entries(skills).map(([key, item]) => `
            <button class="coach-skill ${state.coachSkill === key ? "active" : ""}" onclick="app.setCoachSkill('${key}')">
              <span>${item.icon}</span>${item.label}
            </button>
          `).join("")}
        </div>
      `}

      <div class="chat-scroll coach-thread-scroll" id="chat-scroll">
        <div class="coach-thread ${state.chats.length ? "" : "coach-thread-empty"}">
          ${state.chats.length ? state.chats.map(coachMessageMarkup).join("") : welcome}
        </div>
      </div>

      <div class="coach-composer-wrap">
        ${state.chats.length ? `
          <div class="coach-quick-replies">
            ${coachQuickReplies(adjustment, suggestions)}
          </div>
        ` : ""}
        <div class="coach-composer">
          <input id="chat-input" type="text" maxlength="500" placeholder="${placeholder}" onkeydown="if(event.key==='Enter'){app.sendChat()}">
          <button class="coach-send" onclick="app.sendChat()" aria-label="发送">↑</button>
        </div>
      </div>
    </div>
  `;
}
