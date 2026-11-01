import SwiftUI

struct DataExportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var json = ""

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("DATA / 导出")
                        .font(AppType.overline)
                        .tracking(1.5)
                        .foregroundStyle(Theme.cobalt)

                    Text("我的数据")
                        .font(AppType.hero)
                        .tracking(-0.6)
                        .foregroundStyle(Theme.ink)

                    Text("JSON 包含本机训练、饮食、身体和计划数据；分享前请确认接收方。")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(json)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(Theme.secondaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        }
                }
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("导出数据")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if json.isEmpty {
                    json = store.exportData()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: json) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
