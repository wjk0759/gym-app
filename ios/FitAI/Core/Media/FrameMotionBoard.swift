import SwiftUI

/// RepDB Free evaluation surface: alternates the start and peak stills in the
/// UI. The source images stay separate; no GIF or derived media file is made.
struct FrameMotionBoard: View {
    let startURL: URL
    let endURL: URL
    let title: String

    @State private var showPeak = false

    private let attributionURL = URL(string: "https://repdb.co/")!

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.86, green: 0.93, blue: 0.97),
                    Color(red: 0.70, green: 0.82, blue: 0.91)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            frame(url: startURL)
                .opacity(showPeak ? 0 : 1)

            frame(url: endURL)
                .opacity(showPeak ? 1 : 0)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    detailPill("RepDB Free · 双帧")
                    Spacer()
                    Text(showPeak ? "发力" : "起始")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.08, green: 0.19, blue: 0.28))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.72), in: Capsule())
                }
                Spacer()
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.07, green: 0.16, blue: 0.24))
                Link("Exercise data by RepDB (repdb.co)", destination: attributionURL)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color(red: 0.10, green: 0.30, blue: 0.48))
            }
            .padding(13)
        }
        .frame(height: 232)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
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
        .accessibilityLabel("\(title)，RepDB 动作双帧示意")
    }

    @ViewBuilder
    private func frame(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .tint(Color(red: 0.10, green: 0.23, blue: 0.34))
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 30)
            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color(red: 0.10, green: 0.23, blue: 0.34).opacity(0.35))
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(Color(red: 0.02, green: 0.14, blue: 0.08))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Theme.accent.opacity(0.92), in: Capsule())
    }
}
