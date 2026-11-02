import SwiftUI

struct AgentMemoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var items: [AgentMemory] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingDelete: AgentMemory?

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if isLoading {
                        ProgressView().tint(Theme.cobalt)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    } else if items.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("还没有长期记忆")
                                .font(AppType.headline)
                                .foregroundStyle(Theme.ink)
                            Text("你告诉教练的稳定偏好、日程、器械和约束会自动提炼到这里。")
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    } else {
                        ForEach(items) { item in
                            memoryCard(item)
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppType.caption)
                            .foregroundStyle(Theme.danger)
                    }
                }
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("AI 记忆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await load() }
            .alert("删除这条记忆？", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("删除", role: .destructive) {
                    if let item = pendingDelete {
                        Task { await delete(item) }
                    }
                }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: {
                Text(pendingDelete?.content ?? "")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("MEMORY / AI 记忆")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text("教练会记住什么")
                .font(AppType.hero)
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("这里保存的是从对话中提炼出的稳定事实，不是完整聊天记录。关闭记忆后，教练仍可回答本次问题，但不会主动引用这些偏好。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func memoryCard(_ item: AgentMemory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(kindLabel(item.kind))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.cobalt)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.cobalt.opacity(0.08), in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Theme.cobalt.opacity(0.18), lineWidth: 1)
                    }
                Spacer()
                Button {
                    pendingDelete = item
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .buttonStyle(SubtlePressStyle(scale: 0.94))
                .accessibilityLabel("删除记忆")
            }
            Text(item.content)
                .font(AppType.callout)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text(item.source == "agent" ? "自动提炼" : item.source)
                if item.confidence > 0 {
                    Text("置信度 \(Int(item.confidence * 100))%")
                }
                if let updatedAt = item.updatedAt {
                    Text(updatedAt.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "schedule": return "训练日程"
        case "equipment": return "器械"
        case "injury": return "身体限制"
        case "constraint": return "约束"
        case "goal": return "目标"
        case "behavior": return "习惯"
        default: return "偏好"
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await AgentMemoryService().fetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ item: AgentMemory) async {
        pendingDelete = nil
        do {
            try await AgentMemoryService().delete(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
