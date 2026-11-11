import SwiftUI

/// 目录器械图片：本地资源/远端图，失败时回退到器械符号。
struct EquipmentTypeImageView: View {
    let info: EquipmentTypeInfo
    var index: Int = 0
    var symbolSize: CGFloat = 26
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let raw = imagePath, let url = AppConfig.resolveMediaURL(raw) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder
                    default:
                        ZStack {
                            Theme.ink.opacity(0.03)
                            ProgressView()
                                .tint(Theme.tertiaryText)
                        }
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var imagePath: String? {
        let urls = info.imageURLList
        guard urls.indices.contains(index) else { return nil }
        return urls[index]
    }

    private var placeholder: some View {
        ZStack {
            Theme.ink.opacity(0.03)
            Image(systemName: info.symbolName)
                .font(.system(size: symbolSize, weight: .light))
                .foregroundStyle(Theme.cobalt)
        }
    }
}
