/* FitAI Web Preview page module: body-analysis */

function bodyAnalysisScreen() {
  const analysis = state.bodyAnalysis;
  return `
    <div class="stack">
      ${headerBack("体型照片分析")}
      <div class="card">
        <div class="h3">拍一张全身或半身照</div>
        <div class="tiny muted" style="margin-top:6px;line-height:1.6">分析只给训练重点，不判断体脂率、不诊断体态。照片不写入训练记录。</div>
      </div>

      <div class="photo-area ${state.bodyPhoto ? "filled" : ""}">
        <div class="big">${ICONS.camera}</div>
        <div class="small">${state.bodyPhoto ? "已选择体型照片" : "拍照或选择一张照片"}</div>
        <div class="tiny">${state.bodyPhoto ? "确认授权后即可分析" : "正面或侧面，光线充足"}</div>
      </div>

      <div class="row gap8">
        <button class="btn btn-secondary btn-sm grow" onclick="app.bodyMockPhoto()">模拟拍照</button>
        <button class="btn btn-secondary btn-sm grow" onclick="app.bodyMockPhoto()">从相册选择</button>
      </div>

      <div class="card">
        <div class="between">
          <span class="small">我同意将照片用于本次训练分析</span>
          <button class="chip ${state.bodyConsent ? "active" : ""}" onclick="app.bodyConsentToggle()">
            ${state.bodyConsent ? "已同意" : "未同意"}
          </button>
        </div>
        <div class="tiny faint" style="margin-top:7px">预览版不上传照片；真实 App 在远程模式下会做一次性分析，不保存原图。</div>
      </div>

      <button class="btn btn-primary" onclick="app.bodyAnalyze()">分析体型并生成训练建议</button>

      ${analysis ? `
        <div class="card">
          <div class="between">
            <div class="h3">分析结果</div>
            <div class="tiny accent">参考置信度 ${Math.round(analysis.confidence * 100)}%</div>
          </div>
          <div class="small" style="margin-top:8px;line-height:1.6">${analysis.summary}</div>
          <div class="tiny muted" style="margin-top:10px">建议训练重点</div>
          <div class="chips" style="margin-top:6px">
            ${analysis.focus.map((item) => `<span class="chip active">${item}</span>`).join("")}
          </div>
          <div style="margin-top:12px">
            ${analysis.recommendations.map((item) => `<div class="list-row"><span class="dot"></span><span class="small muted grow">${item}</span></div>`).join("")}
          </div>
          <div class="tiny faint" style="margin-top:9px">照片分析仅用于训练重点参考，不构成体脂率、体态诊断或医疗建议。</div>
          <button class="btn btn-primary" style="margin-top:12px" onclick="app.applyBodyAnalysis()">
            ${analysis.applied ? "已应用到当前计划" : "应用到训练计划"}
          </button>
        </div>
      ` : ""}

      <div class="tiny faint" style="line-height:1.6">体型照片属于敏感个人信息。请只上传你本人的照片；不要上传他人或未成年人照片。</div>
    </div>
  `;
}

