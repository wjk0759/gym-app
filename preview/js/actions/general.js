/* FitAI preview actions: general */
Object.assign(window.app, {
  openLegal(doc) {
    state.legalDoc = doc;
    render();
  },

  closeLegal() {
    state.legalDoc = null;
    render();
  },

  mockPrivacy() {
    toast("上线前替换为正式隐私政策、用户协议与备案信息");
  },

  mockMeituan() {
    toast("美团联盟需要企业资质与 CPS 配置；预览版不跳转");
  },

  exportData() {
    const data = JSON.stringify({
      profile: state.profile,
      plan: state.plan,
      sessions: state.sessions,
      foodLogs: state.foodLogs,
      customFoods: state.customFoods,
      chats: state.chats,
      bodyMetrics: state.bodyMetrics,
      periodDates: state.periodDates,
      bodyCheckInFrequency: state.bodyCheckInFrequency,
      bodyCheckInWeekday: state.bodyCheckInWeekday,
      bodyCheckInDay: state.bodyCheckInDay
    }, null, 2);
    const blob = new Blob([data], { type: "application/json" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = "fitai-data.json";
    link.click();
    URL.revokeObjectURL(link.href);
    toast("已导出 JSON 数据");
  },

  resetAll() {
    if (!confirm("确定清除所有演示数据并重新开始？")) return;
    localStorage.removeItem(STORAGE_KEY);
    state = initialState();
    stopRestTimer();
    render();
    toast("演示数据已重置");
  }
});
