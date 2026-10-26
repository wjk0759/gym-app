/* FitAI Web Preview actions: coach-led plan adjustment conversation. */

Object.assign(window.app, {
  startPlanAdjustment(source = "plan") {
    if (!state.plan) return;
    resetToTab("coach");
    state.coachSkill = "trainer";
    if (state.planAdjustment?.active) {
      save();
      render();
      scrollCoachChat();
      return;
    }
    state.planAdjustment = {
      active: true,
      step: "issue",
      issue: "",
      detail: "",
      category: null,
      proposal: null,
      source,
      startedAt: Date.now(),
      quickReplies: [
        "时间不够，练不完",
        "恢复不过来，总是累",
        "某个动作会疼",
        "重量卡住不进步",
        "计划太满，坚持不了"
      ]
    };
    state.chats.push({
      role: "assistant",
      kind: "adjustment-start",
      text: "我们开始调整计划，但我不会先替你拍脑袋改。先说说：最近训练里最困扰你的是什么？是时间、恢复、疼痛、重量卡住，还是计划太满？你也可以直接讲一个最近训练里的具体问题。"
    });
    save();
    render();
    scrollCoachChat();
  },

  continuePlanAdjustment(message) {
    const adjustment = state.planAdjustment;
    if (!adjustment?.active) return;
    const text = String(message || "").trim();
    if (!text) return;
    if (/^(取消|算了|不改|先不改|不改了|结束调整)$/.test(text)) {
      this.cancelPlanAdjustment();
      return;
    }

    if (adjustment.step === "issue") {
      adjustment.issue = text;
      adjustment.category = classifyAdjustmentIssue(text);
      adjustment.step = "detail";
      const prompt = adjustmentDetailPrompt(adjustment.category);
      adjustment.quickReplies = prompt.quickReplies;
      state.chats.push({ role: "assistant", text: prompt.text });
      return;
    }

    if (adjustment.step === "detail") {
      adjustment.detail = text;
      if (adjustment.category === "generic") {
        adjustment.category = classifyAdjustmentIssue(`${adjustment.issue} ${text}`);
      }
      adjustment.proposal = buildPlanAdjustmentProposal(
        adjustment.issue,
        adjustment.detail,
        adjustment.category
      );
      adjustment.step = "proposal";
      adjustment.quickReplies = ["应用调整", "再改一点", "取消"];
      state.chats.push({
        role: "assistant",
        text: "我按你说的把方案重新算了一遍。先看下面这版是否更贴近你的真实情况；如果不合适，我们可以继续改。"
      });
      state.chats.push({
        role: "assistant",
        kind: "proposal",
        proposal: adjustment.proposal
      });
      return;
    }

    if (adjustment.step === "proposal") {
      if (/取消|算了|不改|先不/.test(text)) {
        this.cancelPlanAdjustment();
        return;
      }
      if (/应用|确认|可以|执行|就按|开始/.test(text)) {
        this.applyPlanAdjustment();
        return;
      }
      if (/再改|重来|调整一下|不合适/.test(text)) {
        adjustment.step = "detail";
        adjustment.proposal = null;
        adjustment.quickReplies = ["减少动作", "少降重量", "换动作", "增加一天", "先不改"];
        state.chats.push({
          role: "assistant",
          text: "可以。你最想先改哪一块：动作数量、重量、动作选择，还是训练频率？直接说具体一点，我按你的要求重算。"
        });
        return;
      }
      // Treat any other message as additional feedback and regenerate.
      adjustment.detail = `${adjustment.detail}；补充：${text}`;
      adjustment.proposal = buildPlanAdjustmentProposal(
        adjustment.issue,
        adjustment.detail,
        adjustment.category
      );
      adjustment.quickReplies = ["应用调整", "再改一点", "取消"];
      state.chats.push({
        role: "assistant",
        text: "收到，我把你的补充也放进去了，重新给你一版。"
      });
      state.chats.push({
        role: "assistant",
        kind: "proposal",
        proposal: adjustment.proposal
      });
    }
  },

  applyPlanAdjustment() {
    const adjustment = state.planAdjustment;
    if (!adjustment?.proposal) return;
    const applied = applyPlanAdjustmentToStore(adjustment.proposal);
    if (!applied) return;
    state.chats.push({
      role: "assistant",
      kind: "applied",
      applied
    });
    state.planAdjustment = {
      active: false,
      step: "applied",
      issue: adjustment.issue,
      detail: adjustment.detail,
      category: adjustment.category,
      proposal: null,
      applied,
      quickReplies: ["查看更新后的计划"]
    };
    save();
    render();
    scrollCoachChat();
    toast(`计划已更新到第 ${applied.version} 版`);
  },

  revisePlanAdjustment() {
    const adjustment = state.planAdjustment;
    if (!adjustment) {
      this.startPlanAdjustment("coach");
      return;
    }
    adjustment.active = true;
    adjustment.step = "detail";
    adjustment.proposal = null;
    adjustment.quickReplies = ["减少动作", "少降重量", "换动作", "增加一天", "先不改"];
    state.chats.push({
      role: "assistant",
      text: "好，我们继续改。你最想先改哪一块：动作数量、重量、动作选择，还是训练频率？"
    });
    save();
    render();
    scrollCoachChat();
  },

  cancelPlanAdjustment() {
    state.chats.push({
      role: "assistant",
      text: "好，这次先不改计划。你现在的问题我已经记在对话里；下次想调整时，直接告诉我，我们从这里继续。"
    });
    state.planAdjustment = null;
    save();
    render();
    scrollCoachChat();
  },

  openAdjustedPlan() {
    state.planAdjustment = null;
    resetToTab("plan");
    save();
    render();
    toast("已打开更新后的计划");
  }
});
