/* FitAI Web Preview page module: plan-owned exercise training analytics. */

function trainingDataCandidates() {
  return Object.keys(EX)
    .map((slug) => {
      const item = exerciseAnalyticsItem(slug);
      const stats = item ? exerciseAnalyticsStats(item) : null;
      return {
        slug,
        name: EX[slug].name,
        muscle: EX[slug].muscle,
        sessions: stats?.sessions || 0,
        stats
      };
    })
    .sort((left, right) => right.sessions - left.sessions || left.name.localeCompare(right.name));
}

function trainingDataScreen() {
  const candidates = trainingDataCandidates();
  const fallback = candidates.find((item) => item.sessions > 0)?.slug || candidates[0]?.slug || "goblet_squat";
  const selectedSlug = EX[state.trainingDataSlug] ? state.trainingDataSlug : fallback;
  const selected = candidates.find((item) => item.slug === selectedSlug) || candidates[0];
  if (!selected) return `<div class="stack">${headerBack("动作训练数据")}</div>`;
  const item = exerciseAnalyticsItem(selected.slug);
  return `
    <div class="stack training-data-screen">
      ${headerBack("动作训练数据")}

      <section class="training-data-intro">
        <div class="compose-kicker">计划 · 训练数据</div>
        <div class="h2">按动作看趋势</div>
        <p>基于实际训练记录，集中查看容量、单组最重和 1RM 预测。</p>
      </section>

      <div class="training-action-rail" aria-label="选择动作">
        ${candidates.map((candidate) => `
          <button class="training-action-chip ${candidate.slug === selected.slug ? "active" : ""}" onclick="app.openTrainingData('${candidate.slug}')">
            <span>${esc(candidate.name)}</span>
            <small>${candidate.sessions ? `${candidate.sessions} 次` : "暂无"}</small>
          </button>
        `).join("")}
      </div>

      ${exerciseAnalyticsPanel(item)}
    </div>
  `;
}
