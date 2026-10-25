import PhotosUI
import SwiftUI
import UIKit

struct FoodPhotoAnalysisView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var imageData: Data?
    @State private var meal: MealType = .lunch
    @State private var items: [FoodRecognitionItem] = []
    @State private var confidence = 0.0
    @State private var analysisDisclaimer = ""
    @State private var analysisModel = ""
    @State private var isAnalyzing = false
    @State private var showCamera = false
    @State private var message = ""
    @State private var showAlert = false

    private var selectedItems: [FoodRecognitionItem] {
        items.filter(\.selected)
    }

    private var totalKcal: Double {
        selectedItems.reduce(0) { $0 + $1.kcal }
    }

    private var totalProtein: Double {
        selectedItems.reduce(0) { $0 + $1.protein }
    }

    private var totalCarbs: Double {
        selectedItems.reduce(0) { $0 + $1.carbs }
    }

    private var totalFat: Double {
        selectedItems.reduce(0) { $0 + $1.fat }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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

                    if !items.isEmpty {
                        resultCard
                    }

                    disclaimer
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("拍照识别饮食")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: photoItem?.itemIdentifier) { _, _ in
                guard let item = photoItem else { return }
                Task { @MainActor in
                    await load(item)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { picked in
                    apply(picked)
                }
                .ignoresSafeArea()
            }
            .alert("已加入今日饮食", isPresented: $showAlert) {
                Button("完成") { dismiss() }
            } message: {
                Text(message)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拍一张这餐的照片\n自动估算热量和营养")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("照片只用于本次识别，不保存。识别后可以修改份量、勾选实际吃下的食物，再加入今日饮食。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        .padding(10)
                    }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(Theme.accent)
                    Text("拍照或选择一张餐食照片")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text("尽量俯拍，让食物完整进入画面")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                )
            }

            HStack(spacing: 10) {
                Button {
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera")
                }
                .buttonStyle(SecondaryButtonStyle())

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("相册", systemImage: "photo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.accent.opacity(0.10))
                        )
                }
            }
        }
        .card()
    }

    private var mealCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("这是哪一餐？")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            Picker("餐次", selection: $meal) {
                ForEach(MealType.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
        }
        .card(padding: 14)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("识别结果")
                        .font(.headline)
                    Text("勾选实际吃下的食物，份量可以调")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
                Spacer()
                Text("参考置信度 \(Int(confidence * 100))%")
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
            }

            ForEach($items) { $item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 9) {
                        Toggle("", isOn: $item.selected)
                            .labelsHidden()
                            .tint(Theme.accent)

                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Spacer()

                        Text("\(Int(item.kcal)) kcal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }

                    HStack {
                        Stepper(value: $item.grams, in: 10...1000, step: 10) {
                            Text("份量 \(Int(item.grams)) g")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .labelsHidden()
                        Text("\(Int(item.grams)) g")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(width: 58, alignment: .trailing)
                    }

                    Text("P \(item.protein.formatted(.number.precision(.fractionLength(0))))g · C \(item.carbs.formatted(.number.precision(.fractionLength(0))))g · F \(item.fat.formatted(.number.precision(.fractionLength(0))))g")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .opacity(item.selected ? 1 : 0.45)
                .padding(10)
                .background(
                    Theme.surfaceStrong,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }

            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("合计")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(Int(totalKcal)) kcal")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.accent)
                }

                HStack(spacing: 10) {
                    resultMetric("\(Int(totalProtein))g", "蛋白质")
                    resultMetric("\(Int(totalCarbs))g", "碳水")
                    resultMetric("\(Int(totalFat))g", "脂肪")
                }
            }
            .padding(12)
            .background(
                Theme.surfaceStrong.opacity(0.75),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            if !analysisModel.isEmpty {
                Text(analysisModel.hasPrefix("local")
                     ? "当前为本地估算模式，结果仅用于演示流程。"
                     : "结果来自远程识别服务，照片未保存。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text(analysisDisclaimer)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                addToToday()
            } label: {
                Label("加入\(meal.label) · \(Int(totalKcal)) kcal", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedItems.isEmpty)
        }
        .card()
    }

    private func resultMetric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var disclaimer: some View {
        Text("饮食照片识别只能做估算，不能保证份量、烹饪油和隐藏配料完全准确。对花生、海鲜、乳制品等过敏原，请以包装标签或商家确认为准。")
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
    }

    private func analyze() {
        guard let imageData else { return }
        isAnalyzing = true
        items = []
        confidence = 0
        analysisDisclaimer = ""
        analysisModel = ""

        if store.useRemoteAI && store.isPro {
            Task { @MainActor in
                do {
                    finish(try await APIClient.shared.analyzeFood(imageData: imageData))
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
        isAnalyzing = false
    }

    private func addToToday() {
        let logs = selectedItems.map { item in
            FoodLog(
                date: Date(),
                meal: meal,
                foodName: item.name,
                grams: item.grams,
                kcal: item.kcal,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat
            )
        }
        store.addFoodLogs(logs)
        message = "已加入\(meal.label)，共 \(Int(totalKcal)) kcal。你可以在今日记录里继续修改或删除。"
        showAlert = true
    }

    private func apply(_ picked: UIImage) {
        image = picked
        imageData = picked.jpegData(compressionQuality: 0.7)
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
        items = []
    }
}
