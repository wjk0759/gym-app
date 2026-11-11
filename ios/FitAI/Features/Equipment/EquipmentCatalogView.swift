import SwiftUI

/// 器械库添加页：按部位浏览 70 类物理器械。
struct EquipmentCatalogView: View {
    var body: some View {
        EquipmentBrowserView(mode: .addToLibrary)
    }
}
