import Foundation

enum ExerciseLibrary {
    static let all: [Exercise] = [
        Exercise(slug: "pushup", nameZH: "俯卧撑", nameEN: "Push-up", muscle: .chest, equipment: .bodyweight, isCompound: true, instructions: "双手略宽于肩，身体成一条直线。屈肘下沉至胸部接近地面，推起时呼气，全程收紧核心。", contraindications: ["shoulder_pain", "wrist_pain"]),
        Exercise(slug: "bench_press", nameZH: "杠铃卧推", nameEN: "Barbell Bench Press", muscle: .chest, equipment: .barbell, isCompound: true, instructions: "肩胛后缩下沉，双脚踩实。杠铃下放至胸骨中下段，前臂保持垂直，推起时不锁死肘关节。", contraindications: ["shoulder_pain"]),
        Exercise(slug: "dumbbell_press", nameZH: "哑铃卧推", nameEN: "Dumbbell Bench Press", muscle: .chest, equipment: .dumbbell, isCompound: true, instructions: "哑铃下放至胸部两侧，肘部约 45 度，推起时想象把哑铃推向天花板。", contraindications: ["shoulder_pain"]),
        Exercise(slug: "cable_fly", nameZH: "绳索夹胸", nameEN: "Cable Fly", muscle: .chest, equipment: .cable, isCompound: false, instructions: "身体前倾，手肘微屈固定，以胸肌发力把把手合拢，顶峰收缩 1 秒后缓慢还原。", contraindications: ["shoulder_pain"]),
        Exercise(slug: "pullup", nameZH: "引体向上", nameEN: "Pull-up", muscle: .back, equipment: .bodyweight, isCompound: true, instructions: "正握略宽于肩，先沉肩再拉，胸口靠近横杠。控制下放，避免摆动借力。", contraindications: ["shoulder_pain", "elbow_pain"]),
        Exercise(slug: "lat_pulldown", nameZH: "高位下拉", nameEN: "Lat Pulldown", muscle: .back, equipment: .machine, isCompound: true, instructions: "坐稳，胸口抬起，把横杆拉向上胸，肘部向下向后，不要用身体后仰借力。", contraindications: ["shoulder_pain"]),
        Exercise(slug: "seated_row", nameZH: "坐姿划船", nameEN: "Seated Cable Row", muscle: .back, equipment: .machine, isCompound: true, instructions: "挺胸收腹，把手拉向腹部，肩胛骨向后夹紧，还原时保持背部中立。", contraindications: ["lower_back"]),
        Exercise(slug: "barbell_row", nameZH: "杠铃划船", nameEN: "Barbell Row", muscle: .back, equipment: .barbell, isCompound: true, instructions: "髋部后移，背部保持中立，把杠铃拉向下腹，避免耸肩和腰部代偿。", contraindications: ["lower_back"]),
        Exercise(slug: "dumbbell_row", nameZH: "单臂哑铃划船", nameEN: "One-arm Dumbbell Row", muscle: .back, equipment: .dumbbell, isCompound: true, instructions: "一手撑凳，背部平直，把哑铃拉向髋部，肘部贴近身体。", contraindications: ["lower_back"]),
        Exercise(slug: "squat", nameZH: "杠铃深蹲", nameEN: "Barbell Back Squat", muscle: .legs, equipment: .barbell, isCompound: true, instructions: "双脚与肩同宽，脚尖略外展。髋膝同时屈曲下蹲至大腿平行，膝盖与脚尖方向一致。", contraindications: ["knee_pain", "lower_back"]),
        Exercise(slug: "goblet_squat", nameZH: "高脚杯深蹲", nameEN: "Goblet Squat", muscle: .legs, equipment: .dumbbell, isCompound: true, instructions: "双手托哑铃于胸前，保持躯干直立下蹲，肘部在膝盖内侧，脚跟踩实。", contraindications: ["knee_pain"]),
        Exercise(slug: "leg_press", nameZH: "腿举", nameEN: "Leg Press", muscle: .legs, equipment: .machine, isCompound: true, instructions: "腰背贴紧靠垫，双脚与肩同宽，下放至膝盖约 90 度，不要锁死膝关节。", contraindications: ["knee_pain", "lower_back"]),
        Exercise(slug: "romanian_deadlift", nameZH: "罗马尼亚硬拉", nameEN: "Romanian Deadlift", muscle: .legs, equipment: .barbell, isCompound: true, instructions: "膝盖微屈固定，髋部后移，杠铃贴腿下放至腘绳肌有拉伸感，背部全程中立。", contraindications: ["lower_back"]),
        Exercise(slug: "lunge", nameZH: "箭步蹲", nameEN: "Walking Lunge", muscle: .legs, equipment: .bodyweight, isCompound: true, instructions: "向前迈步，下蹲至前后膝约 90 度，前膝不超过脚尖过多，保持躯干直立。", contraindications: ["knee_pain"]),
        Exercise(slug: "hip_thrust", nameZH: "杠铃臀推", nameEN: "Barbell Hip Thrust", muscle: .glutes, equipment: .barbell, isCompound: true, instructions: "上背靠凳，杠铃置于髋部，收紧核心把髋推到躯干与大腿成一直线，顶峰夹紧臀部。", contraindications: ["lower_back"]),
        Exercise(slug: "glute_bridge", nameZH: "臀桥", nameEN: "Glute Bridge", muscle: .glutes, equipment: .bodyweight, isCompound: false, instructions: "仰卧屈膝，脚跟靠近臀部，收紧臀部把髋抬起，避免用腰部代偿。"),
        Exercise(slug: "shoulder_press", nameZH: "哑铃推举", nameEN: "Dumbbell Shoulder Press", muscle: .shoulders, equipment: .dumbbell, isCompound: true, instructions: "坐姿或站姿，核心收紧，把哑铃从肩部推至头顶，肘部不要完全锁死。", contraindications: ["shoulder_pain"]),
        Exercise(slug: "lateral_raise", nameZH: "侧平举", nameEN: "Lateral Raise", muscle: .shoulders, equipment: .dumbbell, isCompound: false, instructions: "手肘微屈，以肩部发力把哑铃抬至与肩同高，避免耸肩和摆动。", contraindications: ["shoulder_pain"]),
        Exercise(slug: "face_pull", nameZH: "面拉", nameEN: "Face Pull", muscle: .shoulders, equipment: .cable, isCompound: false, instructions: "绳索调至面部高度，向面部方向拉，肘部打开，肩胛骨后缩。", contraindications: ["shoulder_pain"]),
        Exercise(slug: "biceps_curl", nameZH: "哑铃弯举", nameEN: "Dumbbell Curl", muscle: .arms, equipment: .dumbbell, isCompound: false, instructions: "肘部固定在身体两侧，弯举时避免借力，下放时控制 2 秒。", contraindications: ["elbow_pain"]),
        Exercise(slug: "triceps_pushdown", nameZH: "绳索下压", nameEN: "Triceps Pushdown", muscle: .arms, equipment: .cable, isCompound: false, instructions: "肘部固定，向下压至手臂伸直，顶峰收紧三头，缓慢还原。", contraindications: ["elbow_pain"]),
        Exercise(slug: "plank", nameZH: "平板支撑", nameEN: "Plank", muscle: .core, equipment: .bodyweight, isCompound: false, instructions: "肘部在肩正下方，身体成直线，收紧核心与臀部，避免塌腰。", contraindications: ["lower_back", "shoulder_pain"]),
        Exercise(slug: "crunch", nameZH: "卷腹", nameEN: "Crunch", muscle: .core, equipment: .bodyweight, isCompound: false, instructions: "仰卧屈膝，用腹部力量把肩胛骨卷离地面，下背贴地，不要用手拉头。", contraindications: ["lower_back"]),
        Exercise(slug: "hanging_leg_raise", nameZH: "悬垂举腿", nameEN: "Hanging Leg Raise", muscle: .core, equipment: .bodyweight, isCompound: false, instructions: "悬垂稳定身体，用腹部力量把腿抬起，避免摆动借力。", contraindications: ["shoulder_pain", "lower_back"]),
        Exercise(slug: "burpee", nameZH: "波比跳", nameEN: "Burpee", muscle: .cardio, equipment: .bodyweight, isCompound: true, instructions: "下蹲撑地，后跳成俯卧撑姿，收腿起身跳起，保持节奏。", contraindications: ["knee_pain", "lower_back", "wrist_pain"]),
        Exercise(slug: "rowing_machine", nameZH: "划船机", nameEN: "Rowing Machine", muscle: .cardio, equipment: .machine, isCompound: true, instructions: "腿-核心-手臂的顺序发力，回程相反。保持背部中立，不要只用手臂拉。", contraindications: ["lower_back"]),
        Exercise(slug: "treadmill_walk", nameZH: "跑步机快走", nameEN: "Treadmill Walk", muscle: .cardio, equipment: .machine, isCompound: false, instructions: "坡度 3–8%，速度以能说短句为准，身体直立，不要扶把手。", contraindications: ["knee_pain"])
    ]

    private static let index: [String: Exercise] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.slug, $0) }
    )

    static func exercise(slug: String) -> Exercise? {
        index[slug]
    }

    static func candidates(
        muscle: MuscleGroup? = nil,
        equipment: Set<Equipment> = Set(Equipment.allCases)
    ) -> [Exercise] {
        all.filter { item in
            let muscleMatch = muscle == nil || item.muscle == muscle
            let equipmentMatch = equipment.contains(item.equipment)
            return muscleMatch && equipmentMatch
        }
    }

    static func search(_ text: String) -> [Exercise] {
        guard !text.isEmpty else { return all }
        return all.filter {
            $0.nameZH.contains(text) || $0.nameEN.localizedCaseInsensitiveContains(text)
        }
    }
}
