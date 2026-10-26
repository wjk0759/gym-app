/* FitAI preview actions: coach-paywall */
Object.assign(window.app, {
  setCoachSkill(skill) {
    state.coachSkill = skill;
    save();
    render();
  },

  clearCoachChat() {
    state.chats = [];
    state.planAdjustment = null;
    save();
    render();
  },

  openCoachCamera() {
    pushRoute("coachPhotoCamera");
    save();
    render();
  },

  coachPhotoCapture() {
    state.chats.push({
      role: "user",
      kind: "photo",
      text: "请教练看看这张照片，帮我判断动作或器械。"
    });
    state.chats.push({
      role: "assistant",
      text: "照片已收到。你想让我重点看动作姿势、器械使用，还是某个部位的不适？再补一句具体问题，我会结合你的训练计划回答。"
    });
    popRoute();
    save();
    render();
    scrollCoachChat();
    toast("照片已发送给教练");
  },

  sendChat(text) {
    let message = text;
    if (message === undefined) {
      const input = document.getElementById("chat-input");
      message = input ? input.value : "";
    }
    message = String(message || "").trim().slice(0, 500);
    if (!message) return;
    state.chats.push({ role: "user", text: message });
    if (state.planAdjustment?.active) {
      this.continuePlanAdjustment(message);
      save();
      render();
      scrollCoachChat();
      return;
    }
    const reply = coachReply(message, state.coachSkill || "trainer");
    state.chats.push({ role: "assistant", text: reply.text, safety: !!reply.safety });
    save();
    render();
    scrollCoachChat();
  },

  openExercise(slug) {
    pushRoute("equipmentItem", { selectedExercise: slug, equipmentItemId: null });
    save();
    render();
  },

  askCoach(slug) {
    const name = EX[slug].name;
    state.chats.push({ role: "user", text: `${name}怎么用？需要注意什么？` });
    state.chats.push({ role: "assistant", text: `${EX[slug].cues}\n如果动作过程中出现关节刺痛、麻木或肿胀，请停止并咨询医生。` });
    resetToTab("coach");
    save();
    render();
    setTimeout(() => {
      const chat = document.getElementById("chat-scroll");
      if (chat) chat.scrollTop = chat.scrollHeight;
    }, 20);
  },

  openPaywall() {
    pushRoute("paywall");
    save();
    render();
  },

  buy(plan) {
    state.paywallPlan = plan;
    state.pro = true;
    save();
    render();
    toast(plan === "yearly" ? "模拟购买成功：年度订阅" : "模拟购买成功：月度订阅");
  },

  selectPaywall(plan) {
    state.paywallPlan = plan;
    save();
    render();
  },

  restorePurchase() {
    toast("预览版不连接 StoreKit；真实 App 会恢复 Apple ID 的订阅");
  },

  startNutritionCoach() {
    const targets = nutritionTargets();
    const totals = nutritionTotals();
    const remainingKcal = Math.max(0, targets.kcal - Math.round(totals.kcal));
    const remainingProtein = Math.max(0, targets.protein - Math.round(totals.p));
    const rest = !todayDay();
    resetToTab("coach");
    state.coachSkill = "nutrition";
    state.planAdjustment = null;
    const calorieText = remainingKcal > 0 ? `还可以摄入 ${remainingKcal} kcal` : "热量已经达标";
    const proteinText = remainingProtein > 0 ? `蛋白质还差 ${remainingProtein}g` : "蛋白质已经达标";
    const context = rest
      ? `今天是休息日，饮食是今天的重点。${calorieText}，${proteinText}。想先调整热量目标、蛋白质分配，还是下一餐安排？`
      : `今天训练后，饮食要帮恢复。${calorieText}，${proteinText}。想先调整热量目标、蛋白质分配，还是下一餐安排？`;
    state.chats = (state.chats || []).filter((message) => message.kind !== "nutrition-context");
    state.chats.push({ role: "assistant", kind: "nutrition-context", text: context });
    save();
    render();
    scrollCoachChat();
  },

  openNutritionDate(dateKey = todayKey(), origin = "plan") {
    state.nutritionDateKey = dateKey;
    state.nutritionOrigin = origin === "home" ? "home" : "plan";
    pushRoute("nutrition", {
      nutritionDateKey: state.nutritionDateKey,
      nutritionOrigin: state.nutritionOrigin
    });
    save();
    render();
  },
});
