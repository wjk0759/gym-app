/* FitAI Web Preview module: route stack and hierarchical back navigation. */

const TAB_ROUTE_NAMES = ["home", "plan", "coach", "equipment", "profile"];
const ROUTE_STACK_LIMIT = 40;

function isTabRouteName(value) {
  return TAB_ROUTE_NAMES.includes(value);
}

function currentRouteSnapshot() {
  const snapshot = {
    screen: state.screen,
    tab: state.tab,
    calendarMonth: state.calendarMonth,
    calendarDateKey: state.calendarDateKey
  };
  if (state.screen === "nutrition") {
    snapshot.nutritionDateKey = state.nutritionDateKey;
    snapshot.nutritionOrigin = state.nutritionOrigin;
  }
  if (state.screen === "sessionDetail" || state.screen === "sessionExercisePicker") {
    snapshot.sessionId = state.sessionId;
    snapshot.sessionOrigin = state.sessionOrigin;
    snapshot.sessionCreating = state.sessionCreating;
    snapshot.sessionEditing = state.sessionEditing;
  }
  if (state.screen === "equipmentItem") {
    snapshot.selectedExercise = state.selectedExercise;
    snapshot.equipmentItemId = state.equipmentItemId;
  }
  if (state.screen === "trainingData") {
    snapshot.trainingDataSlug = state.trainingDataSlug;
  }
  if (state.screen === "foodPhotoCamera") {
    snapshot.foodPhotoCameraFrom = state.foodPhotoCameraFrom;
  }
  if (state.screen === "equipmentLibrary") {
    snapshot.equipLibraryFromProfile = state.equipLibraryFromProfile;
  }
  return snapshot;
}

function clearRouteOverlays() {
  state.equipSelectionOpen = false;
  state.workoutAdjustOpen = false;
  state.numberPicker = null;
}

function cleanupRouteOnBack(screen) {
  if (screen === "sessionDetail") {
    state.sessionId = null;
    state.sessionOrigin = "home";
    state.sessionCreating = false;
    state.sessionEditing = false;
    state.sessionDraft = null;
  }
  if (screen === "profileEdit") state.profileDraft = null;
  if (screen === "planSchedule") state.planScheduleDraft = null;
  if (screen === "periodSchedule") state.periodDraft = null;
  if (screen === "foodCustom") state.foodCustomDraft = null;
  if (screen === "foodAdd") state.foodDraft = null;
  if (screen === "foodPhoto") {
    state.foodPhotoImage = false;
    state.foodPhotoItems = [];
    state.foodPhotoConfidence = 0;
    state.foodPhotoModel = "";
  }
}

function applyRouteSnapshot(snapshot) {
  if (!snapshot || !snapshot.screen) return false;
  state.screen = snapshot.screen;
  if (snapshot.screen === "tabs") {
    state.tab = isTabRouteName(snapshot.tab) ? snapshot.tab : "home";
    state.sessionId = null;
    state.sessionOrigin = "home";
    state.sessionCreating = false;
    state.sessionEditing = false;
    state.sessionDraft = null;
    state.selectedExercise = null;
    state.equipmentItemId = null;
    state.equipLibraryFromProfile = false;
  }
  [
    "calendarMonth",
    "calendarDateKey",
    "nutritionDateKey",
    "nutritionOrigin",
    "sessionId",
    "sessionOrigin",
    "sessionCreating",
    "sessionEditing",
    "selectedExercise",
    "equipmentItemId",
    "trainingDataSlug",
    "foodPhotoCameraFrom",
    "equipLibraryFromProfile"
  ].forEach((key) => {
    if (Object.prototype.hasOwnProperty.call(snapshot, key)) {
      state[key] = snapshot[key];
    }
  });
  clearRouteOverlays();
  return true;
}

function applyRouteTarget(screen, context = {}) {
  state.screen = screen;
  if (screen === "tabs") {
    state.tab = isTabRouteName(context.tab) ? context.tab : state.tab;
  }
  Object.keys(context).forEach((key) => {
    if (key !== "tab") state[key] = context[key];
  });
  clearRouteOverlays();
}

function pushRoute(screen, context = {}) {
  if (!Array.isArray(state.routeStack)) state.routeStack = [];
  if (state.screen === screen && screen !== "tabs") {
    applyRouteTarget(screen, context);
    return;
  }
  state.routeStack.push(currentRouteSnapshot());
  if (state.routeStack.length > ROUTE_STACK_LIMIT) {
    state.routeStack.splice(0, state.routeStack.length - ROUTE_STACK_LIMIT);
  }
  applyRouteTarget(screen, context);
}

function replaceRoute(screen, context = {}) {
  applyRouteTarget(screen, context);
}

function resetToTab(tab) {
  state.routeStack = [];
  state.screen = "tabs";
  state.tab = isTabRouteName(tab) ? tab : "home";
  clearRouteOverlays();
}

function workoutComposeOriginTab() {
  const source = state.workoutDraft?.source;
  if (source === "planEdit") return "plan";
  if (source === "plan") return "home";
  return "equipment";
}

function fallbackRoute() {
  const screen = state.screen;
  if (screen === "foodAdd" || screen === "foodCustom" || screen === "foodPhoto" || screen === "foodPhotoCamera") {
    if (screen === "foodPhotoCamera" && state.foodPhotoCameraFrom === "foodPhoto") {
      return { screen: "foodPhoto" };
    }
    return { screen: "nutrition" };
  }
  if (screen === "nutrition") {
    return { screen: "tabs", tab: state.nutritionOrigin === "plan" ? "plan" : "home" };
  }
  if (screen === "sessionExercisePicker") return { screen: "sessionDetail" };
  if (screen === "sessionDetail") {
    return { screen: "tabs", tab: state.sessionOrigin === "plan" ? "plan" : "home" };
  }
  if (screen === "planExercisePicker") return { screen: "workoutCompose" };
  if (screen === "workoutCompose") return { screen: "tabs", tab: workoutComposeOriginTab() };
  if (screen === "workout") return { screen: "tabs", tab: "home" };
  if (screen === "trainingData") {
    if (state.equipmentItemId || state.selectedExercise) return { screen: "equipmentItem" };
    return { screen: "tabs", tab: "equipment" };
  }
  if (screen === "history") return { screen: "tabs", tab: "plan" };
  if (screen === "planSchedule" || screen === "planReview" || screen === "periodSchedule") {
    return { screen: "tabs", tab: "plan" };
  }
  if (screen === "equipmentLibrary") {
    return { screen: "tabs", tab: state.equipLibraryFromProfile ? "profile" : "equipment" };
  }
  if (screen === "equipmentItem") {
    return state.equipmentItemId
      ? { screen: "equipmentLibrary" }
      : { screen: "tabs", tab: "equipment" };
  }
  if (screen === "equipmentCamera" || screen === "equipmentRecognition") {
    return { screen: "tabs", tab: "equipment" };
  }
  if (screen === "paywall") return { screen: "tabs", tab: "profile" };
  if (screen === "settings" || screen === "profileEdit" || screen === "bodyAnalysis") {
    return { screen: "tabs", tab: "profile" };
  }
  return { screen: "tabs", tab: "home" };
}

function popRoute() {
  if (!Array.isArray(state.routeStack)) state.routeStack = [];
  cleanupRouteOnBack(state.screen);
  if (state.routeStack.length) {
    const previous = state.routeStack.pop();
    if (applyRouteSnapshot(previous)) return previous;
  }
  const fallback = fallbackRoute();
  applyRouteSnapshot(fallback);
  return fallback;
}

function settleCameraRoute(target, context = {}) {
  const stack = Array.isArray(state.routeStack) ? state.routeStack : [];
  const top = stack[stack.length - 1];
  if (top?.screen === target) {
    stack.pop();
    applyRouteSnapshot(top);
    applyRouteTarget(target, context);
    return;
  }
  replaceRoute(target, context);
}

Object.assign(window.app, {
  back() {
    popRoute();
    save();
    render();
  },

  backTo(tab) {
    resetToTab(tab);
    save();
    render();
  }
});
