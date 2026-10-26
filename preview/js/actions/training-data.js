/* FitAI Web Preview actions: plan-owned exercise analytics navigation and controls. */

Object.assign(window.app, {
  openTrainingData(slug = state.trainingDataSlug) {
    if (EX[slug]) state.trainingDataSlug = slug;
    pushRoute("trainingData", { trainingDataSlug: state.trainingDataSlug });
    save();
    render();
  },

  trainingDataPeriod(period) {
    state.equipmentStatsPeriod = ["7", "30", "90", "all", "custom"].includes(period) ? period : "90";
    state.equipmentStatsCustomStart = state.equipmentStatsCustomStart || localDateInputValue(new Date(Date.now() - 30 * 86400000));
    state.equipmentStatsCustomEnd = state.equipmentStatsCustomEnd || localDateInputValue(new Date());
    save();
    render();
  },

  trainingDataMetric(metric) {
    state.equipmentStatsMetric = ["volume", "sets", "maxWeight", "oneRepMax"].includes(metric)
      ? metric
      : "volume";
    save();
    render();
  },

  trainingDataCustomStart(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value || "")) return;
    state.equipmentStatsCustomStart = value;
    if (state.equipmentStatsCustomEnd && value > state.equipmentStatsCustomEnd) {
      state.equipmentStatsCustomEnd = value;
    }
    save();
    render();
  },

  trainingDataCustomEnd(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value || "")) return;
    state.equipmentStatsCustomEnd = value;
    if (state.equipmentStatsCustomStart && value < state.equipmentStatsCustomStart) {
      state.equipmentStatsCustomStart = value;
    }
    save();
    render();
  }
});
