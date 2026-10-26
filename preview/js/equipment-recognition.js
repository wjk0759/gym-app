/* FitAI Web Preview page module: equipment-recognition */

function equipmentCameraScreen() {
  return photoCaptureScreen("equipment");
}

function foodPhotoCameraScreen() {
  return photoCaptureScreen("food");
}

function equipmentRecognitionScreen() {
  const candidates = state.equipRecognitionCandidates || [];
  return `
    <div class="stack">
      ${headerBack("器械识别", "app.equipmentTabOpen()")}
      <div class="card recognition-head-card">
        <div class="recognition-thumb">${state.equipRecognitionPhoto ? "🏋" : "📷"}</div>
        <div class="grow">
          <div class="tiny faint">照片识别</div>
          <div class="h2">识别你的器械</div>
          <div class="tiny muted">从最匹配到相似候选</div>
          <button class="link" style="margin-top:8px" onclick="app.equipmentRecognitionPhoto()">${state.equipRecognitionPhoto ? "重新拍照" : "拍照或选图"}</button>
        </div>
      </div>

      <div class="between" style="padding:0 2px">
        <div class="h3">匹配器械</div>
        <div class="tiny faint">${candidates.length} 个候选</div>
      </div>

      ${candidates.length ? candidates.map((candidate) => `
        <div class="card tight">
          <div class="between">
            <div>
              <div class="small strong">${esc(EX[candidate.slug].name)}</div>
              <div class="tiny faint">${EX[candidate.slug].muscle} · ${EX[candidate.slug].equip}</div>
            </div>
            <div class="tiny accent">${Math.round(candidate.confidence * 100)}%</div>
          </div>
          <button class="link" style="margin-top:8px" onclick="app.equipmentRecognitionSave('${candidate.slug}')">＋ 加入已选动作</button>
        </div>
      `).join("") : `
        <div class="card recognition-empty">
          <div class="h3">${state.equipRecognitionPhoto ? "暂未识别到动作库中的器械" : "先拍一张器械照片"}</div>
          <div class="tiny muted" style="margin-top:8px;line-height:1.7">${state.equipRecognitionPhoto ? "请拍摄完整器械。边缘灰色物体、遮挡严重或只露出局部的照片，可能无法辨别。" : "支持常见固定器械、绳索、杠铃与哑铃。照片只用于本次识别，不保存。"}</div>
          <button class="btn btn-secondary" style="margin-top:14px" onclick="app.equipmentRecognitionPhoto()">${state.equipRecognitionPhoto ? "重新拍照" : "模拟拍照"}</button>
        </div>
      `}
    </div>
  `;
}

