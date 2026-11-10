import SwiftUI

extension EquipmentPickerView {
    var equipmentTools: some View {
        VStack(alignment: .leading, spacing: 9) {
            searchBar

            if isSearching {
                searchScopeHint
            }

            if let category = selectedCategory,
               !ExerciseLibrary.subcategories(for: category).isEmpty {
                categorySubChips
            }

            equipmentFilters
        }
        .padding(.horizontal, 16)
        .padding(.top, 9)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.chrome,
            in: UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 20,
                bottomTrailingRadius: 20,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
    }

    var trainingTypeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ExerciseLibrary.trainingTypes, id: \.self) { type in
                    filterChip(type, selected: selectedTrainingType == type && !isSearching) {
                        selectedTrainingType = type
                        selectedCategory = nil
                        selectedSubcategory = nil
                        query = ""
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    var libraryHeader: some View {
        HStack(spacing: 6) {
            Text("动作库")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text("\(filteredExercises.count)")
                .font(.system(size: 9, weight: .bold, design: .default))
                .foregroundStyle(Theme.cobalt)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.cobalt.opacity(0.08), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Theme.cobalt.opacity(0.14), lineWidth: 1)
                )

            Spacer(minLength: 8)

        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    var searchScopeHint: some View {
        Label("全库搜索中，点分类可退出搜索", systemImage: "magnifyingglass")
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.tertiaryText)
            .padding(.leading, 4)
    }

    var selectionFloatingButton: some View {
        Button {
            Haptics.tap()
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
            showSelectionPanel = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: selectedExercises.isEmpty ? "dumbbell" : "dumbbell.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selectedExercises.isEmpty ? Theme.tertiaryText : Theme.cobalt)
                    .frame(width: 50, height: 50)
                    .background(Theme.chrome, in: Circle())
                    .overlay(
                        Circle().stroke(
                            selectedExercises.isEmpty ? Theme.stroke : Theme.cobalt.opacity(0.5),
                            lineWidth: 1
                        )
                    )
                    .shadow(color: .black.opacity(0.22), radius: 14, y: 7)

                if !selectedExercises.isEmpty {
                    Text("\(selectedExercises.count)")
                        .font(.system(size: 9, weight: .bold, design: .default))
                        .foregroundStyle(Theme.onAccent)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Theme.cobalt, in: Capsule())
                        .offset(x: 3, y: -3)
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 54, height: 54)
            .motionAnimation(Motion.quick, value: selectedExercises.count)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.94))
        .accessibilityLabel("已选动作，共 \(selectedExercises.count) 个")
        .popover(
            isPresented: $showSelectionPanel,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        ) {
            EquipmentSelectionPanelView(
                exercises: selectedExercises,
                onRemove: { exercise in
                    selectedExercises.removeAll { $0.slug == exercise.slug }
                },
                onClear: {
                    selectedExercises.removeAll()
                },
                onMakePlan: makeTrainingPlanFromSelection
            )
            .presentationCompactAdaptation(.popover)
            .presentationBackground(Theme.background)
        }
    }

    @ViewBuilder
    var feedbackBanner: some View {
        if let feedback {
            Text(feedback)
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Theme.chrome, in: Capsule())
                .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.20), radius: 10, y: 5)
                .padding(.top, 6)
                .allowsHitTesting(false)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: feedback) {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.feedback = nil
                    }
                }
        }
    }

    var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.tertiaryText.opacity(0.82))

            TextField("搜索动作、肌群或器械", text: $query)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .foregroundStyle(Theme.ink)
                .submitLabel(.search)
                .onChange(of: query) { _, value in
                    if value.count > 60 {
                        query = String(value.prefix(60))
                    }
                }

            if !query.isEmpty {
                Button {
                    Haptics.tap()
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(SubtlePressStyle(scale: 0.9))
                .accessibilityLabel("清空搜索")
            }

            if !isPickingForSession {
                Button {
                    Haptics.tap()
                    showScanner = true
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.cobalt)
                        .frame(width: 34, height: 34)
                        .background(
                            Theme.cobalt.opacity(0.13),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Theme.cobalt.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(SubtlePressStyle(scale: 0.94))
                .accessibilityLabel("拍照识别器械")
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 7)
        .padding(.vertical, 6)
        .frame(minHeight: 48)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    var categorySidebar: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 1) {
                categorySideButton(nil, title: "全部")
                ForEach(ExerciseLibrary.visibleCategoryTree) { entry in
                    categorySideButton(entry.l1, title: entry.l1)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
        }
        .frame(width: 72)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    func categorySideButton(_ category: String?, title: String) -> some View {
        let active = selectedCategory == category && !isSearching

        return Button {
            Haptics.select()
            withAnimation(Motion.quick) {
                selectedCategory = (selectedCategory == category) ? nil : category
                selectedSubcategory = nil
                if isSearching {
                    query = ""
                }
            }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: active ? .bold : .medium))
                .foregroundStyle(active ? Theme.onPrimary : Theme.secondaryText.opacity(0.86))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6.5)
                .background(
                    active ? Theme.primary : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            active ? Theme.ink.opacity(0.12) : Color.clear,
                            lineWidth: 1
                        )
                )
                .animation(Motion.quick, value: active)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.95))
        .accessibilityLabel("\(title)分类")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    var categorySubChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip("全部", selected: selectedSubcategory == nil) {
                    selectedSubcategory = nil
                }
                ForEach(ExerciseLibrary.subcategories(for: selectedCategory ?? ""), id: \.self) { sub in
                    filterChip(sub, selected: selectedSubcategory == sub) {
                        selectedSubcategory = sub
                    }
                }
            }
        }
    }

    var equipmentFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip("全部", selected: selectedEquipment == nil && !savedOnly && !isSearching) {
                    selectedEquipment = nil
                    savedOnly = false
                    query = ""
                }
                filterChip("已添加", selected: savedOnly && selectedEquipment == nil && !isSearching) {
                    savedOnly = true
                    selectedEquipment = nil
                    query = ""
                }
                ForEach(Equipment.allCases) { equipment in
                    filterChip(
                        equipment.label,
                        selected: selectedEquipment == equipment && !savedOnly && !isSearching
                    ) {
                        selectedEquipment = equipment
                        savedOnly = false
                        query = ""
                    }
                }
            }
        }
    }

    func filterChip(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.select()
            withAnimation(Motion.quick) {
                action()
            }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? Theme.onPrimary : Theme.secondaryText.opacity(0.86))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    selected ? Theme.primary : Theme.paper,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(
                            selected ? Theme.ink.opacity(0.12) : Theme.stroke,
                            lineWidth: 1
                        )
                )
                .animation(Motion.quick, value: selected)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.95))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

}
