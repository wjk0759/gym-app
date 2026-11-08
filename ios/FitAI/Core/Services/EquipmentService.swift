import Foundation

/// 旧的本地 mock 已移除。
///
/// 器械识别必须走远程视觉模型；离线或服务不可用时由界面明确提示重试或手动
/// 添加，不能返回随机动作。保留这个命名空间给后续真正的本地分类器使用。
enum EquipmentService {
    static let unavailableMessage = "器械识别需要联网。请检查网络后重试，或手动添加器械。"
}
