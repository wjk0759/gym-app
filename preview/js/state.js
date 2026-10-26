/* FitAI Web Preview module: state schema, persistence, and derived selectors. */

function normalizeState(value) {
  const next = value || initialState();
  next.equipmentLibrary = next.equipmentLibrary || demoEquipment();
  next.useEquipLibrary = next.useEquipLibrary !== false;
  next.trainingDataSlug = EX[next.trainingDataSlug] ? next.trainingDataSlug : "goblet_squat";
  if (next.planAdjustment && typeof next.planAdjustment === "object") {
    next.planAdjustment.active = next.planAdjustment.active !== false;
    next.planAdjustment.step = ["issue", "detail", "proposal", "applied"].includes(next.planAdjustment.step)
      ? next.planAdjustment.step
      : "issue";
  } else {
    next.planAdjustment = null;
  }
  if (next.plan) {
    next.plan.createdAt = Number(next.plan.createdAt) || Date.now();
    if (Array.isArray(next.plan.days)) {
      next.plan.days.forEach((day) => {
        (day.exercises || []).forEach((exercise) => {
          exercise.reps = String(parseReps(exercise.reps));
        });
      });
    }
  }
  next.equipLibraryQuery = typeof next.equipLibraryQuery === "string" ? next.equipLibraryQuery : "";
  next.pinnedEquipIds = Array.isArray(next.pinnedEquipIds) ? next.pinnedEquipIds : [];
  next.equipmentStatsPeriod = ["7", "30", "90", "all", "custom"].includes(next.equipmentStatsPeriod)
    ? next.equipmentStatsPeriod
    : "90";
  next.equipmentStatsMetric = ["volume", "sets", "maxWeight", "oneRepMax"].includes(next.equipmentStatsMetric)
    ? next.equipmentStatsMetric
    : "volume";
  next.equipmentStatsCustomStart = /^\d{4}-\d{2}-\d{2}$/.test(next.equipmentStatsCustomStart || "")
    ? next.equipmentStatsCustomStart
    : localDateInputValue(new Date(Date.now() - 30 * 86400000));
  next.equipmentStatsCustomEnd = /^\d{4}-\d{2}-\d{2}$/.test(next.equipmentStatsCustomEnd || "")
    ? next.equipmentStatsCustomEnd
    : localDateInputValue(new Date());

  if (
    Array.isArray(next.sessions)
    && next.sessions.length === 3
    && next.sessions.every((session) => ["s1", "s2", "s3"].includes(session.id))
  ) {
    next.sessions = [...next.sessions, ...demoHistorySessions()];
  }

  next.bodyPhoto = !!next.bodyPhoto;
  next.bodyConsent = false;
  next.bodyAnalysis = next.bodyAnalysis || null;
  next.equipmentItemId = next.equipmentItemId || null;
  next.sessionDraft = null;
  next.sessionEditing = false;
  next.sessionCreating = !!next.sessionCreating;
  next.calendarMonth = /^\d{4}-\d{2}$/.test(next.calendarMonth || "")
    ? next.calendarMonth
    : localDateInputValue(new Date()).slice(0, 7);
  next.calendarDateKey = /^\d{4}-\d{2}-\d{2}$/.test(next.calendarDateKey || "")
    ? next.calendarDateKey
    : localDateInputValue(new Date());
  next.nutritionDateKey = /^\d{4}-\d{2}-\d{2}$/.test(next.nutritionDateKey || "")
    ? next.nutritionDateKey
    : localDateInputValue(new Date());
  next.sessionOrigin = next.sessionOrigin === "plan" ? "plan" : "home";
  next.nutritionOrigin = next.nutritionOrigin === "plan" ? "plan" : "home";
  next.foodPhotoCameraFrom = next.foodPhotoCameraFrom === "foodPhoto" ? "foodPhoto" : "nutrition";
  next.foodPhotoImage = false;
  next.foodPhotoMeal = next.foodPhotoMeal || "午餐";
  next.foodPhotoItems = [];
  next.foodPhotoConfidence = 0;
  next.foodPhotoModel = "";
  next.foodLogs = Array.isArray(next.foodLogs)
    ? next.foodLogs.map((log) => ({ ...log, date: log.date || localDateInputValue(new Date()) }))
    : [];
  next.customFoods = Array.isArray(next.customFoods) ? next.customFoods : [];
  next.foodCustomDraft = null;
  next.equipSearchQuery = "";
  next.equipSelected = Array.isArray(next.equipSelected) ? next.equipSelected : [];
  next.equipMuscle = next.equipMuscle || "全部";
  next.equipFilter = next.equipFilter || "全部";
  next.equipSelectionOpen = !!next.equipSelectionOpen;
  next.equipRecognitionCandidates = Array.isArray(next.equipRecognitionCandidates) ? next.equipRecognitionCandidates : [];
  next.equipRecognitionPhoto = !!next.equipRecognitionPhoto;
  next.equipLibraryFromProfile = !!next.equipLibraryFromProfile;
  next.workoutDraft = next.workoutDraft && Array.isArray(next.workoutDraft.exercises)
    ? next.workoutDraft
    : null;
  next.workoutAdjustOpen = false;
  next.workoutAdjustDraft = null;
  next.numberPicker = null;
  if (next.workout && typeof next.workout === "object") {
    next.workout.adjustments = next.workout.adjustments && typeof next.workout.adjustments === "object"
      ? next.workout.adjustments
      : {};
  }
  next.workoutCustomDay = null;
  next.authenticated = !!next.authenticated;
  next.authMode = next.authMode || "phone";
  next.authPhone = next.authPhone || "13800138000";
  next.authCode = next.authCode || "";
  next.authAccount = next.authAccount || "";
  next.authPassword = next.authPassword || "";
  next.authConsent = false;
  next.authError = "";
  next.authDevCode = "";
  next.paywallPlan = next.paywallPlan || "yearly";
  next.legalDoc = null;
  next.profileDraft = null;
  next.coachSkill = next.coachSkill || "trainer";
  return next;
}

function initialState() {
  const profile = { ...DEFAULT_PROFILE };
  return {
    version: 1,
    screen: "onboarding",
    tab: "home",
    onboarded: false,
    profile,
    profileDraft: null,
    plan: buildPlan(profile),
    sessions: demoSessions(),
    chats: [],
    coachSkill: "trainer",
    foodLogs: demoLogs(),
    customFoods: [],
    foodCustomDraft: null,
    disliked: [],
    selectedExercise: null,
    sessionId: null,
    sessionCreating: false,
    calendarMonth: localDateInputValue(new Date()).slice(0, 7),
    calendarDateKey: localDateInputValue(new Date()),
    nutritionDateKey: localDateInputValue(new Date()),
    nutritionOrigin: "home",
    foodPhotoCameraFrom: "nutrition",
    sessionOrigin: "home",
    foodDraft: { meal: "早餐", query: "", selected: null, grams: 100 },
    equipmentLibrary: demoEquipment(),
    useEquipLibrary: true,
    equipLibraryQuery: "",
    pinnedEquipIds: [],
    equipmentStatsPeriod: "90",
    equipmentStatsMetric: "volume",
    equipmentStatsCustomStart: localDateInputValue(new Date(Date.now() - 30 * 86400000)),
    equipmentStatsCustomEnd: localDateInputValue(new Date()),
    bodyPhoto: false,
    bodyConsent: false,
    bodyAnalysis: null,
    equipmentItemId: null,
    sessionDraft: null,
    sessionEditing: false,
    foodPhotoImage: false,
    foodPhotoMeal: "午餐",
    foodPhotoItems: [],
    foodPhotoConfidence: 0,
    foodPhotoModel: "",
    equipSearchQuery: "",
    equipSelected: [],
    equipMuscle: "全部",
    equipFilter: "全部",
    equipSelectionOpen: false,
    equipRecognitionCandidates: [],
    equipRecognitionPhoto: false,
    equipLibraryFromProfile: false,
    planAdjustment: null,
    trainingDataSlug: "goblet_squat",
    workoutDraft: null,
    workoutAdjustOpen: false,
    workoutAdjustDraft: null,
    numberPicker: null,
    workoutCustomDay: null,
    authenticated: false,
    authMode: "phone",
    authPhone: "13800138000",
    authCode: "",
    authAccount: "",
    authPassword: "",
    authConsent: false,
    authError: "",
    authDevCode: "",
    paywallPlan: "yearly",
    legalDoc: null,
    workout: null,
    pro: false,
    reminder: "19:00"
  };
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return parsed && parsed.version === 1 ? parsed : null;
  } catch (error) {
    return null;
  }
}

let state = normalizeState(loadState() || initialState());

let saveTimer = null;

function flushSave() {
  if (saveTimer) {
    clearTimeout(saveTimer);
    saveTimer = null;
  }
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (error) {
    /* ignore */
  }
}

function save() {
  if (saveTimer) return;
  saveTimer = setTimeout(() => {
    saveTimer = null;
    flushSave();
  }, 120);
}

window.addEventListener("pagehide", flushSave);
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden") flushSave();
});

function toast(message, duration = 2600) {
  const el = document.getElementById("toast");
  if (!el) return;
  el.textContent = message;
  el.classList.add("show");
  clearTimeout(window.__toastTimer);
  window.__toastTimer = setTimeout(() => el.classList.remove("show"), duration);
}

function todayDay() {
  if (!state.plan?.days?.length) return null;
  const week = currentPlanWeekNumber();
  const weekday = new Date().getDay() || 7;
  return state.plan.days.find((day) => day.week === week && day.weekday === weekday) || null;
}

function planAdjustmentPreview() {
  const completed = currentWeekSessions().length;
  const completionRate = Math.min(1, completed / Math.max(1, state.profile.weeklyDays));
  const targetRPEs = state.plan.days.flatMap((day) =>
    day.exercises.map((exercise) => Number(exercise.rpe) || 0)
  ).filter((value) => value > 0);
  const averageRPE = targetRPEs.length
    ? targetRPEs.reduce((sum, value) => sum + value, 0) / targetRPEs.length
    : 0;

  if (completionRate < 0.6) {
    return {
      completed,
      completionRate,
      averageRPE,
      headline: "先把训练频率稳住",
      detail: `最近完成率 ${Math.round(completionRate * 100)}%，下版每个动作减少 1 组；先建立规律，不急着加重量。`,
      setsDelta: -1,
      weightMultiplier: 1
    };
  }
  if (averageRPE >= 9) {
    return {
      completed,
      completionRate,
      averageRPE,
      headline: "负荷偏高，先降一点",
      detail: `最近平均 RPE ${averageRPE.toFixed(1)}，下版主项重量下调 5%，把动作质量放在前面。`,
      setsDelta: 0,
      weightMultiplier: 0.95
    };
  }
  if (completionRate >= 0.8 && averageRPE > 0 && averageRPE <= 8) {
    return {
      completed,
      completionRate,
      averageRPE,
      headline: "可以小幅加负荷",
      detail: `完成率 ${Math.round(completionRate * 100)}%，平均 RPE ${averageRPE.toFixed(1)}，下版主项重量上调 2.5%。`,
      setsDelta: 0,
      weightMultiplier: 1.025
    };
  }
  return {
    completed,
    completionRate,
    averageRPE,
    headline: "保持当前负荷",
    detail: `最近完成率 ${Math.round(completionRate * 100)}%，这版先不改重量，优先把训练日补齐。`,
    setsDelta: 0,
    weightMultiplier: 1
  };
}

function estimatedMinutes(day) {
  return Math.max(25, 18 + day.exercises.length * 4);
}

function nutritionTargets() {
  const p = state.profile;
  const weight = Number(p.weight);
  const height = Number(p.height);
  const age = Number(p.age);
  const bmr = p.sex === "女"
    ? 10 * weight + 6.25 * height - 5 * age - 161
    : 10 * weight + 6.25 * height - 5 * age + 5;
  const activity = p.weeklyDays <= 2 ? 1.375 : p.weeklyDays <= 4 ? 1.55 : 1.725;
  let factor = 1;
  let proteinPerKg = 1.6;
  if (p.goal === "减脂") { factor = 0.85; proteinPerKg = 1.8; }
  if (p.goal === "增肌") { factor = 1.10; proteinPerKg = 2.0; }
  const kcal = Math.round(bmr * activity * factor);
  const protein = Math.round(weight * proteinPerKg);
  const fat = Math.round(weight * 0.9);
  const carbs = Math.max(0, Math.round((kcal - protein * 4 - fat * 9) / 4));
  return {
    bmr: Math.round(bmr),
    tdee: Math.round(bmr * activity),
    kcal,
    protein,
    carbs,
    fat
  };
}

function nutritionTotals(dateKey = todayKey()) {
  return foodLogsForDateKey(dateKey).reduce((total, item) => {
    total.kcal += item.kcal;
    total.p += item.p;
    total.c += item.c;
    total.f += item.f;
    return total;
  }, { kcal: 0, p: 0, c: 0, f: 0 });
}

