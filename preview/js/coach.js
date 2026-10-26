/* ---------------- Coach ---------------- */

function coachScreen() {
  const skills = {
    trainer: {
      label: "健身教练",
      icon: "◎",
      desc: "训练安排、动作替代和负荷调整",
      starters: ["今天练什么？", "没有器械怎么替代？", "训练后很酸正常吗？", "下次怎么加重量？"],
      placeholder: "问问训练、动作或计划…"
    },
    rehab: {
      label: "康复师",
      icon: "✚",
      desc: "疼痛分级、恢复期活动和就医提示",
      starters: ["膝盖不舒服还能练吗？", "训练后腰痛怎么恢复？", "扭伤后多久能训练？", "恢复期能做什么动作？"],
      placeholder: "描述疼痛位置、时间和程度…"
    },
    nutrition: {
      label: "营养师",
      icon: "◇",
      desc: "热量、蛋白质和膳食结构建议",
      starters: ["每天吃多少蛋白质？", "减脂怎么安排三餐？", "训练后吃什么？", "外卖怎么选更健康？"],
      placeholder: "问问热量、蛋白质或饮食安排…"
    }
  };
  const skill = skills[state.coachSkill] || skills.trainer;
  const suggestions = skill.starters.slice(0, 3);
  const weekSessions = currentWeekSessions().length;
  const ratio = Math.min(100, Math.round((weekSessions / Math.max(1, state.profile.weeklyDays)) * 100));
  return `
    <div class="chat-screen">
      <div class="chat-head">
        <div class="h3">AI 教练</div>
        <div class="tiny muted" style="margin-top:4px">健身教练 · 康复师 · 营养师</div>
      </div>

      <div class="coach-skill-bar">
        ${Object.entries(skills).map(([key, item]) => `
          <button class="coach-skill ${state.coachSkill === key ? "active" : ""}" onclick="app.setCoachSkill('${key}')">
            <span>${item.icon}</span>${item.label}
          </button>
        `).join("")}
      </div>

      <div class="chat-scroll" id="chat-scroll">
        ${state.chats.length === 0 ? `
          <div class="card" style="margin-top:12px">
            <div class="row gap10" style="margin-bottom:10px">
              <div class="coach-avatar">AI</div>
              <div>
                <div class="h3">${skill.label}在线</div>
                <div class="tiny faint" style="margin-top:2px">${skill.desc}</div>
              </div>
            </div>
            <div class="small muted" style="line-height:1.65">涉及疼痛、孕期、术后等情况，会建议你就医，而不是继续加练。</div>
          </div>

          ${state.pro ? "" : `
            <div class="card tight" style="margin-top:12px;cursor:pointer" onclick="app.openPaywall()">
              <div class="between">
                <div>
                  <div class="small strong">解锁 DeepSeek AI ${skill.label}</div>
                  <div class="tiny faint" style="margin-top:3px">当前使用本地规则建议；Pro 会员可使用完整 AI Skill。</div>
                </div>
                <span class="accent">›</span>
              </div>
            </div>
          `}

          <div class="h3" style="margin:16px 2px 2px">快速开始</div>
          <div class="coach-starters">
            ${skill.starters.map((text) => `<button class="suggestion-card" onclick="app.sendChat('${text}')">${text}</button>`).join("")}
          </div>

          <div class="card tight" style="margin-top:12px">
            <div class="between">
              <div class="small strong">本周状态</div>
              <div class="tiny faint">第 ${currentPlanWeekNumber()} 周</div>
            </div>
            <div class="tiny muted" style="margin-top:5px">${weekSessions}/${state.profile.weeklyDays} 练 · 完成率 ${ratio}%</div>
            <button class="link" style="margin-top:9px" onclick="app.sendChat('帮我复盘一下本周训练，接下来应该怎么调整？')">让教练复盘本周 →</button>
          </div>
        ` : state.chats.map((message) => `
          <div class="chat-row ${message.role}">
            <div class="bubble ${message.role} ${message.safety ? "safety" : ""}">
              ${message.safety ? '<span class="safety-label">⚠ 需要就医评估</span>' : ""}
              ${esc(message.text)}
            </div>
          </div>
        `).join("")}

        ${state.chats.length ? `
          <div class="suggestions" style="margin-top:10px">
            ${suggestions.map((text) => `<button class="suggestion" onclick="app.sendChat('${text.replace(/'/g, "\\'")}')">${text}</button>`).join("")}
          </div>
        ` : ""}
      </div>

      <div class="composer">
        <div class="composer-row">
          <input id="chat-input" type="text" maxlength="500" placeholder="${skill.placeholder}" onkeydown="if(event.key==='Enter'){app.sendChat()}">
          <button class="send-btn" onclick="app.sendChat()">↑</button>
        </div>
      </div>
    </div>
  `;
}

