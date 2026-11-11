import SwiftUI

/// 手动添加器械时的类型选择：与器械库使用同一套部位/图片/详情。
struct EquipmentTypePickerView: View {
    let onSelect: (EquipmentTypeInfo?) -> Void

    var body: some View {
        EquipmentBrowserView(mode: .selectType(onSelect))
    }
}
