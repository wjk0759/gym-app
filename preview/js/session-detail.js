/* FitAI Web Preview page module: session-detail */

function sessionScreen() {
  const saved = state.sessions.find((item) => item.id === state.sessionId);
  const creating = !!state.sessionCreating && !!state.sessionDraft;
  if (!saved && !creating) return home();
  const session = state.sessionEditing && state.sessionDraft ? state.sessionDraft : (saved || state.sessionDraft);
  const volume = session.items.reduce((sum, item) => sum + item.weight * item.reps * item.sets, 0);

  if (state.sessionEditing) {
    return `
      <div class="stack">
        ${headerBack(creating ? "记录训练" : "编辑训练记录", "app.sessionCancel()")}
        <div class="card">
          <div class="between" style="margin-bottom:10px">
            <div class="tiny faint">记录日期</div>
            <div class="tiny accent">${dateLabel(sessionDateKey(session))}</div>
          </div>
          <div class="form-label">训练名称</div>
          <input type="text" maxlength="40" value="${esc(String(session.title || "").slice(0, 40))}" onchange="app.sessionField('title', this.value)">
          <div class="form-label" style="margin-top:10px">时长（分钟）</div>
          <input type="number" min="1" max="300" value="${session.duration}" onchange="app.sessionField('duration', this.value)">
          <div class="form-label" style="margin-top:10px">训练感受</div>
          <div class="seg">
            ${[1, 2, 3, 4, 5].map((value) => `
              <button class="${session.feeling === value ? "active" : ""}" onclick="app.sessionFeeling(${value})">
                ${["😫", "😕", "😐", "🙂", "💪"][value - 1]}
              </button>
            `).join("")}
          </div>
          <div class="between" style="margin-top:12px">
            <div class="form-label" style="margin:0">训练心得</div>
            <div class="tiny faint field-counter" id="session-notes-count">${String(session.notes || "").slice(0, 300).length}/300</div>
          </div>
          <textarea rows="3" maxlength="300" onchange="app.sessionField('notes', this.value)" oninput="updateFieldCounter('session-notes-count', this.value, 300)" placeholder="今天状态、动作感受…">${esc((session.notes || "").slice(0, 300))}</textarea>
        </div>

        ${session.items.length ? session.items.map((item, index) => `
          <div class="card">
            <div class="between">
              <div class="h3">${esc(item.name)}</div>
              <button class="trash-btn" onclick="app.sessionDeleteItem(${index})">🗑</button>
            </div>
            <div class="row gap8" style="margin-top:10px">
              <div class="grow">
                <div class="tiny faint">重量 kg</div>
                <input type="number" min="0" step="0.5" value="${item.weight}" onchange="app.sessionItem(${index}, 'weight', this.value)">
              </div>
              <div class="grow">
                <div class="tiny faint">次数</div>
                <input type="number" min="0" value="${item.reps}" onchange="app.sessionItem(${index}, 'reps', this.value)">
              </div>
              <div class="grow">
                <div class="tiny faint">组数</div>
                <input type="number" min="1" value="${item.sets}" onchange="app.sessionItem(${index}, 'sets', this.value)">
              </div>
            </div>
          </div>
        `).join("") : `<div class="tiny muted" style="padding:2px 2px 0">还没有动作。可以点下方「添加动作」从动作库补录。</div>`}

        <button class="btn btn-secondary" onclick="app.sessionAddItem()">＋ 添加动作</button>
        <button class="btn btn-primary" onclick="app.sessionSave()">${creating ? "保存训练记录" : "保存修改"}</button>
        ${creating ? "" : `<button class="btn btn-danger" onclick="app.deleteSession()">删除这条记录</button>`}
      </div>
    `;
  }

  return `
    <div class="stack">
      ${headerBack("训练详情")}
      <div class="card">
        <div class="between">
          <div>
            <div class="h2">${esc(String(session.title || "").slice(0, 40))}</div>
            <div class="tiny muted" style="margin-top:4px">${session.date}</div>
          </div>
          <button class="link" onclick="app.sessionEdit()">编辑</button>
        </div>
        <div class="row gap8" style="margin-top:12px">
          <div class="metric"><div class="value">${session.duration}</div><div class="label">分钟</div></div>
          <div class="metric"><div class="value">${session.items.reduce((sum, item) => sum + item.sets, 0)}</div><div class="label">组数</div></div>
          <div class="metric"><div class="value">${Math.round(volume)}</div><div class="label">容量 kg</div></div>
        </div>
        ${session.notes ? `<div class="tiny muted session-notes-preview" style="margin-top:12px;line-height:1.6"><span class="accent">训练心得</span><br>${esc(String(session.notes).slice(0, 300))}</div>` : ""}
      </div>
      <div class="card">
        ${session.items.map((item) => `
          <div class="set-line">
            <span class="small">${item.name}</span>
            <span class="tiny muted">${item.sets} 组 × ${item.reps}${item.weight ? " · " + item.weight + "kg" : " · 自重"}</span>
          </div>
        `).join("")}
      </div>
      <button class="btn btn-danger" onclick="app.deleteSession()">删除这条记录</button>
    </div>
  `;
}

/* ---------------- Workout history ---------------- */

