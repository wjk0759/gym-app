import AVKit
import SwiftUI

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let exercise: Exercise

    @ViewBuilder
    private var videoSection: some View {
        if let videoURL = exercise.videoURL {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "play.rectangle")
                        .foregroundStyle(Theme.accent)
                    Text("教学视频")
                        .font(.headline)
                }
                Text("还没有配置视频。把授权素材上传后，在 videos.json 里填上动作 slug 与播放地址即可。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            .card()
        }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.nameZH)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("动作要领")
                            .font(.headline)
                        Text(exercise.instructions)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .card()

                    videoSection
                    Button {
                        store.sendChat("\(exercise.nameZH)怎么用？需要注意什么？")
                        dismiss()
                    } label: {
                        Label("问教练这个动作", systemImage: "bubble.left")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("如果动作过程中出现关节刺痛、麻木或肿胀，请停止并咨询医生。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle("动作详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
