/* FitAI preview actions: profile-auth */
Object.assign(window.app, {
  field(key, value) {
    state.profile[key] = key === "name" ? String(value || "").slice(0, 30) : value;
    save();
  },

  profileDraftInput(key, value) {
    if (!state.profileDraft) return;
    state.profileDraft[key] = key === "name" ? String(value || "").slice(0, 30) : value;
    save();
  },

  profileDraftNumber(key, value) {
    if (!state.profileDraft) return;
    const number = Number(value);
    state.profileDraft[key] = number;
    const units = {
      age: "岁", height: "cm", weight: "kg", bodyFat: "%", waist: "cm",
      arm: "cm", thigh: "cm", chest: "cm", hip: "cm",
      targetWeight: "kg", targetWaist: "cm", targetBodyFat: "%"
    };
    const decimalKeys = ["weight", "bodyFat", "arm", "thigh", "targetWeight", "targetBodyFat"];
    const label = document.getElementById(`draft-val-${key}`);
    if (label) {
      const shown = decimalKeys.includes(key) ? number.toFixed(1) : String(Math.round(number));
      label.textContent = `${shown}${units[key] || ""}`;
    }
    const bmi = document.getElementById("draft-bmi");
    if (bmi) bmi.textContent = bmiText(state.profileDraft);
    save();
  },

  profileDraftSelect(key, value) {
    if (!state.profileDraft) return;
    state.profileDraft[key] = Number.isNaN(Number(value)) ? value : Number(value);
    save();

    if (key === "goal") {
      document.querySelectorAll("[data-draft-goal]").forEach((button) => {
        button.classList.toggle("active", button.dataset.draftGoal === value);
      });
      const targetFields = document.getElementById("profile-target-fields");
      if (targetFields) {
        targetFields.style.display = value === "提升体能" ? "none" : "";
      }
    }

    document.querySelectorAll(`[data-draft-seg="${key}"]`).forEach((button) => {
      button.classList.toggle("active", button.dataset.value === String(value));
    });
  },

  profileDraftToggleEquip(name) {
    if (!state.profileDraft) return;
    const list = state.profileDraft.equipment;
    const active = !list.includes(name);
    state.profileDraft.equipment = active
      ? list.concat(name)
      : list.filter((item) => item !== name);
    save();
    document.querySelectorAll("[data-equip]").forEach((button) => {
      if (button.dataset.equip === name) {
        button.classList.toggle("active", active);
      }
    });
  },

  openProfileEdit() {
    state.profileDraft = JSON.parse(JSON.stringify(state.profile));
    pushRoute("profileEdit");
    save();
    render();
  },

  closeProfileEdit() {
    state.profileDraft = null;
    app.back();
  },

  saveProfileEdit() {
    const draft = state.profileDraft;
    if (!draft) return;
    const name = String(draft.name || "").trim();
    if (!name) {
      toast("请填写称呼");
      return;
    }
    if (Number(draft.height) > 0 && Number(draft.weight) / Math.pow(Number(draft.height) / 100, 2) < 18.5 && draft.goal === "减脂") {
      toast("BMI 低于 18.5，不建议以减脂为目标");
      return;
    }
    draft.name = name;
    if (!Array.isArray(draft.equipment)) draft.equipment = [];
    if (!hasPlanEquipment(draft.equipment)) {
      return toast("请至少选择一种可用器械：徒手 / 哑铃 / 杠铃 / 固定器械 / 绳索");
    }
    const equipmentChanged = JSON.stringify([...state.profile.equipment].sort())
      !== JSON.stringify([...draft.equipment].sort());
    const planSettingsChanged = state.profile.goal !== draft.goal
      || state.profile.split !== draft.split
      || Number(state.profile.weeklyDays) !== Number(draft.weeklyDays)
      || Number(state.profile.minutes) !== Number(draft.minutes)
      || state.profile.experience !== draft.experience
      || equipmentChanged;
    const goalChanged = state.profile.goal !== draft.goal
      || Number(state.profile.targetWeight) !== Number(draft.targetWeight)
      || Number(state.profile.targetWaist) !== Number(draft.targetWaist)
      || Number(state.profile.targetBodyFat) !== Number(draft.targetBodyFat);
    if (goalChanged) {
      draft.goalStartWeight = Number(draft.weight) || Number(state.profile.weight) || 0;
      draft.goalStartDate = todayKey();
    }
    state.profile = { ...draft };
    if (planSettingsChanged && state.plan) {
      const nextVersion = (Number(state.plan.version) || 1) + 1;
      state.plan = applyEquipmentLibrary(buildPlan(state.profile));
      state.plan.version = nextVersion;
      state.plan.updatedAt = Date.now();
    }
    const date = todayKey();
    const metric = {
      id: `bm-${date}`,
      date,
      timestamp: Date.now(),
      weight: Number(draft.weight) || Number(state.profile.weight) || 0,
      bodyFat: Number(draft.bodyFat) || Number(state.profile.bodyFat) || 0,
      waist: Number(draft.waist) || Number(state.profile.waist) || 0,
      arm: Number(draft.arm) || Number(state.profile.arm) || 0,
      thigh: Number(draft.thigh) || Number(state.profile.thigh) || 0
    };
    state.bodyMetrics = [metric, ...(state.bodyMetrics || []).filter((entry) => entry.date !== date)]
      .sort((left, right) => right.timestamp - left.timestamp);
    state.profileDraft = null;
    popRoute();
    save();
    render();
    toast(planSettingsChanged ? "资料已保存，计划已按新设置更新" : "资料已保存");
  },

  openGoalEditor() {
    state.goalEditorOpen = true;
    state.bodyCheckInOpen = false;
    render();
  },

  closeGoalEditor() {
    state.goalEditorOpen = false;
    render();
  },

  saveGoalDate() {
    const input = document.getElementById("goal-target-date");
    const value = String(input?.value || "");
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return toast("请选择目标日期");
    }
    if (value < todayKey()) {
      return toast("目标日期不能早于今天");
    }
    state.profile.goalTargetDate = value;
    state.goalEditorOpen = false;
    save();
    render();
    toast("目标日期已更新");
  },

  range(key, value, unit) {
    state.profile[key] = Number(value);
    const label = document.getElementById(`val-${key}`);
    if (label) label.textContent = `${value}${unit}`;
    save();
  },

  seg(key, value) {
    state.profile[key] = Number.isNaN(Number(value)) ? value : Number(value);
    save();
    render();
  },

  toggleEquip(name) {
    const list = state.profile.equipment;
    state.profile.equipment = list.includes(name) ? list.filter((item) => item !== name) : list.concat(name);
    save();
    render();
  },

  setGoal(goal) {
    state.profile.goal = goal;
    save();
    render();
  },

  generatePlan() {
    if (!hasPlanEquipment(state.profile.equipment)) {
      return toast("请至少选择一种可用器械：徒手 / 哑铃 / 杠铃 / 固定器械 / 绳索");
    }
    const button = document.getElementById("gen-btn");
    if (button) {
      button.disabled = true;
      button.textContent = "正在编排 4 周计划…";
    }
    setTimeout(() => {
      state.profile.name = String(state.profile.name || "小林").trim() || "小林";
      applyGoalProfileDefaults(state.profile, state.bodyMetrics);
      state.plan = applyEquipmentLibrary(buildPlan(state.profile));
      state.onboarded = true;
      resetToTab("home");
      save();
      render();
      toast("已生成 4 周计划，开始训练吧");
    }, 700);
  },

  skipOnboarding() {
    state.authenticated = true;
    state.profile = applyGoalProfileDefaults({ ...DEFAULT_PROFILE }, state.bodyMetrics);
    state.plan = applyEquipmentLibrary(buildPlan(state.profile));
    state.onboarded = true;
    resetToTab("home");
    save();
    render();
    toast("已载入示例数据", 1400);
  },

  previewAuthFocus(input) {
    loginFocusMode = true;
    loginFocusInputId = input?.id || "";
    document.querySelector(".login-page")?.classList.add("login-focus");
  },

  previewAuthBlur() {
    loginFocusMode = false;
    loginFocusInputId = "";
    document.querySelector(".login-page")?.classList.remove("login-focus");
  },

  restoreLoginFocus() {
    if (!loginFocusMode) return;
    requestAnimationFrame(() => {
      const target = document.getElementById(loginFocusInputId)
        || document.querySelector(".login-card input");
      target?.focus({ preventScroll: true });
    });
  },

  previewAuthMode(mode) {
    state.authMode = mode;
    state.authError = "";
    save();
    render();
    this.restoreLoginFocus();
  },

  previewAuthField(key, value) {
    const limits = { authPhone: 11, authCode: 6, authAccount: 50, authPassword: 64 };
    state[key] = String(value || "").slice(0, limits[key] || 100);
    save();
  },

  previewAuthConsent() {
    state.authConsent = !state.authConsent;
    state.authError = "";
    save();
    render();
  },

  previewSendCode() {
    if (!/^1\d{10}$/.test(state.authPhone)) {
      state.authError = "请输入正确的 11 位手机号";
      render();
      this.restoreLoginFocus();
      return;
    }
    state.authDevCode = "123456";
    state.authCode = "123456";
    state.authError = "";
    save();
    render();
    this.restoreLoginFocus();
    toast("开发验证码 123456 已填入");
  },

  confirmAuthConsent() {
    const provider = state.authConsentProvider;
    state.authConsent = true;
    state.authConsentPrompt = false;
    state.authConsentProvider = null;
    state.authError = "";
    if (provider) this.previewSocial(provider);
    else this.previewLogin();
  },

  cancelAuthConsent() {
    state.authConsentPrompt = false;
    state.authConsentProvider = null;
    state.authError = "";
    render();
  },

  previewLogin() {
    this.previewAuthBlur();
    if (!state.authConsent) {
      state.authConsentPrompt = true;
      state.authConsentProvider = null;
      state.authError = "";
      render();
      return;
    }
    if (state.authMode === "phone") {
      if (!/^1\d{10}$/.test(state.authPhone)) {
        state.authError = "请输入正确的 11 位手机号";
        render();
        return;
      }
      if (state.authCode.length !== 6) {
        state.authError = "请输入 6 位验证码";
        render();
        return;
      }
    } else if (state.authAccount.length < 4 || state.authPassword.length < 8) {
      state.authError = "请输入账号和至少 8 位密码";
      render();
      return;
    }

    state.authenticated = true;
    state.authError = "";
    if (!state.onboarded) {
      state.profile = applyGoalProfileDefaults({ ...DEFAULT_PROFILE }, state.bodyMetrics);
      state.plan = applyEquipmentLibrary(buildPlan(state.profile));
      state.onboarded = true;
    }
    resetToTab("home");
    save();
    render();
    toast("登录成功（预览模拟）");
  },

  previewSocial(provider) {
    if (!state.authConsent) {
      state.authConsentPrompt = true;
      state.authConsentProvider = provider;
      state.authError = "";
      render();
      return;
    }
    state.authenticated = true;
    if (!state.onboarded) {
      state.profile = applyGoalProfileDefaults({ ...DEFAULT_PROFILE }, state.bodyMetrics);
      state.plan = applyEquipmentLibrary(buildPlan(state.profile));
      state.onboarded = true;
    }
    resetToTab("home");
    state.authError = "";
    save();
    render();
    toast(`已通过${provider}登录（预览模拟）`);
  },

  previewForgotPassword() {
    toast("iOS 端已支持手机验证码重置密码；Web 预览不发送真实短信。");
  },

  previewLogout() {
    state.authenticated = false;
    state.authError = "";
    state.authConsent = false;
    state.authConsentPrompt = false;
    state.authConsentProvider = null;
    state.routeStack = [];
    save();
    render();
    toast("已退出登录");
  },

  tab(tab) {
    resetToTab(tab);
    save();
    render();
  },

  go(screen) {
    pushRoute(screen);
    save();
    render();
  },

  openSettings() {
    pushRoute("settings");
    save();
    render();
  },

  closeSettings() {
    app.back();
  }
});
