/* FitAI Web Preview page module: history */

function historyScreen() {
  const sessions = state.sessions;
  const totalVolume = sessions.reduce((sum, session) => sum + session.volume, 0);
  const totalMinutes = sessions.reduce((sum, session) => sum + session.duration, 0);
  return `
    <div class="stack">
      ${headerBack("训练记录")}
      <div class="card">
        <div class="h2">训练数据</div>
        <div class="row gap8" style="margin-top:12px">
          <div class="metric"><div class="value">${sessions.length}</div><div class="label">训练次数</div></div>
          <div class="metric"><div class="value">${Math.round(totalVolume).toLocaleString()}</div><div class="label">总容量 kg</div></div>
          <div class="metric"><div class="value">${totalMinutes}</div><div class="label">总分钟</div></div>
        </div>
        <div class="tiny faint" style="margin-top:10px;line-height:1.6">训练容量 = 组数 × 重量 × 次数，用来观察长期趋势，不是训练好坏评分。</div>
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:8px">全部训练</div>
        ${sessions.length ? sortedSessionsNewest().map((session) => sessionListRow(session, "home")).join("") : `<div class="tiny muted" style="padding:10px 0">还没有训练记录。</div>`}
      </div>
    </div>
  `;
}

