/* FitAI Web Preview module: shared camera capture UI for food and equipment. */

function photoCaptureScreen(context) {
  const isFood = context === "food";
  const title = isFood ? "拍摄餐食" : "拍摄器械";
  const icon = isFood ? ICONS.utensils : ICONS.dumbbell;
  const heading = isFood ? "把整餐放进画面" : "把器械完整放进画面";
  const hint = isFood ? "尽量俯拍，让食物完整进入画面" : "避免只拍到局部、边缘或严重遮挡";
  const closeAction = "app.back()";
  const captureAction = isFood ? "app.foodPhotoCapture()" : "app.equipmentCapturePhoto()";

  return `
    <div class="photo-capture-screen">
      <div class="camera-top">
        <button class="camera-icon-btn" onclick="${closeAction}" aria-label="退出拍摄">×</button>
        <div class="camera-title">${title}</div>
        <button class="camera-icon-btn camera-album-btn" onclick="${captureAction}" aria-label="从相册选择">相册</button>
      </div>

      <div class="camera-view">
        <span class="camera-corner top-left" aria-hidden="true"></span>
        <span class="camera-corner top-right" aria-hidden="true"></span>
        <span class="camera-corner bottom-left" aria-hidden="true"></span>
        <span class="camera-corner bottom-right" aria-hidden="true"></span>
        <div class="camera-view-icon">${icon}</div>
        <div class="camera-view-title">${heading}</div>
        <div class="camera-view-hint">${hint}</div>
      </div>

      <div class="camera-bottom">
        <button class="camera-shutter" onclick="${captureAction}" aria-label="拍照">
          <span></span>
        </button>
        <div class="camera-shutter-label">拍照 · 照片仅用于本次识别</div>
      </div>
    </div>
  `;
}
