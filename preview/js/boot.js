/* ---------------- boot ---------------- */

const previewParams = new URLSearchParams(location.search);
if (previewParams.has("tab") || previewParams.has("screen") || previewParams.get("demo") === "1") {
  if (!state.onboarded) {
    state.profile = { ...DEFAULT_PROFILE };
    state.plan = applyEquipmentLibrary(buildPlan(state.profile));
    state.onboarded = true;
  }
  state.authenticated = true;
  state.screen = previewParams.has("screen") ? previewParams.get("screen") : "tabs";
  if (previewParams.has("tab")) state.tab = previewParams.get("tab");
}
if (previewParams.has("session")) {
  const session = state.sessions.find((item) => item.id === previewParams.get("session"));
  if (session) {
    state.onboarded = true;
    state.sessionId = session.id;
    state.sessionDraft = JSON.parse(JSON.stringify(session));
    state.screen = "sessionDetail";
    state.sessionEditing = previewParams.get("editSession") === "1";
  }
}
if (previewParams.get("screen") === "foodPhoto") {
  state.onboarded = true;
  state.foodPhotoImage = true;
  state.foodPhotoItems = foodPhotoMockItems();
  state.foodPhotoConfidence = state.foodPhotoItems.reduce((sum, item) => sum + item.confidence, 0) / state.foodPhotoItems.length;
  state.foodPhotoModel = "local-mock";
}
if (previewParams.has("equipSearch")) {
  state.onboarded = true;
  state.equipSearchQuery = previewParams.get("equipSearch") || "";
  state.screen = "tabs";
  state.tab = "equipment";
}
if (previewParams.has("equipPhoto")) {
  state.onboarded = true;
  state.screen = "equipmentRecognition";
  state.equipRecognitionPhoto = true;
  state.equipRecognitionCandidates = [];
}

render();
