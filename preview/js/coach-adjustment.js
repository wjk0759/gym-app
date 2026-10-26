/* FitAI Web Preview module: coach-led, evidence-based plan adjustment flow. */

function adjustmentQuote(text, limit = 80) {
  const value = String(text || "").replace(/\s+/g, " ").trim();
  return value.length > limit ? `${value.slice(0, limit)}…` : value;
}

function classifyAdjustmentIssue(text) {
  const value = String(text || "");
  if (/疼|痛|膝|肩|腰|肘|腕|麻|肿|伤|不舒服/.test(value)) return "pain";
  if (/时间|忙|没空|加班|分钟|小时|频率|几天|练不完/.test(value)) return "time";
  if (/恢复|累|疲劳|睡|酸|疲惫|没力|状态差/.test(value)) return "recovery";
  if (/重量|卡|瓶颈|不涨|进步|平台|停滞/.test(value)) return "plateau";
  if (/太满|太多|坚持|缺练|放弃|中断/.test(value)) return "tooMuch";
  if (/不想|懒|动力|没兴趣|提不起劲/.test(value)) return "motivation";
  return "generic";
}

function adjustmentDetailPrompt(category) {
  const prompts = {
    pain: {
      text: "收到，安全优先。先别急着硬练。具体是哪个位置不舒服：膝、肩、腰、肘还是手腕？是哪个动作最明显，疼到几分（1–10）？有没有刺痛、麻木或肿胀？如果出现这些信号，我会建议你先停止相关动作并做专业评估。",
      quickReplies: ["膝盖，深蹲时明显", "肩膀，推举时疼", "腰，硬拉后不舒服", "肘或腕，撑地时疼"]
    },
    time: {
      text: "明白，时间是最现实的约束。你现在每次实际能练多久、每周最多几天？我宁愿把计划压缩到你真的能完成，也不想给你排一个看起来很满、实际坚持不了的计划。",
      quickReplies: ["每次 30 分钟，每周 2 天", "每次 45 分钟，每周 3 天", "每次 60 分钟，每周 3 天"]
    },
    recovery: {
      text: "收到。最近睡眠大概几小时？训练后酸痛会持续几天？是全身都累，还是某个部位恢复特别慢？我会先调容量和休息，不继续加量。",
      quickReplies: ["睡 5–6 小时，总是累", "酸痛 2 天以上", "工作忙，恢复不过来"]
    },
    plateau: {
      text: "收到。是哪几个动作卡住了？大概多久没进步？每组是做到力竭，还是还留有余力？我会先改负荷进阶和次数，不会只让你“再拼一点”。",
      quickReplies: ["深蹲和卧推卡住", "1 个月没进步", "每次都快力竭但还是不涨"]
    },
    tooMuch: {
      text: "明白，计划需要匹配真实生活。最近一周哪几天最容易缺练？每次能完成几个动作？我会把计划压缩到你能稳定执行的版本，再逐步加量。",
      quickReplies: ["经常加班，缺练", "每次只能做 3 个动作", "计划太满，想减一天"]
    },
    motivation: {
      text: "收到。先不评判自己，能坚持比一次练狠更重要。你更希望计划更短、更有趣，还是固定一个更容易执行的时间？我会先降低启动难度。",
      quickReplies: ["想要更短的计划", "想固定晚上练", "先让我重新开始"]
    },
    generic: {
      text: "收到。我想再确认一下：最想先解决的是训练频率、动作选择、组数 / 重量、恢复，还是时间？最好举一个最近训练里的具体例子，我会按你的真实情况改。",
      quickReplies: ["训练频率", "动作选择", "组数 / 重量", "恢复或时间"]
    }
  };
  return prompts[category] || prompts.generic;
}

function detectPainArea(text) {
  const value = String(text || "");
  if (/膝|腿|膝盖/.test(value)) return { muscle: "腿", label: "腿部 / 膝" };
  if (/肩/.test(value)) return { muscle: "肩", label: "肩部" };
  if (/腰|下背/.test(value)) return { muscle: "腿", label: "腰背 / 下肢链" };
  if (/肘|腕|手/.test(value)) return { muscle: "手臂", label: "手臂 / 肘腕" };
  return null;
}

function adjustmentMinutesFromText(text) {
  const match = String(text || "").match(/(\d{2,3})\s*(分钟|分|min)/);
  return match ? Number(match[1]) : null;
}

function adjustmentDaysFromText(text) {
  const value = String(text || "");
  const match = value.match(/(?:每周|一周)[^\d]{0,5}(\d)\s*(?:天|练)/)
    || value.match(/(\d)\s*天(?:训练|练)?/);
  const days = match ? Number(match[1]) : null;
  return days && days >= 1 && days <= 6 ? days : null;
}

function adjustmentNamedExerciseSlugs(text) {
  const value = String(text || "");
  const known = [
    ["深蹲", "goblet_squat"],
    ["箭步蹲", "lunge"],
    ["卧推", "dumbbell_press"],
    ["推举", "shoulder_press"],
    ["硬拉", "romanian_deadlift"],
    ["划船", "seated_row"],
    ["下拉", "lat_pulldown"],
    ["臀推", "hip_thrust"],
    ["腿举", "leg_press"],
    ["俯卧撑", "pushup"]
  ];
  return known.filter(([name]) => value.includes(name)).map(([, slug]) => slug);
}

function buildPlanAdjustmentProposal(issue, detail, category) {
  const recent = state.sessions.filter((session) => {
    const date = new Date(Number(session.timestamp) || 0);
    return date >= addDays(new Date(), -30);
  });
  const weekCount = currentWeekSessions().length;
  const avgMinutes = recent.length
    ? Math.round(recent.reduce((sum, session) => sum + Number(session.duration || 0), 0) / recent.length)
    : 0;
  const evidence = recent.length
    ? `最近 30 天完成 ${recent.length} 次训练，本周 ${weekCount} 次，平均 ${avgMinutes} 分钟。`
    : "目前训练记录还不多，我会用更保守的调整，先确保你能稳定执行。";

  let type = category;
  let setsDelta = 0;
  let weightMultiplier = 1;
  let restDelta = 0;
  let maxExercises = null;
  let maxDaysPerWeek = null;
  let painMuscle = null;
  let avoidSlugs = [];
  let headline = "先把计划调到你能稳定执行";
  let analysis = "";
  let changes = [];

  if (category === "pain") {
    const area = detectPainArea(`${issue} ${detail}`);
    painMuscle = area?.muscle || null;
    if (!area) {
      setsDelta = -1;
      weightMultiplier = 0.9;
    }
    avoidSlugs = adjustmentNamedExerciseSlugs(`${issue} ${detail}`);
    restDelta = 15;
    headline = "先避开疼痛，再谈进步";
    analysis = area
      ? `我的判断是：${area.label}相关动作先降到 2 组、负重下调 10%，同时增加组间休息。`
      : "你没有说清具体位置，我会先整体降低相关动作的组数和负重。";
    changes = [
      area ? `${area.label}相关动作改为 2 组、负重 -10%` : "所有可能诱发疼痛的动作降到 2 组、负重 -10%",
      avoidSlugs.length
        ? `先把${avoidSlugs.map((slug) => EX[slug]?.name || slug).join("、")}移出计划`
        : "先避开会诱发疼痛的动作，不硬顶",
      "组间休息增加 15 秒，训练前先做 5 分钟动态热身",
      "出现刺痛、麻木或肿胀时停止训练，并进行专业评估"
    ];
  } else if (category === "time") {
    const minutes = adjustmentMinutesFromText(detail);
    const days = adjustmentDaysFromText(detail) || adjustmentDaysFromText(issue);
    maxExercises = minutes && minutes <= 30 ? 3 : 4;
    maxDaysPerWeek = days;
    restDelta = minutes && minutes <= 30 ? -15 : 0;
    headline = "把计划压缩到真实可完成的长度";
    analysis = `我的判断是：时间有限${minutes ? `，每次大约 ${minutes} 分钟` : ""}。不会继续往计划里塞动作，而是优先保留主项。`;
    changes = [
      `每个训练日最多保留 ${maxExercises} 个动作，主项优先`,
      maxDaysPerWeek ? `每周只保留 ${maxDaysPerWeek} 个训练日，其余安排恢复` : "保留最容易坚持的训练频率",
      "去掉低优先级的孤立动作，保留推、拉、蹲 / 髋主导动作",
      "先连续两周完成，再考虑增加动作或训练量"
    ];
  } else if (category === "recovery") {
    setsDelta = -1;
    weightMultiplier = 0.95;
    restDelta = 30;
    headline = "先把恢复拉回来，不继续加量";
    analysis = "我的判断是：恢复慢、疲劳或睡眠不足时，当前更需要降容量和负荷，而不是用意志力硬顶。";
    changes = [
      "每个动作减少 1 组，保留动作质量",
      "负重下调 5%，先把动作稳定性和睡眠拉回来",
      "组间休息增加 30 秒，下一次训练前确认疲劳已恢复"
    ];
  } else if (category === "plateau") {
    weightMultiplier = 1.025;
    restDelta = 15;
    maxExercises = 4;
    headline = "换进阶方式，不靠每次拼到力竭";
    analysis = "我的判断是：先减少无效容量，把主项做得更重、更干净，再观察两周趋势。";
    changes = [
      "主项负重 +2.5%，每个动作保留 1–2 次余力",
      "每个训练日最多 4 个动作，把精力留给主项",
      "组间休息增加 15 秒，连续两周记录同一动作表现"
    ];
  } else if (category === "tooMuch") {
    setsDelta = -1;
    weightMultiplier = 0.95;
    maxExercises = 4;
    restDelta = 15;
    headline = "先把完成率做回来";
    analysis = "我的判断是：完成率比单次强度更重要，这版先减量。";
    changes = [
      "每个训练日最多 4 个动作",
      "每个动作减少 1 组，负重下调 5%",
      "先稳定完成两周，再逐周增加一个动作或一组"
    ];
  } else if (category === "motivation") {
    setsDelta = -1;
    maxExercises = 3;
    restDelta = 15;
    headline = "先把启动难度降到最低";
    analysis = "我的判断是：先把训练缩短到容易开始，再靠连续完成建立节奏。";
    changes = [
      "每个训练日压缩到 3 个动作",
      "每个动作减少 1 组，先保留最容易执行的主项",
      "连续完成两周后再加量，不追求一次练到极限"
    ];
  } else {
    setsDelta = -1;
    weightMultiplier = 0.95;
    maxExercises = 4;
    restDelta = 15;
    headline = "先做一版更稳的计划";
    analysis = "信息还不够具体，这版先保守减量，避免继续累积疲劳。";
    changes = [
      "每个训练日最多 4 个动作",
      "每个动作减少 1 组，负重下调 5%",
      "两周后根据完成率和感受再决定是否加量"
    ];
  }

  return {
    id: `adjust-${Date.now()}`,
    type,
    headline,
    summary: `${evidence}你提到“${adjustmentQuote(`${issue} ${detail}`)}”。${analysis}`,
    changes,
    setsDelta,
    weightMultiplier,
    restDelta,
    maxExercises,
    maxDaysPerWeek,
    painMuscle,
    avoidSlugs,
    createdAt: Date.now()
  };
}

function applyPlanAdjustmentToStore(proposal) {
  if (!proposal || !state.plan) return null;
  state.plan.version += 1;
  state.plan.updatedAt = Date.now();
  state.plan.lastAdjustment = {
    version: state.plan.version,
    headline: proposal.headline,
    summary: proposal.summary,
    changes: proposal.changes,
    appliedAt: Date.now()
  };

  state.plan.days.forEach((day) => {
    let exercises = day.exercises
      .filter((exercise) => !proposal.avoidSlugs?.includes(exercise.slug))
      .map((exercise) => {
        const next = { ...exercise };
        next.sets = Math.max(2, Math.min(6, Number(next.sets) + proposal.setsDelta));
        next.rest = Math.max(30, Math.min(180, Number(next.rest) + proposal.restDelta));
        if (Number(next.weight) > 0 && proposal.weightMultiplier !== 1) {
          next.weight = roundHalf(Number(next.weight) * proposal.weightMultiplier);
        }
        if (proposal.painMuscle && EX[next.slug]?.muscle === proposal.painMuscle) {
          next.sets = Math.min(next.sets, 2);
          if (Number(next.weight) > 0) next.weight = roundHalf(Number(next.weight) * 0.9);
        }
        return next;
      });
    if (proposal.maxExercises) {
      exercises = exercises.slice(0, Math.max(2, proposal.maxExercises));
    }
    day.exercises = exercises;
    day.focus = [...new Set(exercises.map((exercise) => EX[exercise.slug]?.muscle).filter(Boolean))];
  });

  if (proposal.maxDaysPerWeek) {
    state.plan.days = state.plan.days.filter((day) => {
      const weekDays = state.plan.days
        .filter((entry) => entry.week === day.week)
        .sort((left, right) => left.weekday - right.weekday);
      const index = weekDays.findIndex((entry) => entry.id === day.id);
      return index < proposal.maxDaysPerWeek;
    });
    state.profile.weeklyDays = proposal.maxDaysPerWeek;
    state.plan.title = /每周\s*\d+\s*练/.test(state.plan.title)
      ? state.plan.title.replace(/每周\s*\d+\s*练/, `每周 ${proposal.maxDaysPerWeek} 练`)
      : `${state.plan.title} · 每周 ${proposal.maxDaysPerWeek} 练`;
  }

  return state.plan.lastAdjustment;
}
