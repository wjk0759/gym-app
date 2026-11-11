import SwiftUI
import UIKit

/// 本地缓存优先，其次远端图，最后回退到器械符号。
struct EquipmentPhotoView: View {
    let item: EquipmentItem
    let symbol: String
    var symbolSize: CGFloat = 22

    var body: some View {
        Group {
            if let data = item.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = AppConfig.resolveMediaURL(item.photoURL ?? catalogImage) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var catalogImage: String? {
        EquipmentCatalog.type(for: item.equipmentType)?.imageURLList.first
    }

    private var placeholder: some View {
        ZStack {
            Color.clear
            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .light))
                .foregroundStyle(Theme.cobalt)
        }
    }
}
