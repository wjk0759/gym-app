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
  { name: "包子", cat: "主食", kcal: 220, p: 8, c: 30, f: 7, serving: 100 },
  { name: "饺子", cat: "主食", kcal: 240, p: 9, c: 30, f: 9, serving: 200 },
  { name: "炒饭", cat: "主食", kcal: 180, p: 5, c: 28, f: 6, serving: 300 },
  { name: "便利店饭团", cat: "主食", kcal: 180, p: 6, c: 30, f: 4, serving: 120 },
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
  { name: "拿铁", cat: "饮品", kcal: 60, p: 3, c: 5, f: 3, serving: 350 },
  { name: "可乐", cat: "饮品", kcal: 42, p: 0, c: 10.6, f: 0, serving: 500 },
  { name: "奶茶", cat: "饮品", kcal: 70, p: 1, c: 12, f: 2.3, serving: 500 },
  { name: "螺蛳粉", cat: "外食", kcal: 125, p: 5.5, c: 18.5, f: 3.5, serving: 600 },
  { name: "桂林米粉", cat: "外食", kcal: 130, p: 6, c: 20, f: 3.5, serving: 500 },
  { name: "兰州拉面", cat: "外食", kcal: 110, p: 5, c: 18, f: 2.5, serving: 550 },
  { name: "酸辣粉", cat: "外食", kcal: 140, p: 4, c: 22, f: 4.5, serving: 500 },
  { name: "凉皮", cat: "外食", kcal: 150, p: 4, c: 25, f: 4, serving: 350 },
  { name: "牛肉面", cat: "外食", kcal: 110, p: 6, c: 16, f: 3, serving: 550 },
  { name: "麻辣烫", cat: "外食", kcal: 120, p: 6, c: 10, f: 6, serving: 500 },
  { name: "麻辣香锅", cat: "外食", kcal: 180, p: 8, c: 10, f: 12, serving: 400 },
  { name: "火锅", cat: "外食", kcal: 160, p: 9, c: 8, f: 10, serving: 500 },
  { name: "烧烤", cat: "外食", kcal: 250, p: 18, c: 2, f: 19, serving: 300 },
  { name: "炸鸡", cat: "外食", kcal: 280, p: 18, c: 10, f: 18, serving: 200 },
  { name: "汉堡", cat: "外食", kcal: 250, p: 12, c: 26, f: 11, serving: 220 },
  { name: "薯条", cat: "外食", kcal: 312, p: 3.4, c: 41, f: 15, serving: 120 },
  { name: "煎饼果子", cat: "外食", kcal: 220, p: 8, c: 28, f: 8, serving: 250 },
  { name: "肉夹馍", cat: "外食", kcal: 260, p: 12, c: 27, f: 11, serving: 200 },
  { name: "小笼包", cat: "外食", kcal: 230, p: 10, c: 25, f: 10, serving: 180 },
  { name: "蛋糕", cat: "甜点", kcal: 350, p: 5, c: 45, f: 17, serving: 100 }
];

function allFoods() {
  return [...(state.customFoods || []), ...FOODS];
}

const ICONS = {
  home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-5v-6h-4v6H5a1 1 0 0 1-1-1z"/></svg>',
  plan: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="5" width="16" height="16" rx="3"/><path d="M8 3v4M16 3v4M4 10h16"/></svg>',
  coach: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 6h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H9l-5 4v-4H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Z"/></svg>',
  equipment: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8h3M17 8h3M7 6v4M17 6v4M7 8h10"/><circle cx="12" cy="16" r="4"/></svg>',
  user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="3.5"/><path d="M5 20c.6-3.6 3.1-5.5 7-5.5s6.4 1.9 7 5.5"/></svg>',
  settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1Z"/></svg>'
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
  next.foodPhotoImage = false;
  next.foodPhotoMeal = next.foodPhotoMeal || "午餐";
  next.foodPhotoItems = [];
  next.foodPhotoConfidence = 0;
  next.foodPhotoModel = "";
  next.customFoods = Array.isArray(next.customFoods) ? next.customFoods : [];
  next.foodCustomDraft = null;
  next.equipSearchQuery = "";
  next.equipPhotoSource = next.equipPhotoSource || "拍照";
  next.authenticated = !!next.authenticated;
  next.authMode = next.authMode || "phone";
  next.authPhone = next.authPhone || "13800138000";
  next.authCode = next.authCode || "";
  next.authAccount = next.authAccount || "";
  next.authPassword = next.authPassword || "";
  next.authConsent = false;
  next.authError = "";
  next.authDevCode = "";
  next.paywallPlan = next.paywallPlan || "yearly";
  next.legalDoc = null;
  next.profileDraft = null;
  next.coachSkill = next.coachSkill || "trainer";
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
    profileDraft: null,
    plan: buildPlan(profile),
    sessions: demoSessions(),
    chats: [],
    coachSkill: "trainer",
    foodLogs: demoLogs(),
    customFoods: [],
    foodCustomDraft: null,
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
    foodPhotoImage: false,
    foodPhotoMeal: "午餐",
    foodPhotoItems: [],
    foodPhotoConfidence: 0,
    foodPhotoModel: "",
    equipSearchQuery: "",
    equipPhotoSource: "拍照",
    authenticated: false,
    authMode: "phone",
    authPhone: "13800138000",
    authCode: "",
    authAccount: "",
    authPassword: "",
    authConsent: false,
    authError: "",
    authDevCode: "",
    paywallPlan: "yearly",
    legalDoc: null,
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

let saveTimer = null;

function flushSave() {
  if (saveTimer) {
    clearTimeout(saveTimer);
    saveTimer = null;
  }
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (error) {
    /* ignore */
  }
}

function save() {
  if (saveTimer) return;
  saveTimer = setTimeout(() => {
    saveTimer = null;
    flushSave();
  }, 120);
}

window.addEventListener("pagehide", flushSave);
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden") flushSave();
});

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

function planAdjustmentPreview() {
  const completed = state.sessions.filter((session) => session.thisWeek).length;
  const completionRate = Math.min(1, completed / Math.max(1, state.profile.weeklyDays));
  const targetRPEs = state.plan.days.flatMap((day) =>
    day.exercises.map((exercise) => Number(exercise.rpe) || 0)
  ).filter((value) => value > 0);
  const averageRPE = targetRPEs.length
    ? targetRPEs.reduce((sum, value) => sum + value, 0) / targetRPEs.length
    : 0;

  if (completionRate < 0.6) {
    return {
      completed,
      completionRate,
      averageRPE,
      headline: "先把训练频率稳住",
      detail: `最近完成率 ${Math.round(completionRate * 100)}%，下版每个动作减少 1 组；先建立规律，不急着加重量。`,
      setsDelta: -1,
      weightMultiplier: 1
    };
  }
  if (averageRPE >= 9) {
    return {
      completed,
      completionRate,
      averageRPE,
      headline: "负荷偏高，先降一点",
      detail: `最近平均 RPE ${averageRPE.toFixed(1)}，下版主项重量下调 5%，把动作质量放在前面。`,
      setsDelta: 0,
      weightMultiplier: 0.95
    };
  }
  if (completionRate >= 0.8 && averageRPE > 0 && averageRPE <= 8) {
    return {
      completed,
      completionRate,
      averageRPE,
      headline: "可以小幅加负荷",
      detail: `完成率 ${Math.round(completionRate * 100)}%，平均 RPE ${averageRPE.toFixed(1)}，下版主项重量上调 2.5%。`,
      setsDelta: 0,
      weightMultiplier: 1.025
    };
  }
  return {
    completed,
    completionRate,
    averageRPE,
    headline: "保持当前负荷",
    detail: `最近完成率 ${Math.round(completionRate * 100)}%，这版先不改重量，优先把训练日补齐。`,
    setsDelta: 0,
    weightMultiplier: 1
  };
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

function settingsButton() {
  return `<button class="icon-btn" onclick="app.openSettings()" aria-label="设置">${ICONS.settings}</button>`;
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

function profileDraftRangeRow(key, label, unit, min, max, step) {
  const draft = state.profileDraft;
  if (!draft) return "";
  const value = draft[key] ?? min;
  const shown = step < 1 ? Number(value).toFixed(1) : String(Math.round(value));
  return `
    <div class="slider-row">
      <div class="between">
        <span class="small muted">${label}</span>
        <span class="small strong" id="draft-val-${key}">${shown}${unit}</span>
      </div>
      <input type="range" min="${min}" max="${max}" step="${step}" value="${value}"
        oninput="app.profileDraftNumber('${key}', this.value)">
    </div>
  `;
}

/* ---------------- Login ---------------- */

function loginScreen() {
  const phoneMode = state.authMode === "phone";
  return `
    <div class="login-page">
      <div class="login-brand">
        <div class="login-mark">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M4 9v6M7 7v10M17 7v10M20 9v6M7 12h10" />
          </svg>
        </div>
        <div>
          <div class="login-brand-name">练途</div>
          <div class="login-brand-sub">AI 健身教练</div>
        </div>
      </div>

      <div class="login-intro">
        <h1>登录练途</h1>
        <p>同步训练计划、记录和 AI 复盘。</p>
      </div>

      <div class="login-card">
        <div class="login-seg">
          <button class="${phoneMode ? "active" : ""}" onclick="app.previewAuthMode('phone')">手机验证码</button>
          <button class="${!phoneMode ? "active" : ""}" onclick="app.previewAuthMode('password')">账号密码</button>
        </div>

        ${phoneMode ? `
          <div class="login-field">
            <div class="login-field-label">手机号</div>
            <div class="login-input">
              <span class="login-prefix">+86</span>
              <span class="login-input-divider"></span>
              <input id="login-phone" type="tel" inputmode="numeric" autocomplete="tel" placeholder="请输入手机号" value="${esc(state.authPhone)}" oninput="app.previewAuthField('authPhone', this.value)">
            </div>
          </div>
          <div class="login-field">
            <div class="login-field-label">验证码</div>
            <div class="login-input">
              <input id="login-code" type="tel" inputmode="numeric" autocomplete="one-time-code" placeholder="请输入 6 位验证码" value="${esc(state.authCode)}" oninput="app.previewAuthField('authCode', this.value)">
              <button class="code-btn" onclick="app.previewSendCode()">获取验证码</button>
            </div>
          </div>
          <div class="field-hint ${state.authDevCode ? "warning" : ""}">${state.authDevCode ? `开发验证码 ${state.authDevCode}，已自动填入` : "验证码仅用于本次登录，请勿转发"}</div>
        ` : `
          <div class="login-field">
            <div class="login-field-label">手机号或用户名</div>
            <div class="login-input">
              <input id="login-account" type="text" autocomplete="username" placeholder="请输入手机号或用户名" value="${esc(state.authAccount)}" oninput="app.previewAuthField('authAccount', this.value)">
            </div>
          </div>
          <div class="login-field">
            <div class="login-field-label">密码</div>
            <div class="login-input">
              <input id="login-password" type="password" autocomplete="current-password" placeholder="请输入密码" value="${esc(state.authPassword)}" oninput="app.previewAuthField('authPassword', this.value)">
            </div>
          </div>
          <div class="row between" style="margin-top:-4px">
            <div class="field-hint" style="margin:0">密码至少 8 位，含字母和数字</div>
            <button class="link" style="font-size:11px" onclick="app.previewForgotPassword()">忘记密码？</button>
          </div>
        `}

        ${state.authError ? `<div class="login-error">${esc(state.authError)}</div>` : ""}

        <button class="btn btn-primary login-submit" onclick="app.previewLogin()">登录并继续</button>
        <div class="login-auto">${phoneMode ? "未注册手机号会自动创建账号并登录" : "未注册账号会自动创建并登录"}</div>
      </div>

      <div class="social-divider">
        <div></div>
        <span>或使用以下方式登录</span>
        <div></div>
      </div>

      <div class="social-row">
        <button class="social-login wechat" onclick="app.previewSocial('微信')"><span class="social-icon">微</span>微信登录</button>
        <button class="social-login qq" onclick="app.previewSocial('QQ')"><span class="social-icon">Q</span>QQ 登录</button>
      </div>

      <div class="login-consent">
        <button class="consent-check ${state.authConsent ? "checked" : ""}" onclick="app.previewAuthConsent()" aria-label="同意用户协议与隐私政策" aria-pressed="${state.authConsent}">${state.authConsent ? "✓" : ""}</button>
        <div class="login-consent-copy">
          我已阅读并同意<button class="link" onclick="app.openLegal('terms')">《用户协议》</button>和<button class="link" onclick="app.openLegal('privacy')">《隐私政策》</button>，且已年满 14 周岁
        </div>
      </div>
    </div>
  `;
}

const LEGAL_DOCS = {
  terms: {
    title: "用户协议",
    updated: "2026 年 10 月 25 日",
    intro: "欢迎使用练途。本协议约定你与练途之间关于账号、训练计划、AI 教练、饮食记录和订阅服务的使用规则。请在使用前完整阅读。",
    sections: [
      ["1. 服务内容与边界", "练途提供训练计划、动作说明、训练记录、饮食估算和 AI 对话等功能。这些内容用于一般健身与生活方式参考，不构成医疗诊断、治疗或营养处方。出现胸痛、眩晕、呼吸困难、急性损伤，或处于孕期、术后恢复期时，请先咨询医生。"],
      ["2. 账号注册与安全", "手机号验证通过，或使用微信/QQ 授权后，系统可能为你自动创建账号。请妥善保管验证码、密码与登录设备；发现异常登录时及时退出并修改密码。"],
      ["3. 订阅与自动续费", "练途 Pro 通过 Apple App Store 销售。价格、周期和试用条件以下单页面为准；订阅会自动续期，可在系统设置中取消。取消后，已付费周期内仍可使用 Pro 功能。"],
      ["4. AI 生成内容", "AI 计划与建议基于你填写的档案、器械、训练记录和对话内容生成，可能存在不准确或不适用的情况。请根据身体反应调整，不要将 AI 输出作为医疗依据。"],
      ["5. 使用规范", "不得利用本服务发布违法信息、侵犯他人权益、干扰系统运行或绕过安全限制。因违规导致的账号限制或终止，由用户承担相应责任。"],
      ["6. 知识产权", "App 界面、文本、图形和训练内容的知识产权归练途或授权方所有。未经许可不得复制、出售或用于商业培训。你上传的照片仅用于你主动选择的对应功能。"],
      ["7. 服务变更与终止", "我们可能因产品升级、合规要求或不可抗力调整服务，重大变更会通过 App 内提示。你可以随时停止使用。账号注销与数据删除需由运营方按法律法规和账号安全流程处理。"],
      ["8. 协议更新与联系", "协议更新后会在登录页或 App 内公示。继续使用视为接受更新内容；如不同意，可停止使用。对协议有疑问，可通过 App 内反馈渠道联系我们。"]
    ]
  },
  privacy: {
    title: "隐私政策",
    updated: "2026 年 10 月 25 日",
    intro: "练途重视你的个人信息与身体数据。本政策说明我们收集哪些信息、为什么收集、如何保护，以及你可以如何管理这些信息。",
    sections: [
      ["1. 我们收集的信息", "账号信息（手机号、微信/QQ 标识）；你主动填写的性别、年龄、身高、体重、围度、目标与训练偏好；训练记录、饮食记录、对话内容和器械库；你上传的器械照片、体型照片和食物照片；以及用于安全和故障排查的设备与日志信息。"],
      ["2. 敏感个人信息", "体型照片、食物照片、健康与身体数据可能属于敏感个人信息。我们仅在你主动使用对应功能并同意后处理；你可以拒绝或撤回同意，但相关功能将无法使用。"],
      ["3. 使用目的", "用于生成和调整训练/饮食计划、记录与复盘、提供 AI 教练回答、器械识别、保障账号与服务安全、处理订阅和客服问题。我们不会将健康数据用于广告定向。"],
      ["4. 存储与安全", "数据存储在中华人民共和国境内。我们采用访问控制、传输保护、权限隔离和日志审计等措施，仅在实现目的所需期限内保留；注销或删除后，按法律要求处理。"],
      ["5. 共享与委托处理", "我们不会出售个人信息。为提供短信验证、云托管、AI 推理、支付与登录服务，可能委托合作方处理必要信息，并通过协议约束其用途。除法律要求或取得单独同意外，不向第三方提供。"],
      ["6. 设备权限", "相机和相册用于器械、体型与食物照片；通知用于训练提醒；HealthKit 用于读写你授权的训练与体重数据。你可以在系统设置中随时关闭这些权限。"],
      ["7. 你的权利", "你可以访问、更正和导出个人数据，或撤回授权。账号注销与数据删除需由运营方按法律法规及账号安全流程处理。"],
      ["8. 未成年人保护", "未满 14 周岁的用户应在监护人同意和指导下使用；未满 18 周岁的用户应在监护人知情下使用订阅与训练功能。"],
      ["9. 更新与联系", "隐私政策更新会在 App 内公示。对个人信息处理有疑问，可通过 App 内反馈渠道联系我们。"]
    ]
  },
  ai: {
    title: "生成式 AI 服务说明",
    updated: "2026 年 10 月 25 日",
    intro: "本说明介绍练途中的生成式 AI 能力、内容边界和数据使用方式。",
    sections: [
      ["1. 服务说明", "生成式 AI 用于训练计划、动作替代、饮食建议和教练对话。当前版本可能使用规则引擎或模拟结果，正式模型接入后会更新本说明。"],
      ["2. 不提供医疗诊断", "AI 输出不能替代医生、康复师或营养师的专业意见。出现疼痛、眩晕、胸闷、呼吸困难，或处于孕期、术后恢复期时，请先就医或咨询专业人士。"],
      ["3. 内容局限", "AI 可能产生不准确、不完整或不适用的建议。请结合器械条件、动作能力和身体反应判断，必要时降低负荷或停止训练。"],
      ["4. 数据与模型", "AI 回答会使用你主动提供的档案、训练、饮食和对话信息。我们不会将你的对话用于公开展示；如使用第三方模型服务，将按最小必要原则传输并约束用途。"],
      ["5. 备案与公示", "正式上线前将完成适用的生成式人工智能服务与算法备案，并在 App 内公示模型提供方、备案信息和处理规则。"],
      ["6. 安全反馈", "如果你发现错误、歧视性内容或其他安全问题，请通过 App 内反馈渠道告诉我们，我们会核查并改进。"]
    ]
  }
};

function legalModal() {
  const doc = LEGAL_DOCS[state.legalDoc];
  if (!doc) return "";
  return `
    <div class="modal-backdrop" onclick="if(event.target===this)app.closeLegal()">
      <div class="legal-sheet" role="dialog" aria-modal="true" aria-label="${doc.title}">
        <div class="legal-head">
          <div>
            <div class="tiny accent strong">练途 · 协议与隐私</div>
            <div class="h2" style="margin-top:3px">${doc.title}</div>
            <div class="tiny faint" style="margin-top:3px">更新日期：${doc.updated}</div>
          </div>
          <button class="icon-btn" onclick="app.closeLegal()" aria-label="关闭">✕</button>
        </div>
        <div class="legal-body">
          <p class="small muted" style="line-height:1.75;margin:0 0 16px">${doc.intro}</p>
          ${doc.sections.map(([title, body]) => `
            <section class="legal-section">
              <h3>${title}</h3>
              <p>${body}</p>
            </section>
          `).join("")}
          <div class="legal-note">本页为应用内公示文本。正式上线版本将在 App Store 页面与 App 内同步更新。</div>
        </div>
        <button class="btn btn-primary" style="margin-top:14px" onclick="app.closeLegal()">我知道了</button>
      </div>
    </div>
  `;
}

/* ---------------- Home ---------------- */

function home() {
  const day = todayDay();
  const targets = nutritionTargets();
  const totals = nutritionTotals();
  const weekSessions = state.sessions.filter((s) => s.thisWeek).length;
  const ratio = Math.min(100, Math.round((weekSessions / Math.max(1, state.profile.weeklyDays)) * 100));
  const preview = planAdjustmentPreview();
  const remainingKcal = Math.max(0, targets.kcal - Math.round(totals.kcal));
  const remainingProtein = Math.max(0, targets.protein - Math.round(totals.p));

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

        <div class="row gap12" style="margin:14px 0 10px;align-items:flex-end">
          <div class="grow"><div class="small strong">${day.exercises.length} 个</div><div class="tiny faint">动作</div></div>
          <div class="grow"><div class="small strong">${estimatedMinutes(day)} 分钟</div><div class="tiny faint">预计</div></div>
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
        <div class="between">
          <div>
            <div class="tiny accent strong">AI 复盘</div>
            <div class="h3" style="margin-top:3px">${state.plan.title}</div>
            <div class="tiny muted" style="margin-top:3px">第 ${state.plan.version} 版 · ${state.plan.days.length} 个训练日</div>
          </div>
          <span class="accent">↗</span>
        </div>
        <div class="row gap8" style="margin-top:10px">
          <div class="review-metric"><div class="tiny faint">本周完成</div><div class="small strong">${weekSessions}/${Math.max(1, state.profile.weeklyDays)} 次</div></div>
          <div class="review-metric"><div class="tiny faint">平均 RPE</div><div class="small strong">${preview.averageRPE ? preview.averageRPE.toFixed(1) : "—"}</div></div>
          <div class="review-metric"><div class="tiny faint">训练容量</div><div class="small strong">${state.sessions.filter((s) => s.thisWeek).reduce((sum, s) => sum + s.volume, 0).toLocaleString()} kg</div></div>
        </div>
        <div class="small strong" style="margin-top:10px">${weekSessions ? `这次复盘：${preview.headline}` : "先记录一次训练，复盘才有数据。"}</div>
        <div class="tiny muted" style="margin-top:4px;line-height:1.6">${weekSessions ? preview.detail : "完成率、平均 RPE 与训练容量会一起参与判断。"}</div>
        <button class="link" style="margin-top:10px" onclick="app.adjustPlan()">✦ 让 AI 复盘并调整 →</button>
      </div>

      <div class="card">
        <div class="between" style="margin-bottom:10px">
          <div class="h3">本周完成</div>
          <div class="small muted">${weekSessions}/${state.profile.weeklyDays} 次</div>
        </div>
        <div class="bar"><span style="width:${ratio}%"></span></div>
        <div class="row gap12" style="margin-top:12px">
          <div class="grow"><div class="h3">${state.sessions.length}</div><div class="tiny faint">累计训练</div></div>
          <div class="grow"><div class="h3">18,400</div><div class="tiny faint">总容量 kg</div></div>
          <div class="grow"><div class="h3">${weekSessions}</div><div class="tiny faint">本周</div></div>
        </div>
      </div>

      <div class="card nutrition-card" onclick="app.go('nutrition')">
        <div class="nutrition-icon">🍽</div>
        <div class="grow">
          <div class="h3">今日饮食</div>
          <div class="tiny muted" style="margin-top:3px">${remainingKcal > 0 ? `还可摄入 ${remainingKcal} kcal · 蛋白质还差 ${remainingProtein}g` : `已达到今日热量目标 · 蛋白质还差 ${remainingProtein}g`}</div>
        </div>
        <div class="faint">›</div>
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
  const preview = planAdjustmentPreview();
  return `
    <div class="stack">
      <div class="between">
        <div>
          <h1 class="h1">训练计划</h1>
          <div class="tiny muted" style="margin-top:4px">第 ${state.plan.version} 版 · 4 周</div>
        </div>
      </div>

      <div class="card">
        <div class="between">
          <div class="badge">当前计划</div>
          <button class="link" style="color:var(--muted)" onclick="app.regeneratePlan()">重新生成</button>
        </div>
        <div class="h2" style="margin-top:9px">${state.plan.title}</div>
        <div class="tiny muted" style="margin-top:4px">共 ${state.plan.days.length} 个训练日 · 当前第 ${state.selectedWeek} 周 · 本周完成 ${preview.completed}/${Math.max(1, state.profile.weeklyDays)}</div>
        <div class="tiny accent" style="margin-top:8px;line-height:1.6">${preview.completed ? `复盘预告：${preview.detail}` : "完成一次训练后，这里会显示具体的复盘调整。"}</div>
        <button class="btn btn-primary" style="margin-top:12px" onclick="app.adjustPlan()">✦ 复盘并调整</button>
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
  const skills = {
    trainer: {
      label: "健身教练",
      icon: "◎",
      desc: "训练安排、动作替代和负荷调整",
      starters: ["今天练什么？", "没有器械怎么替代？", "训练后很酸正常吗？", "下次怎么加重量？"],
      placeholder: "问问训练、动作或计划…"
    },
    rehab: {
      label: "康复师",
      icon: "✚",
      desc: "疼痛分级、恢复期活动和就医提示",
      starters: ["膝盖不舒服还能练吗？", "训练后腰痛怎么恢复？", "扭伤后多久能训练？", "恢复期能做什么动作？"],
      placeholder: "描述疼痛位置、时间和程度…"
    },
    nutrition: {
      label: "营养师",
      icon: "◇",
      desc: "热量、蛋白质和膳食结构建议",
      starters: ["每天吃多少蛋白质？", "减脂怎么安排三餐？", "训练后吃什么？", "外卖怎么选更健康？"],
      placeholder: "问问热量、蛋白质或饮食安排…"
    }
  };
  const skill = skills[state.coachSkill] || skills.trainer;
  const suggestions = skill.starters.slice(0, 3);
  const weekSessions = state.sessions.filter((s) => s.thisWeek).length;
  const ratio = Math.min(100, Math.round((weekSessions / Math.max(1, state.profile.weeklyDays)) * 100));
  return `
    <div class="chat-screen">
      <div class="chat-head">
        <h1 class="h1">AI 教练</h1>
        <div class="tiny muted" style="margin-top:4px">健身教练 · 康复师 · 营养师</div>
      </div>

      <div class="coach-skill-bar">
        ${Object.entries(skills).map(([key, item]) => `
          <button class="coach-skill ${state.coachSkill === key ? "active" : ""}" onclick="app.setCoachSkill('${key}')">
            <span>${item.icon}</span>${item.label}
          </button>
        `).join("")}
      </div>

      <div class="chat-scroll" id="chat-scroll">
        ${state.chats.length === 0 ? `
          <div class="card" style="margin-top:12px">
            <div class="row gap10" style="margin-bottom:10px">
              <div class="coach-avatar">AI</div>
              <div>
                <div class="h3">${skill.label}在线</div>
                <div class="tiny faint" style="margin-top:2px">${skill.desc}</div>
              </div>
            </div>
            <div class="small muted" style="line-height:1.65">涉及疼痛、孕期、术后等情况，会建议你就医，而不是继续加练。</div>
          </div>

          ${state.pro ? "" : `
            <div class="card tight" style="margin-top:12px;cursor:pointer" onclick="app.openPaywall()">
              <div class="between">
                <div>
                  <div class="small strong">解锁 DeepSeek AI ${skill.label}</div>
                  <div class="tiny faint" style="margin-top:3px">当前使用本地规则建议；Pro 会员可使用完整 AI Skill。</div>
                </div>
                <span class="accent">›</span>
              </div>
            </div>
          `}

          <div class="h3" style="margin:16px 2px 2px">快速开始</div>
          <div class="coach-starters">
            ${skill.starters.map((text) => `<button class="suggestion-card" onclick="app.sendChat('${text}')">${text}</button>`).join("")}
          </div>

          <div class="card tight" style="margin-top:12px">
            <div class="between">
              <div class="small strong">本周状态</div>
              <div class="tiny faint">第 ${state.selectedWeek} 周</div>
            </div>
            <div class="tiny muted" style="margin-top:5px">${weekSessions}/${state.profile.weeklyDays} 练 · 完成率 ${ratio}%</div>
            <button class="link" style="margin-top:9px" onclick="app.sendChat('帮我复盘一下本周训练，接下来应该怎么调整？')">让教练复盘本周 →</button>
          </div>
        ` : state.chats.map((message) => `
          <div class="chat-row ${message.role}">
            <div class="bubble ${message.role} ${message.safety ? "safety" : ""}">
              ${message.safety ? '<span class="safety-label">⚠ 需要就医评估</span>' : ""}
              ${esc(message.text)}
            </div>
          </div>
        `).join("")}

        ${state.chats.length ? `
          <div class="suggestions" style="margin-top:10px">
            ${suggestions.map((text) => `<button class="suggestion" onclick="app.sendChat('${text.replace(/'/g, "\\'")}')">${text}</button>`).join("")}
          </div>
        ` : ""}
      </div>

      <div class="composer">
        <div class="composer-row">
          <input id="chat-input" type="text" placeholder="${skill.placeholder}" onkeydown="if(event.key==='Enter'){app.sendChat()}">
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
      ${headerBack("添加器械", "app.tab('equipment')")}
      <div>
        <h1 class="h1">拍一下器械</h1>
        <div class="tiny muted" style="margin-top:4px">马上知道怎么用</div>
      </div>

      <div class="row gap8">
        <button class="btn btn-secondary btn-sm grow" onclick="app.equipmentSearchOpen()">🔍 搜索</button>
        <button class="btn btn-secondary btn-sm grow" onclick="app.mockPhoto('拍照')">📷 拍照</button>
        <button class="btn btn-secondary btn-sm grow" onclick="app.mockPhoto('相册')">🖼 相册</button>
      </div>

      <div class="photo-area ${equipment.scanned ? "filled" : ""}">
        <div class="big">📷</div>
        <div class="small">${equipment.scanned ? "已拍摄：高位下拉器械" : "拍一张器械照片"}</div>
        <div class="tiny">${equipment.scanned ? "点击下方识别器械" : "支持常见固定器械、绳索、杠铃与哑铃"}</div>
      </div>

      <button class="btn btn-primary" onclick="app.scanEquipment()">识别器械</button>

      ${equipment.candidates.length ? `
        <div class="card">
          <div class="h3">识别结果</div>
          <div class="tiny muted" style="margin-top:3px">保存后返回上一页查看已添加的器械</div>
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

      <div class="tiny faint" style="line-height:1.6">照片只用于识别，不保存。识别结果仅供选择动作，具体器械使用请以现场说明为准。</div>
    </div>
  `;
}

function equipGlyph(item) {
  const muscle = item.muscle || "";
  if (muscle.includes("有氧")) return "🏃";
  if (muscle.includes("腿") || muscle.includes("臀")) return "🦵";
  if (muscle.includes("背")) return "🏋️";
  if (muscle.includes("肩") || muscle.includes("手臂")) return "💪";
  if (muscle.includes("核心")) return "🧘";
  const map = {
    "固定器械": "⚙️",
    "哑铃": "💪",
    "杠铃": "🏋️",
    "有氧": "🏃",
    "绳索": "🪢",
    "徒手": "🤸"
  };
  return map[item.equip] || "🏋️";
}

function equipmentLibraryScreen() {
  const items = state.equipmentLibrary;
  return `
    <div class="stack">
      <div>
        <h1 class="h1">器械</h1>
        <div class="tiny muted" style="margin-top:4px">已添加的器械 · 教学视频与 AI 计划</div>
      </div>

      <div class="card nutrition-card" onclick="app.equipmentAddOpen()">
        <div class="nutrition-icon">＋</div>
        <div class="grow">
          <div class="h3">添加器械</div>
          <div class="tiny muted" style="margin-top:3px">搜索、拍照或相册录入</div>
        </div>
        <div class="faint">›</div>
      </div>

      <div class="between" style="padding:2px 2px 0">
        <div class="h3">已添加的器械</div>
        <div class="tiny faint">${items.length} 件</div>
      </div>

      ${items.length === 0 ? `
        <div class="card">
          <div class="h3">器械库还是空的</div>
          <div class="tiny muted" style="margin-top:5px">点上方「添加器械」搜索、拍照或从相册上传第一件器械。</div>
        </div>
      ` : `
        <div class="equipment-grid">
          ${items.map((item) => `
            <div class="equipment-tile" onclick="app.openEquipItem('${item.id}')">
              <div class="equipment-tile-image">${equipGlyph(item)}</div>
              <div class="equipment-tile-name">${esc(item.name)}</div>
              <div class="equipment-tile-meta">${item.muscle} · ${item.equip}</div>
              <div class="equipment-tile-video ${item.video ? "ready" : ""}">
                ${item.video ? "教学视频" : "视频准备中"}
              </div>
            </div>
          `).join("")}
        </div>
      `}

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

      <div class="tiny faint" style="line-height:1.6">器械库会作为 AI 生成计划的可用器械来源。删除器械不会删除历史训练记录。</div>
    </div>
  `;
}

function equipmentSearchMatches(query) {
  const text = String(query || "").trim();
  return Object.keys(EX).filter((slug) => {
    if (!text) return true;
    return EX[slug].name.includes(text) || EX[slug].muscle.includes(text) || EX[slug].equip.includes(text);
  });
}

function equipmentSearchResults(query) {
  const list = equipmentSearchMatches(query).slice(0, 60);

  if (!list.length) {
    return `<div class="card"><div class="h3">没有找到</div><div class="tiny muted" style="margin-top:5px">换个关键词，或手动填写自定义器械。</div></div>`;
  }

  return list.map((slug) => {
    const added = state.equipmentLibrary.some((entry) => entry.slug === slug);
    return `
      <div class="card tight">
        <div class="between">
          <div>
            <div class="small strong">${esc(EX[slug].name)}</div>
            <div class="tiny faint" style="margin-top:2px">${EX[slug].muscle} · ${EX[slug].equip}</div>
          </div>
          ${added
            ? `<span class="tiny faint">已添加</span>`
            : `<button class="link" onclick="app.equipmentSearchAdd('${slug}')">＋ 添加</button>`}
        </div>
      </div>
    `;
  }).join("");
}

function equipmentSearchScreen() {
  const results = equipmentSearchMatches(state.equipSearchQuery);

  return `
    <div class="stack">
      ${headerBack("搜索器械", "app.equipmentAddOpen()")}
      <div class="card">
        <div class="tiny muted">输入器械或动作名称，选中后直接加入器械库，并自动带上教学视频。</div>
        <input id="equipment-search-input" type="text" placeholder="例如：高位下拉、腿举" value="${esc(state.equipSearchQuery)}" oninput="app.equipmentSearchInput(this.value)" style="margin-top:10px" autofocus>
      </div>
      <div class="between">
        <div class="h3">搜索结果</div>
        <div class="tiny faint" id="equipment-search-count">${results.length} 个</div>
      </div>
      <div id="equipment-search-results" style="display:grid;gap:14px">${equipmentSearchResults(state.equipSearchQuery)}</div>
      <div class="tiny faint" style="line-height:1.6">找不到自定义器械？返回后可以在真实 App 里用「手动填写」补充名称、视频和备注。</div>
    </div>
  `;
}

function equipmentPhotoScreen() {
  const source = state.equipPhotoSource;
  return `
    <div class="stack">
      ${headerBack("添加器械", "app.equipmentAddOpen()")}
      <div class="card">
        <div class="h3">${source === "拍照" ? "拍一张器械照片" : "选择一张器械照片"}</div>
        <div class="tiny muted" style="margin-top:5px">支持常见固定器械、绳索、杠铃与哑铃。照片只用于识别，不保存。</div>
      </div>
      <div class="photo-area filled">
        <div class="big">🏋️</div>
        <div class="small">已选择照片（预览模拟）</div>
        <div class="tiny">${source} · 器械照片</div>
      </div>
      <div class="row gap8">
        <button class="btn btn-secondary btn-sm grow" onclick="app.equipmentPhotoOpen('拍照')">重新拍照</button>
        <button class="btn btn-secondary btn-sm grow" onclick="app.equipmentPhotoOpen('相册')">重新选择</button>
      </div>
      <button class="btn btn-primary" onclick="app.equipmentPhotoSave()">识别并添加到器械库</button>
      <div class="tiny faint" style="line-height:1.6">真实 App 会调用视觉识别或本地动作库，确认后再保存到器械库。</div>
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
        <div style="font-size:40px;margin-bottom:8px">${equipGlyph(item)}</div>
        <div class="h2">${esc(item.name)}</div>
        <div class="small accent" style="margin-top:4px">${item.muscle} · ${item.equip}</div>
        ${item.notes ? `<div class="tiny muted" style="margin-top:10px">${esc(item.notes)}</div>` : ""}
      </div>

      <div class="card">
        <div class="row gap8" style="margin-bottom:8px"><span class="accent">▶</span><span class="h3">教学视频</span></div>
        ${item.video
          ? `<div class="tiny muted">已由练途动作库配置，真实 App 会直接播放。</div>
             <div style="height:150px;border-radius:14px;margin-top:10px;background:linear-gradient(135deg,#1a2028,#0d1016);display:grid;place-items:center;color:var(--faint)">视频占位</div>`
          : `<div class="tiny muted" style="line-height:1.6">教学视频准备中。这件器械的示范视频尚未上线，可先向 AI 教练询问动作要点。</div>`}
      </div>

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
  return `
    <div class="stack">
      <div class="between" style="align-items:flex-start">
        <div>
          <h1 class="h1">我的</h1>
          <div class="tiny muted" style="margin-top:4px">档案、身体数据与训练工具</div>
        </div>
        ${settingsButton()}
      </div>

      <div class="section-kicker">账户与会员</div>

      <div class="card" style="padding:0">
        <div class="list-row" style="padding:16px;cursor:pointer;align-items:center" onclick="app.openProfileEdit()">
          <div class="nutrition-icon" style="font-size:18px">${esc(p.name.slice(0, 1))}</div>
          <div class="grow">
            <div class="h3">${esc(p.name)}</div>
            <div class="tiny muted" style="margin-top:3px">${p.goal} · ${p.experience} · 每周 ${p.weeklyDays} 练</div>
          </div>
          <div class="row gap6" style="flex-shrink:0;white-space:nowrap">
            <span class="tiny accent strong">编辑资料</span>
            <span class="faint">›</span>
          </div>
        </div>

        <div style="height:1px;background:var(--stroke);margin:0 16px"></div>

        <div class="list-row" style="padding:14px 16px;cursor:pointer;align-items:center" onclick="app.openPaywall()">
          <div class="nutrition-icon" style="color:var(--warning);background:rgba(250,184,77,.12)">♛</div>
          <div class="grow">
            <div class="small strong">练途 Pro</div>
            <div class="tiny muted" style="margin-top:2px">${state.pro ? "已订阅 · 所有功能已解锁" : "AI 计划、教练与器械识别"}</div>
          </div>
          <div class="accent small">${state.pro ? "管理会员" : "开通会员"} ›</div>
        </div>
      </div>

      <div class="section-kicker">身体与目标</div>

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
          <div class="metric"><div class="value">18,400 kg</div><div class="label">总容量</div></div>
        </div>
      </div>

      <div class="card">
        <div class="between"><div class="h3">当前目标</div><span class="badge">${p.goal}</span></div>
        <div class="between" style="margin-top:10px"><span class="small muted">目标体重</span><span class="small strong">${p.targetWeight} kg</span></div>
        <div class="between" style="margin-top:7px"><span class="small muted">目标腰围</span><span class="small strong">${p.targetWaist} cm</span></div>
        <div class="tiny faint" style="margin-top:8px">减重建议不超过 0.5kg/周，不追求极端速度。</div>
      </div>

      <div class="section-kicker">训练工具</div>

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

    </div>
  `;
}

/* ---------------- Profile edit ---------------- */

function profileDraftSegmented(key, options) {
  const draft = state.profileDraft;
  return `<div class="seg">${options.map((option) => {
    const active = String(draft[key]) === String(option) ? "active" : "";
    return `<button class="${active}" data-draft-seg="${key}" data-value="${option}" onclick="app.profileDraftSelect('${key}', ${JSON.stringify(option)})">${option}</button>`;
  }).join("")}</div>`;
}

function profileEditScreen() {
  const draft = state.profileDraft;
  if (!draft) return profileScreen();

  return `
    <div class="stack">
      ${headerBack("编辑资料", "app.closeProfileEdit()")}

      <div class="card">
        <div class="h3">基础信息</div>
        <div class="tiny muted" style="margin-top:3px;margin-bottom:14px">用于计算热量与训练负荷</div>

        <div class="form-label">怎么称呼你</div>
        <input type="text" value="${esc(draft.name)}" placeholder="例如：小林" oninput="app.profileDraftInput('name', this.value)">

        <div class="form-label" style="margin-top:14px">性别</div>
        ${profileDraftSegmented("sex", ["男", "女"])}

        ${profileDraftRangeRow("age", "年龄", "岁", 18, 60, 1)}
        ${profileDraftRangeRow("height", "身高", "cm", 140, 210, 1)}
      </div>

      <div class="card">
        <div class="h3">身体数据</div>
        <div class="tiny muted" style="margin-top:3px;margin-bottom:12px">三围选填，用于追踪体型变化</div>
        ${profileDraftRangeRow("weight", "体重", "kg", 40, 150, 0.5)}
        ${profileDraftRangeRow("waist", "腰围", "cm", 50, 150, 1)}
        ${profileDraftRangeRow("chest", "胸围", "cm", 60, 150, 1)}
        ${profileDraftRangeRow("hip", "臀围", "cm", 60, 150, 1)}
        <div class="row between" style="margin-top:12px">
          <span class="small muted">BMI</span>
          <span class="small strong" id="draft-bmi">${bmiText(draft)}</span>
        </div>
      </div>

      <div class="card">
        <div class="h3">可用器械</div>
        <div class="tiny muted" style="margin-top:3px;margin-bottom:12px">只安排你能用上的动作</div>
        <div class="chips">
          ${["徒手", "哑铃", "杠铃", "固定器械", "绳索", "弹力带", "壶铃"].map((item) => `
            <button class="chip ${draft.equipment.includes(item) ? "active" : ""}" data-equip="${item}" onclick="app.profileDraftToggleEquip('${item}')">${item}</button>
          `).join("")}
        </div>
      </div>

      <div class="card">
        <div class="h3">训练安排</div>
        <div class="tiny muted" style="margin-top:3px;margin-bottom:12px">之后可以随时调整</div>
        <div class="form-label">每周训练</div>
        ${profileDraftSegmented("weeklyDays", [2, 3, 4, 5])}
        <div class="form-label" style="margin-top:14px">单次时长</div>
        ${profileDraftSegmented("minutes", [30, 45, 60, 90])}
        <div class="form-label" style="margin-top:14px">训练经验</div>
        ${profileDraftSegmented("experience", ["新手", "有基础", "进阶"])}
      </div>

      <div class="card">
        <div class="h3">你的目标</div>
        <div class="tiny muted" style="margin-top:3px;margin-bottom:12px">计划会围绕目标调整组次与负荷</div>
        <div class="goal-grid">
          ${[
            ["减脂", "控制热量，保留肌肉"],
            ["增肌", "渐进超负荷，稳定增重"],
            ["重塑体型", "体重变化不大，改善围度"],
            ["提升体能", "提高心肺与耐力"]
          ].map(([goal, desc]) => `
            <button class="goal ${draft.goal === goal ? "active" : ""}" data-draft-goal="${goal}" onclick="app.profileDraftSelect('goal', '${goal}')">
              <strong>${goal}</strong><span>${desc}</span>
            </button>
          `).join("")}
        </div>
        <div id="profile-target-fields" style="${draft.goal === "提升体能" ? "display:none" : ""}">
          ${profileDraftRangeRow("targetWeight", "目标体重", "kg", 40, 120, 0.5)}
          ${profileDraftRangeRow("targetWaist", "目标腰围", "cm", 50, 120, 1)}
        </div>
      </div>

      <div class="card tight">
        <div class="tiny muted" style="line-height:1.6">保存资料不会自动覆盖当前训练计划。如需让计划适配新的目标或器械，可回到「计划」页让 AI 复盘调整。</div>
      </div>

      <button class="btn btn-primary" onclick="app.saveProfileEdit()">保存资料</button>
      <button class="btn btn-ghost" onclick="app.closeProfileEdit()">取消并返回</button>
    </div>
  `;
}

/* ---------------- Settings ---------------- */

function settingsScreen() {
  const phone = state.authPhone || "13800138000";
  const maskedPhone = phone.length === 11 ? `${phone.slice(0, 3)}****${phone.slice(-4)}` : "已登录";

  return `
    <div class="stack">
      ${headerBack("设置", "app.closeSettings()")}

      <div class="card">
        <div class="h3">账号与安全</div>
        <div class="tiny muted" style="margin-top:3px">登录账号 · ${esc(maskedPhone)}</div>
      </div>

      <div class="section-kicker">训练设置</div>

      <div class="card">
        <div class="between"><div class="h3">训练提醒</div><span class="tiny faint">每周重复</span></div>
        <div class="row gap8" style="margin-top:10px">
          <input type="time" value="${state.reminder}" id="reminder-time">
          <button class="btn btn-secondary btn-sm" style="flex-shrink:0;white-space:nowrap" onclick="app.saveReminder()">保存</button>
        </div>
        <div class="tiny faint" style="margin-top:8px">iOS 静音和专注模式可能影响提醒，请在系统设置中允许通知。</div>
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

      <div class="card">
        <div class="between">
          <div class="h3">训练偏好</div>
          <div class="tiny faint">${state.disliked.length} 个</div>
        </div>
        <div class="tiny muted" style="margin-top:6px">删除过的动作会被记住，下次生成尽量避开。</div>
        ${state.disliked.length ? `<button class="btn btn-secondary" style="margin-top:10px" onclick="app.clearPreferences()">清除训练偏好</button>` : ""}
      </div>

      <div class="section-kicker">数据与隐私</div>

      <div class="card">
        <div class="list-row" onclick="app.openLegal('privacy')"><span class="grow small">隐私政策</span><span class="faint">›</span></div>
        <div class="list-row" onclick="app.openLegal('terms')"><span class="grow small">用户协议</span><span class="faint">›</span></div>
        <div class="list-row" onclick="app.exportData()"><span class="grow small">导出我的数据</span><span class="faint">›</span></div>
        <div class="list-row" onclick="app.openLegal('ai')"><span class="grow small">生成式 AI 备案信息</span><span class="faint">›</span></div>
        <div class="tiny faint" style="margin-top:8px">本产品不提供医疗诊断。孕期、术后、心血管疾病或关节急性疼痛，请先咨询医生。</div>
        <div class="tiny faint" style="margin-top:6px">练途 Web Preview · v0.1</div>
      </div>

      <div class="section-kicker">账号操作</div>

      <div class="card">
        <button class="btn btn-danger" onclick="app.previewLogout()">退出登录</button>
        <div class="tiny faint" style="margin-top:9px;text-align:center">退出登录不会删除训练计划、训练记录或身体数据。</div>
      </div>
    </div>
  `;
}

/* ---------------- Nutrition ---------------- */

function suggestedMealName() {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 11) return "早餐";
  if (hour >= 11 && hour < 15) return "午餐";
  if (hour >= 17 && hour < 21) return "晚餐";
  return "加餐";
}

function nutritionScreen() {
  const targets = nutritionTargets();
  const totals = nutritionTotals();
  const ratio = Math.min(100, Math.round((totals.kcal / Math.max(1, targets.kcal)) * 100));
  const remainingKcal = Math.max(0, targets.kcal - Math.round(totals.kcal));
  const remainingProtein = Math.max(0, targets.protein - Math.round(totals.p));
  const meals = ["早餐", "午餐", "晚餐", "加餐"];

  return `
    <div class="stack">
      ${headerBack("饮食计划", "app.tab('home')")}
      <div class="card">
        <div class="tiny muted">今日热量目标</div>
        <div class="kcal-hero" style="margin-top:4px"><span class="num">${targets.kcal}</span><span class="unit">kcal</span></div>
        <div class="tiny accent" style="margin-top:6px;font-weight:600">${remainingKcal > 0 ? `还可摄入 ${remainingKcal} kcal · 蛋白质还差 ${remainingProtein}g` : `已达到今日热量目标 · 蛋白质还差 ${remainingProtein}g`}</div>
        <div class="tiny faint" style="margin-top:4px">按${state.profile.goal}目标与每周 ${state.profile.weeklyDays} 练估算，结果是区间。</div>
      </div>

      <div class="card nutrition-card" onclick="app.openFoodPhoto()">
        <div class="nutrition-icon">📷</div>
        <div class="grow">
          <div class="small strong">拍照识别饮食</div>
          <div class="tiny muted" style="margin-top:3px">拍一餐，估算热量与三大营养素</div>
        </div>
        <div class="tiny accent">›</div>
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

        ${state.foodLogs.length === 0 ? `<div class="tiny muted" style="margin-top:10px">还没有记录。吃了什么就记什么，奶茶、火锅、螺蛳粉都可以。</div>` : ""}
        <button class="btn btn-secondary" style="margin-top:12px" onclick="app.openFoodAdd('${suggestedMealName()}')">＋ 添加食物</button>
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
      <div class="tiny faint" style="line-height:1.6;margin-top:-4px">只是参考，不是必须照着吃；外食也可以正常记录。</div>
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
        <button class="btn btn-secondary" style="margin-top:10px" onclick="app.mockMeituan()">在美团找外卖 ↗</button>
      </div>

      <div class="tiny faint" style="line-height:1.6">饮食建议为估算，不构成医疗或疾病饮食处方。孕期、术后、糖尿病、肾病等请咨询医生或营养师。</div>
    </div>
  `;
}

const FOOD_PHOTO_COMBOS = [
  [["米饭", 150], ["鸡胸肉", 150], ["西兰花", 150]],
  [["燕麦（干）", 60], ["鸡蛋", 100], ["牛奶", 250], ["香蕉", 100]],
  [["糙米饭", 150], ["三文鱼", 120], ["番茄", 80]],
  [["全麦面包", 80], ["鸡蛋", 100], ["香蕉", 100]],
  [["米饭", 180], ["豆腐", 150], ["西兰花", 180]],
  [["螺蛳粉", 600], ["奶茶", 500]],
  [["炸鸡", 200], ["可乐", 500]],
  [["麻辣香锅", 400], ["米饭", 150]]
];

function foodPhotoMockItems() {
  const combo = FOOD_PHOTO_COMBOS[state.foodPhotoItems.length % FOOD_PHOTO_COMBOS.length];
  return combo.map(([name, grams], index) => {
    const food = FOODS.find((item) => item.name === name) || FOODS[0];
    return {
      id: `fp-${Date.now()}-${index}`,
      name: food.name,
      grams,
      kcalPer100g: food.kcal,
      pPer100g: food.p,
      cPer100g: food.c,
      fPer100g: food.f,
      confidence: Math.max(0.55, 0.91 - index * 0.07),
      selected: true
    };
  });
}

function foodPhotoTotals(items = state.foodPhotoItems) {
  return items.filter((item) => item.selected).reduce((total, item) => {
    const factor = item.grams / 100;
    total.kcal += item.kcalPer100g * factor;
    total.p += item.pPer100g * factor;
    total.c += item.cPer100g * factor;
    total.f += item.fPer100g * factor;
    return total;
  }, { kcal: 0, p: 0, c: 0, f: 0 });
}

function foodPhotoScreen() {
  const items = state.foodPhotoItems;
  const totals = foodPhotoTotals(items);
  const meals = ["早餐", "午餐", "晚餐", "加餐"];

  return `
    <div class="stack">
      ${headerBack("拍照识别饮食", "app.go('nutrition')")}

      <div class="card">
        <div class="h2">拍一张这餐的照片</div>
        <div class="tiny muted" style="margin-top:6px;line-height:1.6">
          自动估算热量和营养。照片只用于本次识别，不保存；结果可以修改后加入今日饮食。
        </div>
        <div class="tiny accent" style="margin-top:6px;line-height:1.6">
          螺蛳粉、火锅、奶茶也可以识别。这里只估算热量，不评价食物好坏。
        </div>
      </div>

      ${state.foodPhotoImage ? `
        <div class="card" style="padding:0;overflow:hidden">
          <div style="height:220px;background:linear-gradient(145deg,#5b4632 0%,#2d392e 55%,#151b16 100%);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px">
            <div style="font-size:64px;filter:drop-shadow(0 8px 16px rgba(0,0,0,.35))">🍱</div>
            <div class="tiny muted">已选择照片（预览模拟）</div>
          </div>
        </div>
      ` : `
        <div style="height:220px;border:1px dashed var(--stroke);border-radius:18px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;background:var(--surface)">
          <div style="font-size:34px">🍽</div>
          <div class="small strong">拍照或选择一张餐食照片</div>
          <div class="tiny faint">尽量俯拍，让食物完整进入画面</div>
        </div>
      `}

      <div class="row gap8">
        <button class="btn btn-secondary grow" onclick="app.foodPhotoTake()">📷 拍照</button>
        <button class="btn btn-secondary grow" onclick="app.foodPhotoTake()">🖼 相册</button>
      </div>

      <div class="card">
        <div class="tiny muted">这是哪一餐？</div>
        <div class="seg" style="margin-top:8px">
          ${meals.map((meal) => `
            <button class="${state.foodPhotoMeal === meal ? "active" : ""}" onclick="app.foodPhotoMeal('${meal}')">${meal}</button>
          `).join("")}
        </div>
      </div>

      <button class="btn btn-primary" onclick="app.foodPhotoAnalyze()" ${state.foodPhotoImage ? "" : "disabled"}>
        识别这餐并计算热量
      </button>

      ${items.length ? `
        <div class="card">
          <div class="between">
            <div>
              <div class="h3">识别结果</div>
              <div class="tiny faint">勾选实际吃下的食物，拖动份量</div>
            </div>
            <div class="tiny accent">参考置信度 ${Math.round(state.foodPhotoConfidence * 100)}%</div>
          </div>

          ${items.map((item, index) => {
            const kcal = Math.round(item.grams * item.kcalPer100g / 100);
            const p = Math.round(item.grams * item.pPer100g / 100);
            const c = Math.round(item.grams * item.cPer100g / 100);
            const f = Math.round(item.grams * item.fPer100g / 100);
            return `
              <div class="card tight" style="margin-top:10px;opacity:${item.selected ? 1 : 0.45}">
                <div class="between">
                  <label class="row gap8" style="cursor:pointer">
                    <input type="checkbox" ${item.selected ? "checked" : ""} onchange="app.foodPhotoToggle(${index}, this.checked)">
                    <span class="small strong">${item.name}</span>
                  </label>
                  <span class="tiny accent" id="food-photo-kcal-${index}">${kcal} kcal</span>
                </div>
                <div class="row gap8" style="margin-top:8px">
                  <input type="range" min="10" max="2000" step="10" value="${item.grams}" oninput="app.foodPhotoGrams(${index}, this.value)" style="flex:1;accent-color:var(--accent)">
                  <span class="tiny" id="food-photo-grams-${index}" style="width:52px;text-align:right">${item.grams} g</span>
                </div>
                <div class="tiny faint" id="food-photo-macros-${index}">P ${p}g · C ${c}g · F ${f}g</div>
              </div>
            `;
          }).join("")}

          <div class="card tight" style="margin-top:10px">
            <div class="between">
              <span class="small strong">合计</span>
              <span class="h3 accent" id="food-photo-total">${Math.round(totals.kcal)} kcal</span>
            </div>
            <div class="row gap8" style="margin-top:8px;flex-wrap:wrap">
              <span class="tiny muted">蛋白质 <span id="food-photo-p">${Math.round(totals.p)}</span>g</span>
              <span class="tiny muted">碳水 <span id="food-photo-c">${Math.round(totals.c)}</span>g</span>
              <span class="tiny muted">脂肪 <span id="food-photo-f">${Math.round(totals.f)}</span>g</span>
            </div>
          </div>

          <div class="tiny faint" style="margin-top:10px">${state.foodPhotoModel.startsWith("local") ? "当前为本地估算模式，结果仅用于演示流程。" : "结果来自远程识别服务，照片未保存。"}</div>
          <div class="tiny faint" style="margin-top:6px;line-height:1.6">识别结果为估算，热量与营养素可能有偏差。过敏原、疾病饮食与特殊人群需求请以包装标签、商家信息或医生/营养师意见为准。</div>

          <button class="btn btn-primary" style="margin-top:12px" onclick="app.foodPhotoAdd()" ${totals.kcal > 0 ? "" : "disabled"}>
            加入${state.foodPhotoMeal} · <span id="food-photo-add-kcal">${Math.round(totals.kcal)}</span> kcal
          </button>
        </div>
      ` : ""}

      <div class="tiny faint" style="line-height:1.6">拍照识别只能做估算，不能保证份量、烹饪油和隐藏配料完全准确。对花生、海鲜、乳制品等过敏原，请以包装标签或商家确认为准。</div>
    </div>
  `;
}

function foodAddScreen() {
  const draft = state.foodDraft;
  const selected = draft.selected ? allFoods().find((food) => food.name === draft.selected) : null;
  const manualLabel = draft.query.trim()
    ? `找不到？手动添加「${esc(draft.query.trim())}」`
    : "找不到？手动添加食物";
  return `
    <div class="stack">
      ${headerBack("记录食物", "app.go('nutrition')")}
      <div class="seg">
        ${["早餐", "午餐", "晚餐", "加餐"].map((meal) => `
          <button class="${draft.meal === meal ? "active" : ""}" onclick="app.foodMeal('${meal}')">${meal}</button>
        `).join("")}
      </div>

      <input type="text" id="food-search" placeholder="搜索食物，例如：螺蛳粉、奶茶、鸡胸肉" value="${esc(draft.query)}" oninput="app.foodQuery(this.value)">
      <div class="tiny faint" style="line-height:1.6">记录是为了了解，不是为了给食物打分。奶茶、火锅、螺蛳粉都可以记。</div>

      ${selected ? `
        <div class="card">
          <div class="between">
            <div>
              <div class="h3">${esc(selected.name)}</div>
              <div class="tiny muted">${selected.serving ? `常用份量约 ${selected.serving}g · ` : ""}每 100g · ${selected.kcal} kcal</div>
            </div>
            <button class="link" onclick="app.clearFoodSelection()">重新选择</button>
          </div>
          <div class="slider-row" style="margin-top:12px">
            <div class="between">
              <span class="small muted">份量</span>
              <span class="small strong" id="food-grams-label">${draft.grams} g</span>
            </div>
            <input type="range" min="10" max="2000" step="10" value="${draft.grams}" oninput="app.foodGrams(this.value)">
          </div>
          <div class="macro-grid" style="margin-top:10px;grid-template-columns:repeat(4,1fr)">
            <div class="macro"><div class="label">热量</div><div class="value" id="food-kcal">${Math.round(selected.kcal * draft.grams / 100)}</div></div>
            <div class="macro"><div class="label">蛋白质</div><div class="value" id="food-p">${Math.round(selected.p * draft.grams / 100)}g</div></div>
            <div class="macro"><div class="label">碳水</div><div class="value" id="food-c">${Math.round(selected.c * draft.grams / 100)}g</div></div>
            <div class="macro"><div class="label">脂肪</div><div class="value" id="food-f">${Math.round(selected.f * draft.grams / 100)}g</div></div>
          </div>
          <button class="btn btn-primary" style="margin-top:12px" onclick="app.addFood()">添加到${draft.meal}</button>
        </div>
      ` : `
        <div id="food-results">
          ${foodResults(draft.query)}
        </div>
        <button class="btn btn-secondary" onclick="app.openFoodCustom()">${manualLabel}</button>
      `}
    </div>
  `;
}

function foodCustomScreen() {
  const draft = state.foodCustomDraft;
  if (!draft) return foodAddScreen();
  return `
    <div class="stack">
      ${headerBack("手动添加食物", "app.closeFoodCustom()")}
      <div class="card">
        <div class="h3">按你实际吃的一份填写</div>
        <div class="tiny muted" style="margin-top:6px;line-height:1.6">不知道蛋白质、碳水或脂肪可以留空。先记下热量也可以，之后还能补充。</div>
      </div>

      <div class="card">
        <div class="form-label">食物名称</div>
        <input type="text" value="${esc(draft.name)}" placeholder="例如：螺蛳粉" oninput="app.foodCustomInput('name', this.value)">

        <div class="form-label" style="margin-top:14px">这一份重量（g）</div>
        <input type="text" inputmode="decimal" value="${esc(draft.portion)}" placeholder="例如：600" oninput="app.foodCustomInput('portion', this.value)">
        <div class="tiny faint" style="margin-top:6px">如果吃的是一整碗/一整份，填整份重量。螺蛳粉通常约 500–700g。</div>
      </div>

      <div class="card">
        <div class="between">
          <div class="h3">这一份的营养素</div>
          <div class="tiny faint">可选</div>
        </div>
        <div class="form-label" style="margin-top:12px">热量（kcal）</div>
        <input type="text" inputmode="decimal" value="${esc(draft.kcal)}" placeholder="例如：750" oninput="app.foodCustomInput('kcal', this.value)">
        <div class="form-label" style="margin-top:12px">蛋白质（g）</div>
        <input type="text" inputmode="decimal" value="${esc(draft.p)}" placeholder="可选" oninput="app.foodCustomInput('p', this.value)">
        <div class="row gap8" style="margin-top:12px">
          <div style="flex:1"><div class="form-label">碳水（g）</div><input type="text" inputmode="decimal" value="${esc(draft.c)}" placeholder="可选" oninput="app.foodCustomInput('c', this.value)"></div>
          <div style="flex:1"><div class="form-label">脂肪（g）</div><input type="text" inputmode="decimal" value="${esc(draft.f)}" placeholder="可选" oninput="app.foodCustomInput('f', this.value)"></div>
        </div>
        <div class="tiny faint" style="margin-top:8px">会按“这一份”换算成每 100g 保存，下次搜索时可以直接复用。</div>
      </div>

      <button class="btn btn-primary" onclick="app.saveFoodCustom()">保存并选择</button>
      <div class="tiny faint center" style="line-height:1.6">没有“好食物/坏食物”。记录只是帮你了解今天吃了什么。</div>
    </div>
  `;
}

function foodResults(query) {
  const list = allFoods()
    .filter((food) => !query || food.name.includes(query) || food.cat.includes(query))
    .slice(0, 30);
  if (!list.length) {
    return `<div class="tiny muted" style="padding:22px 12px;text-align:center">没有匹配的食物，直接手动添加就好。</div>`;
  }
  return list.map((food) => `
    <button class="food-item" onclick="app.selectFood(decodeURIComponent('${encodeURIComponent(food.name)}'))">
      <div>
        <div class="small strong">${esc(food.name)}</div>
        <div class="tiny faint">${food.cat} · ${food.serving ? `常用 ${food.serving}g · ` : ""}每 100g</div>
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
      ${headerBack("练途 Pro")}
      <div class="card hero center">
        <div class="crown">♛</div>
        <div class="h2">把 AI 教练带在身边</div>
        <div class="small muted" style="margin-top:6px">解锁 DeepSeek AI 计划、三种专业 Skill 与完整教练对话。</div>
      </div>

      <div class="card">
        ${[
          ["DeepSeek AI 计划生成与调整", "✦"],
          ["健身教练、康复师、营养师 AI Skills", "◎"],
          ["周复盘、训练偏好记忆与动作替代", "💬"],
          ["器械拍照识别与饮食记录", "📷"]
        ].map(([text, icon]) => `
          <div class="benefit-row"><span>${icon}</span><span>${text}</span><span class="check">✓</span></div>
        `).join("")}
      </div>

      ${state.pro ? `
        <div class="card center">
          <div class="h3 accent">✓ 已订阅练途 Pro</div>
          <div class="tiny muted" style="margin-top:5px">所有 Pro 功能已解锁。</div>
        </div>
      ` : `
        <div class="stack" style="gap:9px">
          <button class="plan-option ${state.paywallPlan === "monthly" ? "selected" : ""}" onclick="app.selectPaywall('monthly')">
            <div style="text-align:left"><div class="title">月度订阅</div><div class="desc">随时取消</div></div>
            <div class="price">¥28 / 月</div>
          </button>
          <button class="plan-option ${state.paywallPlan === "yearly" ? "selected" : ""}" onclick="app.selectPaywall('yearly')">
            <div style="text-align:left">
              <div class="row gap6"><div class="title">年度订阅</div><span class="save-badge">推荐 · 省 41%</span></div>
              <div class="desc">约 ¥16.5 / 月</div>
            </div>
            <div class="price">¥198 / 年</div>
          </button>
        </div>
        <button class="btn btn-primary" style="margin-top:12px" onclick="app.buy(state.paywallPlan)">立即订阅 · ${state.paywallPlan === "yearly" ? "¥198 / 年" : "¥28 / 月"}</button>
      `}

      <button class="link" style="display:block;margin:8px auto" onclick="app.restorePurchase()">恢复购买</button>
      <div class="tiny faint center" style="line-height:1.6">订阅会自动续期，可随时在系统设置中取消。</div>
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
  const setsDone = workout.setIndex >= exercise.sets;
  const actionLabel = setsDone
    ? (workout.index < day.exercises.length - 1 ? "下一个动作" : "查看训练总结")
    : `完成第 ${workout.setIndex + 1} 组`;
  const action = setsDone ? "app.nextExercise()" : "app.completeSet()";

  return `
    <div class="stack workout-screen">
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

      </div>

      <div class="card tight">
        <div class="between">
          <div class="small strong">训练提示</div>
          <div class="tiny faint">目标 RPE 7.5</div>
        </div>
        <div class="tiny muted" style="margin-top:6px;line-height:1.6">保留 1–2 次余力；组间休息 ${exercise.rest}s，动作变形就降重量。</div>
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

      <div class="workout-action-bar">
        <div class="between">
          <button class="link" style="color:var(--muted)" onclick="app.nextExercise()">跳过这个动作</button>
          <span class="tiny faint">已完成 ${done}/${total} 组</span>
        </div>
        <button class="btn btn-primary" style="margin-top:8px" onclick="${action}">${actionLabel}</button>
      </div>
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

let lastRouteKey = "";

function render() {
  if (!state.onboarded) state.screen = "onboarding";
  if (state.onboarded && state.screen === "onboarding") state.screen = "tabs";

  const root = document.getElementById("app");
  if (!root) return;

  if (!state.authenticated) {
    const loginRoute = "login";
    const loginChanged = lastRouteKey !== loginRoute;
    lastRouteKey = loginRoute;
    root.innerHTML = loginScreen() + legalModal();
    root.className = "app no-tabs" + (loginChanged ? " route-changed" : "");
    document.getElementById("tabbar").innerHTML = "";
    document.getElementById("tabbar").className = "tabbar hidden";
    if (loginChanged) {
      requestAnimationFrame(() => { root.scrollTop = 0; });
    }
    return;
  }

  const routeKey = [
    state.screen,
    state.tab,
    state.planDayId || "",
    state.sessionId || "",
    state.equipmentItemId || ""
  ].join("|");
  const routeChanged = routeKey !== lastRouteKey;
  lastRouteKey = routeKey;

  let html = "";
  if (state.screen === "onboarding") html = onboarding();
  else if (state.screen === "tabs") {
    if (state.tab === "home") html = home();
    else if (state.tab === "plan") html = planScreen();
    else if (state.tab === "coach") html = coachScreen();
    else if (state.tab === "equipment") html = equipmentLibraryScreen();
    else html = profileScreen();
  } else if (state.screen === "planDay") html = planDayScreen();
  else if (state.screen === "nutrition") html = nutritionScreen();
  else if (state.screen === "foodAdd") html = foodAddScreen();
  else if (state.screen === "foodCustom") html = foodCustomScreen();
  else if (state.screen === "foodPhoto") html = foodPhotoScreen();
  else if (state.screen === "paywall") html = paywallScreen();
  else if (state.screen === "profileEdit") html = profileEditScreen();
  else if (state.screen === "settings") html = settingsScreen();
  else if (state.screen === "workout") html = workoutScreen();
  else if (state.screen === "sessionDetail") html = sessionScreen();
  else if (state.screen === "exerciseDetail") html = exerciseScreen();
  else if (state.screen === "equipmentAdd") html = equipmentScreen();
  else if (state.screen === "equipmentSearch") html = equipmentSearchScreen();
  else if (state.screen === "equipmentPhoto") html = equipmentPhotoScreen();
  else if (state.screen === "equipmentItem") html = equipmentItemScreen();
  else if (state.screen === "bodyAnalysis") html = bodyAnalysisScreen();
  else html = home();

  root.innerHTML = html + legalModal();
  root.className = "app"
    + (state.screen === "tabs" ? "" : " no-tabs")
    + (state.screen === "tabs" && state.tab === "coach" ? " chat-mode" : "")
    + (routeChanged ? " route-changed" : "");
  document.getElementById("tabbar").innerHTML = tabbar();
  document.getElementById("tabbar").className = "tabbar" + (state.onboarded && state.screen === "tabs" ? "" : " hidden");
  if (routeChanged) {
    requestAnimationFrame(() => { root.scrollTop = 0; });
  }

  if (state.screen === "tabs" && state.tab === "coach") {
    setTimeout(() => {
      const chat = document.getElementById("chat-scroll");
      if (chat) chat.scrollTop = chat.scrollHeight;
    }, 20);
  }

  if (state.screen === "equipmentSearch") {
    setTimeout(() => {
      const input = document.getElementById("equipment-search-input");
      if (input) {
        input.focus();
        input.setSelectionRange(input.value.length, input.value.length);
      }
    }, 30);
  }
}

function coachReply(text, skill = "trainer") {
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
  if (skill === "nutrition") {
    const targets = nutritionTargets();
    return { text: `营养师模式下，我先给一个保守区间：每天蛋白质约 ${targets.protein}g，分 3–4 餐摄入；每餐先安排蛋白质和蔬菜，再根据训练量调整主食。如果有糖尿病、肾病、孕期或进食障碍，请先咨询医生或注册营养师。` };
  }
  if (skill === "rehab") {
    return { text: "康复师模式下，我不会在未评估的情况下给你诊断或加练。请先告诉我疼痛位置、持续多久、疼痛 0–10 分，以及是否有肿胀、麻木或无力。如果有明显肿胀、无法承重或神经症状，请先线下就医。" };
  }
  return { text: "我记住了。你可以具体问：今天练什么、某个动作怎么替代，或者把训练感受告诉我。当前计划会参考你的完成率和 RPE 做调整。" };
}

/* ---------------- app actions ---------------- */

window.app = {
  field(key, value) {
    state.profile[key] = value;
    save();
  },

  profileDraftInput(key, value) {
    if (!state.profileDraft) return;
    state.profileDraft[key] = value;
    save();
  },

  profileDraftNumber(key, value) {
    if (!state.profileDraft) return;
    const number = Number(value);
    state.profileDraft[key] = number;
    const units = {
      age: "岁", height: "cm", weight: "kg", waist: "cm", chest: "cm", hip: "cm",
      targetWeight: "kg", targetWaist: "cm"
    };
    const label = document.getElementById(`draft-val-${key}`);
    if (label) {
      const shown = key === "weight" || key === "targetWeight" ? number.toFixed(1) : String(Math.round(number));
      label.textContent = `${shown}${units[key] || ""}`;
    }
    const bmi = document.getElementById("draft-bmi");
    if (bmi) bmi.textContent = bmiText(state.profileDraft);
    save();
  },

  profileDraftSelect(key, value) {
    if (!state.profileDraft) return;
    state.profileDraft[key] = Number.isNaN(Number(value)) ? value : Number(value);
    save();

    if (key === "goal") {
      document.querySelectorAll("[data-draft-goal]").forEach((button) => {
        button.classList.toggle("active", button.dataset.draftGoal === value);
      });
      const targetFields = document.getElementById("profile-target-fields");
      if (targetFields) {
        targetFields.style.display = value === "提升体能" ? "none" : "";
      }
    }

    document.querySelectorAll(`[data-draft-seg="${key}"]`).forEach((button) => {
      button.classList.toggle("active", button.dataset.value === String(value));
    });
  },

  profileDraftToggleEquip(name) {
    if (!state.profileDraft) return;
    const list = state.profileDraft.equipment;
    const active = !list.includes(name);
    state.profileDraft.equipment = active
      ? list.concat(name)
      : list.filter((item) => item !== name);
    save();
    document.querySelectorAll("[data-equip]").forEach((button) => {
      if (button.dataset.equip === name) {
        button.classList.toggle("active", active);
      }
    });
  },

  openProfileEdit() {
    state.profileDraft = JSON.parse(JSON.stringify(state.profile));
    state.screen = "profileEdit";
    save();
    render();
  },

  closeProfileEdit() {
    state.profileDraft = null;
    state.screen = "tabs";
    state.tab = "profile";
    save();
    render();
  },

  saveProfileEdit() {
    const draft = state.profileDraft;
    if (!draft) return;
    const name = String(draft.name || "").trim();
    if (!name) {
      toast("请填写称呼");
      return;
    }
    if (Number(draft.height) > 0 && Number(draft.weight) / Math.pow(Number(draft.height) / 100, 2) < 18.5 && draft.goal === "减脂") {
      toast("BMI 低于 18.5，不建议以减脂为目标");
      return;
    }
    draft.name = name;
    if (!draft.equipment.includes("徒手")) draft.equipment.push("徒手");
    state.profile = { ...draft };
    state.profileDraft = null;
    state.screen = "tabs";
    state.tab = "profile";
    save();
    render();
    toast("资料已保存");
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
    state.authenticated = true;
    state.profile = { ...DEFAULT_PROFILE };
    state.plan = applyEquipmentLibrary(buildPlan(state.profile));
    state.onboarded = true;
    state.screen = "tabs";
    state.tab = "home";
    save();
    render();
    toast("已载入示例数据");
  },

  previewAuthMode(mode) {
    state.authMode = mode;
    state.authError = "";
    save();
    render();
  },

  previewAuthField(key, value) {
    state[key] = value;
    save();
  },

  previewAuthConsent() {
    state.authConsent = !state.authConsent;
    state.authError = "";
    save();
    render();
  },

  previewSendCode() {
    if (!/^1\d{10}$/.test(state.authPhone)) {
      state.authError = "请输入正确的 11 位手机号";
      render();
      return;
    }
    state.authDevCode = "123456";
    state.authCode = "123456";
    state.authError = "";
    save();
    render();
    toast("开发验证码 123456 已填入");
  },

  previewLogin() {
    if (!state.authConsent) {
      state.authError = "请先勾选页面底部的用户协议与隐私政策";
      render();
      return;
    }
    if (state.authMode === "phone") {
      if (!/^1\d{10}$/.test(state.authPhone)) {
        state.authError = "请输入正确的 11 位手机号";
        render();
        return;
      }
      if (state.authCode.length !== 6) {
        state.authError = "请输入 6 位验证码";
        render();
        return;
      }
    } else if (state.authAccount.length < 4 || state.authPassword.length < 8) {
      state.authError = "请输入账号和至少 8 位密码";
      render();
      return;
    }

    state.authenticated = true;
    state.authError = "";
    if (!state.onboarded) {
      state.profile = { ...DEFAULT_PROFILE };
      state.plan = applyEquipmentLibrary(buildPlan(state.profile));
      state.onboarded = true;
    }
    state.screen = "tabs";
    state.tab = "home";
    save();
    render();
    toast("登录成功（预览模拟）");
  },

  previewSocial(provider) {
    if (!state.authConsent) {
      state.authError = "请先勾选页面底部的用户协议与隐私政策";
      render();
      return;
    }
    state.authenticated = true;
    if (!state.onboarded) {
      state.profile = { ...DEFAULT_PROFILE };
      state.plan = applyEquipmentLibrary(buildPlan(state.profile));
      state.onboarded = true;
    }
    state.screen = "tabs";
    state.tab = "home";
    state.authError = "";
    save();
    render();
    toast(`已通过${provider}登录（预览模拟）`);
  },

  previewForgotPassword() {
    toast("iOS 端已支持手机验证码重置密码；Web 预览不发送真实短信。");
  },

  previewLogout() {
    state.authenticated = false;
    state.authError = "";
    state.authConsent = false;
    save();
    render();
    toast("已退出登录");
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

  openSettings() {
    state.screen = "settings";
    save();
    render();
  },

  closeSettings() {
    state.screen = "tabs";
    state.tab = "profile";
    save();
    render();
  },

  back() {
    if (state.screen === "foodCustom") { state.foodCustomDraft = null; state.screen = "foodAdd"; }
    else if (state.screen === "foodAdd") state.screen = "nutrition";
    else if (state.screen === "planDay") { state.screen = "tabs"; state.tab = "plan"; }
    else if (state.screen === "paywall") { state.screen = "tabs"; state.tab = "profile"; }
    else if (state.screen === "sessionDetail") { state.screen = "tabs"; state.tab = "home"; }
    else if (state.screen === "exerciseDetail") { state.screen = "tabs"; state.tab = "equipment"; }
    else if (state.screen === "equipmentItem") { state.screen = "tabs"; state.tab = "equipment"; }
    else if (state.screen === "equipmentAdd") { state.screen = "tabs"; state.tab = "equipment"; }
    else if (state.screen === "equipmentSearch" || state.screen === "equipmentPhoto") state.screen = "equipmentAdd";
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
    const preview = planAdjustmentPreview();
    if (!preview.completed) {
      return toast("先完成一次训练，复盘才有数据");
    }
    state.plan.version += 1;
    state.plan.days.forEach((day) => {
      day.exercises.forEach((exercise) => {
        if (preview.setsDelta) {
          exercise.sets = Math.max(2, exercise.sets + preview.setsDelta);
        }
        if (preview.weightMultiplier !== 1 && exercise.weight > 0) {
          const adjusted = roundHalf(exercise.weight * preview.weightMultiplier);
          exercise.weight = preview.weightMultiplier > 1
            ? Math.max(adjusted, exercise.weight + 0.5)
            : Math.max(0, Math.min(adjusted, exercise.weight - 0.5));
        }
      });
    });
    save();
    render();
    toast(`复盘完成：${preview.detail} 已生成第 ${state.plan.version} 版`);
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

  setCoachSkill(skill) {
    state.coachSkill = skill;
    save();
    render();
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
    const reply = coachReply(message, state.coachSkill || "trainer");
    state.chats.push({ role: "assistant", text: reply.text, safety: !!reply.safety });
    save();
    render();
    setTimeout(() => {
      const chat = document.getElementById("chat-scroll");
      if (chat) chat.scrollTop = chat.scrollHeight;
    }, 20);
  },

  mockPhoto(source = "拍照") {
    state.equipment.scanned = true;
    state.equipment.candidates = [];
    save();
    render();
    toast(source === "相册" ? "已从相册选择一张器械照片" : "已模拟拍摄一张器械照片");
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
    state.paywallPlan = plan;
    state.pro = true;
    save();
    render();
    toast(plan === "yearly" ? "模拟购买成功：年度订阅" : "模拟购买成功：月度订阅");
  },

  selectPaywall(plan) {
    state.paywallPlan = plan;
    save();
    render();
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
    const food = allFoods().find((item) => item.name === name);
    state.foodDraft.selected = name;
    state.foodDraft.grams = food && food.serving ? food.serving : 100;
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
    const food = allFoods().find((item) => item.name === state.foodDraft.selected);
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
    const food = allFoods().find((item) => item.name === draft.selected);
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
    if (!confirm("确认删除这条饮食记录？")) return;
    state.foodLogs = state.foodLogs.filter((item) => item.id !== id);
    save();
    render();
    toast("已删除记录");
  },

  openFoodCustom() {
    state.foodCustomDraft = {
      name: state.foodDraft.query.trim(),
      portion: "100",
      kcal: "",
      p: "",
      c: "",
      f: ""
    };
    state.screen = "foodCustom";
    save();
    render();
  },

  closeFoodCustom() {
    state.foodCustomDraft = null;
    state.screen = "foodAdd";
    save();
    render();
  },

  foodCustomInput(key, value) {
    if (!state.foodCustomDraft) return;
    state.foodCustomDraft[key] = value;
    save();
  },

  saveFoodCustom() {
    const draft = state.foodCustomDraft;
    if (!draft) return;
    const name = (draft.name || "").trim();
    const portion = Number(String(draft.portion).replace(",", "."));
    const kcalText = String(draft.kcal || "").trim();
    const kcal = Number(kcalText.replace(",", "."));
    if (!name) return toast("先填写食物名称");
    if (!Number.isFinite(portion) || portion <= 0) return toast("填写这一份的重量");
    if (!kcalText || !Number.isFinite(kcal) || kcal < 0) return toast("先填写这一份的热量，估算也可以");

    const factor = 100 / portion;
    const food = {
      name,
      cat: "自定义",
      kcal: kcal * factor,
      p: (Number(draft.p) || 0) * factor,
      c: (Number(draft.c) || 0) * factor,
      f: (Number(draft.f) || 0) * factor,
      serving: portion
    };
    state.customFoods = [food, ...(state.customFoods || []).filter((item) => item.name !== name)];
    state.foodDraft.query = name;
    state.foodDraft.selected = name;
    state.foodDraft.grams = portion;
    state.foodCustomDraft = null;
    state.screen = "foodAdd";
    save();
    render();
    toast("已保存，下次可以直接搜索这个食物");
  },

  openFoodPhoto() {
    state.foodPhotoImage = false;
    state.foodPhotoItems = [];
    state.foodPhotoConfidence = 0;
    state.foodPhotoModel = "";
    state.screen = "foodPhoto";
    save();
    render();
  },

  foodPhotoTake() {
    state.foodPhotoImage = true;
    state.foodPhotoItems = [];
    save();
    render();
    toast("已选择照片（预览模拟）");
  },

  foodPhotoMeal(meal) {
    state.foodPhotoMeal = meal;
    save();
    render();
  },

  foodPhotoAnalyze() {
    if (!state.foodPhotoImage) return toast("先拍照或选择照片");
    state.foodPhotoItems = foodPhotoMockItems();
    state.foodPhotoConfidence = state.foodPhotoItems.reduce((sum, item) => sum + item.confidence, 0) / state.foodPhotoItems.length;
    state.foodPhotoModel = "local-mock";
    save();
    render();
    toast("识别完成，可以修改份量和勾选");
  },

  foodPhotoToggle(index, checked) {
    const item = state.foodPhotoItems[index];
    if (!item) return;
    item.selected = checked;
    save();
    render();
  },

  foodPhotoGrams(index, value) {
    const item = state.foodPhotoItems[index];
    if (!item) return;
    item.grams = Math.max(10, Number(value) || 10);
    const factor = item.grams / 100;
    const kcal = Math.round(item.kcalPer100g * factor);
    const p = Math.round(item.pPer100g * factor);
    const c = Math.round(item.cPer100g * factor);
    const f = Math.round(item.fPer100g * factor);
    const gramsLabel = document.getElementById(`food-photo-grams-${index}`);
    const kcalLabel = document.getElementById(`food-photo-kcal-${index}`);
    const macroLabel = document.getElementById(`food-photo-macros-${index}`);
    if (gramsLabel) gramsLabel.textContent = `${item.grams} g`;
    if (kcalLabel) kcalLabel.textContent = `${kcal} kcal`;
    if (macroLabel) macroLabel.textContent = `P ${p}g · C ${c}g · F ${f}g`;

    const totals = foodPhotoTotals();
    const totalLabel = document.getElementById("food-photo-total");
    const addLabel = document.getElementById("food-photo-add-kcal");
    const proteinLabel = document.getElementById("food-photo-p");
    const carbLabel = document.getElementById("food-photo-c");
    const fatLabel = document.getElementById("food-photo-f");
    if (totalLabel) totalLabel.textContent = `${Math.round(totals.kcal)} kcal`;
    if (addLabel) addLabel.textContent = Math.round(totals.kcal);
    if (proteinLabel) proteinLabel.textContent = Math.round(totals.p);
    if (carbLabel) carbLabel.textContent = Math.round(totals.c);
    if (fatLabel) fatLabel.textContent = Math.round(totals.f);
    save();
  },

  foodPhotoAdd() {
    const selected = state.foodPhotoItems.filter((item) => item.selected);
    if (!selected.length) return toast("至少勾选一种食物");
    const meal = state.foodPhotoMeal;
    selected.forEach((item, index) => {
      const factor = item.grams / 100;
      state.foodLogs.push({
        id: `fp-log-${Date.now()}-${index}`,
        meal,
        name: item.name,
        grams: item.grams,
        kcal: Math.round(item.kcalPer100g * factor),
        p: Math.round(item.pPer100g * factor * 10) / 10,
        c: Math.round(item.cPer100g * factor * 10) / 10,
        f: Math.round(item.fPer100g * factor * 10) / 10
      });
    });
    const total = Math.round(foodPhotoTotals(selected).kcal);
    state.foodPhotoImage = false;
    state.foodPhotoItems = [];
    state.screen = "nutrition";
    save();
    render();
    toast(`${meal}已加入 ${total} kcal`);
  },

  equipmentLibraryOpen() {
    state.screen = "tabs";
    state.tab = "equipment";
    save();
    render();
  },

  equipmentAddOpen() {
    state.screen = "equipmentAdd";
    save();
    render();
  },

  equipmentSearchOpen() {
    state.equipSearchQuery = "";
    state.screen = "equipmentSearch";
    save();
    render();
  },

  equipmentSearchInput(value) {
    state.equipSearchQuery = value;
    const box = document.getElementById("equipment-search-results");
    const count = document.getElementById("equipment-search-count");
    if (box) box.innerHTML = equipmentSearchResults(value);
    if (count) count.textContent = `${equipmentSearchMatches(value).length} 个`;
    save();
  },

  equipmentSearchAdd(slug) {
    const ex = EX[slug];
    if (!ex) return;
    if (state.equipmentLibrary.some((entry) => entry.slug === slug)) {
      return toast("这个器械已经在库里");
    }
    state.equipmentLibrary.push({
      id: `e${Date.now()}`,
      name: ex.name,
      slug,
      muscle: ex.muscle,
      equip: ex.equip,
      video: false,
      notes: "从动作库搜索添加"
    });
    state.equipSearchQuery = "";
    state.screen = "tabs";
    state.tab = "equipment";
    save();
    render();
    toast(`已添加 ${ex.name}`);
  },

  equipmentPhotoOpen(source) {
    state.equipPhotoSource = source;
    state.screen = "equipmentPhoto";
    save();
    render();
  },

  equipmentPhotoSave() {
    const preferred = ["seated_row", "treadmill", "face_pull", "leg_press", "biceps_curl"];
    let slug = preferred.find((item) => !state.equipmentLibrary.some((entry) => entry.slug === item));
    if (!slug) {
      slug = Object.keys(EX).find((item) => !state.equipmentLibrary.some((entry) => entry.slug === item));
    }
    if (!slug) return toast("示例器械已全部添加");
    const ex = EX[slug];
    state.equipmentLibrary.push({
      id: `e${Date.now()}`,
      name: ex.name,
      slug,
      muscle: ex.muscle,
      equip: ex.equip,
      video: false,
      notes: `来自${state.equipPhotoSource}（预览模拟）`
    });
    state.screen = "tabs";
    state.tab = "equipment";
    save();
    render();
    toast(`已通过${state.equipPhotoSource}添加 ${ex.name}`);
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
    state.screen = "tabs";
    state.tab = "equipment";
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

  openLegal(doc) {
    state.legalDoc = doc;
    render();
  },

  closeLegal() {
    state.legalDoc = null;
    render();
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
      customFoods: state.customFoods,
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
  state.authenticated = true;
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
if (previewParams.get("screen") === "foodPhoto") {
  state.onboarded = true;
  state.foodPhotoImage = true;
  state.foodPhotoItems = foodPhotoMockItems();
  state.foodPhotoConfidence = state.foodPhotoItems.reduce((sum, item) => sum + item.confidence, 0) / state.foodPhotoItems.length;
  state.foodPhotoModel = "local-mock";
}
if (previewParams.has("equipSearch")) {
  state.onboarded = true;
  state.equipSearchQuery = previewParams.get("equipSearch") || "";
  state.screen = "equipmentSearch";
}
if (previewParams.has("equipPhoto")) {
  state.onboarded = true;
  state.equipPhotoSource = previewParams.get("equipPhoto") || "拍照";
  state.screen = "equipmentPhoto";
}

render();
