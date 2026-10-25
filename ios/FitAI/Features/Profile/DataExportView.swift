import SwiftUI

struct DataExportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var json = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.secondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
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
