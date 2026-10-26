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
