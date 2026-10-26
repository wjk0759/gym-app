/* FitAI Web Preview page module: settings */

function settingsScreen() {
  const phone = state.authPhone || "13800138000";
  const maskedPhone = phone.length === 11 ? `${phone.slice(0, 3)}****${phone.slice(-4)}` : "已登录";

  return `
    <div class="stack">
      ${headerBack("设置")}

      <div class="card">
        <div class="h3">账号与安全</div>
        <div class="tiny muted" style="margin-top:3px">登录账号 · ${esc(maskedPhone)}</div>
      </div>

      <div class="section-kicker">训练设置</div>

      <div class="card">
        <div class="between"><div class="h3">训练提醒</div><span class="tiny faint">每周重复</span></div>
        <div class="row gap8" style="margin-top:10px">
          <input type="time" value="${state.reminder}" id="reminder-time">
          <button class="btn btn-secondary btn-sm" style="flex-shrink:0;white-space:nowrap" onclick="app.saveReminder()">保存</button>
        </div>
        <div class="tiny faint" style="margin-top:8px">iOS 静音和专注模式可能影响提醒，请在系统设置中允许通知。</div>
      </div>

      <div class="card">
        <div class="between">
          <div>
            <div class="h3">Apple 健康</div>
            <div class="tiny muted" style="margin-top:3px">读取体重，写入完成的训练</div>
          </div>
          <span class="accent">♥</span>
        </div>
        <button class="btn btn-secondary" style="margin-top:10px" onclick="app.mockHealth()">连接 Apple 健康</button>
      </div>

      <div class="card">
        <div class="between">
          <div class="h3">训练偏好</div>
          <div class="tiny faint">${state.disliked.length} 个</div>
        </div>
        <div class="tiny muted" style="margin-top:6px">删除过的动作会被记住，下次生成尽量避开。</div>
        ${state.disliked.length ? `<button class="btn btn-secondary" style="margin-top:10px" onclick="app.clearPreferences()">清除训练偏好</button>` : ""}
      </div>

      <div class="section-kicker">数据与隐私</div>

      <div class="card">
        <div class="list-row" onclick="app.openLegal('privacy')"><span class="grow small">隐私政策</span><span class="faint">›</span></div>
        <div class="list-row" onclick="app.openLegal('terms')"><span class="grow small">用户协议</span><span class="faint">›</span></div>
        <div class="list-row" onclick="app.exportData()"><span class="grow small">导出我的数据</span><span class="faint">›</span></div>
        <div class="list-row" onclick="app.openLegal('ai')"><span class="grow small">生成式 AI 备案信息</span><span class="faint">›</span></div>
        <div class="tiny faint" style="margin-top:8px">本产品不提供医疗诊断。孕期、术后、心血管疾病或关节急性疼痛，请先咨询医生。</div>
        <div class="tiny faint" style="margin-top:6px">练途 Web Preview · v0.1</div>
      </div>

      <div class="section-kicker">账号操作</div>

      <div class="card">
        <button class="btn btn-danger" onclick="app.previewLogout()">退出登录</button>
        <div class="tiny faint" style="margin-top:9px;text-align:center">退出登录不会删除训练计划、训练记录或身体数据。</div>
      </div>
    </div>
  `;
}

