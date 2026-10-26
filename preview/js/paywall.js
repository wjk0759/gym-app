/* ---------------- Paywall ---------------- */

function paywallScreen() {
  return `
    <div class="stack">
      ${headerBack("练途 Pro")}
      <div class="card hero center">
        <div class="crown">${ICONS.crown}</div>
        <div class="h2">把 AI 教练带在身边</div>
        <div class="small muted" style="margin-top:6px">解锁 DeepSeek AI 计划、三种专业 Skill 与完整教练对话。</div>
      </div>

      <div class="card">
        ${[
          ["DeepSeek AI 计划生成与调整", "✦"],
          ["健身教练、康复师、营养师 AI Skills", "◎"],
          ["周复盘、训练偏好记忆与动作替代", ICONS.coach],
          ["器械拍照识别与饮食记录", ICONS.camera]
        ].map(([text, icon]) => `
          <div class="benefit-row"><span>${icon}</span><span>${text}</span><span class="check">✓</span></div>
        `).join("")}
      </div>

      ${state.pro ? `
        <div class="card center">
          <div class="h3 accent">✓ 已订阅练途 Pro</div>
          <div class="tiny muted" style="margin-top:5px">所有 Pro 功能已解锁。</div>
        </div>
      ` : `
        <div class="stack" style="gap:9px">
          <button class="plan-option ${state.paywallPlan === "monthly" ? "selected" : ""}" onclick="app.selectPaywall('monthly')">
            <div style="text-align:left"><div class="title">月度订阅</div><div class="desc">随时取消</div></div>
            <div class="price">¥28 / 月</div>
          </button>
          <button class="plan-option ${state.paywallPlan === "yearly" ? "selected" : ""}" onclick="app.selectPaywall('yearly')">
            <div style="text-align:left">
              <div class="row gap6"><div class="title">年度订阅</div><span class="save-badge">推荐 · 省 41%</span></div>
              <div class="desc">约 ¥16.5 / 月</div>
            </div>
            <div class="price">¥198 / 年</div>
          </button>
        </div>
        <button class="btn btn-primary" style="margin-top:12px" onclick="app.buy(state.paywallPlan)">立即订阅 · ${state.paywallPlan === "yearly" ? "¥198 / 年" : "¥28 / 月"}</button>
      `}

      <button class="link" style="display:block;margin:8px auto" onclick="app.restorePurchase()">恢复购买</button>
      <div class="tiny faint center" style="line-height:1.6">订阅会自动续期，可随时在系统设置中取消。</div>
    </div>
  `;
}

