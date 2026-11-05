import SwiftUI

/// Alternates start and peak stills for the action-path card.
/// RepDB is no longer used; if it is re-enabled, restore its required
/// "Exercise data by RepDB (repdb.co)" attribution.
struct FrameMotionBoard: View {
    let startURL: URL
    let endURL: URL
    let title: String

    @State private var showPeak = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.primary.opacity(0.10), Theme.paper],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            frame(url: startURL)
                .opacity(showPeak ? 0 : 1)

            frame(url: endURL)
                .opacity(showPeak ? 1 : 0)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    detailPill("双帧示意")
                    Spacer()
                    Text(showPeak ? "发力" : "起始")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Theme.paper.opacity(0.86), in: Capsule())
                }
                Spacer()
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(13)
        }
        .frame(height: 232)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    showPeak.toggle()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，动作双帧示意")
    }

    @ViewBuilder
    private func frame(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .tint(Theme.primary)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 30)
            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.ink.opacity(0.35))
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Theme.cobalt.opacity(0.92), in: Capsule())
    }
}
