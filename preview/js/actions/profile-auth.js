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
      age: "岁", height: "cm", weight: "kg", waist: "cm", chest: "cm", hip: "cm",
      targetWeight: "kg", targetWaist: "cm"
    };
    const label = document.getElementById(`draft-val-${key}`);
    if (label) {
      const shown = key === "weight" || key === "targetWeight" ? number.toFixed(1) : String(Math.round(number));
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
    state.screen = "profileEdit";
    save();
    render();
  },

  closeProfileEdit() {
    state.profileDraft = null;
    state.screen = "tabs";
    state.tab = "profile";
    save();
    render();
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
    if (!draft.equipment.includes("徒手")) draft.equipment.push("徒手");
    state.profile = { ...draft };
    state.profileDraft = null;
    state.screen = "tabs";
    state.tab = "profile";
    save();
    render();
    toast("资料已保存");
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
    const button = document.getElementById("gen-btn");
    if (button) {
      button.disabled = true;
      button.textContent = "正在编排 4 周计划…";
    }
    setTimeout(() => {
      state.profile.name = String(state.profile.name || "小林").trim() || "小林";
      state.plan = applyEquipmentLibrary(buildPlan(state.profile));
      state.onboarded = true;
      state.screen = "tabs";
      state.tab = "home";
      save();
      render();
      toast("已生成 4 周计划，开始训练吧");
    }, 700);
  },

  skipOnboarding() {
    state.authenticated = true;
    state.profile = { ...DEFAULT_PROFILE };
    state.plan = applyEquipmentLibrary(buildPlan(state.profile));
    state.onboarded = true;
    state.screen = "tabs";
    state.tab = "home";
    save();
    render();
    toast("已载入示例数据");
  },

  previewAuthMode(mode) {
    state.authMode = mode;
    state.authError = "";
    save();
    render();
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
      return;
    }
    state.authDevCode = "123456";
    state.authCode = "123456";
    state.authError = "";
    save();
    render();
    toast("开发验证码 123456 已填入");
  },

  previewLogin() {
    if (!state.authConsent) {
      state.authError = "请先勾选页面底部的用户协议与隐私政策";
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
      state.profile = { ...DEFAULT_PROFILE };
      state.plan = applyEquipmentLibrary(buildPlan(state.profile));
      state.onboarded = true;
    }
    state.screen = "tabs";
    state.tab = "home";
    save();
    render();
    toast("登录成功（预览模拟）");
  },

  previewSocial(provider) {
    if (!state.authConsent) {
      state.authError = "请先勾选页面底部的用户协议与隐私政策";
      render();
      return;
    }
    state.authenticated = true;
    if (!state.onboarded) {
      state.profile = { ...DEFAULT_PROFILE };
      state.plan = applyEquipmentLibrary(buildPlan(state.profile));
      state.onboarded = true;
    }
    state.screen = "tabs";
    state.tab = "home";
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
    save();
    render();
    toast("已退出登录");
  },

  tab(tab) {
    state.screen = "tabs";
    state.tab = tab;
    state.equipSelectionOpen = false;
    save();
    render();
  },

  go(screen) {
    state.screen = screen;
    save();
    render();
  },

  openSettings() {
    state.screen = "settings";
    save();
    render();
  },

  closeSettings() {
    state.screen = "tabs";
    state.tab = "profile";
    save();
    render();
  },

  back() {
    state.equipSelectionOpen = false;
    if (state.screen === "foodCustom") { state.foodCustomDraft = null; state.screen = "foodAdd"; }
    else if (state.screen === "foodAdd") state.screen = "nutrition";
    else if (state.screen === "history") { state.screen = "tabs"; state.tab = "home"; }
    else if (state.screen === "trainingData") { state.screen = "tabs"; state.tab = "plan"; }
    else if (state.screen === "paywall") { state.screen = "tabs"; state.tab = "profile"; }
    else if (state.screen === "sessionDetail") { state.screen = "tabs"; state.tab = state.sessionOrigin === "plan" ? "plan" : "home"; state.sessionOrigin = "home"; }
    else if (state.screen === "equipmentItem") { state.screen = "equipmentLibrary"; }
    else if (state.screen === "foodPhotoCamera") state.screen = state.foodPhotoCameraFrom === "nutrition" ? "nutrition" : "foodPhoto";
    else if (state.screen === "equipmentLibrary" || state.screen === "equipmentRecognition" || state.screen === "equipmentCamera") { state.screen = "tabs"; state.tab = "equipment"; }
    else if (state.screen === "bodyAnalysis") { state.screen = "tabs"; state.tab = "profile"; }
    else { state.screen = "tabs"; state.tab = "home"; }
    save();
    render();
  },

  backTo(tab) {
    state.screen = "tabs";
    state.tab = tab;
    state.equipSelectionOpen = false;
    save();
    render();
  },
});
