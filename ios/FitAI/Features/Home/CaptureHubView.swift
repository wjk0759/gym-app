import Foundation
import SwiftUI

enum CaptureKind: String, Identifiable {
    case food
    case body
    case equipment
    case action

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return "拍饮食"
        case .body: return "拍体型"
        case .equipment: return "拍器械"
        case .action: return "拍动作"
        }
    }

    var detail: String {
        switch self {
        case .food: return "估算热量、蛋白和碳水"
        case .body: return "看体态和训练重点"
        case .equipment: return "识别器械，加入动作库"
        case .action: return "关键帧点评动作"
        }
    }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .body: return "figure.stand"
        case .equipment: return "dumbbell.fill"
        case .action: return "video.fill"
        }
    }

    var accent: Color {
        switch self {
        case .food: return Theme.coral
        case .body: return Theme.cobalt
        case .equipment: return Theme.lime
        case .action: return Theme.accentWarm
        }
    }
}

/// One camera entry for every visual capability. The screens themselves are
/// unchanged; this only replaces four scattered entry points with one obvious
/// action that still routes to the existing food/body/equipment/video flows.
struct CaptureHubView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (CaptureKind) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    EditorialHeader(
                        eyebrow: "视觉输入",
                        title: "拍一张，比打字快",
                        subtitle: "照片和视频只用于本次分析，原图不保存。"
                    )

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach([CaptureKind.food, .body, .equipment, .action]) { kind in
                            Button {
                                Haptics.tap()
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    onSelect(kind)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(systemName: kind.symbol)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(Theme.onAccent)
                                        .frame(width: 48, height: 48)
                                        .background(kind.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1)
                                        }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(kind.title)
                                            .font(AppType.headline)
                                            .foregroundStyle(Theme.ink)
                                        Text(kind.detail)
                                            .font(AppType.micro)
                                            .foregroundStyle(Theme.secondaryText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                                .padding(14)
                                .background(Theme.paper)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Theme.stroke, lineWidth: 1)
                                }
                            }
                            .buttonStyle(CardPressStyle(scale: 0.98))
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(Theme.cobalt)
                        Text("拍照后会先给你确认页；不会直接写入饮食或身体记录。")
                            .font(AppType.micro)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(.top, 4)
                }
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("拍照")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
