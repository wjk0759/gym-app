/* FitAI Web Preview actions: equipment-picker */
Object.assign(window.app, {
  equipmentTabOpen() {
    state.screen = "tabs";
    state.tab = "equipment";
    state.equipSelectionOpen = false;
    save();
    render();
  },

  equipmentLibraryOpen(source = "equipment") {
    state.screen = "equipmentLibrary";
    state.equipLibraryFromProfile = source === "profile";
    state.equipSelectionOpen = false;
    save();
    render();
  },

  equipmentLibraryQuery(value) {
    state.equipLibraryQuery = String(value || "").slice(0, 60);
    save();

    const filtered = filteredEquipmentLibraryItems();
    const root = document.getElementById("library-list-root");
    if (root) root.innerHTML = equipmentLibraryResultsMarkup(filtered);
    setupLibrarySwipeRows();

    const count = document.getElementById("library-list-count");
    if (count) count.textContent = `${filtered.length} 件`;

    const clear = document.getElementById("library-search-clear");
    if (clear) clear.hidden = !String(value || "").trim();
  },

  equipmentLibraryClearQuery() {
    const input = document.getElementById("library-search");
    if (input) input.value = "";
    this.equipmentLibraryQuery("");
    input?.focus();
  },

  equipmentPickerToggle(slug) {
    if (state.equipSelected.includes(slug)) {
      state.equipSelected = state.equipSelected.filter((item) => item !== slug);
    } else {
      state.equipSelected = [...state.equipSelected, slug];
    }
    save();
    render();
  },

  equipmentPickerClear() {
    state.equipSelected = [];
    save();
    render();
  },

  equipmentSelectionToggle() {
    state.equipSelectionOpen = !state.equipSelectionOpen;
    save();
    render();
  },

  equipmentSelectionClose() {
    state.equipSelectionOpen = false;
    save();
    render();
  },

  equipmentSelectionMakePlan() {
    if (!state.equipSelected.length) return;
    const selected = state.equipSelected
      .map((slug) => ({ slug, ...EX[slug] }))
      .filter((item) => item.name);
    if (!selected.length) return;

    state.workoutDraft = {
      source: "custom",
      title: "自选训练",
      createdAt: Date.now(),
      exercises: selected.map((item, index) => ({
        id: `draft-ex-${Date.now()}-${index}`,
        slug: item.slug,
        sets: 3,
        reps: "10",
        weight: Number(item.base) || 0,
        rest: 60,
        rpe: 7.5
      }))
    };
    state.equipSelectionOpen = false;
    state.screen = "workoutCompose";
    save();
    render();
  },
});
