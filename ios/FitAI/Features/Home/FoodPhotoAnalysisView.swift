import PhotosUI
import SwiftUI
import UIKit

struct FoodPhotoAnalysisView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    let date: Date

    init(date: Date = Date()) {
        self.date = Calendar.current.startOfDay(for: date)
    }

    @State var photoItem: PhotosPickerItem?
    @State var image: UIImage?
    @State var imageData: Data?
    @State var analysisKey = UUID().uuidString
    @State var meal: MealType = .lunch
    @State var items: [FoodRecognitionItem] = []
    @State var confidence = 0.0
    @State var analysisDisclaimer = ""
    @State var analysisModel = ""
    @State var analysisSummary = ""
    @State var isFood = true
    @State var isAnalyzing = false
    @State var showCamera = false
    @State var didAutoStartCamera = false
    @State var message = ""
    @State var showAlert = false

    var selectedItems: [FoodRecognitionItem] {
        items.filter(\.selected)
    }

    var totalKcal: Double {
        selectedItems.reduce(0) { $0 + $1.kcal }
    }

    var totalProtein: Double {
        selectedItems.reduce(0) { $0 + $1.protein }
    }

    var totalCarbs: Double {
        selectedItems.reduce(0) { $0 + $1.carbs }
    }

    var totalFat: Double {
        selectedItems.reduce(0) { $0 + $1.fat }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: 16) {
                    header
                    photoCard
                    mealCard

                    Button {
                        analyze()
                    } label: {
                        if isAnalyzing {
                            HStack(spacing: 8) {
                                ProgressView().tint(.black)
                                Text("正在识别…")
                            }
                        } else {
                            Text("识别这餐并计算热量")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(imageData == nil || isAnalyzing)

                    if !analysisSummary.isEmpty {
                        summaryCard
                    }

                    if !items.isEmpty {
                        resultCard
                    }

                    disclaimer
                }
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("拍照识别饮食")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: photoItem) { _, _ in
                guard let item = photoItem else { return }
                Task { @MainActor in
                    await load(item)
                }
            }
            .fullScreenCover(
                isPresented: $showCamera,
                onDismiss: {
                    if imageData == nil {
                        dismiss()
                    }
                }
            ) {
                PhotoCaptureView(
                    title: "拍摄餐食",
                    hint: "尽量俯拍，让整餐完整进入画面。",
                    onImage: { picked in
                        apply(picked)
                        showCamera = false
                    },
                    onCancel: {
                        showCamera = false
                    }
                )
            }
            .task {
                guard !didAutoStartCamera, imageData == nil else { return }
                didAutoStartCamera = true
                showCamera = true
            }
            .alert("已加入今日饮食", isPresented: $showAlert) {
                Button("完成") { dismiss() }
            } message: {
                Text(message)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("VISION / 饮食识别")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text("拍一餐，算个大概")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("照片只用于本次识别，不保存。识别后可以修改份量、勾选实际吃下的食物，再加入今日饮食。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

        }
    }

    private var photoCard: some View {
        VStack(spacing: 12) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 230)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            self.image = nil
                            imageData = nil
                            photoItem = nil
                            items = []
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.onMedia)
                                .padding(8)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        .padding(10)
                    }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(Theme.cobalt)
                    Text("拍照或选择一张餐食照片")
                        .font(AppType.callout.weight(.medium))
                        .foregroundStyle(Theme.ink)
                    Text("尽量俯拍，让食物完整进入画面")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .background(
                    Theme.ink.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                )
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera")
                }
                .buttonStyle(SecondaryButtonStyle())

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("相册", systemImage: "photo")
                        .font(AppType.buttonSecondary)
                        .foregroundStyle(Theme.cobalt)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            Theme.ink.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        }
                }
            }
        }
        .card()
    }

    private var mealCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("这是哪一餐？")
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Picker("餐次", selection: $meal) {
                ForEach(MealType.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .tint(Theme.cobalt)
        }
        .card(padding: 14)
    }





    private var disclaimer: some View {
        Text("饮食照片识别只能做估算，不能保证份量、烹饪油和隐藏配料完全准确。对花生、海鲜、乳制品等过敏原，请以包装标签或商家确认为准。")
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
    }

    private var summaryCard: some View {
        Text(analysisSummary)
            .font(AppType.caption)
            .foregroundStyle(isFood ? Theme.secondaryText : Theme.coral)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                (isFood ? Theme.paper : Theme.coral.opacity(0.07)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFood ? Theme.stroke : Theme.coral.opacity(0.24),
                        lineWidth: 1
                    )
            }
    }

    private func analyze() {
        guard let imageData else { return }
        isAnalyzing = true
        items = []
        confidence = 0
        analysisDisclaimer = ""
        analysisModel = ""

        if store.canUseRemoteAI {
            Task { @MainActor in
                do {
                    finish(try await FoodVisionService.analyzeRemote(
                        imageData: imageData,
                        idempotencyKey: analysisKey
                    ))
                } catch {
                    finish(FoodVisionService.analyze(imageData: imageData))
                }
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            finish(FoodVisionService.analyze(imageData: imageData))
        }
    }

    private func finish(_ result: FoodRecognitionResult) {
        items = result.items
        confidence = result.confidence
        analysisDisclaimer = result.disclaimer
        analysisModel = result.model
        analysisSummary = result.summary
        isFood = result.isFood
        isAnalyzing = false
    }

    func addToToday() {
        let logs = selectedItems.map { item in
            FoodLog(
                date: date,
                meal: meal,
                foodName: item.name,
                grams: item.grams,
                kcal: item.kcal,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                fiber: item.fiber
            )
        }
        store.addFoodLogs(logs)
        message = "已加入\(meal.label)，共 \(Int(totalKcal)) kcal。你可以在饮食记录里继续修改或删除。"
        showAlert = true
    }

    private func apply(_ picked: UIImage) {
        image = picked
        imageData = picked.jpegData(compressionQuality: 0.7)
        analysisKey = UUID().uuidString
        items = []
    }

    @MainActor
    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let picked = UIImage(data: data) else {
            return
        }
        imageData = picked.jpegData(compressionQuality: 0.7)
        image = picked
        analysisKey = UUID().uuidString
        items = []
        photoItem = nil
    }
}
