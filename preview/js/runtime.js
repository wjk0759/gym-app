/* FitAI Web Preview module: router render and coach demo responses. */

function renderModalLayer(html = "") {
  const layer = document.getElementById("modal-layer");
  if (!layer) return;
  layer.innerHTML = html;
  layer.classList.toggle("active", !!html);
}

function setupDragScroll() {
  const root = document.getElementById("app");
  if (!root) return;
  enableDragScroll(root);
  root.querySelectorAll(
    ".chat-scroll, .equipment-selection-list, .equipment-filter-scroll, .week-tabs, .suggestions, .coach-skill-bar, .coach-quick-replies, .training-action-rail"
  ).forEach(enableDragScroll);
  setupLibrarySwipeRows();
  containSelectionListScroll();
  setupEquipmentScrollState();
  setupEquipmentLayout();
  syncEquipmentScrollState();
}

/* ---------------- render ---------------- */

let lastRouteKey = "";

function render() {
  if (!state.onboarded) state.screen = "onboarding";
  if (state.onboarded && state.screen === "onboarding") state.screen = "tabs";

  const root = document.getElementById("app");
  if (!root) return;

  const cameraScreen = state.screen === "equipmentCamera" || state.screen === "foodPhotoCamera";
  document.querySelector(".device")?.classList.toggle(
    "camera-mode",
    state.authenticated && cameraScreen
  );
  const selectionOpen = state.authenticated
    && state.screen === "tabs"
    && state.tab === "equipment"
    && state.equipSelectionOpen;
  document.body.classList.toggle("selection-open", selectionOpen);
  document.documentElement.classList.toggle("selection-open", selectionOpen);

  if (!state.authenticated) {
    const loginRoute = "login";
    const loginChanged = lastRouteKey !== loginRoute;
    lastRouteKey = loginRoute;
    root.innerHTML = loginScreen() + legalModal();
    root.className = "app no-tabs" + (loginChanged ? " route-changed" : "");
    document.getElementById("tabbar").innerHTML = "";
    document.getElementById("tabbar").className = "tabbar hidden";
    renderModalLayer("");
    if (loginChanged) {
      requestAnimationFrame(() => {
        root.scrollTop = 0;
        syncEquipmentLayout();
        syncEquipmentScrollState();
      });
    }
    setupDragScroll();
    return;
  }

  const routeKey = [
    state.screen,
    state.tab,
    state.sessionId || "",
    state.equipmentItemId || "",
    state.selectedExercise || ""
  ].join("|");
  const routeChanged = routeKey !== lastRouteKey;
  lastRouteKey = routeKey;

  let html = "";
  if (state.screen === "onboarding") html = onboarding();
  else if (state.screen === "tabs") {
    if (state.tab === "home") html = home();
    else if (state.tab === "plan") html = planScreen();
    else if (state.tab === "coach") html = coachScreen();
    else if (state.tab === "equipment") html = equipmentPickerScreen();
    else html = profileScreen();
  } else if (state.screen === "nutrition") html = nutritionScreen();
  else if (state.screen === "foodAdd") html = foodAddScreen();
  else if (state.screen === "foodCustom") html = foodCustomScreen();
  else if (state.screen === "foodPhoto") html = foodPhotoScreen();
  else if (state.screen === "paywall") html = paywallScreen();
  else if (state.screen === "profileEdit") html = profileEditScreen();
  else if (state.screen === "settings") html = settingsScreen();
  else if (state.screen === "workoutCompose") html = workoutComposeScreen();
  else if (state.screen === "workout") html = workoutScreen();
  else if (state.screen === "sessionDetail") html = sessionScreen();
  else if (state.screen === "sessionExercisePicker") html = equipmentPickerScreen();
  else if (state.screen === "trainingData") html = trainingDataScreen();
  else if (state.screen === "planSchedule") html = planScheduleScreen();
  else if (state.screen === "planReview") html = planReviewScreen();
  else if (state.screen === "periodSchedule") html = periodScreen();
  else if (state.screen === "history") html = historyScreen();
  else if (state.screen === "equipmentLibrary") html = equipmentLibraryScreen();
  else if (state.screen === "equipmentCamera") html = equipmentCameraScreen();
  else if (state.screen === "foodPhotoCamera") html = foodPhotoCameraScreen();
  else if (state.screen === "equipmentRecognition") html = equipmentRecognitionScreen();
  else if (state.screen === "equipmentItem") html = equipmentItemScreen();
  else if (state.screen === "planExercisePicker") html = equipmentPickerScreen();
  else if (state.screen === "bodyAnalysis") html = bodyAnalysisScreen();
  else html = home();

  root.innerHTML = html + legalModal()
    + (state.workoutAdjustOpen && state.screen === "workout" ? workoutAdjustSheet() : "")
    + (state.numberPicker ? numberPickerSheet() : "");
  root.className = "app"
    + (state.screen === "tabs" ? "" : " no-tabs")
    + (state.screen === "workout" ? " workout-mode" : "")
    + (state.screen === "workoutCompose" ? " compose-mode" : "")
    + (state.screen === "planReview" ? " review-mode" : "")
    + (state.screen === "periodSchedule" ? " period-mode" : "")
    + (state.screen === "tabs" && state.tab === "coach" ? " chat-mode" : "")
    + (state.equipSelectionOpen && state.screen === "tabs" && state.tab === "equipment" ? " selection-open" : "")
    + (state.screen === "equipmentCamera" || state.screen === "foodPhotoCamera" ? " camera-mode" : "")
    + (routeChanged ? " route-changed" : "");
  document.getElementById("tabbar").innerHTML = tabbar();
  document.getElementById("tabbar").className = "tabbar" + (state.onboarded && state.screen === "tabs" ? "" : " hidden");
  settleTabIndicator();
  if (routeChanged) {
    requestAnimationFrame(() => {
      root.scrollTop = 0;
      syncEquipmentLayout();
      syncEquipmentScrollState();
    });
  }

  if (state.screen === "tabs" && state.tab === "coach") {
    setTimeout(() => {
      const chat = document.getElementById("chat-scroll");
      if (chat) chat.scrollTop = chat.scrollHeight;
    }, 20);
  }

  const shouldShowGoalEditor = state.authenticated
    && state.onboarded
    && state.screen === "tabs"
    && state.tab === "home"
    && !state.legalDoc
    && state.goalEditorOpen;
  const shouldShowBodyCheckIn = state.authenticated
    && state.onboarded
    && state.screen === "tabs"
    && state.tab === "home"
    && !state.legalDoc
    && (state.bodyCheckInOpen || bodyCheckInDue());
  renderModalLayer(shouldShowGoalEditor
    ? goalDateSheet()
    : shouldShowBodyCheckIn
      ? bodyCheckInSheet(!!state.bodyCheckInOpen)
      : "");

  setupDragScroll();
  setupComposeDrag();
  setupNumberPicker();
}

function coachReply(text, skill = "trainer") {
  if (/胸痛|胸闷|晕|呼吸困难|喘不上气|昏倒/.test(text)) {
    return { text: "你描述的可能是需要立即处理的情况。请马上停止训练，坐下休息；如果症状持续或加重，请立即就医或拨打 120。不要继续做任何高强度动作。", safety: true };
  }
  if (/怀孕|孕期|产后|术后|手术/.test(text)) {
    return { text: "孕期、产后恢复期和术后训练需要专业评估。建议先咨询产科医生或康复师，再决定训练内容。我可以记录状态，但不提供这类训练处方。", safety: true };
  }
  if (/今天|练什么|计划/.test(text)) {
    const period = periodForDate(todayKey());
    if (period) {
      return { text: `今天是经期第 ${period.day} 天，优先恢复。散步、拉伸或低强度训练都可以；如果按计划练，组数减 1 组、负重降到约 80%。腹痛明显、量大或头晕时直接休息。` };
    }
    const day = todayDay();
    if (!day) {
      return { text: "今天没有安排训练，恢复也是计划的一部分。可以散步、拉伸，或者和教练聊聊最近恢复和计划调整。" };
    }
    return { text: `今天建议练「${day.title}」，共 ${day.exercises.length} 个动作：\n${day.exercises.map((item) => `· ${EX[item.slug].name} ${item.sets} 组 × ${item.reps}`).join("\n")}\n如果状态一般，把最后一组去掉，优先保证动作质量。` };
  }
  if (/替代|没有器械|换动作/.test(text)) {
    return { text: "可以试试这些替代：\n· 俯卧撑（徒手，胸）\n· 高脚杯深蹲（哑铃，腿）\n· 单臂哑铃划船（哑铃，背）\n选择能稳定完成 8–12 次的重量，动作变形就降重量。" };
  }
  if (/蛋白|吃|热量|饮食/.test(text)) {
    const targets = nutritionTargets();
    return { text: `按你的体重，每天蛋白质建议在 ${targets.protein}g 左右，分 3–4 餐摄入；训练后 1–2 小时内吃到 20–30g 蛋白质即可。疾病相关饮食请咨询营养科医生。` };
  }
  if (/酸|疼|痛/.test(text)) {
    return { text: "训练后的延迟性酸痛通常 24–72 小时缓解，可以低强度活动、拉伸、保证睡眠。如果是关节刺痛、肿胀或影响走路，先停止训练并找医生评估。" };
  }
  if (skill === "nutrition") {
    const targets = nutritionTargets();
    return { text: `营养师模式下，我先给一个保守区间：每天蛋白质约 ${targets.protein}g，分 3–4 餐摄入；每餐先安排蛋白质和蔬菜，再根据训练量调整主食。如果有糖尿病、肾病、孕期或进食障碍，请先咨询医生或注册营养师。` };
  }
  if (skill === "rehab") {
    return { text: "康复师模式下，我不会在未评估的情况下给你诊断或加练。请先告诉我疼痛位置、持续多久、疼痛 0–10 分，以及是否有肿胀、麻木或无力。如果有明显肿胀、无法承重或神经症状，请先线下就医。" };
  }
  return { text: "我记住了。你可以具体问：今天练什么、某个动作怎么替代，或者把训练感受告诉我。当前计划会参考你的完成率和 RPE 做调整。" };
}

