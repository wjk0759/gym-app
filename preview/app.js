/* FitAI Web Preview — 只用于界面与流程演示，不是 iOS 模拟器 */

const STORAGE_KEY = "fitai-preview-v1";

const EX = {
  goblet_squat: { name: "高脚杯深蹲", muscle: "腿", equip: "哑铃", base: 12, cues: "双手托哑铃于胸前，保持躯干直立下蹲，肘部在膝盖内侧，脚跟踩实。" },
  pushup: { name: "俯卧撑", muscle: "胸", equip: "徒手", base: 0, cues: "双手略宽于肩，身体成一条直线。屈肘下沉至胸部接近地面，推起时呼气。" },
  lat_pulldown: { name: "高位下拉", muscle: "背", equip: "固定器械", base: 25, cues: "坐稳，胸口抬起，把横杆拉向上胸，肘部向下向后，不要用身体后仰借力。" },
  seated_row: { name: "坐姿划船", muscle: "背", equip: "固定器械", base: 25, cues: "挺胸收腹，把手拉向腹部，肩胛骨向后夹紧，还原时保持背部中立。" },
  shoulder_press: { name: "哑铃推举", muscle: "肩", equip: "哑铃", base: 8, cues: "核心收紧，把哑铃从肩部推至头顶，肘部不要完全锁死。" },
  dumbbell_press: { name: "哑铃卧推", muscle: "胸", equip: "哑铃", base: 10, cues: "哑铃下放至胸部两侧，肘部约 45 度，推起时想象把哑铃推向天花板。" },
  plank: { name: "平板支撑", muscle: "核心", equip: "徒手", base: 0, fixedReps: "30-45s", cues: "肘部在肩正下方，身体成直线，收紧核心与臀部，避免塌腰。" },
  lunge: { name: "箭步蹲", muscle: "腿", equip: "徒手", base: 0, cues: "向前迈步，下蹲至前后膝约 90 度，前膝不超过脚尖过多，保持躯干直立。" },
  face_pull: { name: "面拉", muscle: "肩", equip: "绳索", base: 10, cues: "绳索调至面部高度，向面部方向拉，肘部打开，肩胛骨后缩。" },
  crunch: { name: "卷腹", muscle: "核心", equip: "徒手", base: 0, cues: "用腹部力量把肩胛骨卷离地面，下背贴地，不要用手拉头。" },
  hip_thrust: { name: "杠铃臀推", muscle: "臀", equip: "杠铃", base: 30, cues: "上背靠凳，杠铃置于髋部，收紧核心把髋推到躯干与大腿成一直线。" },
  triceps_pushdown: { name: "绳索下压", muscle: "手臂", equip: "绳索", base: 10, cues: "肘部固定，向下压至手臂伸直，顶峰收紧三头，缓慢还原。" },
  biceps_curl: { name: "哑铃弯举", muscle: "手臂", equip: "哑铃", base: 8, cues: "肘部固定在身体两侧，弯举时避免借力，下放时控制 2 秒。" },
  leg_press: { name: "腿举", muscle: "腿", equip: "固定器械", base: 40, cues: "腰背贴紧靠垫，下放至膝盖约 90 度，不要锁死膝关节。" },
  romanian_deadlift: { name: "罗马尼亚硬拉", muscle: "腿", equip: "杠铃", base: 30, cues: "膝盖微屈固定，髋部后移，杠铃贴腿下放，背部全程中立。" },
  lateral_raise: { name: "侧平举", muscle: "肩", equip: "哑铃", base: 4, cues: "手肘微屈，以肩部发力把哑铃抬至与肩同高，避免耸肩和摆动。" },
  rowing: { name: "划船机", muscle: "有氧", equip: "固定器械", base: 0, fixedReps: "8-12 min", cues: "腿-核心-手臂的顺序发力，回程相反，保持背部中立。" },
  burpee: { name: "波比跳", muscle: "有氧", equip: "徒手", base: 0, cues: "下蹲撑地，后跳成俯卧撑姿，收腿起身跳起，保持节奏。" },
  treadmill: { name: "跑步机", muscle: "有氧", equip: "固定器械", base: 0, fixedReps: "10-20 min", cues: "坡度 3–8%，速度以能说短句为准，身体直立，不要扶把手。" }
};

const FOODS = [
  { name: "燕麦（干）", cat: "主食", kcal: 367, p: 15, c: 61, f: 6.7 },
  { name: "米饭", cat: "主食", kcal: 116, p: 2.6, c: 25.9, f: 0.3 },
  { name: "糙米饭", cat: "主食", kcal: 111, p: 2.6, c: 23, f: 0.9 },
  { name: "红薯", cat: "主食", kcal: 86, p: 1.6, c: 20.1, f: 0.1 },
  { name: "全麦面包", cat: "主食", kcal: 247, p: 13, c: 41, f: 3.4 },
  { name: "鸡胸肉", cat: "蛋白质", kcal: 133, p: 24, c: 0, f: 5 },
  { name: "鸡蛋", cat: "蛋白质", kcal: 143, p: 13, c: 1, f: 10 },
  { name: "牛肉", cat: "蛋白质", kcal: 125, p: 20, c: 0, f: 5 },
  { name: "三文鱼", cat: "蛋白质", kcal: 208, p: 20, c: 0, f: 13 },
  { name: "豆腐", cat: "蛋白质", kcal: 76, p: 8, c: 2, f: 5 },
  { name: "牛奶", cat: "蛋白质", kcal: 54, p: 3, c: 5, f: 3 },
  { name: "无糖酸奶", cat: "蛋白质", kcal: 63, p: 4, c: 5, f: 3 },
  { name: "乳清蛋白粉", cat: "蛋白质", kcal: 400, p: 75, c: 10, f: 6 },
  { name: "西兰花", cat: "蔬菜", kcal: 34, p: 2.8, c: 7, f: 0.4 },
  { name: "菠菜", cat: "蔬菜", kcal: 23, p: 2.9, c: 3.6, f: 0.4 },
  { name: "番茄", cat: "蔬菜", kcal: 18, p: 0.9, c: 3.9, f: 0.2 },
  { name: "苹果", cat: "水果", kcal: 52, p: 0.3, c: 14, f: 0.2 },
  { name: "香蕉", cat: "水果", kcal: 89, p: 1.1, c: 23, f: 0.3 },
  { name: "蓝莓", cat: "水果", kcal: 57, p: 0.7, c: 14, f: 0.3 },
  { name: "坚果", cat: "脂肪", kcal: 600, p: 20, c: 20, f: 50 },
  { name: "橄榄油", cat: "脂肪", kcal: 884, p: 0, c: 0, f: 100 },
  { name: "拿铁", cat: "饮品", kcal: 60, p: 3, c: 5, f: 3 }
];

const ICONS = {
  home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-5v-6h-4v6H5a1 1 0 0 1-1-1z"/></svg>',
  plan: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="5" width="16" height="16" rx="3"/><path d="M8 3v4M16 3v4M4 10h16"/></svg>',
  coach: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 6h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H9l-5 4v-4H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Z"/></svg>',
  equipment: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8h3M17 8h3M7 6v4M17 6v4M7 8h10"/><circle cx="12" cy="16" r="4"/></svg>',
  user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="3.5"/><path d="M5 20c.6-3.6 3.1-5.5 7-5.5s6.4 1.9 7 5.5"/></svg>'
};

const SEC = { 3: [1, 3, 5], 4: [1, 2, 4, 5], 5: [1, 2, 3, 5, 6] };

const DEFAULT_PROFILE = {
  name: "小林",
  sex: "男",
  age: 28,
  height: 175,
  weight: 72.5,
  waist: 82,
  chest: 96,
  hip: 95,
  experience: "新手",
  equipment: ["徒手", "哑铃", "固定器械"],
  weeklyDays: 3,
  minutes: 45,
  goal: "增肌",
  targetWeight: 76,
  targetWaist: 78
};

function esc(value) {
  return String(value).replace(/[&<>"']/g, (ch) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  }[ch]));
}

function roundHalf(n) {
  return Math.round(n * 2) / 2;
}

function parseReps(reps) {
  const match = String(reps).match(/\d+/);
  return match ? Number(match[0]) : 10;
}

function demoLogs() {
  const add = (meal, name, grams, id) => {
    const food = FOODS.find((f) => f.name === name);
    const factor = grams / 100;
    return {
      id,
      meal,
      name,
      grams,
      kcal: Math.round(food.kcal * factor),
      p: Math.round(food.p * factor * 10) / 10,
      c: Math.round(food.c * factor * 10) / 10,
      f: Math.round(food.f * factor * 10) / 10
    };
  };
  return [
    add("早餐", "燕麦（干）", 50, "f1"),
    add("早餐", "鸡蛋", 100, "f2"),
    add("午餐", "米饭", 150, "f3"),
    add("午餐", "鸡胸肉", 150, "f4")
  ];
}

function demoSessions() {
  return [
    {
      id: "s1", title: "全身 A", date: "10月24日 19:10", duration: 46,
      volume: 1840, thisWeek: true,
      items: [
        { name: "高脚杯深蹲", weight: 12, reps: 10, sets: 4 },
        { name: "俯卧撑", weight: 0, reps: 12, sets: 3 },
        { name: "高位下拉", weight: 25, reps: 10, sets: 4 },
        { name: "哑铃推举", weight: 8, reps: 10, sets: 3 }
      ]
    },
    {
      id: "s2", title: "全身 B", date: "10月22日 18:40", duration: 43,
      volume: 1620, thisWeek: true,
      items: [
        { name: "箭步蹲", weight: 0, reps: 12, sets: 3 },
        { name: "坐姿划船", weight: 25, reps: 12, sets: 4 },
        { name: "面拉", weight: 10, reps: 15, sets: 3 }
      ]
    },
    {
      id: "s3", title: "全身 C", date: "10月20日 19:05", duration: 48,
      volume: 1750, thisWeek: false,
      items: [
        { name: "杠铃臀推", weight: 30, reps: 10, sets: 4 },
        { name: "哑铃卧推", weight: 10, reps: 10, sets: 4 },
        { name: "绳索下压", weight: 10, reps: 12, sets: 3 }
      ]
    }
  ];
}

function buildPlan(profile) {
  const templates = [
    { title: "全身 A", weekday: 1, focus: ["腿", "胸", "背"], slugs: ["goblet_squat", "pushup", "lat_pulldown", "shoulder_press", "plank"] },
    { title: "全身 B", weekday: 3, focus: ["腿", "背", "肩", "核心"], slugs: ["lunge", "seated_row", "dumbbell_press", "face_pull", "crunch"] },
    { title: "全身 C", weekday: 5, focus: ["臀", "胸", "手臂"], slugs: ["hip_thrust", "dumbbell_press", "triceps_pushdown", "biceps_curl", "plank"] }
  ];
  const reps = profile.goal === "增肌" ? "8-10" : profile.goal === "减脂" ? "12-15" : profile.goal === "提升体能" ? "15-20" : "10-12";
  const sets = profile.goal === "增肌" ? 4 : 3;
  const rest = profile.goal === "增肌" ? 90 : profile.goal === "减脂" ? 45 : 60;
  const days = [];
  for (let week = 1; week <= 4; week += 1) {
    templates.forEach((template) => {
      days.push({
        id: `w${week}d${template.weekday}`,
        week,
        weekday: template.weekday,
        title: template.title,
        focus: template.focus,
        exercises: template.slugs.map((slug) => {
          const ex = EX[slug];
          const weight = ex.base ? roundHalf(ex.base * (1 + 0.025 * (week - 1))) : 0;
          return {
            slug,
            sets,
            reps: ex.fixedReps || reps,
            weight,
            rest,
            rpe: 7.5
          };
        })
      });
    });
  }
  return {
    id: "plan-1",
    title: `4 周${profile.goal}计划 · 每周 ${profile.weeklyDays} 练`,
    version: 1,
    weeks: 4,
    days
  };
}

function applyEquipmentLibrary(plan) {
  if (!state.useEquipLibrary) return plan;
  const slugs = state.equipmentLibrary.map((item) => item.slug).filter(Boolean);
  if (!slugs.length) return plan;

  plan.days.forEach((day, index) => {
    const slug = slugs[index % slugs.length];
    const exercise = EX[slug];
    if (!exercise) return;
    if (day.exercises.some((item) => item.slug === slug)) return;
    const last = day.exercises[day.exercises.length - 1];
    day.exercises[day.exercises.length - 1] = {
      slug,
      sets: last ? last.sets : 3,
      reps: exercise.fixedReps || "10-12",
      weight: exercise.base || 0,
      rest: last ? last.rest : 60,
      rpe: 7
    };
  });
  return plan;
}

function demoEquipment() {
  return [
    { id: "e1", name: "高位下拉", slug: "lat_pulldown", muscle: "背", equip: "固定器械", video: false, notes: "座位高度 3 档" },
    { id: "e2", name: "腿举", slug: "leg_press", muscle: "腿", equip: "固定器械", video: false, notes: "脚距与肩同宽" },
    { id: "e3", name: "跑步机", slug: "treadmill", muscle: "有氧", equip: "固定器械", video: false, notes: "坡度 5%" }
  ];
}

function normalizeState(value) {
  const next = value || initialState();
  next.equipmentTab = next.equipmentTab || "scan";
  next.equipmentLibrary = next.equipmentLibrary || demoEquipment();
  next.useEquipLibrary = next.useEquipLibrary !== false;
  next.bodyPhoto = !!next.bodyPhoto;
  next.bodyConsent = false;
  next.bodyAnalysis = next.bodyAnalysis || null;
  next.equipmentItemId = next.equipmentItemId || null;
  next.sessionDraft = null;
  next.sessionEditing = false;
  return next;
}

function initialState() {
  const profile = { ...DEFAULT_PROFILE };
  return {
    version: 1,
    screen: "onboarding",
    tab: "home",
    onboarded: false,
    profile,
    plan: buildPlan(profile),
    sessions: demoSessions(),
    chats: [],
    foodLogs: demoLogs(),
    disliked: [],
    selectedWeek: 1,
    planDayId: null,
    selectedExercise: null,
    sessionId: null,
    foodDraft: { meal: "早餐", query: "", selected: null, grams: 100 },
    equipment: { scanned: false, candidates: [], query: "" },
    equipmentTab: "scan",
    equipmentLibrary: demoEquipment(),
    useEquipLibrary: true,
    bodyPhoto: false,
    bodyConsent: false,
    bodyAnalysis: null,
    equipmentItemId: null,
    sessionDraft: null,
    sessionEditing: false,
    workout: null,
    pro: false,
    reminder: "19:00"
  };
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return parsed && parsed.version === 1 ? parsed : null;
  } catch (error) {
    return null;
  }
}

let state = normalizeState(loadState() || initialState());

function save() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (error) {
    /* ignore */
  }
}

function toast(message) {
  const el = document.getElementById("toast");
  if (!el) return;
  el.textContent = message;
  el.classList.add("show");
  clearTimeout(window.__toastTimer);
  window.__toastTimer = setTimeout(() => el.classList.remove("show"), 2600);
}

function todayDay() {
  return state.plan.days.find((day) => day.week === 1) || state.plan.days[0];
}

function estimatedMinutes(day) {
  return Math.max(25, 18 + day.exercises.length * 4);
}

function nutritionTargets() {
  const p = state.profile;
  const weight = Number(p.weight);
  const height = Number(p.height);
  const age = Number(p.age);
  const bmr = p.sex === "女"
    ? 10 * weight + 6.25 * height - 5 * age - 161
    : 10 * weight + 6.25 * height - 5 * age + 5;
  const activity = p.weeklyDays <= 2 ? 1.375 : p.weeklyDays <= 4 ? 1.55 : 1.725;
  let factor = 1;
  let proteinPerKg = 1.6;
  if (p.goal === "减脂") { factor = 0.85; proteinPerKg = 1.8; }
  if (p.goal === "增肌") { factor = 1.10; proteinPerKg = 2.0; }
  const kcal = Math.round(bmr * activity * factor);
  const protein = Math.round(weight * proteinPerKg);
  const fat = Math.round(weight * 0.9);
  const carbs = Math.max(0, Math.round((kcal - protein * 4 - fat * 9) / 4));
  return {
    bmr: Math.round(bmr),
    tdee: Math.round(bmr * activity),
    kcal,
    protein,
    carbs,
    fat
  };
}

function nutritionTotals() {
  return state.foodLogs.reduce((total, item) => {
    total.kcal += item.kcal;
    total.p += item.p;
    total.c += item.c;
    total.f += item.f;
    return total;
  }, { kcal: 0, p: 0, c: 0, f: 0 });
}

function tabbar() {
  if (!state.onboarded || state.screen !== "tabs") return "";
  const items = [
    ["home", "今日", ICONS.home],
    ["plan", "计划", ICONS.plan],
    ["coach", "教练", ICONS.coach],
    ["equipment", "器械", ICONS.equipment],
    ["profile", "我的", ICONS.user]
  ];
  return items.map(([id, label, icon]) => `
    <button class="tab ${state.tab === id ? "active" : ""}" onclick="app.tab('${id}')">
      ${icon}<span>${label}</span>
    </button>
  `).join("");
}

function headerBack(title, action = "app.back()") {
  return `
    <div class="row between" style="margin-bottom:14px">
      <button class="icon-btn" onclick="${action}">‹</button>
      <div class="h3">${title}</div>
      <div style="width:34px"></div>
    </div>
  `;
}

/* ---------------- Onboarding ---------------- */

function onboarding() {
  const p = state.profile;
  return `
    <div class="stack">
      <div class="hero">
        <div class="badge hero-badge">✦ AI 健身教练</div>
        <h1 class="hero-title">先花 2 分钟<br>让计划适合你</h1>
        <p class="hero-sub">根据目标、器械和可用时间编排训练，并随着记录持续调整。</p>
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:3px">基础信息</div>
        <div class="tiny muted" style="margin-bottom:14px">用于计算热量与训练负荷</div>
        <div class="form-label">怎么称呼你</div>
        <input type="text" value="${esc(p.name)}" placeholder="例如：小林" oninput="app.field('name', this.value)">
        <div class="form-label" style="margin-top:14px">性别</div>
        ${segmented("sex", ["男", "女"], p.sex)}
        ${rangeRow("age", "年龄", "岁", 18, 60, 1)}
        ${rangeRow("height", "身高", "cm", 140, 210, 1)}
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:3px">身体数据</div>
        <div class="tiny muted" style="margin-bottom:14px">三围选填，用于追踪体型变化</div>
        ${rangeRow("weight", "体重", "kg", 40, 150, 0.5)}
        ${rangeRow("waist", "腰围", "cm", 50, 150, 1)}
        ${rangeRow("chest", "胸围", "cm", 60, 150, 1)}
        ${rangeRow("hip", "臀围", "cm", 60, 150, 1)}
        <div class="row between" style="margin-top:12px">
          <span class="small muted">BMI</span>
          <span class="small strong">${bmiText(p)}</span>
        </div>
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:3px">可用器械</div>
        <div class="tiny muted" style="margin-bottom:12px">只安排你能用上的动作</div>
        <div class="chips">
          ${["徒手", "哑铃", "杠铃", "固定器械", "绳索", "弹力带", "壶铃"].map((item) => `
            <button class="chip ${p.equipment.includes(item) ? "active" : ""}" onclick="app.toggleEquip('${item}')">${item}</button>
          `).join("")}
        </div>
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:3px">训练安排</div>
        <div class="tiny muted" style="margin-bottom:12px">之后可以随时调整</div>
        <div class="form-label">每周训练</div>
        ${segmented("weeklyDays", [1, 2, 3, 4, 5], String(p.weeklyDays), true)}
        <div class="form-label" style="margin-top:14px">单次时长</div>
        ${segmented("minutes", [30, 45, 60, 90], String(p.minutes), true)}
        <div class="form-label" style="margin-top:14px">训练经验</div>
        ${segmented("experience", ["新手", "有基础", "进阶"], p.experience)}
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:3px">你的目标</div>
        <div class="tiny muted" style="margin-bottom:12px">计划会围绕目标调整组次与负荷</div>
        <div class="goal-grid">
          ${[
            ["减脂", "控制热量，保留肌肉"],
            ["增肌", "渐进超负荷，稳定增重"],
            ["重塑体型", "体重变化不大，改善围度"],
            ["提升体能", "提高心肺与耐力"]
          ].map(([goal, desc]) => `
            <button class="goal ${p.goal === goal ? "active" : ""}" onclick="app.setGoal('${goal}')">
              <strong>${goal}</strong><span>${desc}</span>
            </button>
          `).join("")}
        </div>
        ${p.goal !== "提升体能" ? `
          ${rangeRow("targetWeight", "目标体重", "kg", 40, 120, 0.5)}
          ${rangeRow("targetWaist", "目标腰围", "cm", 50, 120, 1)}
        ` : ""}
      </div>

      <div class="card tight">
        <div class="row gap10" style="align-items:flex-start">
          <span style="color:var(--accent)">✚</span>
          <div class="tiny muted">本产品不提供医疗诊断。孕期、术后、心血管疾病或关节急性疼痛，请先咨询医生。</div>
        </div>
      </div>

      <button id="gen-btn" class="btn btn-primary" onclick="app.generatePlan()">生成我的计划</button>
      <button class="btn btn-ghost" onclick="app.skipOnboarding()">直接看已建好的示例 →</button>
      <div class="tiny faint center" style="padding-bottom:8px">当前为 Web 预览，数据只保存在浏览器本地。</div>
    </div>
  `;
}

function segmented(key, options, current, numeric = false) {
  return `<div class="seg">${options.map((option) => {
    const value = String(option);
    const active = String(current) === value ? "active" : "";
    const arg = numeric ? value : `'${value}'`;
    return `<button class="${active}" onclick="app.seg('${key}', ${arg})">${value}</button>`;
  }).join("")}</div>`;
}

function rangeRow(key, label, unit, min, max, step) {
  const value = state.profile[key];
  return `
    <div class="slider-row">
      <div class="between">
        <span class="small muted">${label}</span>
        <span class="small strong" id="val-${key}">${value}${unit}</span>
      </div>
      <input type="range" min="${min}" max="${max}" step="${step}" value="${value}"
        oninput="app.range('${key}', this.value, '${unit}')">
    </div>
  `;
}

function bmiText(profile) {
  const h = Number(profile.height) / 100;
  const value = h > 0 ? Number(profile.weight) / (h * h) : 0;
  const label = value < 18.5 ? "偏瘦" : value < 24 ? "正常" : value < 28 ? "偏高" : "肥胖";
  return `${value.toFixed(1)} · ${label}`;
}

/* ---------------- Home ---------------- */

function home() {
  const day = todayDay();
  const targets = nutritionTargets();
  const totals = nutritionTotals();
  const weekSessions = state.sessions.filter((s) => s.thisWeek).length;
  const ratio = Math.min(100, Math.round((weekSessions / Math.max(1, state.profile.weeklyDays)) * 100));

  return `
    <div class="stack">
      <div class="greeting">
        <div class="h1">晚上好，${esc(state.profile.name)}</div>
        <div class="date">10月25日 · 周日</div>
      </div>

      <div class="card">
        <div class="today-head">
          <div>
            <div class="badge">今日训练</div>
            <h2 class="today-title" style="margin-top:9px">${day.title}</h2>
            <div class="today-focus">${day.focus.join(" · ")}</div>
          </div>
          <div class="tiny faint">第 1 周</div>
        </div>

        <div class="row gap8" style="margin:14px 0 10px">
          <div class="metric"><div class="value">${day.exercises.length} 个</div><div class="label">动作</div></div>
          <div class="metric"><div class="value">${estimatedMinutes(day)} 分钟</div><div class="label">预计</div></div>
          <div class="metric"><div class="value">${ratio}%</div><div class="label">本周完成</div></div>
        </div>

        <div>
          ${day.exercises.slice(0, 3).map((item) => `
            <div class="exercise-line">
              <span class="dot"></span>
              <span class="name grow">${EX[item.slug].name}</span>
              <span class="target">${item.sets} 组 × ${item.reps}</span>
            </div>
          `).join("")}
          ${day.exercises.length > 3 ? `<div class="tiny faint" style="padding-left:15px">还有 ${day.exercises.length - 3} 个动作</div>` : ""}
        </div>

        <button class="btn btn-primary" style="margin-top:14px" onclick="app.startWorkout()">开始训练</button>
      </div>

      <div class="card">
        <div class="between" style="margin-bottom:10px">
          <div class="h3">本周完成</div>
          <div class="small muted">${weekSessions}/${state.profile.weeklyDays} 练</div>
        </div>
        <div class="bar"><span style="width:${ratio}%"></span></div>
        <div class="row gap12" style="margin-top:12px">
          <div class="grow"><div class="h3">${state.sessions.length}</div><div class="tiny faint">累计训练</div></div>
          <div class="grow"><div class="h3">18.4k</div><div class="tiny faint">总容量 kg</div></div>
          <div class="grow"><div class="h3">${weekSessions}</div><div class="tiny faint">本周</div></div>
        </div>
      </div>

      <div class="card nutrition-card" onclick="app.go('nutrition')">
        <div class="nutrition-icon">🍽</div>
        <div class="grow">
          <div class="h3">今日饮食</div>
          <div class="tiny muted" style="margin-top:3px">已摄入 ${nutritionTotals().kcal} / ${targets.kcal} kcal · 蛋白质 ${Math.round(totals.p)}g</div>
        </div>
        <div class="faint">›</div>
      </div>

      <div class="card">
        <div class="between">
          <div>
            <div class="h3">${state.plan.title}</div>
            <div class="tiny muted" style="margin-top:3px">第 ${state.plan.version} 版 · ${state.plan.days.length} 个训练日</div>
          </div>
          <span class="accent">↗</span>
        </div>
        <div class="tiny muted" style="margin-top:10px">完成率 ${ratio}%。AI 会按完成率和负荷趋势调整下一版。</div>
        <button class="btn btn-secondary" style="margin-top:12px" onclick="app.adjustPlan()">✦ 让 AI 复盘并调整</button>
      </div>

      <div class="card">
        <div class="between" style="margin-bottom:6px">
          <div class="h3">最近训练</div>
          <div class="tiny faint">共 ${state.sessions.length} 次</div>
        </div>
        ${state.sessions.map((session) => `
          <div class="recent-row" onclick="app.openSession('${session.id}')">
            <div class="grow">
              <div class="small strong">${session.title}</div>
              <div class="tiny faint">${session.date}</div>
            </div>
            <div style="text-align:right">
              <div class="small accent" style="font-weight:650">${session.volume} kg</div>
              <div class="tiny faint">${session.duration} 分钟</div>
            </div>
            <div class="faint">›</div>
          </div>
        `).join("")}
      </div>
    </div>
  `;
}

/* ---------------- Plan ---------------- */

function planScreen() {
  const days = state.plan.days.filter((day) => day.week === state.selectedWeek);
  return `
    <div class="stack">
      <div class="between">
        <div>
          <h1 class="h1">训练计划</h1>
          <div class="tiny muted" style="margin-top:4px">第 ${state.plan.version} 版 · 4 周</div>
        </div>
        <button class="icon-btn" onclick="app.regeneratePlan()">↻</button>
      </div>

      <div class="card">
        <div class="between">
          <div class="badge">当前计划</div>
          <div class="tiny faint">v${state.plan.version}</div>
        </div>
        <div class="h2" style="margin-top:9px">${state.plan.title}</div>
        <div class="tiny muted" style="margin-top:4px">${state.plan.days.length} 个训练日 · 每周 ${state.profile.weeklyDays} 练</div>
        <div class="row gap8" style="margin-top:12px">
          <button class="btn btn-secondary btn-sm grow" onclick="app.adjustPlan()">✦ AI 调整</button>
          <button class="btn btn-secondary btn-sm grow" onclick="app.regeneratePlan()">重新生成</button>
        </div>
      </div>

      <div class="week-tabs">
        ${[1, 2, 3, 4].map((week) => `
          <button class="week-tab ${state.selectedWeek === week ? "active" : ""}" onclick="app.selectWeek(${week})">第 ${week} 周</button>
        `).join("")}
      </div>

      ${days.map((day) => `
        <div class="card day-card" onclick="app.openPlanDay('${day.id}')">
          <div class="between">
            <div>
              <div class="h3">周${["一", "二", "三", "四", "五", "六", "日"][day.weekday - 1]} · ${day.title}</div>
              <div class="tiny muted" style="margin-top:3px">${day.focus.join(" · ")}</div>
            </div>
            <div class="faint">›</div>
          </div>
          <div style="margin-top:8px">
            ${day.exercises.slice(0, 4).map((item) => `
              <div class="ex-line">
                <span>${EX[item.slug].name}</span>
                <span class="muted">${item.sets} 组 × ${item.reps}</span>
              </div>
            `).join("")}
            ${day.exercises.length > 4 ? `<div class="tiny faint">还有 ${day.exercises.length - 4} 个动作</div>` : ""}
          </div>
        </div>
      `).join("")}

      <div class="card tight">
        <div class="tiny muted">点任意训练日可以换动作、改组数。删除过的动作会被记住，下次生成尽量避开。</div>
        ${state.useEquipLibrary && state.equipmentLibrary.length
          ? `<div class="tiny accent" style="margin-top:6px">已启用器械库：${state.equipmentLibrary.length} 件，生成计划时优先使用。</div>`
          : ""}
      </div>
    </div>
  `;
}

function planDayScreen() {
  const day = state.plan.days.find((item) => item.id === state.planDayId);
  if (!day) return planScreen();
  const available = Object.keys(EX).filter((slug) => !day.exercises.some((item) => item.slug === slug)).slice(0, 4);

  return `
    <div class="stack">
      ${headerBack("编辑训练日")}
      <div class="card">
        <div class="tiny accent">第 ${day.week} 周 · 周${["一", "二", "三", "四", "五", "六", "日"][day.weekday - 1]}</div>
        <div class="h2" style="margin-top:4px">${day.title}</div>
        <div class="tiny muted" style="margin-top:3px">${day.focus.join(" · ")}</div>
      </div>

      ${day.exercises.map((item, index) => `
        <div class="editor-ex">
          <div class="between">
            <div>
              <div class="small strong">${EX[item.slug].name}</div>
              <div class="tiny faint">${EX[item.slug].muscle} · ${EX[item.slug].equip}</div>
            </div>
            <button class="trash-btn" onclick="app.deletePlanExercise(${index})">🗑</button>
          </div>
          <div class="row between" style="margin-top:9px">
            <div class="stepper">
              <button onclick="app.changeSets(${index}, -1)">−</button>
              <span>${item.sets} 组</span>
              <button onclick="app.changeSets(${index}, 1)">＋</button>
            </div>
            <div class="tiny muted">${item.reps} · 休息 ${item.rest}s</div>
          </div>
        </div>
      `).join("")}

      <div class="card">
        <div class="tiny muted" style="margin-bottom:8px">添加动作</div>
        <div class="chips">
          ${available.map((slug) => `<button class="chip" onclick="app.addPlanExercise('${slug}')">+ ${EX[slug].name}</button>`).join("")}
        </div>
      </div>

      <button class="btn btn-primary" onclick="app.savePlanDay()">保存修改</button>
      <div class="tiny faint center">改动只影响当前训练日。</div>
    </div>
  `;
}

/* ---------------- Coach ---------------- */

function coachScreen() {
  const suggestions = ["今天练什么？", "没有器械怎么替代？", "深蹲膝盖不舒服", "训练后很酸正常吗？", "每天要吃多少蛋白质？"];
  return `
    <div class="chat-screen">
      <div class="chat-head">
        <h1 class="h1">AI 教练</h1>
        <div class="tiny muted" style="margin-top:4px">结合档案、计划和训练记录回答</div>
      </div>

      <div class="chat-scroll" id="chat-scroll">
        ${state.chats.length === 0 ? `
          <div class="card" style="margin-top:12px">
            <div class="row gap10" style="margin-bottom:10px">
              <span style="font-size:22px;color:var(--accent)">🧠</span>
              <div class="h3">训练有问题，直接问</div>
            </div>
            <div class="small muted" style="line-height:1.65">我会结合你的档案、当前计划和训练记录回答。涉及疼痛、孕期、术后等情况，会建议你就医，而不是继续加练。</div>
          </div>
        ` : state.chats.map((message) => `
          <div class="chat-row ${message.role}">
            <div class="bubble ${message.role} ${message.safety ? "safety" : ""}">
              ${message.safety ? '<span class="safety-label">⚠ 需要就医评估</span>' : ""}
              ${esc(message.text)}
            </div>
          </div>
        `).join("")}

        <div class="suggestions" style="margin-top:10px">
          ${suggestions.map((text) => `<button class="suggestion" onclick="app.sendChat('${text.replace(/'/g, "\\'")}')">${text}</button>`).join("")}
        </div>
      </div>

      <div class="composer">
        <div class="composer-row">
          <input id="chat-input" type="text" placeholder="问问动作、计划或饮食…" onkeydown="if(event.key==='Enter'){app.sendChat()}">
          <button class="send-btn" onclick="app.sendChat()">↑</button>
        </div>
      </div>
    </div>
  `;
}

/* ---------------- Equipment ---------------- */

function equipmentScreen() {
  const equipment = state.equipment;
  return `
    <div class="stack">
      <div>
        <h1 class="h1">器械识别</h1>
        <div class="tiny muted" style="margin-top:4px">拍一下器械，马上知道怎么用</div>
      </div>

      <div class="card nutrition-card" onclick="app.equipmentLibraryOpen()">
        <div class="nutrition-icon">🏋️</div>
        <div class="grow">
          <div class="h3">我的器械库</div>
          <div class="tiny muted" style="margin-top:3px">已录入 ${state.equipmentLibrary.length} 件 · 查看教学视频</div>
        </div>
        <div class="faint">›</div>
      </div>

      <div class="photo-area ${equipment.scanned ? "filled" : ""}">
        <div class="big">📷</div>
        <div class="small">${equipment.scanned ? "已拍摄：高位下拉器械" : "拍一张器械照片"}</div>
        <div class="tiny">${equipment.scanned ? "点击下方识别器械" : "支持常见固定器械、绳索、杠铃与哑铃"}</div>
      </div>

      <div class="row gap8">
        <button class="btn btn-secondary btn-sm grow" onclick="app.mockPhoto()">模拟拍照</button>
        <button class="btn btn-secondary btn-sm grow" onclick="app.mockPhoto()">从相册选择</button>
      </div>

      <button class="btn btn-primary" onclick="app.scanEquipment()">识别器械</button>

      ${equipment.candidates.length ? `
        <div class="card">
          <div class="h3">识别结果</div>
          <div class="tiny muted" style="margin-top:3px">点击查看动作要领</div>
          ${equipment.candidates.map((candidate) => `
            <div class="result-row" onclick="app.openExercise('${candidate.slug}')">
              <div class="between">
                <div>
                  <div class="small strong">${EX[candidate.slug].name}</div>
                  <div class="tiny faint">${EX[candidate.slug].muscle} · ${EX[candidate.slug].equip}</div>
                </div>
                <div class="tiny ${candidate.confidence >= 0.6 ? "accent" : "warning"}">${Math.round(candidate.confidence * 100)}%</div>
              </div>
                <div class="confidence ${candidate.confidence < 0.6 ? "low" : ""}"><span style="width:${candidate.confidence * 100}%"></span></div>
                <div class="row between" style="margin-top:6px">
                  <button class="link" onclick="event.stopPropagation();app.saveCandidate('${candidate.slug}')">
                    ${state.equipmentLibrary.some((entry) => entry.slug === candidate.slug) ? "已保存" : "＋ 保存到器械库"}
                  </button>
                  <span class="tiny faint">查看动作 ›</span>
                </div>
              </div>
            `).join("")}
        </div>
      ` : ""}

      <div class="card">
        <div class="h3" style="margin-bottom:8px">找不到？手动搜索</div>
        <input id="equip-search" type="text" placeholder="例如：高位下拉、腿举" oninput="app.equipSearch(this.value)">
        <div id="equip-results" style="margin-top:8px">${equipResults(equipment.query)}</div>
      </div>
    </div>
  `;
}

function equipResults(query) {
  const list = Object.keys(EX).filter((slug) => {
    if (!query) return true;
    return EX[slug].name.includes(query) || EX[slug].muscle.includes(query);
  }).slice(0, 5);
  return list.map((slug) => `
    <div class="result-row" onclick="app.openExercise('${slug}')">
      <div class="between">
        <div class="small">${EX[slug].name}</div>
        <div class="tiny faint">${EX[slug].equip} ›</div>
      </div>
    </div>
  `).join("");
}

function equipmentLibraryScreen() {
  const items = state.equipmentLibrary;
  return `
    <div class="stack">
      ${headerBack("我的器械库", "app.backTo('equipment')")}
      <div class="card">
        <div class="h3">已录入 ${items.length} 件器械</div>
        <div class="tiny muted" style="margin-top:4px">集中查看教学视频，并让 AI 按你的器械安排计划。</div>
      </div>

      <div class="card">
        <div class="between">
          <span class="small">生成计划时优先使用器械库</span>
          <button class="chip ${state.useEquipLibrary ? "active" : ""}" onclick="app.toggleEquipLibrary()">
            ${state.useEquipLibrary ? "已启用" : "未启用"}
          </button>
        </div>
        <div class="tiny faint" style="margin-top:8px">${state.useEquipLibrary
          ? "下次生成/重新生成计划时，会优先从器械库和徒手动作里选择。"
          : "已关闭：计划仍按档案里的器械类型生成。"}</div>
      </div>

      ${items.length === 0 ? `
        <div class="card">
          <div class="h3">器械库还是空的</div>
          <div class="tiny muted" style="margin-top:5px">识别器械后保存，或手动添加。</div>
        </div>
      ` : items.map((item) => `
        <div class="card" style="cursor:pointer" onclick="app.openEquipItem('${item.id}')">
          <div class="row gap10">
            <div class="nutrition-icon">🏋️</div>
            <div class="grow">
              <div class="h3">${esc(item.name)}</div>
              <div class="tiny muted" style="margin-top:2px">${item.muscle} · ${item.equip}</div>
              <div class="tiny ${item.video ? "accent" : "faint"}" style="margin-top:2px">
                ${item.video ? "已配置教学视频" : "未配置视频"}
              </div>
            </div>
            <div class="faint">›</div>
          </div>
        </div>
      `).join("")}

      <button class="btn btn-secondary" onclick="app.addDemoEquipment()">＋ 添加器械</button>
      <div class="tiny faint" style="line-height:1.6">器械库会作为 AI 生成计划的可用器械来源。删除器械不会删除历史训练记录。</div>
    </div>
  `;
}

function equipmentItemScreen() {
  const item = state.equipmentLibrary.find((entry) => entry.id === state.equipmentItemId);
  if (!item) return equipmentLibraryScreen();
  return `
    <div class="stack">
      ${headerBack("器械详情", "app.equipmentLibraryOpen()")}
      <div class="card center">
        <div style="font-size:40px;margin-bottom:8px">🏋️</div>
        <div class="h2">${esc(item.name)}</div>
        <div class="small accent" style="margin-top:4px">${item.muscle} · ${item.equip}</div>
        ${item.notes ? `<div class="tiny muted" style="margin-top:10px">${esc(item.notes)}</div>` : ""}
      </div>

      <div class="card">
        <div class="row gap8" style="margin-bottom:8px"><span class="accent">▶</span><span class="h3">教学视频</span></div>
        <div class="tiny muted">${item.video ? "已配置视频地址，真实 App 会直接播放。" : "还没有视频地址。真实 App 里可在添加/编辑器械时填入 HLS/MP4 链接。"}</div>
        <div style="height:150px;border-radius:14px;margin-top:10px;background:linear-gradient(135deg,#1a2028,#0d1016);display:grid;place-items:center;color:var(--faint)">视频占位</div>
      </div>

      <button class="btn btn-primary" onclick="app.regenerateWithLibrary()">按器械库重新生成计划</button>
      <button class="btn btn-danger" onclick="app.deleteEquipItem('${item.id}')">从器械库删除</button>
    </div>
  `;
}

const BODY_VARIANTS = [
  {
    summary: "整体比例比较均衡，建议把训练重点放在背部与臀部，配合核心稳定，减少只练胸和手臂的倾向。",
    focus: ["背", "臀", "核心"],
    recommendations: [
      "每周增加 1 次背部训练，优先高位下拉、坐姿划船",
      "臀部训练加入臀推或臀桥，每周 2 次",
      "核心稳定加入平板支撑，每次训练收尾 2 组"
    ],
    confidence: 0.82
  },
  {
    summary: "下肢与核心可以承担更多训练量，建议采用上下肢分化，先把深蹲和髋伸动作做扎实。",
    focus: ["腿", "臀", "核心"],
    recommendations: [
      "保留深蹲或腿举作为下肢主项",
      "加入罗马尼亚硬拉，强化后链",
      "每周至少 2 次核心稳定训练"
    ],
    confidence: 0.76
  },
  {
    summary: "上肢推拉比例可以更平衡，建议增加划船类动作，同时控制卧推总量，避免肩部过度疲劳。",
    focus: ["背", "肩", "核心"],
    recommendations: [
      "推拉比例调整为 1:1.5",
      "加入面拉，改善肩胛稳定",
      "推日最后减少 1 组卧推，改为划船"
    ],
    confidence: 0.71
  }
];

function bodyAnalysisScreen() {
  const analysis = state.bodyAnalysis;
  return `
    <div class="stack">
      ${headerBack("体型照片分析", "app.backTo('profile')")}
      <div class="card">
        <div class="h3">拍一张全身或半身照</div>
        <div class="tiny muted" style="margin-top:6px;line-height:1.6">分析只给训练重点，不判断体脂率、不诊断体态。照片不写入训练记录。</div>
      </div>

      <div class="photo-area ${state.bodyPhoto ? "filled" : ""}">
        <div class="big">📷</div>
        <div class="small">${state.bodyPhoto ? "已选择体型照片" : "拍照或选择一张照片"}</div>
        <div class="tiny">${state.bodyPhoto ? "确认授权后即可分析" : "正面或侧面，光线充足"}</div>
      </div>

      <div class="row gap8">
        <button class="btn btn-secondary btn-sm grow" onclick="app.bodyMockPhoto()">模拟拍照</button>
        <button class="btn btn-secondary btn-sm grow" onclick="app.bodyMockPhoto()">从相册选择</button>
      </div>

      <div class="card">
        <div class="between">
          <span class="small">我同意将照片用于本次训练分析</span>
          <button class="chip ${state.bodyConsent ? "active" : ""}" onclick="app.bodyConsentToggle()">
            ${state.bodyConsent ? "已同意" : "未同意"}
          </button>
        </div>
        <div class="tiny faint" style="margin-top:7px">预览版不上传照片；真实 App 在远程模式下会做一次性分析，不保存原图。</div>
      </div>

      <button class="btn btn-primary" onclick="app.bodyAnalyze()">分析体型并生成训练建议</button>

      ${analysis ? `
        <div class="card">
          <div class="between">
            <div class="h3">分析结果</div>
            <div class="tiny accent">参考置信度 ${Math.round(analysis.confidence * 100)}%</div>
          </div>
          <div class="small" style="margin-top:8px;line-height:1.6">${analysis.summary}</div>
          <div class="tiny muted" style="margin-top:10px">建议训练重点</div>
          <div class="chips" style="margin-top:6px">
            ${analysis.focus.map((item) => `<span class="chip active">${item}</span>`).join("")}
          </div>
          <div style="margin-top:12px">
            ${analysis.recommendations.map((item) => `<div class="list-row"><span class="dot"></span><span class="small muted grow">${item}</span></div>`).join("")}
          </div>
          <div class="tiny faint" style="margin-top:9px">照片分析仅用于训练重点参考，不构成体脂率、体态诊断或医疗建议。</div>
          <button class="btn btn-primary" style="margin-top:12px" onclick="app.applyBodyAnalysis()">
            ${analysis.applied ? "已应用到当前计划" : "应用到训练计划"}
          </button>
        </div>
      ` : ""}

      <div class="tiny faint" style="line-height:1.6">体型照片属于敏感个人信息。请只上传你本人的照片；不要上传他人或未成年人照片。</div>
    </div>
  `;
}

function exerciseScreen() {
  const exercise = EX[state.selectedExercise];
  if (!exercise) return equipmentScreen();
  return `
    <div class="stack">
      ${headerBack("动作详情", "app.backTo('equipment')")}
      <div class="card">
        <div class="h2">${exercise.name}</div>
        <div class="small accent" style="margin-top:4px">${exercise.muscle} · ${exercise.equip}</div>
        <div class="small muted" style="margin-top:12px;line-height:1.7">${exercise.cues}</div>
      </div>

      <div class="card">
        <div class="row gap8" style="margin-bottom:8px"><span class="accent">▶</span><span class="h3">教学视频</span></div>
        <div class="tiny muted">预览版没有配置视频。真实 App 会读取 videos.json，配置素材后在这里播放 HLS/MP4。</div>
        <div style="height:160px;border-radius:14px;margin-top:10px;background:linear-gradient(135deg,#1a2028,#0d1016);display:grid;place-items:center;color:var(--faint)">视频占位</div>
      </div>

      <button class="btn btn-secondary" onclick="app.askCoach('${state.selectedExercise}')">问教练这个动作</button>
      <div class="tiny faint center">关节刺痛、麻木或肿胀时请停止训练并咨询医生。</div>
    </div>
  `;
}

/* ---------------- Profile ---------------- */

function profileScreen() {
  const p = state.profile;
  const targets = nutritionTargets();
  return `
    <div class="stack">
      <div class="card">
        <div class="row gap12">
          <div class="nutrition-icon" style="font-size:18px">${esc(p.name.slice(0, 1))}</div>
          <div class="grow">
            <div class="h3">${esc(p.name)}</div>
            <div class="tiny muted" style="margin-top:3px">${p.goal} · ${p.experience} · 每周 ${p.weeklyDays} 练</div>
          </div>
          <button class="link" onclick="app.restartOnboarding()">编辑</button>
        </div>
      </div>

      <div class="card" onclick="app.openPaywall()" style="cursor:pointer">
        <div class="row gap12">
          <div class="nutrition-icon" style="color:var(--warning);background:rgba(250,184,77,.12)">♛</div>
          <div class="grow">
            <div class="h3">FitAI Pro</div>
            <div class="tiny muted" style="margin-top:3px">${state.pro ? "已订阅 · 所有功能已解锁" : "解锁 AI 计划、教练对话与器械识别"}</div>
          </div>
          <div class="accent small">${state.pro ? "管理" : "查看"}</div>
        </div>
      </div>

      <div class="card">
        <div class="row gap8">
          <div class="metric"><div class="value">${p.weight} kg</div><div class="label">体重</div></div>
          <div class="metric"><div class="value">${bmiText(p).split(" · ")[0]}</div><div class="label">BMI</div></div>
        </div>
        <div class="row gap8" style="margin-top:8px">
          <div class="metric"><div class="value">${p.waist} cm</div><div class="label">腰围</div></div>
          <div class="metric"><div class="value">${p.height} cm</div><div class="label">身高</div></div>
        </div>
        <div class="row gap8" style="margin-top:8px">
          <div class="metric"><div class="value">${state.sessions.length} 次</div><div class="label">累计训练</div></div>
          <div class="metric"><div class="value">18.4k kg</div><div class="label">总容量</div></div>
        </div>
      </div>

      <div class="card">
        <div class="between"><div class="h3">当前目标</div><span class="badge">${p.goal}</span></div>
        <div class="between" style="margin-top:10px"><span class="small muted">目标体重</span><span class="small strong">${p.targetWeight} kg</span></div>
        <div class="between" style="margin-top:7px"><span class="small muted">目标腰围</span><span class="small strong">${p.targetWaist} cm</span></div>
        <div class="tiny faint" style="margin-top:8px">减重建议不超过 0.5kg/周，不追求极端速度。</div>
      </div>

      <div class="card">
        <div class="between">
          <div>
            <div class="h3">Apple 健康</div>
            <div class="tiny muted" style="margin-top:3px">读取体重，写入完成的训练</div>
          </div>
          <span class="accent">♥</span>
        </div>
        <button class="btn btn-secondary" style="margin-top:10px" onclick="app.mockHealth()">连接 Apple 健康</button>
      </div>

      <div class="card" onclick="app.bodyAnalysisOpen()" style="cursor:pointer">
        <div class="between">
          <div>
            <div class="h3">体型照片分析</div>
            <div class="tiny muted" style="margin-top:3px">AI 给训练重点建议</div>
          </div>
          <span class="accent">›</span>
        </div>
        ${state.bodyAnalysis
          ? `<div class="tiny muted" style="margin-top:8px">${state.bodyAnalysis.summary}</div>
             <div class="chips" style="margin-top:6px">${state.bodyAnalysis.focus.map((item) => `<span class="chip active">${item}</span>`).join("")}</div>`
          : `<div class="tiny faint" style="margin-top:8px">照片只用于本次分析，不写入训练记录。</div>`}
      </div>

      <div class="card" onclick="app.equipmentLibraryOpen()" style="cursor:pointer">
        <div class="between">
          <div>
            <div class="h3">我的器械库</div>
            <div class="tiny muted" style="margin-top:3px">已录入 ${state.equipmentLibrary.length} 件 · 教学视频与计划</div>
          </div>
          <span class="accent">›</span>
        </div>
      </div>

      <div class="card">
        <div class="between"><div class="h3">训练提醒</div><span class="tiny faint">每周重复</span></div>
        <div class="row gap8" style="margin-top:10px">
          <input type="time" value="${state.reminder}" id="reminder-time">
          <button class="btn btn-secondary btn-sm" onclick="app.saveReminder()">保存</button>
        </div>
        <div class="tiny faint" style="margin-top:8px">iOS 静音和专注模式可能影响提醒，请在系统设置中允许通知。</div>
      </div>

      <div class="card">
        <div class="between">
          <div class="h3">训练偏好</div>
          <div class="tiny faint">${state.disliked.length} 个</div>
        </div>
        <div class="tiny muted" style="margin-top:6px">删除过的动作会被记住，下次生成尽量避开。</div>
        ${state.disliked.length ? `<button class="btn btn-secondary" style="margin-top:10px" onclick="app.clearPreferences()">清除训练偏好</button>` : ""}
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:8px">关于与合规</div>
        <div class="list-row" onclick="app.mockPrivacy()"><span class="grow small">隐私政策</span><span class="faint">›</span></div>
        <div class="list-row" onclick="app.mockPrivacy()"><span class="grow small">用户协议</span><span class="faint">›</span></div>
        <div class="list-row" onclick="app.exportData()"><span class="grow small">导出我的数据</span><span class="faint">›</span></div>
        <div class="list-row" onclick="app.mockPrivacy()"><span class="grow small">生成式 AI 备案信息</span><span class="faint">›</span></div>
        <div class="tiny faint" style="margin-top:8px">本产品不提供医疗诊断。孕期、术后、心血管疾病或关节急性疼痛，请先咨询医生。</div>
      </div>

      <div class="card">
        <div class="h3">注销与本地数据</div>
        <div class="tiny muted" style="margin-top:6px">数据只保存在浏览器本地。清除后无法恢复。</div>
        <button class="btn btn-danger" style="margin-top:10px" onclick="app.resetAll()">注销并删除全部数据</button>
      </div>

      <div class="tiny faint center" style="padding-bottom:8px">FitAI Web Preview · v0.1</div>
    </div>
  `;
}

/* ---------------- Nutrition ---------------- */

function nutritionScreen() {
  const targets = nutritionTargets();
  const totals = nutritionTotals();
  const ratio = Math.min(100, Math.round((totals.kcal / Math.max(1, targets.kcal)) * 100));
  const meals = ["早餐", "午餐", "晚餐", "加餐"];

  return `
    <div class="stack">
      ${headerBack("饮食计划", "app.tab('home')")}
      <div class="card">
        <div class="tiny muted">今日热量目标</div>
        <div class="kcal-hero" style="margin-top:4px"><span class="num">${targets.kcal}</span><span class="unit">kcal</span></div>
        <div class="tiny faint" style="margin-top:6px">按${state.profile.goal}目标与每周 ${state.profile.weeklyDays} 练估算，结果是区间。</div>
      </div>

      <div class="card">
        <div class="between">
          <div class="h3">今日记录</div>
          <div class="tiny muted">${totals.kcal} / ${targets.kcal} kcal</div>
        </div>
        <div class="bar" style="margin-top:9px"><span style="width:${ratio}%"></span></div>

        ${meals.map((meal) => {
          const logs = state.foodLogs.filter((item) => item.meal === meal);
          if (!logs.length) return "";
          return `
            <div class="meal-head">
              <div class="small strong">${meal}</div>
              <div class="row gap8">
                <span class="tiny muted">${logs.reduce((sum, item) => sum + item.kcal, 0)} kcal</span>
                <button class="add-btn" onclick="app.openFoodAdd('${meal}')">＋</button>
              </div>
            </div>
            ${logs.map((log) => `
              <div class="food-row">
                <div class="grow">
                  <div class="small">${log.name}</div>
                  <div class="tiny faint">${log.grams} g</div>
                </div>
                <div class="tiny muted">${log.kcal} kcal</div>
                <button class="trash-btn" onclick="app.deleteFood('${log.id}')">🗑</button>
              </div>
            `).join("")}
          `;
        }).join("")}

        ${state.foodLogs.length === 0 ? `<div class="tiny muted" style="margin-top:10px">还没有记录。记下吃了什么，才能知道离目标还差多少。</div>` : ""}
        <button class="btn btn-secondary" style="margin-top:12px" onclick="app.openFoodAdd('早餐')">＋ 添加食物</button>
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:10px">宏量营养素</div>
        <div class="macro-grid">
          <div class="macro"><div class="label">蛋白质</div><div class="value">${Math.round(totals.p)} / ${targets.protein}g</div></div>
          <div class="macro"><div class="label">碳水</div><div class="value">${Math.round(totals.c)} / ${targets.carbs}g</div></div>
          <div class="macro"><div class="label">脂肪</div><div class="value">${Math.round(totals.f)} / ${targets.fat}g</div></div>
        </div>
        <div class="tiny faint" style="margin-top:9px">BMR ${targets.bmr} kcal · 维持热量约 ${targets.tdee} kcal</div>
      </div>

      <div class="h3" style="padding-top:4px">建议餐单</div>
      ${[
        ["早餐", "燕麦 50g · 鸡蛋 2 个 · 无糖酸奶 150g", Math.round(targets.kcal * 0.25)],
        ["午餐", "糙米饭 150g · 鸡胸肉 150g · 西兰花 200g", Math.round(targets.kcal * 0.35)],
        ["晚餐", "红薯 150g · 三文鱼或豆腐 150g · 混合蔬菜", Math.round(targets.kcal * 0.30)],
        ["加餐", "牛奶 200ml · 坚果 15g", Math.round(targets.kcal * 0.10)]
      ].map(([meal, items, kcal]) => `
        <div class="card tight">
          <div class="between"><div class="small strong">${meal}</div><div class="tiny accent">约 ${kcal} kcal</div></div>
          <div class="tiny muted" style="margin-top:5px">${items}</div>
        </div>
      `).join("")}

      <div class="card">
        <div class="h3">附近外卖</div>
        <div class="tiny muted" style="margin-top:6px">美团联盟只提供活动/搜索跳转，不提供菜品营养数据。</div>
        <button class="btn btn-secondary" style="margin-top:10px" onclick="app.mockMeituan()">在美团找轻食 ↗</button>
      </div>

      <div class="tiny faint" style="line-height:1.6">饮食建议为估算，不构成医疗或疾病饮食处方。孕期、术后、糖尿病、肾病等请咨询医生或营养师。</div>
    </div>
  `;
}

function foodAddScreen() {
  const draft = state.foodDraft;
  const selected = draft.selected ? FOODS.find((food) => food.name === draft.selected) : null;
  return `
    <div class="stack">
      ${headerBack("记录食物", "app.go('nutrition')")}
      <div class="seg">
        ${["早餐", "午餐", "晚餐", "加餐"].map((meal) => `
          <button class="${draft.meal === meal ? "active" : ""}" onclick="app.foodMeal('${meal}')">${meal}</button>
        `).join("")}
      </div>

      <input type="text" id="food-search" placeholder="搜索食物，例如：鸡胸肉、米饭" value="${esc(draft.query)}" oninput="app.foodQuery(this.value)">

      <div id="food-results">
        ${foodResults(draft.query)}
      </div>

      ${selected ? `
        <div class="card">
          <div class="between">
            <div>
              <div class="h3">${selected.name}</div>
              <div class="tiny muted">每 100g · ${selected.kcal} kcal</div>
            </div>
            <button class="link" onclick="app.clearFoodSelection()">重新选择</button>
          </div>
          <div class="slider-row" style="margin-top:12px">
            <div class="between">
              <span class="small muted">份量</span>
              <span class="small strong" id="food-grams-label">${draft.grams} g</span>
            </div>
            <input type="range" min="10" max="500" step="10" value="${draft.grams}" oninput="app.foodGrams(this.value)">
          </div>
          <div class="macro-grid" style="margin-top:10px">
            <div class="macro"><div class="label">热量</div><div class="value" id="food-kcal">${Math.round(selected.kcal * draft.grams / 100)}</div></div>
            <div class="macro"><div class="label">蛋白质</div><div class="value" id="food-p">${Math.round(selected.p * draft.grams / 100)}g</div></div>
            <div class="macro"><div class="label">碳水</div><div class="value" id="food-c">${Math.round(selected.c * draft.grams / 100)}g</div></div>
          </div>
          <button class="btn btn-primary" style="margin-top:12px" onclick="app.addFood()">添加到${draft.meal}</button>
        </div>
      ` : ""}
    </div>
  `;
}

function foodResults(query) {
  const list = FOODS.filter((food) => !query || food.name.includes(query) || food.cat.includes(query)).slice(0, 12);
  return list.map((food) => `
    <button class="food-item" onclick="app.selectFood('${food.name.replace(/'/g, "\\'")}')">
      <div>
        <div class="small strong">${food.name}</div>
        <div class="tiny faint">${food.cat} · 每 100g</div>
      </div>
      <div style="text-align:right">
        <div class="tiny accent">${food.kcal} kcal</div>
        <div class="tiny faint">P${Math.round(food.p)} C${Math.round(food.c)} F${Math.round(food.f)}</div>
      </div>
    </button>
  `).join("");
}

/* ---------------- Paywall ---------------- */

function paywallScreen() {
  return `
    <div class="stack">
      ${headerBack("FitAI Pro")}
      <div class="card hero center">
        <div class="crown">♛</div>
        <div class="h2">把 AI 教练带在身边</div>
        <div class="small muted" style="margin-top:6px">解锁完整的计划生成、教练对话与器械识别。</div>
      </div>

      <div class="card">
        ${[
          ["无限次 AI 计划生成与调整", "✦"],
          ["教练对话、周复盘与训练偏好记忆", "💬"],
          ["器械拍照识别与动作库", "📷"],
          ["饮食计划与热量记录", "🍽"]
        ].map(([text, icon]) => `
          <div class="benefit-row"><span>${icon}</span><span>${text}</span><span class="check">✓</span></div>
        `).join("")}
      </div>

      ${state.pro ? `
        <div class="card center">
          <div class="h3 accent">✓ 已订阅 FitAI Pro</div>
          <div class="tiny muted" style="margin-top:5px">所有 Pro 功能已解锁。</div>
        </div>
      ` : `
        <button class="plan-option" onclick="app.buy('monthly')">
          <div style="text-align:left"><div class="title">月度订阅</div><div class="desc">随时取消</div></div>
          <div class="price">¥28 / 月</div>
        </button>
        <button class="plan-option" onclick="app.buy('yearly')">
          <div style="text-align:left"><div class="title">年度订阅</div><div class="desc">约 ¥16.5 / 月</div></div>
          <div class="price">¥198 / 年</div>
        </button>
      `}

      <button class="link" style="display:block;margin:8px auto" onclick="app.restorePurchase()">恢复购买</button>
      <div class="tiny faint center" style="line-height:1.6">订阅会自动续期，可随时在系统设置中取消。预览版不会真的扣款。</div>
    </div>
  `;
}

/* ---------------- Workout ---------------- */

function workoutScreen() {
  const workout = state.workout;
  if (!workout) return home();
  const day = state.plan.days.find((item) => item.id === workout.dayId);
  if (!day) return home();
  if (workout.index >= day.exercises.length) return workoutSummary(day);

  const exercise = day.exercises[workout.index];
  const info = EX[exercise.slug];
  const done = workout.logs.length;
  const total = day.exercises.reduce((sum, item) => sum + item.sets, 0);
  const ratio = Math.min(100, Math.round((done / Math.max(1, total)) * 100));

  return `
    <div class="stack">
      <div class="row between" style="margin-bottom:4px">
        <button class="icon-btn" onclick="app.exitWorkout()">✕</button>
        <div class="h3">训练中</div>
        <div style="width:34px"></div>
      </div>

      <div>
        <div class="workout-progress"><span>${done}/${total} 组</span><span>${workout.index + 1}/${day.exercises.length} 动作</span></div>
        <div class="bar"><span style="width:${ratio}%"></span></div>
      </div>

      <div class="card">
        <div class="between">
          <div class="badge">动作 ${workout.index + 1}/${day.exercises.length}</div>
          <div class="tiny faint">${info.equip}</div>
        </div>
        <div class="h2" style="margin-top:9px">${info.name}</div>
        <div class="small accent" style="margin-top:4px">${exercise.sets} 组 × ${exercise.reps}</div>
        <div class="small muted" style="margin-top:10px;line-height:1.65">${info.cues}</div>
      </div>

      ${workout.rest > 0 ? `
        <div class="rest-pill">
          <span id="rest-text">休息 ${workout.rest}s</span>
          <button class="link" onclick="app.skipRest()">跳过</button>
        </div>
      ` : ""}

      <div class="card">
        <div class="between">
          <div class="h3">第 ${Math.min(workout.setIndex + 1, exercise.sets)} 组 / 共 ${exercise.sets} 组</div>
          <div class="tiny muted">RPE 7.5</div>
        </div>

        ${exercise.weight > 0 ? `
          <div class="row between" style="margin-top:14px">
            <span class="small muted">重量</span>
            <div class="stepper">
              <button onclick="app.workoutWeight(-2.5)">−</button>
              <span>${workout.weight} kg</span>
              <button onclick="app.workoutWeight(2.5)">＋</button>
            </div>
          </div>
        ` : ""}

        <div class="row between" style="margin-top:14px">
          <span class="small muted">次数</span>
          <div class="stepper">
            <button onclick="app.workoutReps(-1)">−</button>
            <span>${workout.reps} 次</span>
            <button onclick="app.workoutReps(1)">＋</button>
          </div>
        </div>

        ${workout.setIndex < exercise.sets ? `
          <button class="btn btn-primary" style="margin-top:16px" onclick="app.completeSet()">完成第 ${workout.setIndex + 1} 组</button>
        ` : `
          <button class="btn btn-primary" style="margin-top:16px" onclick="app.nextExercise()">
            ${workout.index < day.exercises.length - 1 ? "下一个动作" : "查看训练总结"}
          </button>
        `}

        <button class="btn btn-ghost" style="margin-top:4px" onclick="app.nextExercise()">跳过这个动作</button>
      </div>

      ${workout.logs.length ? `
        <div class="card">
          <div class="h3" style="margin-bottom:6px">本次已完成</div>
          ${workout.logs.map((log) => `
            <div class="set-line">
              <span class="small muted">${EX[log.slug].name} · 第 ${log.set} 组</span>
              <span class="small">${log.weight > 0 ? log.weight + "kg × " : "自重 × "}${log.reps}</span>
            </div>
          `).join("")}
        </div>
      ` : ""}
    </div>
  `;
}

function workoutSummary(day) {
  const workout = state.workout;
  const volume = workout.logs.reduce((sum, log) => sum + log.weight * log.reps, 0);
  const minutes = Math.max(1, Math.round((Date.now() - workout.startedAt) / 60000));
  return `
    <div class="stack">
      <div class="card">
        <div class="h2">训练完成</div>
        <div class="tiny muted" style="margin-top:4px">${day.title}</div>
        <div class="row gap8" style="margin-top:14px">
          <div class="metric"><div class="value">${workout.logs.length}</div><div class="label">完成组数</div></div>
          <div class="metric"><div class="value">${Math.round(volume)}</div><div class="label">总容量 kg</div></div>
          <div class="metric"><div class="value">${minutes}</div><div class="label">分钟</div></div>
        </div>
      </div>

      <div class="card">
        <div class="h3">今天感觉如何？</div>
        <div class="row gap8" style="margin-top:10px">
          ${["😫", "😕", "😐", "🙂", "💪"].map((emoji, index) => `
            <button class="chip ${index === 3 ? "active" : ""}" style="flex:1;font-size:18px" onclick="app.feeling(${index + 1})">${emoji}</button>
          `).join("")}
        </div>
      </div>

      <button class="btn btn-primary" onclick="app.finishWorkout()">保存并结束</button>
      <div class="tiny faint center">记录会用于下一次计划调整。</div>
    </div>
  `;
}

/* ---------------- Session detail ---------------- */

function sessionScreen() {
  const saved = state.sessions.find((item) => item.id === state.sessionId);
  if (!saved) return home();
  const session = state.sessionEditing && state.sessionDraft ? state.sessionDraft : saved;
  const volume = session.items.reduce((sum, item) => sum + item.weight * item.reps * item.sets, 0);

  if (state.sessionEditing) {
    return `
      <div class="stack">
        ${headerBack("编辑训练记录", "app.sessionCancel()")}
        <div class="card">
          <div class="form-label">训练名称</div>
          <input type="text" value="${esc(session.title)}" onchange="app.sessionField('title', this.value)">
          <div class="form-label" style="margin-top:10px">时长（分钟）</div>
          <input type="number" min="1" max="300" value="${session.duration}" onchange="app.sessionField('duration', this.value)">
          <div class="form-label" style="margin-top:10px">训练感受</div>
          <div class="seg">
            ${[1, 2, 3, 4, 5].map((value) => `
              <button class="${session.feeling === value ? "active" : ""}" onclick="app.sessionFeeling(${value})">
                ${["😫", "😕", "😐", "🙂", "💪"][value - 1]}
              </button>
            `).join("")}
          </div>
        </div>

        ${session.items.map((item, index) => `
          <div class="card">
            <div class="between">
              <div class="h3">${esc(item.name)}</div>
              <button class="trash-btn" onclick="app.sessionDeleteItem(${index})">🗑</button>
            </div>
            <div class="row gap8" style="margin-top:10px">
              <div class="grow">
                <div class="tiny faint">重量 kg</div>
                <input type="number" min="0" step="0.5" value="${item.weight}" onchange="app.sessionItem(${index}, 'weight', this.value)">
              </div>
              <div class="grow">
                <div class="tiny faint">次数</div>
                <input type="number" min="0" value="${item.reps}" onchange="app.sessionItem(${index}, 'reps', this.value)">
              </div>
              <div class="grow">
                <div class="tiny faint">组数</div>
                <input type="number" min="1" value="${item.sets}" onchange="app.sessionItem(${index}, 'sets', this.value)">
              </div>
            </div>
          </div>
        `).join("")}

        <button class="btn btn-secondary" onclick="app.sessionAddItem()">＋ 添加动作</button>
        <button class="btn btn-primary" onclick="app.sessionSave()">保存修改</button>
        <button class="btn btn-danger" onclick="app.deleteSession()">删除这条记录</button>
      </div>
    `;
  }

  return `
    <div class="stack">
      ${headerBack("训练详情")}
      <div class="card">
        <div class="between">
          <div>
            <div class="h2">${esc(session.title)}</div>
            <div class="tiny muted" style="margin-top:4px">${session.date}</div>
          </div>
          <button class="link" onclick="app.sessionEdit()">编辑</button>
        </div>
        <div class="row gap8" style="margin-top:12px">
          <div class="metric"><div class="value">${session.duration}</div><div class="label">分钟</div></div>
          <div class="metric"><div class="value">${session.items.reduce((sum, item) => sum + item.sets, 0)}</div><div class="label">组数</div></div>
          <div class="metric"><div class="value">${Math.round(volume)}</div><div class="label">容量 kg</div></div>
        </div>
      </div>
      <div class="card">
        ${session.items.map((item) => `
          <div class="set-line">
            <span class="small">${item.name}</span>
            <span class="tiny muted">${item.sets} 组 × ${item.reps}${item.weight ? " · " + item.weight + "kg" : " · 自重"}</span>
          </div>
        `).join("")}
      </div>
      <button class="btn btn-danger" onclick="app.deleteSession()">删除这条记录</button>
    </div>
  `;
}

/* ---------------- render ---------------- */

function render() {
  if (!state.onboarded) state.screen = "onboarding";
  if (state.onboarded && state.screen === "onboarding") state.screen = "tabs";

  const root = document.getElementById("app");
  if (!root) return;

  let html = "";
  if (state.screen === "onboarding") html = onboarding();
  else if (state.screen === "tabs") {
    if (state.tab === "home") html = home();
    else if (state.tab === "plan") html = planScreen();
    else if (state.tab === "coach") html = coachScreen();
    else if (state.tab === "equipment") html = equipmentScreen();
    else html = profileScreen();
  } else if (state.screen === "planDay") html = planDayScreen();
  else if (state.screen === "nutrition") html = nutritionScreen();
  else if (state.screen === "foodAdd") html = foodAddScreen();
  else if (state.screen === "paywall") html = paywallScreen();
  else if (state.screen === "workout") html = workoutScreen();
  else if (state.screen === "sessionDetail") html = sessionScreen();
  else if (state.screen === "exerciseDetail") html = exerciseScreen();
  else if (state.screen === "equipmentLibrary") html = equipmentLibraryScreen();
  else if (state.screen === "equipmentItem") html = equipmentItemScreen();
  else if (state.screen === "bodyAnalysis") html = bodyAnalysisScreen();
  else html = home();

  root.innerHTML = html;
  root.className = "app"
    + (state.screen === "tabs" ? "" : " no-tabs")
    + (state.screen === "tabs" && state.tab === "coach" ? " chat-mode" : "");
  document.getElementById("tabbar").innerHTML = tabbar();
  document.getElementById("tabbar").className = "tabbar" + (state.onboarded && state.screen === "tabs" ? "" : " hidden");

  if (state.screen === "tabs" && state.tab === "coach") {
    setTimeout(() => {
      const chat = document.getElementById("chat-scroll");
      if (chat) chat.scrollTop = chat.scrollHeight;
    }, 20);
  }
}

function coachReply(text) {
  if (/胸痛|胸闷|晕|呼吸困难|喘不上气|昏倒/.test(text)) {
    return { text: "你描述的可能是需要立即处理的情况。请马上停止训练，坐下休息；如果症状持续或加重，请立即就医或拨打 120。不要继续做任何高强度动作。", safety: true };
  }
  if (/怀孕|孕期|产后|术后|手术/.test(text)) {
    return { text: "孕期、产后恢复期和术后训练需要专业评估。建议先咨询产科医生或康复师，再决定训练内容。我可以记录状态，但不提供这类训练处方。", safety: true };
  }
  if (/今天|练什么|计划/.test(text)) {
    const day = todayDay();
    return { text: `今天建议练「${day.title}」，共 ${day.exercises.length} 个动作：\n${day.exercises.map((item) => `· ${EX[item.slug].name} ${item.sets} 组 × ${item.reps}`).join("\n")}\n如果状态一般，把最后一组去掉，优先保证动作质量。` };
  }
  if (/替代|没有器械|换动作/.test(text)) {
    return { text: "可以试试这些替代：\n· 俯卧撑（徒手，胸）\n· 高脚杯深蹲（哑铃，腿）\n· 单臂哑铃划船（哑铃，背）\n选择能稳定完成 8–12 次的重量，动作变形就降重量。" };
  }
  if (/蛋白|吃|热量|饮食/.test(text)) {
    const targets = nutritionTargets();
    return { text: `按你的体重，每天蛋白质建议在 ${targets.protein}g 左右，分 3–4 餐摄入；训练后 1–2 小时内吃到 20–30g 蛋白质即可。疾病相关饮食请咨询营养科医生。` };
  }
  if (/酸|疼|痛/.test(text)) {
    return { text: "训练后的延迟性酸痛通常 24–72 小时缓解，可以低强度活动、拉伸、保证睡眠。如果是关节刺痛、肿胀或影响走路，先停止训练并找医生评估。" };
  }
  return { text: "我记住了。你可以具体问：今天练什么、某个动作怎么替代，或者把训练感受告诉我。当前计划会参考你的完成率和 RPE 做调整。" };
}

/* ---------------- app actions ---------------- */

window.app = {
  field(key, value) {
    state.profile[key] = value;
    save();
  },

  range(key, value, unit) {
    state.profile[key] = Number(value);
    const label = document.getElementById(`val-${key}`);
    if (label) label.textContent = `${value}${unit}`;
    save();
  },

  seg(key, value) {
    state.profile[key] = Number.isNaN(Number(value)) ? value : Number(value);
    save();
    render();
  },

  toggleEquip(name) {
    const list = state.profile.equipment;
    state.profile.equipment = list.includes(name) ? list.filter((item) => item !== name) : list.concat(name);
    save();
    render();
  },

  setGoal(goal) {
    state.profile.goal = goal;
    save();
    render();
  },

  generatePlan() {
    const button = document.getElementById("gen-btn");
    if (button) {
      button.disabled = true;
      button.textContent = "正在编排 4 周计划…";
    }
    setTimeout(() => {
      state.profile.name = String(state.profile.name || "小林").trim() || "小林";
      state.plan = applyEquipmentLibrary(buildPlan(state.profile));
      state.onboarded = true;
      state.screen = "tabs";
      state.tab = "home";
      save();
      render();
      toast("已生成 4 周计划，开始训练吧");
    }, 700);
  },

  skipOnboarding() {
    state.profile = { ...DEFAULT_PROFILE };
    state.plan = applyEquipmentLibrary(buildPlan(state.profile));
    state.onboarded = true;
    state.screen = "tabs";
    state.tab = "home";
    save();
    render();
    toast("已载入示例数据");
  },

  tab(tab) {
    state.screen = "tabs";
    state.tab = tab;
    save();
    render();
  },

  go(screen) {
    state.screen = screen;
    save();
    render();
  },

  back() {
    if (state.screen === "foodAdd") state.screen = "nutrition";
    else if (state.screen === "planDay") { state.screen = "tabs"; state.tab = "plan"; }
    else if (state.screen === "paywall") { state.screen = "tabs"; state.tab = "profile"; }
    else if (state.screen === "sessionDetail") { state.screen = "tabs"; state.tab = "home"; }
    else if (state.screen === "exerciseDetail") { state.screen = "tabs"; state.tab = "equipment"; }
    else if (state.screen === "equipmentLibrary") { state.screen = "tabs"; state.tab = "equipment"; }
    else if (state.screen === "equipmentItem") state.screen = "equipmentLibrary";
    else if (state.screen === "bodyAnalysis") { state.screen = "tabs"; state.tab = "profile"; }
    else { state.screen = "tabs"; state.tab = "home"; }
    save();
    render();
  },

  backTo(tab) {
    state.screen = "tabs";
    state.tab = tab;
    save();
    render();
  },

  openPlanDay(id) {
    state.planDayId = id;
    state.screen = "planDay";
    save();
    render();
  },

  selectWeek(week) {
    state.selectedWeek = week;
    save();
    render();
  },

  changeSets(index, delta) {
    const day = state.plan.days.find((item) => item.id === state.planDayId);
    const exercise = day.exercises[index];
    exercise.sets = Math.max(1, Math.min(6, exercise.sets + delta));
    save();
    render();
  },

  deletePlanExercise(index) {
    const day = state.plan.days.find((item) => item.id === state.planDayId);
    if (day.exercises.length <= 1) return toast("至少保留一个动作");
    const removed = day.exercises.splice(index, 1)[0];
    if (!state.disliked.includes(removed.slug)) state.disliked.push(removed.slug);
    save();
    render();
    toast("已删除，并记住这个偏好");
  },

  addPlanExercise(slug) {
    const day = state.plan.days.find((item) => item.id === state.planDayId);
    const ex = EX[slug];
    day.exercises.push({
      slug,
      sets: 3,
      reps: ex.fixedReps || "10-12",
      weight: ex.base || 0,
      rest: 60,
      rpe: 7
    });
    state.disliked = state.disliked.filter((item) => item !== slug);
    save();
    render();
    toast("已添加动作");
  },

  savePlanDay() {
    state.screen = "tabs";
    state.tab = "plan";
    save();
    render();
    toast("训练日已保存");
  },

  regeneratePlan() {
    state.plan = applyEquipmentLibrary(buildPlan(state.profile));
    state.plan.version += 1;
    save();
    render();
    toast("已重新生成计划");
  },

  adjustPlan() {
    const weekSessions = state.sessions.filter((item) => item.thisWeek).length;
    const ratio = Math.round((weekSessions / Math.max(1, state.profile.weeklyDays)) * 100);
    state.plan.version += 1;
    state.plan.days.forEach((day) => {
      day.exercises.forEach((exercise) => {
        if (ratio < 60) exercise.sets = Math.max(2, exercise.sets - 1);
        else if (ratio >= 80 && exercise.weight > 0) exercise.weight = roundHalf(exercise.weight * 1.025 + 0.5);
      });
    });
    save();
    render();
    toast(`AI 复盘完成：完成率 ${ratio}%，已生成第 ${state.plan.version} 版`);
  },

  startWorkout() {
    const day = todayDay();
    const first = day.exercises[0];
    state.workout = {
      dayId: day.id,
      index: 0,
      setIndex: 0,
      weight: first.weight,
      reps: parseReps(first.reps),
      logs: [],
      rest: 0,
      startedAt: Date.now(),
      feeling: 4
    };
    state.screen = "workout";
    save();
    render();
  },

  workoutWeight(delta) {
    state.workout.weight = Math.max(0, roundHalf(state.workout.weight + delta));
    save();
    render();
  },

  workoutReps(delta) {
    state.workout.reps = Math.max(1, state.workout.reps + delta);
    save();
    render();
  },

  completeSet() {
    const workout = state.workout;
    const day = state.plan.days.find((item) => item.id === workout.dayId);
    const exercise = day.exercises[workout.index];
    workout.logs.push({
      slug: exercise.slug,
      set: workout.setIndex + 1,
      weight: exercise.weight > 0 ? workout.weight : 0,
      reps: workout.reps
    });
    workout.setIndex += 1;
    if (workout.setIndex < exercise.sets) {
      workout.rest = exercise.rest;
      save();
      render();
      startRestTimer();
    } else {
      workout.rest = 0;
      save();
      render();
      toast("本动作完成");
    }
  },

  skipRest() {
    if (state.workout) state.workout.rest = 0;
    stopRestTimer();
    save();
    render();
  },

  nextExercise() {
    const workout = state.workout;
    const day = state.plan.days.find((item) => item.id === workout.dayId);
    stopRestTimer();
    workout.rest = 0;
    workout.index += 1;
    workout.setIndex = 0;
    if (workout.index < day.exercises.length) {
      const next = day.exercises[workout.index];
      workout.weight = next.weight;
      workout.reps = parseReps(next.reps);
    }
    save();
    render();
  },

  feeling(value) {
    if (state.workout) state.workout.feeling = value;
    save();
    render();
    toast("已记录训练感受");
  },

  finishWorkout() {
    const workout = state.workout;
    if (!workout) return;
    const day = state.plan.days.find((item) => item.id === workout.dayId);
    const volume = workout.logs.reduce((sum, log) => sum + log.weight * log.reps, 0);
    const items = day.exercises.map((exercise) => ({
      name: EX[exercise.slug].name,
      weight: exercise.weight,
      reps: parseReps(exercise.reps),
      sets: workout.logs.filter((log) => log.slug === exercise.slug).length || exercise.sets
    }));
    state.sessions.unshift({
      id: `s${Date.now()}`,
      title: day.title,
      date: "刚刚",
      duration: Math.max(1, Math.round((Date.now() - workout.startedAt) / 60000)),
      volume: Math.round(volume) || 1860,
      thisWeek: true,
      items
    });
    state.workout = null;
    stopRestTimer();
    state.screen = "tabs";
    state.tab = "home";
    save();
    render();
    toast("训练已保存");
  },

  exitWorkout() {
    if (!state.workout) return;
    if (!confirm("结束这次训练？已完成的组不会保存。")) return;
    state.workout = null;
    stopRestTimer();
    state.screen = "tabs";
    state.tab = "home";
    save();
    render();
  },

  openSession(id) {
    state.sessionId = id;
    const session = state.sessions.find((item) => item.id === id);
    state.sessionDraft = session ? JSON.parse(JSON.stringify(session)) : null;
    state.sessionEditing = false;
    state.screen = "sessionDetail";
    save();
    render();
  },

  sessionEdit() {
    const session = state.sessions.find((item) => item.id === state.sessionId);
    if (!session) return;
    state.sessionDraft = JSON.parse(JSON.stringify(session));
    state.sessionEditing = true;
    render();
  },

  sessionCancel() {
    state.sessionEditing = false;
    state.sessionDraft = null;
    render();
  },

  sessionField(key, value) {
    if (!state.sessionDraft) return;
    if (key === "duration") {
      state.sessionDraft.duration = Math.max(1, Number(value) || 1);
    } else {
      state.sessionDraft[key] = value;
    }
  },

  sessionFeeling(value) {
    if (!state.sessionDraft) return;
    state.sessionDraft.feeling = value;
    render();
  },

  sessionItem(index, key, value) {
    if (!state.sessionDraft || !state.sessionDraft.items[index]) return;
    const number = Math.max(0, Number(value) || 0);
    state.sessionDraft.items[index][key] = key === "sets" ? Math.max(1, number) : number;
  },

  sessionAddItem() {
    if (!state.sessionDraft) return;
    const name = prompt("动作名称", "自定义动作");
    if (!name) return;
    state.sessionDraft.items.push({ name, weight: 0, reps: 10, sets: 3 });
    render();
  },

  sessionDeleteItem(index) {
    if (!state.sessionDraft) return;
    state.sessionDraft.items.splice(index, 1);
    render();
  },

  sessionSave() {
    if (!state.sessionDraft) return;
    const draft = state.sessionDraft;
    draft.title = String(draft.title || "").trim() || "训练记录";
    draft.duration = Math.max(1, Number(draft.duration) || 1);
    draft.feeling = Math.min(5, Math.max(1, Number(draft.feeling) || 3));
    draft.items = draft.items.map((item) => ({
      name: item.name,
      weight: Math.max(0, Number(item.weight) || 0),
      reps: Math.max(0, Number(item.reps) || 0),
      sets: Math.max(1, Number(item.sets) || 1)
    }));
    draft.volume = draft.items.reduce((sum, item) => sum + item.weight * item.reps * item.sets, 0);
    const index = state.sessions.findIndex((item) => item.id === draft.id);
    if (index >= 0) state.sessions[index] = draft;
    state.sessionEditing = false;
    state.sessionDraft = null;
    save();
    render();
    toast("训练记录已保存，首页数据已同步");
  },

  deleteSession() {
    if (!confirm("删除这条训练记录？删除后无法恢复。")) return;
    state.sessions = state.sessions.filter((item) => item.id !== state.sessionId);
    state.sessionEditing = false;
    state.sessionDraft = null;
    state.screen = "tabs";
    state.tab = "home";
    save();
    render();
    toast("已删除训练记录");
  },

  sendChat(text) {
    let message = text;
    if (message === undefined) {
      const input = document.getElementById("chat-input");
      message = input ? input.value : "";
    }
    message = String(message || "").trim();
    if (!message) return;
    state.chats.push({ role: "user", text: message });
    const reply = coachReply(message);
    state.chats.push({ role: "assistant", text: reply.text, safety: !!reply.safety });
    save();
    render();
    setTimeout(() => {
      const chat = document.getElementById("chat-scroll");
      if (chat) chat.scrollTop = chat.scrollHeight;
    }, 20);
  },

  mockPhoto() {
    state.equipment.scanned = true;
    state.equipment.candidates = [];
    save();
    render();
    toast("已模拟拍摄一张器械照片");
  },

  scanEquipment() {
    if (!state.equipment.scanned) return toast("先模拟拍一张照片");
    state.equipment.candidates = [
      { slug: "lat_pulldown", confidence: 0.91 },
      { slug: "seated_row", confidence: 0.64 },
      { slug: "face_pull", confidence: 0.48 }
    ];
    save();
    render();
    toast("识别完成，置信度低的候选请手动确认");
  },

  equipSearch(query) {
    state.equipment.query = query;
    const box = document.getElementById("equip-results");
    if (box) box.innerHTML = equipResults(query);
    save();
  },

  openExercise(slug) {
    state.selectedExercise = slug;
    state.screen = "exerciseDetail";
    save();
    render();
  },

  askCoach(slug) {
    const name = EX[slug].name;
    state.chats.push({ role: "user", text: `${name}怎么用？需要注意什么？` });
    state.chats.push({ role: "assistant", text: `${EX[slug].cues}\n如果动作过程中出现关节刺痛、麻木或肿胀，请停止并咨询医生。` });
    state.screen = "tabs";
    state.tab = "coach";
    save();
    render();
    setTimeout(() => {
      const chat = document.getElementById("chat-scroll");
      if (chat) chat.scrollTop = chat.scrollHeight;
    }, 20);
  },

  openPaywall() {
    state.screen = "paywall";
    save();
    render();
  },

  buy(plan) {
    state.pro = true;
    save();
    render();
    toast(plan === "yearly" ? "模拟购买成功：年度订阅" : "模拟购买成功：月度订阅");
  },

  restorePurchase() {
    toast("预览版不连接 StoreKit；真实 App 会恢复 Apple ID 的订阅");
  },

  openFoodAdd(meal) {
    state.foodDraft = { meal, query: "", selected: null, grams: 100 };
    state.screen = "foodAdd";
    save();
    render();
  },

  foodMeal(meal) {
    state.foodDraft.meal = meal;
    save();
    render();
  },

  foodQuery(query) {
    state.foodDraft.query = query;
    const box = document.getElementById("food-results");
    if (box) box.innerHTML = foodResults(query);
    save();
  },

  selectFood(name) {
    state.foodDraft.selected = name;
    state.foodDraft.grams = 100;
    save();
    render();
  },

  clearFoodSelection() {
    state.foodDraft.selected = null;
    save();
    render();
  },

  foodGrams(value) {
    const grams = Number(value);
    state.foodDraft.grams = grams;
    const food = FOODS.find((item) => item.name === state.foodDraft.selected);
    const label = document.getElementById("food-grams-label");
    const kcal = document.getElementById("food-kcal");
    const protein = document.getElementById("food-p");
    const carbs = document.getElementById("food-c");
    const fat = document.getElementById("food-f");
    if (label) label.textContent = `${grams} g`;
    if (food && kcal) kcal.textContent = Math.round(food.kcal * grams / 100);
    if (food && protein) protein.textContent = `${Math.round(food.p * grams / 100)}g`;
    if (food && carbs) carbs.textContent = `${Math.round(food.c * grams / 100)}g`;
    if (food && fat) fat.textContent = `${Math.round(food.f * grams / 100)}g`;
    save();
  },

  addFood() {
    const draft = state.foodDraft;
    const food = FOODS.find((item) => item.name === draft.selected);
    if (!food) return toast("先选择一个食物");
    const factor = draft.grams / 100;
    state.foodLogs.push({
      id: `f${Date.now()}`,
      meal: draft.meal,
      name: food.name,
      grams: draft.grams,
      kcal: Math.round(food.kcal * factor),
      p: Math.round(food.p * factor * 10) / 10,
      c: Math.round(food.c * factor * 10) / 10,
      f: Math.round(food.f * factor * 10) / 10
    });
    state.screen = "nutrition";
    save();
    render();
    toast("已添加到今日饮食");
  },

  deleteFood(id) {
    state.foodLogs = state.foodLogs.filter((item) => item.id !== id);
    save();
    render();
    toast("已删除记录");
  },

  equipmentLibraryOpen() {
    state.screen = "equipmentLibrary";
    save();
    render();
  },

  openEquipItem(id) {
    state.equipmentItemId = id;
    state.screen = "equipmentItem";
    save();
    render();
  },

  addDemoEquipment() {
    const pool = ["seated_row", "treadmill", "face_pull", "leg_press", "biceps_curl"];
    const slug = pool.find((item) => !state.equipmentLibrary.some((entry) => entry.slug === item));
    if (!slug) return toast("示例器械已全部添加");
    const ex = EX[slug];
    state.equipmentLibrary.push({
      id: `e${Date.now()}`,
      name: ex.name,
      slug,
      muscle: ex.muscle,
      equip: ex.equip,
      video: false,
      notes: "手动添加"
    });
    save();
    render();
    toast(`已添加 ${ex.name}`);
  },

  toggleEquipLibrary() {
    state.useEquipLibrary = !state.useEquipLibrary;
    save();
    render();
    toast(state.useEquipLibrary ? "已启用器械库优先" : "已关闭器械库优先");
  },

  saveCandidate(slug) {
    if (state.equipmentLibrary.some((entry) => entry.slug === slug)) {
      return toast("这个器械已经在库里");
    }
    const ex = EX[slug];
    if (!ex) return;
    state.equipmentLibrary.push({
      id: `e${Date.now()}`,
      name: ex.name,
      slug,
      muscle: ex.muscle,
      equip: ex.equip,
      video: false,
      notes: "来自拍照识别"
    });
    save();
    render();
    toast(`已保存 ${ex.name} 到器械库`);
  },

  deleteEquipItem(id) {
    state.equipmentLibrary = state.equipmentLibrary.filter((item) => item.id !== id);
    state.screen = "equipmentLibrary";
    save();
    render();
    toast("已从器械库删除");
  },

  regenerateWithLibrary() {
    state.useEquipLibrary = true;
    state.plan = applyEquipmentLibrary(buildPlan(state.profile));
    state.plan.version += 1;
    state.screen = "tabs";
    state.tab = "plan";
    save();
    render();
    toast("已按器械库生成新计划");
  },

  bodyAnalysisOpen() {
    state.screen = "bodyAnalysis";
    save();
    render();
  },

  bodyMockPhoto() {
    state.bodyPhoto = true;
    save();
    render();
    toast("已模拟选择体型照片");
  },

  bodyConsentToggle() {
    state.bodyConsent = !state.bodyConsent;
    render();
  },

  bodyAnalyze() {
    if (!state.bodyPhoto) return toast("先拍一张照片");
    if (!state.bodyConsent) return toast("请先同意用于本次分析");
    const variant = BODY_VARIANTS[Math.floor(Math.random() * BODY_VARIANTS.length)];
    state.bodyAnalysis = { ...variant, applied: false };
    save();
    render();
    toast("分析完成，仅作训练重点参考");
  },

  applyBodyAnalysis() {
    const analysis = state.bodyAnalysis;
    if (!analysis) return;
    state.plan.version += 1;
    state.plan.days.forEach((day) => {
      day.exercises.forEach((exercise) => {
        const muscle = EX[exercise.slug] ? EX[exercise.slug].muscle : "";
        if (analysis.focus.includes(muscle)) {
          exercise.sets = Math.min(6, exercise.sets + 1);
        }
      });
    });
    analysis.applied = true;
    state.screen = "tabs";
    state.tab = "profile";
    save();
    render();
    toast("已应用体型分析：重点部位增加训练量");
  },

  mockHealth() {
    toast("预览版不接 HealthKit；真实 App 会读取体重并写入训练");
  },

  saveReminder() {
    const input = document.getElementById("reminder-time");
    state.reminder = input ? input.value : "19:00";
    save();
    toast(`已设置 ${state.reminder} 训练提醒`);
  },

  clearPreferences() {
    state.disliked = [];
    save();
    render();
    toast("已清除训练偏好");
  },

  mockPrivacy() {
    toast("上线前替换为正式隐私政策、用户协议与备案信息");
  },

  mockMeituan() {
    toast("美团联盟需要企业资质与 CPS 配置；预览版不跳转");
  },

  exportData() {
    const data = JSON.stringify({
      profile: state.profile,
      plan: state.plan,
      sessions: state.sessions,
      foodLogs: state.foodLogs,
      chats: state.chats
    }, null, 2);
    const blob = new Blob([data], { type: "application/json" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = "fitai-data.json";
    link.click();
    URL.revokeObjectURL(link.href);
    toast("已导出 JSON 数据");
  },

  restartOnboarding() {
    state.onboarded = false;
    state.screen = "onboarding";
    state.workout = null;
    save();
    render();
  },

  resetAll() {
    if (!confirm("确定清除所有演示数据并重新开始？")) return;
    localStorage.removeItem(STORAGE_KEY);
    state = initialState();
    stopRestTimer();
    render();
    toast("演示数据已重置");
  }
};

/* ---------------- rest timer ---------------- */

let restTimer = null;

function startRestTimer() {
  stopRestTimer();
  if (!state.workout || state.workout.rest <= 0) return;
  restTimer = setInterval(() => {
    if (!state.workout) {
      stopRestTimer();
      return;
    }
    state.workout.rest = Math.max(0, state.workout.rest - 1);
    const label = document.getElementById("rest-text");
    if (label) label.textContent = `休息 ${state.workout.rest}s`;
    if (state.workout.rest <= 0) {
      stopRestTimer();
      save();
      render();
    }
  }, 1000);
}

function stopRestTimer() {
  if (restTimer) {
    clearInterval(restTimer);
    restTimer = null;
  }
}

/* ---------------- boot ---------------- */

const previewParams = new URLSearchParams(location.search);
if (previewParams.has("tab") || previewParams.has("screen") || previewParams.get("demo") === "1") {
  if (!state.onboarded) {
    state.profile = { ...DEFAULT_PROFILE };
    state.plan = applyEquipmentLibrary(buildPlan(state.profile));
    state.onboarded = true;
  }
  state.screen = previewParams.has("screen") ? previewParams.get("screen") : "tabs";
  if (previewParams.has("tab")) state.tab = previewParams.get("tab");
}
if (previewParams.has("session")) {
  const session = state.sessions.find((item) => item.id === previewParams.get("session"));
  if (session) {
    state.onboarded = true;
    state.sessionId = session.id;
    state.sessionDraft = JSON.parse(JSON.stringify(session));
    state.screen = "sessionDetail";
    state.sessionEditing = previewParams.get("editSession") === "1";
  }
}

render();
