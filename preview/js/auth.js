/* FitAI Web Preview page module: login and legal */

let loginFocusMode = false;
let loginFocusInputId = "";

function loginScreen() {
  const phoneMode = state.authMode === "phone";
  return `
    <div class="login-page${loginFocusMode ? " login-focus" : ""}">
      <div class="login-brand">
        <div class="login-mark">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M4 9v6M7 7v10M17 7v10M20 9v6M7 12h10" />
          </svg>
        </div>
        <div class="login-brand-copy">
          <div class="login-brand-name">练途</div>
          <div class="login-brand-sub"><span class="login-live-dot"></span>AI 私人健身教练</div>
        </div>
      </div>

      <div class="login-intro">
        <div class="login-kicker">WELCOME BACK</div>
        <h1>回到你的训练节奏</h1>
      </div>

      <div class="login-card">
        <div class="login-seg" data-mode="${phoneMode ? "phone" : "password"}">
          <button class="${phoneMode ? "active" : ""}" onclick="app.previewAuthMode('phone')">手机验证码</button>
          <button class="${!phoneMode ? "active" : ""}" onclick="app.previewAuthMode('password')">账号密码</button>
        </div>

        ${phoneMode ? `
          <div class="login-field">
            <div class="login-input">
              <span class="login-prefix">+86</span>
              <span class="login-input-divider"></span>
              <input id="login-phone" type="tel" inputmode="numeric" maxlength="11" autocomplete="tel" placeholder="手机号" value="${esc(state.authPhone)}" onfocus="app.previewAuthFocus(this)" oninput="app.previewAuthField('authPhone', this.value)">
            </div>
          </div>
          <div class="login-field">
            <div class="login-input">
              <input id="login-code" type="tel" inputmode="numeric" maxlength="6" autocomplete="one-time-code" placeholder="6 位验证码" value="${esc(state.authCode)}" onfocus="app.previewAuthFocus(this)" oninput="app.previewAuthField('authCode', this.value)">
              <button class="code-btn" onclick="app.previewSendCode()">获取验证码</button>
            </div>
          </div>
          <div class="field-hint ${state.authDevCode ? "warning" : ""}">${state.authDevCode ? `开发验证码 ${state.authDevCode}，已自动填入` : "验证码仅用于本次登录"}</div>
        ` : `
          <div class="login-field">
            <div class="login-input">
              <input id="login-account" type="text" maxlength="50" autocomplete="username" placeholder="手机号或用户名" value="${esc(state.authAccount)}" onfocus="app.previewAuthFocus(this)" oninput="app.previewAuthField('authAccount', this.value)">
            </div>
          </div>
          <div class="login-field">
            <div class="login-input">
              <input id="login-password" type="password" maxlength="64" autocomplete="current-password" placeholder="密码" value="${esc(state.authPassword)}" onfocus="app.previewAuthFocus(this)" oninput="app.previewAuthField('authPassword', this.value)">
            </div>
          </div>
          <div class="row between">
            <div class="field-hint">密码至少 8 位，含字母和数字</div>
            <button class="link compact-link" onclick="app.previewForgotPassword()">忘记密码？</button>
          </div>
        `}

        ${state.authError ? `<div class="login-error">${esc(state.authError)}</div>` : ""}

        <button class="btn btn-primary login-submit" onclick="app.previewLogin()">
          <span>登录</span>
          <span class="login-submit-arrow" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="M5 12h13M13.5 6.5 19 12l-5.5 5.5"/></svg>
          </span>
        </button>
      </div>

      <div class="login-consent" onclick="app.previewAuthConsent()" role="button" tabindex="0" aria-label="同意用户协议与隐私政策" aria-pressed="${state.authConsent}">
        <span class="consent-check ${state.authConsent ? "checked" : ""}">${state.authConsent ? "✓" : ""}</span>
        <div class="login-consent-copy">
          我已阅读并同意<button class="link" onclick="event.stopPropagation();app.openLegal('terms')">《用户协议》</button>和<button class="link" onclick="event.stopPropagation();app.openLegal('privacy')">《隐私政策》</button>，且已年满 14 周岁
        </div>
      </div>

      <div class="login-icon-row">
        <button class="social-icon-btn apple" onclick="app.previewSocial('Apple')" aria-label="Apple 登录">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M16.7 12.9c0-2 1.6-3 1.7-3.1-.9-1.3-2.3-1.5-2.8-1.5-1.2-.1-2.3.7-2.9.7-.6 0-1.5-.7-2.5-.7-1.3 0-2.5.8-3.2 2-1.4 2.4-.4 5.9 1 7.8.7 1 1.5 2 2.6 2 1 0 1.4-.6 2.6-.6s1.5.6 2.5.6c1.1 0 1.8-.9 2.5-1.9.8-1.1 1.1-2.2 1.1-2.3-.1 0-2.1-.8-2.1-3.1z"/>
            <path d="M14.6 6.9c.6-.7 1-1.7.9-2.7-.9 0-1.9.6-2.5 1.3-.5.6-1 1.6-.9 2.6 1 .1 1.9-.5 2.5-1.2z"/>
          </svg>
        </button>
        <button class="social-icon-btn wechat" onclick="app.previewSocial('微信')" aria-label="微信登录">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M8.691 2.188C3.891 2.188 0 5.476 0 9.53c0 2.212 1.17 4.203 3.002 5.55a.59.59 0 0 1 .213.665l-.39 1.48c-.019.07-.048.141-.048.213 0 .163.13.295.29.295a.326.326 0 0 0 .167-.054l1.903-1.114a.864.864 0 0 1 .717-.098 10.16 10.16 0 0 0 2.837.403c.276 0 .543-.027.811-.05-.857-2.578.157-4.972 1.932-6.446 1.703-1.415 3.882-1.98 5.853-1.838-.576-3.583-4.196-6.348-8.596-6.348zM5.785 5.991c.642 0 1.162.529 1.162 1.18a1.17 1.17 0 0 1-1.162 1.178A1.17 1.17 0 0 1 4.623 7.17c0-.651.52-1.18 1.162-1.18zm5.813 0c.642 0 1.162.529 1.162 1.18a1.17 1.17 0 0 1-1.162 1.178 1.17 1.17 0 0 1-1.162-1.178c0-.651.52-1.18 1.162-1.18zm5.34 2.867c-1.797-.052-3.746.512-5.28 1.786-1.72 1.428-2.687 3.72-1.78 6.22.942 2.453 3.666 4.229 6.884 4.229.826 0 1.622-.12 2.361-.336a.722.722 0 0 1 .598.082l1.584.926a.272.272 0 0 0 .14.047c.134 0 .24-.111.24-.247 0-.06-.023-.12-.038-.177l-.327-1.233a.582.582 0 0 1-.023-.156.49.49 0 0 1 .201-.398C23.024 18.48 24 16.82 24 14.98c0-3.21-2.931-5.837-6.656-6.088V8.89c-.135-.01-.27-.027-.407-.03zm-2.53 3.274c.535 0 .969.44.969.982a.976.976 0 0 1-.969.983.976.976 0 0 1-.969-.983c0-.542.434-.982.97-.982zm4.844 0c.535 0 .969.44.969.982a.976.976 0 0 1-.969.983.976.976 0 0 1-.969-.983c0-.542.434-.982.969-.982z"/>
          </svg>
        </button>
        <button class="social-icon-btn qq" onclick="app.previewSocial('QQ')" aria-label="QQ 登录">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M21.395 15.035a40 40 0 0 0-.803-2.264l-1.079-2.695c.001-.032.014-.562.014-.836C19.526 4.632 17.351 0 12 0S4.474 4.632 4.474 9.241c0 .274.013.804.014.836l-1.08 2.695a39 39 0 0 0-.802 2.264c-1.021 3.283-.69 4.643-.438 4.673.54.065 2.103-2.472 2.103-2.472 0 1.469.756 3.387 2.394 4.771-.612.188-1.363.479-1.845.835-.434.32-.379.646-.301.778.343.578 5.883.369 7.482.189 1.6.18 7.14.389 7.483-.189.078-.132.132-.458-.301-.778-.483-.356-1.233-.646-1.846-.836 1.637-1.384 2.393-3.302 2.393-4.771 0 0 1.563 2.537 2.103 2.472.251-.03.581-1.39-.438-4.673"/>
          </svg>
        </button>
      </div>
    </div>
  `;
}

const LEGAL_DOCS = {
  terms: {
    title: "用户协议",
    updated: "2026 年 10 月 25 日",
    intro: "欢迎使用练途。本协议约定你与练途之间关于账号、训练计划、AI 教练、饮食记录和订阅服务的使用规则。请在使用前完整阅读。",
    sections: [
      ["1. 服务内容与边界", "练途提供训练计划、动作说明、训练记录、饮食估算和 AI 对话等功能。这些内容用于一般健身与生活方式参考，不构成医疗诊断、治疗或营养处方。出现胸痛、眩晕、呼吸困难、急性损伤，或处于孕期、术后恢复期时，请先咨询医生。"],
      ["2. 账号注册与安全", "手机号验证通过，或使用微信/QQ 授权后，系统可能为你自动创建账号。请妥善保管验证码、密码与登录设备；发现异常登录时及时退出并修改密码。"],
      ["3. 订阅与自动续费", "练途 Pro 通过 Apple App Store 销售。价格、周期和试用条件以下单页面为准；订阅会自动续期，可在系统设置中取消。取消后，已付费周期内仍可使用 Pro 功能。"],
      ["4. AI 生成内容", "AI 计划与建议基于你填写的档案、器械、训练记录和对话内容生成，可能存在不准确或不适用的情况。请根据身体反应调整，不要将 AI 输出作为医疗依据。"],
      ["5. 使用规范", "不得利用本服务发布违法信息、侵犯他人权益、干扰系统运行或绕过安全限制。因违规导致的账号限制或终止，由用户承担相应责任。"],
      ["6. 知识产权", "App 界面、文本、图形和训练内容的知识产权归练途或授权方所有。未经许可不得复制、出售或用于商业培训。你上传的照片仅用于你主动选择的对应功能。"],
      ["7. 服务变更与终止", "我们可能因产品升级、合规要求或不可抗力调整服务，重大变更会通过 App 内提示。你可以随时停止使用。账号注销与数据删除需由运营方按法律法规和账号安全流程处理。"],
      ["8. 协议更新与联系", "协议更新后会在登录页或 App 内公示。继续使用视为接受更新内容；如不同意，可停止使用。对协议有疑问，可通过 App 内反馈渠道联系我们。"]
    ]
  },
  privacy: {
    title: "隐私政策",
    updated: "2026 年 10 月 25 日",
    intro: "练途重视你的个人信息与身体数据。本政策说明我们收集哪些信息、为什么收集、如何保护，以及你可以如何管理这些信息。",
    sections: [
      ["1. 我们收集的信息", "账号信息（手机号、微信/QQ 标识）；你主动填写的性别、年龄、身高、体重、围度、目标与训练偏好；训练记录、饮食记录、对话内容和器械库；你上传的器械照片、体型照片和食物照片；以及用于安全和故障排查的设备与日志信息。"],
      ["2. 敏感个人信息", "体型照片、食物照片、健康与身体数据可能属于敏感个人信息。我们仅在你主动使用对应功能并同意后处理；你可以拒绝或撤回同意，但相关功能将无法使用。"],
      ["3. 使用目的", "用于生成和调整训练/饮食计划、记录与复盘、提供 AI 教练回答、器械识别、保障账号与服务安全、处理订阅和客服问题。我们不会将健康数据用于广告定向。"],
      ["4. 存储与安全", "数据存储在中华人民共和国境内。我们采用访问控制、传输保护、权限隔离和日志审计等措施，仅在实现目的所需期限内保留；注销或删除后，按法律要求处理。"],
      ["5. 共享与委托处理", "我们不会出售个人信息。为提供短信验证、云托管、AI 推理、支付与登录服务，可能委托合作方处理必要信息，并通过协议约束其用途。除法律要求或取得单独同意外，不向第三方提供。"],
      ["6. 设备权限", "相机和相册用于器械、体型与食物照片；通知用于训练提醒；HealthKit 用于读写你授权的训练与体重数据。你可以在系统设置中随时关闭这些权限。"],
      ["7. 你的权利", "你可以访问、更正和导出个人数据，或撤回授权。账号注销与数据删除需由运营方按法律法规及账号安全流程处理。"],
      ["8. 未成年人保护", "未满 14 周岁的用户应在监护人同意和指导下使用；未满 18 周岁的用户应在监护人知情下使用订阅与训练功能。"],
      ["9. 更新与联系", "隐私政策更新会在 App 内公示。对个人信息处理有疑问，可通过 App 内反馈渠道联系我们。"]
    ]
  },
  ai: {
    title: "生成式 AI 服务说明",
    updated: "2026 年 10 月 25 日",
    intro: "本说明介绍练途中的生成式 AI 能力、内容边界和数据使用方式。",
    sections: [
      ["1. 服务说明", "生成式 AI 用于训练计划、动作替代、饮食建议和教练对话。当前版本可能使用规则引擎或模拟结果，正式模型接入后会更新本说明。"],
      ["2. 不提供医疗诊断", "AI 输出不能替代医生、康复师或营养师的专业意见。出现疼痛、眩晕、胸闷、呼吸困难，或处于孕期、术后恢复期时，请先就医或咨询专业人士。"],
      ["3. 内容局限", "AI 可能产生不准确、不完整或不适用的建议。请结合器械条件、动作能力和身体反应判断，必要时降低负荷或停止训练。"],
      ["4. 数据与模型", "AI 回答会使用你主动提供的档案、训练、饮食和对话信息。我们不会将你的对话用于公开展示；如使用第三方模型服务，将按最小必要原则传输并约束用途。"],
      ["5. 备案与公示", "正式上线前将完成适用的生成式人工智能服务与算法备案，并在 App 内公示模型提供方、备案信息和处理规则。"],
      ["6. 安全反馈", "如果你发现错误、歧视性内容或其他安全问题，请通过 App 内反馈渠道告诉我们，我们会核查并改进。"]
    ]
  }
};

function authConsentDialog() {
  if (!state.authConsentPrompt) return "";
  const provider = state.authConsentProvider;
  return `
    <div class="modal-backdrop auth-consent-backdrop" onclick="if(event.target===this)app.cancelAuthConsent()">
      <section class="auth-consent-dialog" role="dialog" aria-modal="true" aria-labelledby="auth-consent-title">
        <div class="auth-consent-icon" aria-hidden="true">✓</div>
        <div class="h2" id="auth-consent-title">同意协议并登录</div>
        <p class="auth-consent-copy">登录前请确认：你已阅读并同意《用户协议》和《隐私政策》，且已年满 14 周岁。</p>
        <div class="auth-consent-links">
          <button class="link" onclick="app.openLegal('terms')">查看《用户协议》</button>
          <button class="link" onclick="app.openLegal('privacy')">查看《隐私政策》</button>
        </div>
        <button class="btn btn-primary" onclick="app.confirmAuthConsent()">同意并登录</button>
        <button class="btn btn-ghost" onclick="app.cancelAuthConsent()">暂不同意</button>
        ${provider ? `<div class="auth-consent-provider">授权方式：${esc(provider)}登录</div>` : ""}
      </section>
    </div>
  `;
}

function legalModal() {
  const doc = LEGAL_DOCS[state.legalDoc];
  if (!doc) return "";
  return `
    <div class="modal-backdrop" onclick="if(event.target===this)app.closeLegal()">
      <div class="legal-sheet" role="dialog" aria-modal="true" aria-label="${doc.title}">
        <div class="legal-head">
          <div>
            <div class="tiny accent strong">练途 · 协议与隐私</div>
            <div class="h2" style="margin-top:3px">${doc.title}</div>
            <div class="tiny faint" style="margin-top:3px">更新日期：${doc.updated}</div>
          </div>
          <button class="icon-btn" onclick="app.closeLegal()" aria-label="关闭">✕</button>
        </div>
        <div class="legal-body">
          <p class="small muted" style="line-height:1.75;margin:0 0 16px">${doc.intro}</p>
          ${doc.sections.map(([title, body]) => `
            <section class="legal-section">
              <h3>${title}</h3>
              <p>${body}</p>
            </section>
          `).join("")}
          <div class="legal-note">本页为应用内公示文本。正式上线版本将在 App Store 页面与 App 内同步更新。</div>
        </div>
        <button class="btn btn-primary" style="margin-top:14px" onclick="app.closeLegal()">我知道了</button>
      </div>
    </div>
  `;
}


/* Stay in focus mode while using the login card; dismiss on outside taps. */
document.addEventListener("click", (event) => {
  if (!loginFocusMode) return;
  if (event.target.closest(".login-card")) return;
  app.previewAuthBlur();
});
