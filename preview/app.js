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
  dumbbell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 8v8M4 10v4M17.5 8v8M20 10v4M8 12h8"/></svg>',
  barbell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9v6M7 7v10M17 7v10M20 9v6M7 12h10"/></svg>',
  machine: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="4" width="16" height="16" rx="4"/><circle cx="12" cy="12" r="3.2"/><path d="M12 4v2M12 18v2M4 12h2M18 12h2"/></svg>',
  cable: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M6 5h4v5H6zM16 5h2v9h-2zM10 7.5h6M6 15c0 2.8 2 4.5 4.5 4.5H14"/><circle cx="16" cy="17.5" r="2"/></svg>',
  bodyweight: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="13" cy="4.5" r="2"/><path d="m12.5 8 2 3-1.5 3 2.5 4M12.5 8 9 10.5M13 14l-2.5 6M9 10.5l-3.5 1.5"/></svg>',
  kettlebell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M9.2 9.6C6.7 10.6 5 13 5 15.5 5 18.6 7.4 21 10.5 21h3c3.1 0 5.5-2.4 5.5-5.5 0-2.5-1.7-4.9-4.2-5.9"/><path d="M9.2 9.6c0-2.7 1.1-4.6 2.8-4.6s2.8 1.9 2.8 4.6"/></svg>',
  band: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 8.2c3.8-2.8 7.2 2.7 11 0 2-1.4 3.8-1.4 5.2-.8M3.5 15.8c3.8-2.8 7.2 2.7 11 0 2-1.4 3.8-1.4 5.2-.8"/></svg>',
  cardio: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="15.5" cy="4.5" r="2"/><path d="m13.5 8.5 2.5 3-1.5 3 2.5 3.5M13.5 8.5 9.5 10M15 14.5 12 20M9.5 10 6 12.5"/></svg>',
  muscleChest: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4h12v4.8c0 4.6-2.7 7.6-6 9.2-3.3-1.6-6-4.6-6-9.2z"/><path d="M12 5v6.5M8 8.2c1.5 1.1 2.6 1.2 4 .2M16 8.2c-1.5 1.1-2.6 1.2-4 .2"/></svg>',
  muscleBack: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4h12v4.8c0 4.6-2.7 7.6-6 9.2-3.3-1.6-6-4.6-6-9.2z"/><path d="M12 5v11M8.5 8h7M8.5 12h7"/></svg>',
  muscleLegs: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M8 4h3v6l-1.5 4L8 20H6l1.5-6L9 10V4"/><path d="M16 4h-3v6l1.5 4L16 20h2l-1.5-6L15 10V4"/></svg>',
  muscleGlutes: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 6c3 0 4 2 4 4.5V15c0 2.5-1 4.5-3 5.5M19 6c-3 0-4 2-4 4.5V15c0 2.5 1 4.5 3 5.5M8 10h8M12 10v10"/></svg>',
  muscleShoulder: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12c1.5-4 4.5-6 8-6s6.5 2 8 6"/><path d="M7 10v9M17 10v9M7 15h10"/></svg>',
  muscleArms: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M6 18c0-4 2-6 5-6h1l2-4 3 1.5-2 5.5c-1 2.5-3 4-5.5 4H6z"/><path d="M11 12V8"/></svg>',
  muscleCore: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M7 4h10v5.5c0 4.5-2.2 8.2-5 9.5-2.8-1.3-5-5-5-9.5z"/><path d="M9 9h6M9 12h6M12 7v7"/></svg>',
  play: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 6.4v11.2l8.5-5.6z"/></svg>',
  search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><circle cx="11" cy="11" r="6.6"/><path d="m20 20-3.7-3.7"/></svg>',
  camera: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8h3l1.6-2h6.8L17 8h3v10H4z"/><circle cx="12" cy="13" r="3"/></svg>',
  library: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"><rect x="4" y="4" width="7" height="7" rx="1.7"/><rect x="13" y="4" width="7" height="7" rx="1.7"/><rect x="4" y="13" width="7" height="7" rx="1.7"/><rect x="13" y="13" width="7" height="7" rx="1.7"/></svg>',
  checklist: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="3.5" width="14" height="17" rx="3"/><path d="m8.2 9 1.8 1.8 3.2-3.4M8.2 15.2h7.2"/></svg>',
  clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3.2 2"/></svg>',
  chart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 20V10M12 20V4M19 20v-6"/><path d="M3 20h18"/></svg>',
  pin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 3h6l-1 6 4 4H6l4-4z"/><path d="M12 13v8"/></svg>',
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

function relativeSessionDate(daysAgo, hour, minute) {
  const date = new Date();
  date.setDate(date.getDate() - daysAgo);
  date.setHours(hour, minute, 0, 0);
  return {
    date: `${date.getMonth() + 1}月${date.getDate()}日 ${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`,
    timestamp: date.getTime()
  };
}

function localDateInputValue(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function demoHistorySessions() {
  return [
    {
      id: "s4", title: "全身 A", ...relativeSessionDate(12, 19, 20), duration: 45,
      volume: 1880, thisWeek: false,
      items: [
        { name: "高位下拉", weight: 30, reps: 8, sets: 4 },
        { name: "高脚杯深蹲", weight: 14, reps: 10, sets: 4 },
        { name: "哑铃卧推", weight: 12, reps: 10, sets: 3 }
      ]
    },
    {
      id: "s5", title: "全身 B", ...relativeSessionDate(25, 18, 55), duration: 44,
      volume: 2310, thisWeek: false,
      items: [
        { name: "高位下拉", weight: 30, reps: 9, sets: 4 },
        { name: "坐姿划船", weight: 30, reps: 10, sets: 4 },
        { name: "面拉", weight: 12, reps: 15, sets: 3 }
      ]
    },
    {
      id: "s6", title: "全身 C", ...relativeSessionDate(43, 19, 30), duration: 47,
      volume: 2060, thisWeek: false,
      items: [
        { name: "高位下拉", weight: 32.5, reps: 8, sets: 4 },
        { name: "杠铃臀推", weight: 35, reps: 10, sets: 4 },
        { name: "绳索下压", weight: 12, reps: 12, sets: 3 }
      ]
    },
    {
      id: "s7", title: "全身 A", ...relativeSessionDate(61, 18, 30), duration: 42,
      volume: 1840, thisWeek: false,
      items: [
        { name: "高位下拉", weight: 32.5, reps: 7, sets: 4 },
        { name: "高脚杯深蹲", weight: 14, reps: 10, sets: 3 },
        { name: "俯卧撑", weight: 0, reps: 12, sets: 3 }
      ]
    }
  ];
}

function demoSessions() {
  return [
    {
      id: "s1", title: "全身 A", ...relativeSessionDate(2, 19, 10), duration: 46,
      volume: 1840, thisWeek: true,
      items: [
        { name: "高脚杯深蹲", weight: 12, reps: 10, sets: 4 },
        { name: "俯卧撑", weight: 0, reps: 12, sets: 3 },
        { name: "高位下拉", weight: 25, reps: 10, sets: 4 },
        { name: "哑铃推举", weight: 8, reps: 10, sets: 3 }
      ]
    },
    {
      id: "s2", title: "全身 B", ...relativeSessionDate(4, 18, 40), duration: 43,
      volume: 1620, thisWeek: true,
      items: [
        { name: "箭步蹲", weight: 0, reps: 12, sets: 3 },
        { name: "坐姿划船", weight: 25, reps: 12, sets: 4 },
        { name: "面拉", weight: 10, reps: 15, sets: 3 }
      ]
    },
    {
      id: "s3", title: "全身 C", ...relativeSessionDate(6, 19, 5), duration: 48,
      volume: 1750, thisWeek: false,
      items: [
        { name: "杠铃臀推", weight: 30, reps: 10, sets: 4 },
        { name: "哑铃卧推", weight: 10, reps: 10, sets: 4 },
        { name: "绳索下压", weight: 10, reps: 12, sets: 3 }
      ]
    },
    ...demoHistorySessions()
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
  next.equipmentLibrary = next.equipmentLibrary || demoEquipment();
  next.useEquipLibrary = next.useEquipLibrary !== false;
  next.equipLibraryQuery = typeof next.equipLibraryQuery === "string" ? next.equipLibraryQuery : "";
  next.pinnedEquipIds = Array.isArray(next.pinnedEquipIds) ? next.pinnedEquipIds : [];
  next.equipmentStatsPeriod = ["7", "30", "90", "all", "custom"].includes(next.equipmentStatsPeriod)
    ? next.equipmentStatsPeriod
    : "90";
  next.equipmentStatsMetric = ["volume", "sets", "maxWeight", "oneRepMax"].includes(next.equipmentStatsMetric)
    ? next.equipmentStatsMetric
    : "volume";
  next.equipmentStatsCustomStart = /^\d{4}-\d{2}-\d{2}$/.test(next.equipmentStatsCustomStart || "")
    ? next.equipmentStatsCustomStart
    : localDateInputValue(new Date(Date.now() - 30 * 86400000));
  next.equipmentStatsCustomEnd = /^\d{4}-\d{2}-\d{2}$/.test(next.equipmentStatsCustomEnd || "")
    ? next.equipmentStatsCustomEnd
    : localDateInputValue(new Date());

  if (
    Array.isArray(next.sessions)
    && next.sessions.length === 3
    && next.sessions.every((session) => ["s1", "s2", "s3"].includes(session.id))
  ) {
    next.sessions = [...next.sessions, ...demoHistorySessions()];
  }

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
  next.equipSelected = Array.isArray(next.equipSelected) ? next.equipSelected : [];
  next.equipMuscle = next.equipMuscle || "全部";
  next.equipFilter = next.equipFilter || "全部";
  next.equipSelectionOpen = !!next.equipSelectionOpen;
  next.equipRecognitionCandidates = Array.isArray(next.equipRecognitionCandidates) ? next.equipRecognitionCandidates : [];
  next.equipRecognitionPhoto = !!next.equipRecognitionPhoto;
  next.equipLibraryFromProfile = !!next.equipLibraryFromProfile;
  next.workoutDraft = next.workoutDraft && Array.isArray(next.workoutDraft.exercises)
    ? next.workoutDraft
    : null;
  next.workoutAdjustOpen = false;
  next.workoutAdjustDraft = null;
  next.numberPicker = null;
  if (next.workout && typeof next.workout === "object") {
    next.workout.adjustments = next.workout.adjustments && typeof next.workout.adjustments === "object"
      ? next.workout.adjustments
      : {};
  }
  next.workoutCustomDay = null;
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
    equipmentLibrary: demoEquipment(),
    useEquipLibrary: true,
    equipLibraryQuery: "",
    pinnedEquipIds: [],
    equipmentStatsPeriod: "90",
    equipmentStatsMetric: "volume",
    equipmentStatsCustomStart: localDateInputValue(new Date(Date.now() - 30 * 86400000)),
    equipmentStatsCustomEnd: localDateInputValue(new Date()),
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
    equipSelected: [],
    equipMuscle: "全部",
    equipFilter: "全部",
    equipSelectionOpen: false,
    equipRecognitionCandidates: [],
    equipRecognitionPhoto: false,
    equipLibraryFromProfile: false,
    workoutDraft: null,
    workoutAdjustOpen: false,
    workoutAdjustDraft: null,
    numberPicker: null,
    workoutCustomDay: null,
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
    <div class="page-header">
      <div class="row between">
        <button class="icon-btn" onclick="${action}">‹</button>
        <div class="h3">${title}</div>
        <span class="header-spacer" aria-hidden="true"></span>
      </div>
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
        <div class="h3">晚上好，${esc(state.profile.name)}</div>
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
        <div class="tiny faint center" style="margin-top:7px">下一步可调整顺序和负荷</div>
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
          <button class="link" onclick="app.openHistory()">全部 ${state.sessions.length} 次 →</button>
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
        <div class="between" style="margin-bottom:8px">
          <div>
            <div class="small strong">添加动作</div>
            <div class="tiny faint" style="margin-top:2px">还有更多动作，可从完整动作库选择</div>
          </div>
          <button class="link" onclick="app.openPlanExercisePicker()">完整动作库 ›</button>
        </div>
        <div class="tiny faint" style="margin-bottom:6px">推荐</div>
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
        <div class="h3">AI 教练</div>
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

function exercisePickIcon(item) {
  const muscle = item.muscle || "";
  if (muscle.includes("有氧")) return ICONS.cardio;
  if (muscle.includes("手臂")) return ICONS.muscleArms;
  if (muscle.includes("核心")) return ICONS.muscleCore;
  if (muscle.includes("肩")) return ICONS.muscleShoulder;
  if (muscle.includes("胸")) return ICONS.muscleChest;
  if (muscle.includes("背")) return ICONS.muscleBack;
  if (muscle.includes("臀")) return ICONS.muscleGlutes;
  if (muscle.includes("腿")) return ICONS.muscleLegs;
  const map = {
    "固定器械": ICONS.machine,
    "哑铃": ICONS.dumbbell,
    "杠铃": ICONS.barbell,
    "绳索": ICONS.cable,
    "徒手": ICONS.bodyweight,
    "壶铃": ICONS.kettlebell,
    "弹力带": ICONS.band
  };
  return map[item.equip] || ICONS.dumbbell;
}

function equipmentPickerExercises() {
  const query = String(state.equipSearchQuery || "").trim();
  const planning = state.screen === "planExercisePicker";
  const day = planning
    ? state.plan.days.find((item) => item.id === state.planDayId)
    : null;

  return Object.keys(EX).filter((slug) => {
    const item = EX[slug];

    if (planning && day?.exercises.some((exercise) => exercise.slug === slug)) {
      return false;
    }

    const searchMatch = !query
      || item.name.includes(query)
      || item.muscle.includes(query)
      || item.equip.includes(query);

    // 搜索时跨全部动作查找，不受肌群、器械和“已添加”分类限制。
    if (query) return searchMatch;

    const muscleMatch = state.equipMuscle === "全部" || item.muscle === state.equipMuscle;
    const savedMatch = state.equipFilter !== "已添加"
      || state.equipmentLibrary.some((entry) => entry.slug === slug);
    const equipmentMatch = state.equipFilter === "全部"
      || state.equipFilter === "已添加"
      || item.equip === state.equipFilter;
    return searchMatch && muscleMatch && savedMatch && equipmentMatch;
  }).sort((a, b) => {
    const aSaved = state.equipmentLibrary.some((entry) => entry.slug === a);
    const bSaved = state.equipmentLibrary.some((entry) => entry.slug === b);
    if (aSaved !== bSaved) return aSaved ? -1 : 1;
    return EX[a].name.localeCompare(EX[b].name, "zh-CN");
  });
}

function equipmentPickerGrid() {
  const planning = state.screen === "planExercisePicker";
  const sessionPicking = state.screen === "sessionExercisePicker";
  const addMode = planning || sessionPicking;
  const list = equipmentPickerExercises();
  if (!list.length) {
    return `
      <div class="exercise-grid-empty">
        <span class="exercise-grid-empty-icon">${ICONS.search}</span>
        <strong>没有匹配的动作</strong>
        <span>换个肌群或器械试试</span>
      </div>
    `;
  }

  return list.map((slug) => {
    const item = EX[slug];
    const selected = !addMode && state.equipSelected.includes(slug);
    const action = planning
      ? `app.addPlanExercise('${slug}')`
      : sessionPicking
        ? `app.addSessionExercise('${slug}')`
        : `app.openExercise('${slug}')`;
    const label = planning ? "添加到当前训练日" : sessionPicking ? "添加到训练记录" : "查看详情";
    return `
      <div class="exercise-pick-card ${selected ? "selected" : ""}">
        <button class="exercise-pick-main" onclick="${action}" aria-label="${label}：${esc(item.name)}">
          <div class="exercise-pick-art">
            <span class="exercise-pick-glyph" aria-hidden="true">${exercisePickIcon(item)}</span>
            ${item.video !== false ? `<span class="exercise-pick-badge"><span class="exercise-pick-badge-icon" aria-hidden="true">${ICONS.play}</span>讲解</span>` : ""}
            ${addMode ? `<span class="exercise-pick-check">＋</span>` : ""}
          </div>
          <div class="exercise-pick-name">${esc(item.name)}</div>
          <div class="exercise-pick-meta-row">
            <span class="exercise-pick-meta">${item.muscle} · ${item.equip}</span>
            ${addMode ? "" : `<span class="exercise-pick-chevron" aria-hidden="true">›</span>`}
          </div>
        </button>
        ${addMode ? "" : `
          <button
            class="exercise-pick-select ${selected ? "active" : ""}"
            type="button"
            onclick="app.equipmentPickerToggle('${slug}')"
            aria-label="${selected ? "取消选择" : "选择"}：${esc(item.name)}"
            aria-pressed="${selected}"
          >${selected ? "✓" : "+"}</button>
        `}
      </div>
    `;
  }).join("");
}

function equipmentPickerScreen() {
  const planning = state.screen === "planExercisePicker";
  const sessionPicking = state.screen === "sessionExercisePicker";
  const picking = planning || sessionPicking;
  const muscles = ["全部", "胸", "背", "腿", "臀", "肩", "手臂", "核心", "有氧"];
  const equipment = picking
    ? ["全部", ...new Set(Object.values(EX).map((item) => item.equip))]
    : ["全部", "已添加", ...new Set(Object.values(EX).map((item) => item.equip))];
  const selected = picking
    ? []
    : state.equipSelected.map((slug) => ({ slug, ...EX[slug] })).filter((item) => item.name);
  const searching = String(state.equipSearchQuery || "").trim().length > 0;
  const resultCount = equipmentPickerExercises().length;

  return `
    <div class="stack equipment-picker ${picking ? "plan-picker" : ""}" id="equipment-picker-root">
      ${planning ? headerBack("添加动作", "app.closePlanExercisePicker()") : sessionPicking ? headerBack("添加动作", "app.closeSessionExercisePicker()") : ""}

      <div class="equipment-sticky-tools">
        <div class="equipment-search-line">
          <div class="equipment-search-row">
            <span class="equipment-search-icon">${ICONS.search}</span>
            <input id="equipment-picker-search" type="text" placeholder="搜索动作、肌群或器械" value="${esc(state.equipSearchQuery)}" oninput="app.equipmentPickerQuery(this.value)">
            <button id="equipment-search-clear" class="equipment-search-clear" type="button" onclick="app.equipmentPickerClearQuery()" aria-label="清空搜索" ${state.equipSearchQuery ? "" : "hidden"}>×</button>
            ${picking ? "" : `
              <button class="equipment-scan-btn" onclick="app.equipmentRecognitionOpen()" aria-label="拍照识别器械" title="拍照识别">
                ${ICONS.camera}
              </button>
            `}
          </div>
          ${picking ? "" : `
            <button class="equipment-library-btn" onclick="app.equipmentLibraryOpen()" aria-label="器械库" title="器械库">
              ${ICONS.library}
            </button>
          `}
        </div>

        <div id="equipment-search-scope" class="equipment-search-scope" ${searching ? "" : "hidden"}>全库搜索中 · 点分类可退出搜索</div>

        <div class="equipment-filter-scroll">
          ${equipment.map((label) => `
            <button class="equipment-filter ${state.equipFilter === label && !searching ? "active" : ""}" aria-pressed="${state.equipFilter === label && !searching}" onclick="app.equipmentPickerFilter('${label}')">${label}</button>
          `).join("")}
        </div>
      </div>

      <div class="equipment-content-head">
        <div class="equipment-content-title">
          <span>动作库</span>
          <em id="equipment-grid-count" aria-live="polite">${resultCount}</em>
        </div>
        <div class="exercise-grid-hint">${planning ? "点卡片加入训练日" : sessionPicking ? "点卡片添加到训练记录" : "点卡片看详情 · ⊕ 多选"}</div>
      </div>

      <div class="equipment-content-layout">
        <aside class="muscle-sidebar" aria-label="肌群筛选">
          ${muscles.map((label) => `
            <button class="muscle-side-item ${state.equipMuscle === label && !searching ? "active" : ""}" aria-pressed="${state.equipMuscle === label && !searching}" onclick="app.equipmentPickerMuscle('${label}')">${label}</button>
          `).join("")}
        </aside>

        <div class="exercise-pick-grid" id="equipment-picker-grid">${equipmentPickerGrid()}</div>
      </div>
    </div>

    ${picking ? "" : `
      <button class="equipment-selection-fab no-drag ${selected.length ? "has-items" : ""}" onclick="app.equipmentSelectionToggle()" aria-label="已选动作，共 ${selected.length} 个">
        ${ICONS.dumbbell}
        ${selected.length ? `<span class="equipment-selection-fab-count">${selected.length}</span>` : ""}
      </button>

      ${state.equipSelectionOpen ? equipmentSelectionPanel(selected) : ""}
    `}
  `;
}

function equipmentSelectionPanel(selected) {
  const savedSlugs = new Set(state.equipmentLibrary.map((item) => item.slug).filter(Boolean));
  const unsavedCount = selected.filter((item) => !savedSlugs.has(item.slug)).length;
  const librarySubtitle = !selected.length
    ? "先选择动作"
    : unsavedCount === 0
      ? "所选动作都在器械库里"
      : `把 ${unsavedCount} 个动作存入器械库`;

  return `
    <div class="equipment-selection-backdrop no-drag" onclick="app.equipmentSelectionClose()"></div>
    <section class="equipment-selection-popover" role="dialog" aria-label="已选动作">
      <div class="equipment-selection-arrow"></div>
      <div class="equipment-selection-head no-drag">
        <div class="grow">
          <div class="row gap6">
            <span class="h3">已选动作</span>
            <span class="accent small strong">${selected.length}</span>
          </div>
          <div class="tiny muted" style="margin-top:3px">选好后先安排顺序和负荷</div>
        </div>
        ${selected.length ? `<button class="link muted-link" onclick="app.equipmentPickerClear()">清空</button>` : ""}
      </div>

      <div class="equipment-selection-list ${selected.length ? "" : "empty"}">
        ${selected.length ? selected.map((item) => {
          const saved = savedSlugs.has(item.slug);
          return `
            <div class="equipment-selection-row">
              <span class="equipment-selection-glyph">${equipGlyph({ muscle: item.muscle, equip: item.equip })}</span>
              <div class="grow">
                <div class="small strong">${esc(item.name)}</div>
                <div class="tiny faint">${item.muscle} · ${item.equip}${saved ? " · 已在库" : ""}</div>
              </div>
              <button class="equipment-selection-remove" onclick="app.equipmentPickerToggle('${item.slug}')" aria-label="移除 ${esc(item.name)}">×</button>
            </div>
          `;
        }).join("") : `
          <div class="equipment-selection-empty">
            <div class="equipment-selection-empty-icon">${ICONS.dumbbell}</div>
            <div class="h3">还没有选择动作</div>
            <div class="tiny muted">在下面点选动作，再决定生成训练或存入器械库。</div>
          </div>
        `}
      </div>

      <div class="equipment-selection-actions no-drag">
        <button class="selection-action primary" onclick="app.equipmentSelectionMakePlan()" ${selected.length ? "" : "disabled"}>
          <span class="selection-action-icon">${ICONS.plan}</span>
          <span class="selection-action-copy">
            <span class="selection-action-title">制作训练计划</span>
            <span class="selection-action-sub">先排顺序和负荷，再开始训练</span>
          </span>
          <span class="selection-action-chevron">›</span>
        </button>

        <button class="selection-action secondary" onclick="app.equipmentSelectionAddToLibrary()" ${selected.length && unsavedCount ? "" : "disabled"}>
          <span class="selection-action-icon">${ICONS.equipment}</span>
          <span class="selection-action-copy">
            <span class="selection-action-title">加入我的器械库</span>
            <span class="selection-action-sub">${librarySubtitle}</span>
          </span>
          <span class="selection-action-chevron">›</span>
        </button>
      </div>
    </section>
  `;
}

function equipmentCameraScreen() {
  return `
    <div class="equipment-camera-screen">
      <div class="camera-top">
        <button class="camera-icon-btn" onclick="app.equipmentTabOpen()" aria-label="退出拍摄">×</button>
        <div class="camera-title">拍摄器械</div>
        <button class="camera-icon-btn" onclick="app.equipmentCapturePhoto()" aria-label="从相册选择">相册</button>
      </div>

      <div class="camera-view">
        <div class="camera-view-icon">📷</div>
        <div class="camera-view-title">把器械完整放进画面</div>
        <div class="camera-view-hint">避免只拍到局部、边缘或严重遮挡</div>
      </div>

      <div class="camera-bottom">
        <button class="camera-shutter" onclick="app.equipmentCapturePhoto()" aria-label="拍照">
          <span></span>
        </button>
        <div class="camera-shutter-label">拍照</div>
      </div>
    </div>
  `;
}

function equipmentRecognitionScreen() {
  const candidates = state.equipRecognitionCandidates || [];
  return `
    <div class="stack">
      ${headerBack("器械识别", "app.equipmentTabOpen()")}
      <div class="card recognition-head-card">
        <div class="recognition-thumb">${state.equipRecognitionPhoto ? "🏋" : "📷"}</div>
        <div class="grow">
          <div class="tiny faint">照片识别</div>
          <div class="h2">识别你的器械</div>
          <div class="tiny muted">从最匹配到相似候选</div>
          <button class="link" style="margin-top:8px" onclick="app.equipmentRecognitionPhoto()">${state.equipRecognitionPhoto ? "重新拍照" : "拍照或选图"}</button>
        </div>
      </div>

      <div class="between" style="padding:0 2px">
        <div class="h3">匹配器械</div>
        <div class="tiny faint">${candidates.length} 个候选</div>
      </div>

      ${candidates.length ? candidates.map((candidate) => `
        <div class="card tight">
          <div class="between">
            <div>
              <div class="small strong">${esc(EX[candidate.slug].name)}</div>
              <div class="tiny faint">${EX[candidate.slug].muscle} · ${EX[candidate.slug].equip}</div>
            </div>
            <div class="tiny accent">${Math.round(candidate.confidence * 100)}%</div>
          </div>
          <button class="link" style="margin-top:8px" onclick="app.equipmentRecognitionSave('${candidate.slug}')">＋ 加入已选动作</button>
        </div>
      `).join("") : `
        <div class="card recognition-empty">
          <div class="h3">${state.equipRecognitionPhoto ? "暂未识别到动作库中的器械" : "先拍一张器械照片"}</div>
          <div class="tiny muted" style="margin-top:8px;line-height:1.7">${state.equipRecognitionPhoto ? "请拍摄完整器械。边缘灰色物体、遮挡严重或只露出局部的照片，可能无法辨别。" : "支持常见固定器械、绳索、杠铃与哑铃。照片只用于本次识别，不保存。"}</div>
          <button class="btn btn-secondary" style="margin-top:14px" onclick="app.equipmentRecognitionPhoto()">${state.equipRecognitionPhoto ? "重新拍照" : "模拟拍照"}</button>
        </div>
      `}
    </div>
  `;
}

function filteredEquipmentLibraryItems() {
  const query = String(state.equipLibraryQuery || "").trim().toLowerCase();
  const items = !query
    ? state.equipmentLibrary
    : state.equipmentLibrary.filter((item) => {
        return [item.name, item.muscle, item.equip]
          .some((value) => String(value || "").toLowerCase().includes(query));
      });
  const pinned = new Set(state.pinnedEquipIds || []);
  return [...items].sort((a, b) => Number(pinned.has(b.id)) - Number(pinned.has(a.id)));
}

function equipmentLibraryRowMarkup(item) {
  const pinned = (state.pinnedEquipIds || []).includes(item.id);
  return `
    <div class="library-swipe-row" data-library-id="${item.id}">
      <div class="library-swipe-action">
        <button onclick="app.deleteEquipItem('${item.id}')">删除</button>
      </div>
      <button class="library-row no-drag" onclick="app.openEquipItem('${item.id}')">
        <span class="library-thumb">${equipGlyph(item)}</span>
        <span class="library-row-copy">
          <span class="library-row-name">${esc(item.name)}</span>
          <span class="library-row-meta">${item.muscle} · ${item.equip}</span>
        </span>
        ${pinned ? `<span class="library-pin" title="已置顶">${ICONS.pin}</span>` : ""}
        <span class="library-video ${item.video ? "ready" : ""}">
          ${item.video ? "教学视频" : "视频准备中"}
        </span>
        <span class="library-chevron">›</span>
      </button>
    </div>
  `;
}

function equipmentLibraryResultsMarkup(items) {
  if (!state.equipmentLibrary.length) {
    return `
      <div class="library-empty">
        <div class="library-empty-icon">${ICONS.dumbbell}</div>
        <div class="library-empty-title">器械库还是空的</div>
        <div class="library-empty-copy">拍照或从相册识别第一件器械，AI 生成计划时会优先使用它。</div>
        <button class="btn btn-primary" style="margin-top:14px" onclick="app.equipmentRecognitionOpen()">添加第一件器械</button>
      </div>
    `;
  }

  if (!items.length) {
    return `
      <div class="library-empty">
        <div class="library-empty-icon">${ICONS.search}</div>
        <div class="library-empty-title">没有匹配的器械</div>
        <div class="library-empty-copy">换个名称、肌群或器械类型试试。</div>
        <button class="btn btn-secondary" style="margin-top:14px" onclick="app.equipmentLibraryClearQuery()">清空搜索</button>
      </div>
    `;
  }

  return `
    <div class="library-list">
      ${items.map(equipmentLibraryRowMarkup).join("")}
    </div>
  `;
}

function equipmentLibraryScreen() {
  const items = state.equipmentLibrary;
  const filtered = filteredEquipmentLibraryItems();
  const query = String(state.equipLibraryQuery || "");
  const backAction = state.equipLibraryFromProfile ? "app.backTo('profile')" : "app.equipmentTabOpen()";

  return `
    <div class="stack equipment-library-screen">
      <div class="page-header">
        <div class="row between">
          <button class="icon-btn" onclick="${backAction}" aria-label="返回">‹</button>
          <div class="h3">器械库</div>
          <span class="header-spacer" aria-hidden="true"></span>
        </div>
      </div>

      <section class="library-overview">
        <div class="library-overview-main">
          <div class="library-overview-icon">${ICONS.dumbbell}</div>
          <div class="grow">
            <div class="library-overview-label">我的器械</div>
            <div class="library-overview-value"><span>${items.length}</span><span>件</span></div>
            <div class="library-overview-note">教学视频与 AI 计划会优先读取这里</div>
          </div>
        </div>

        <div class="library-plan-row">
          <div class="grow">
            <div class="library-plan-title">计划优先使用</div>
            <div class="library-plan-note">${state.useEquipLibrary ? "生成计划时优先匹配我的器械" : "已关闭，按档案器械生成"}</div>
          </div>
          <button
            class="library-switch ${state.useEquipLibrary ? "active" : ""}"
            role="switch"
            aria-checked="${state.useEquipLibrary}"
            onclick="app.toggleEquipLibrary()"
          >
            <span></span>
          </button>
        </div>
      </section>

      <div class="library-tools">
        <div class="library-search">
          <span class="library-search-icon">${ICONS.search}</span>
          <input
            id="library-search"
            type="text"
            placeholder="搜索我的器械"
            value="${esc(query)}"
            oninput="app.equipmentLibraryQuery(this.value)"
          >
          <button
            id="library-search-clear"
            class="library-search-clear"
            onclick="app.equipmentLibraryClearQuery()"
            aria-label="清空搜索"
            ${query.trim() ? "" : "hidden"}
          >×</button>
        </div>
        <button class="library-add-btn" onclick="app.equipmentRecognitionOpen()" aria-label="添加器械">
          ${ICONS.camera}
        </button>
      </div>

      <div class="library-section-head">
        <span>器械清单</span>
        <span><span id="library-list-count">${filtered.length} 件</span><span class="library-swipe-hint"> · 左滑删除</span></span>
      </div>

      <div id="library-list-root">
        ${equipmentLibraryResultsMarkup(filtered)}
      </div>

      <div class="library-note">器械库会作为 AI 生成计划的可用来源。删除器械不会影响历史训练记录。</div>
    </div>
  `;
}

function equipmentDetailExercise(item) {
  return item.slug ? EX[item.slug] : null;
}

function equipmentDetailPoints(item) {
  const exercise = equipmentDetailExercise(item);
  const fromLibrary = exercise?.cues || "";
  const points = fromLibrary
    .split(/[。；;]/)
    .map((point) => point.trim())
    .filter(Boolean);

  const general = [
    "先调整座位、靠垫或把手高度，确认起始位置稳定，再开始发力。",
    "全程保持核心收紧、呼吸自然；最后几次也不要靠惯性甩动。",
    "如果出现关节刺痛、麻木或明显代偿，降低重量或停止动作。"
  ];

  general.forEach((point) => {
    if (points.length < 3 && !points.includes(point)) points.push(point);
  });

  return points.slice(0, 5);
}

function equipmentDetailSupport(item) {
  const map = {
    "胸": ["肩", "手臂"],
    "背": ["手臂", "核心"],
    "腿": ["臀", "核心"],
    "臀": ["腿", "核心"],
    "肩": ["手臂", "核心"],
    "手臂": ["肩", "核心"],
    "核心": ["背", "臀"],
    "有氧": ["腿", "核心"]
  };
  return map[item.muscle] || ["核心", "稳定"];
}

function equipmentSessionTimestamp(session) {
  if (Number.isFinite(Number(session.timestamp)) && Number(session.timestamp) > 0) {
    return Number(session.timestamp);
  }
  const raw = String(session.date || "").trim();
  if (!raw) return Number.NaN;
  if (raw.includes("刚刚")) return Date.now();
  const match = raw.match(/(\d{1,2})月(\d{1,2})日(?:\s*(\d{1,2}):(\d{2}))?/);
  if (!match) return Number.NaN;
  const now = new Date();
  const date = new Date(
    now.getFullYear(),
    Number(match[1]) - 1,
    Number(match[2]),
    Number(match[3] || 12),
    Number(match[4] || 0),
    0,
    0
  );
  if (date.getTime() > now.getTime() + 86400000) {
    date.setFullYear(now.getFullYear() - 1);
  }
  return date.getTime();
}

function equipmentParseDateInput(value, endOfDay = false) {
  const match = String(value || "").match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return null;
  const date = new Date(
    Number(match[1]),
    Number(match[2]) - 1,
    Number(match[3]),
    endOfDay ? 23 : 0,
    endOfDay ? 59 : 0,
    endOfDay ? 59 : 0,
    endOfDay ? 999 : 0
  );
  return Number.isNaN(date.getTime()) ? null : date.getTime();
}

function equipmentDetailAllPoints(item) {
  const names = new Set([item.name, item.slug ? EX[item.slug]?.name : null].filter(Boolean));
  const points = [];

  state.sessions.forEach((session) => {
    const matching = (session.items || []).filter((entry) => names.has(entry.name));
    if (!matching.length) return;

    const timestamp = equipmentSessionTimestamp(session);
    if (!Number.isFinite(timestamp)) return;

    const volume = matching.reduce((sum, entry) => {
      return sum + (Number(entry.weight) || 0) * (Number(entry.reps) || 0) * (Number(entry.sets) || 0);
    }, 0);
    const sets = matching.reduce((sum, entry) => sum + (Number(entry.sets) || 0), 0);
    const maxWeight = matching.reduce((max, entry) => {
      return Math.max(max, Number(entry.weight) || 0);
    }, 0);
    const estimated1RM = matching.reduce((max, entry) => {
      const weight = Number(entry.weight) || 0;
      const reps = Number(entry.reps) || 0;
      const estimate = weight > 0 && reps > 0 ? weight * (1 + reps / 30) : 0;
      return Math.max(max, estimate);
    }, 0);

    points.push({
      timestamp,
      date: session.date,
      volume,
      sets,
      maxWeight,
      estimated1RM
    });
  });

  return points.sort((a, b) => a.timestamp - b.timestamp);
}

function equipmentDetailPeriodWindow() {
  const period = state.equipmentStatsPeriod || "90";
  const now = Date.now();

  if (period === "all") {
    return { start: null, end: null, label: "全部" };
  }

  if (period === "custom") {
    const start = equipmentParseDateInput(state.equipmentStatsCustomStart, false);
    const end = equipmentParseDateInput(state.equipmentStatsCustomEnd, true);
    return {
      start,
      end,
      label: "自定义",
      invalid: start == null || end == null || start > end
    };
  }

  const days = Number(period) || 90;
  return {
    start: now - days * 86400000,
    end: now + 1,
    label: `${days} 天`
  };
}

function equipmentDetailStats(item) {
  const all = equipmentDetailAllPoints(item);
  const window = equipmentDetailPeriodWindow();
  const points = window.invalid
    ? []
    : all.filter((point) => {
        if (window.start != null && point.timestamp < window.start) return false;
        if (window.end != null && point.timestamp > window.end) return false;
        return true;
      });

  return {
    all,
    points,
    window,
    sessions: points.length,
    sets: points.reduce((sum, point) => sum + point.sets, 0),
    volume: points.reduce((sum, point) => sum + point.volume, 0),
    maxWeight: points.reduce((max, point) => Math.max(max, point.maxWeight), 0),
    best1RM: points.reduce((max, point) => Math.max(max, point.estimated1RM), 0),
    last: points[points.length - 1]?.date || null
  };
}

function equipmentDetailMetricMeta(metric) {
  return {
    volume: { label: "容量", unit: "kg" },
    sets: { label: "组数", unit: "组" },
    maxWeight: { label: "最大重量", unit: "kg" },
    oneRepMax: { label: "1RM 预测", unit: "kg" }
  }[metric] || { label: "容量", unit: "kg" };
}

function equipmentDetailMetricValue(point, metric) {
  if (metric === "sets") return point.sets;
  if (metric === "maxWeight") return point.maxWeight;
  if (metric === "oneRepMax") return point.estimated1RM;
  return point.volume;
}

function equipmentFormatWeight(value) {
  const number = Number(value) || 0;
  if (number === 0) return "—";
  return Number.isInteger(number) ? number.toLocaleString() : number.toFixed(1);
}

function equipmentFormatAxis(value, metric) {
  const number = Number(value) || 0;
  if (number >= 1000) return `${(number / 1000).toFixed(number >= 10000 ? 0 : 1)}k`;
  return String(Math.round(number));
}

function equipmentChartDate(timestamp, includeYear = false) {
  const date = new Date(timestamp);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return includeYear
    ? `${date.getFullYear()}/${month}/${day}`
    : `${month}/${day}`;
}

function equipmentDetailLineChart(stats) {
  if (!stats.points.length) {
    return `
      <div class="detail-chart-empty">
        <span class="detail-chart-empty-icon">${ICONS.chart}</span>
        <strong>这个周期还没有训练记录</strong>
        <span>换一个周期，或完成一次 ${esc(state.equipmentLibrary.find((entry) => entry.id === state.equipmentItemId)?.name || "这个动作")} 训练。</span>
      </div>
    `;
  }

  const metric = state.equipmentStatsMetric || "volume";
  const meta = equipmentDetailMetricMeta(metric);
  const width = 320;
  const height = 190;
  const padding = { top: 18, right: 12, bottom: 30, left: 37 };
  const plotWidth = width - padding.left - padding.right;
  const plotHeight = height - padding.top - padding.bottom;

  let domainStart = stats.window.start;
  let domainEnd = stats.window.end;
  if (domainStart == null) domainStart = stats.points[0].timestamp;
  if (domainEnd == null) domainEnd = stats.points[stats.points.length - 1].timestamp;
  if (domainEnd <= domainStart) {
    domainStart -= 86400000;
    domainEnd += 86400000;
  }

  const values = stats.points.map((point) => equipmentDetailMetricValue(point, metric));
  const maxValue = Math.max(0, ...values);
  const yMax = maxValue > 0 ? maxValue * 1.12 : 1;

  const xFor = (timestamp) => {
    return padding.left + Math.max(0, Math.min(1, (timestamp - domainStart) / (domainEnd - domainStart))) * plotWidth;
  };
  const yFor = (value) => {
    return padding.top + plotHeight - Math.max(0, Math.min(1, value / yMax)) * plotHeight;
  };

  const points = stats.points.map((point, index) => {
    const value = equipmentDetailMetricValue(point, metric);
    return {
      ...point,
      index,
      value,
      x: xFor(point.timestamp),
      y: yFor(value)
    };
  });

  const linePath = points.map((point, index) => `${index === 0 ? "M" : "L"} ${point.x.toFixed(1)} ${point.y.toFixed(1)}`).join(" ");
  const first = points[0];
  const last = points[points.length - 1];
  const areaPath = `M ${first.x.toFixed(1)} ${(padding.top + plotHeight).toFixed(1)} ${linePath.replace(/^M /, "L ")} L ${last.x.toFixed(1)} ${(padding.top + plotHeight).toFixed(1)} Z`;

  const gridMarkup = [0, 0.5, 1].map((ratio) => {
    const y = padding.top + plotHeight - ratio * plotHeight;
    return `
      <line class="detail-line-grid" x1="${padding.left}" y1="${y.toFixed(1)}" x2="${width - padding.right}" y2="${y.toFixed(1)}" />
      <text class="detail-line-y-label" x="${padding.left - 7}" y="${(y + 3).toFixed(1)}" text-anchor="end">${equipmentFormatAxis(yMax * ratio, metric)}</text>
    `;
  }).join("");

  const spanDays = (domainEnd - domainStart) / 86400000;
  const includeYear = spanDays > 300;
  const labelPoints = points.length <= 3
    ? points
    : [points[0], points[Math.floor((points.length - 1) / 2)], points[points.length - 1]];
  const xLabels = labelPoints.map((point, index) => {
    const anchor = index === 0
      ? "start"
      : index === labelPoints.length - 1
        ? "end"
        : "middle";
    return `<text class="detail-line-x-label" x="${point.x.toFixed(1)}" y="${height - 8}" text-anchor="${anchor}">${equipmentChartDate(point.timestamp, includeYear)}</text>`;
  }).join("");

  const dots = points.map((point) => `
    <g class="detail-line-point-group">
      <circle class="detail-line-point-halo" cx="${point.x.toFixed(1)}" cy="${point.y.toFixed(1)}" r="7" />
      <circle class="detail-line-point" cx="${point.x.toFixed(1)}" cy="${point.y.toFixed(1)}" r="3.2">
        <title>${esc(point.date)} · ${meta.label} ${equipmentFormatWeight(point.value)} ${meta.unit}</title>
      </circle>
    </g>
  `).join("");

  return `
    <div class="detail-line-chart-wrap">
      <svg class="detail-line-chart" viewBox="0 0 ${width} ${height}" role="img" aria-label="${meta.label}趋势折线图">
        <defs>
          <linearGradient id="detailLineGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#30d158" stop-opacity="0.34" />
            <stop offset="100%" stop-color="#30d158" stop-opacity="0" />
          </linearGradient>
        </defs>
        ${gridMarkup}
        ${xLabels}
        <path class="detail-line-area" d="${areaPath}" fill="url(#detailLineGradient)" />
        <path class="detail-line-stroke" d="${linePath}" />
        ${dots}
      </svg>
      <div class="detail-line-chart-last">
        <strong>${equipmentFormatWeight(last.value)}</strong>
        <span>${meta.unit}</span>
      </div>
    </div>
    <div class="detail-line-chart-caption">
      <span>${meta.label}趋势</span>
      <span>${stats.points.length} 次记录 · 每个点代表一次训练</span>
    </div>
  `;
}

function equipmentDetailMuscleMap(item) {
  const muscle = item.muscle || "全身";
  const support = equipmentDetailSupport(item);
  const key = {
    "胸": "chest",
    "背": "back",
    "腿": "legs",
    "臀": "glutes",
    "肩": "shoulders",
    "手臂": "arms",
    "核心": "core",
    "有氧": "cardio"
  }[muscle] || "cardio";

  return `
    <div class="detail-muscle-title">人体肌肉的部位训练概况</div>
    <div class="detail-muscle-figure">
      <img
        class="detail-muscle-anatomy"
        src="assets/muscles/${key}@2x.png"
        alt="人体正面与背面肌肉示意图，重点训练 ${esc(muscle)}，辅助 ${esc(support.join("、"))}"
        loading="lazy"
      >
    </div>
    <div class="detail-muscle-caption">
      <span>重点 <strong>${esc(muscle)}</strong> · 辅助 ${esc(support.join(" · "))}</span>
      <span class="detail-muscle-credit">OpenStax / Nefronus · CC BY-SA 4.0</span>
    </div>
  `;
}

function equipmentDetailSection(index, title, lead, body, id = "") {
  return `
    <section class="detail-section" ${id ? `id="${id}"` : ""}>
      <div class="detail-section-index">${index}</div>
      <h2>${title}</h2>
      <p class="detail-section-lead">${lead}</p>
      ${body}
    </section>
  `;
}

function exerciseEquipmentItem(slug) {
  const exercise = EX[slug];
  if (!exercise) return null;
  return {
    id: `preview-${slug}`,
    name: exercise.name,
    slug,
    muscle: exercise.muscle,
    equip: exercise.equip,
    video: false,
    notes: ""
  };
}

function equipmentItemScreen() {
  const libraryItem = state.equipmentLibrary.find((entry) => entry.id === state.equipmentItemId);
  const previewItem = !libraryItem && state.selectedExercise
    ? exerciseEquipmentItem(state.selectedExercise)
    : null;
  const item = libraryItem || previewItem;
  if (!item) return equipmentLibraryScreen();
  const isPreview = !!previewItem;

  const exercise = equipmentDetailExercise(item);
  const points = equipmentDetailPoints(item);
  const support = equipmentDetailSupport(item);
  const stats = equipmentDetailStats(item);
  const pinned = !isPreview && (state.pinnedEquipIds || []).includes(item.id);
  const muscle = item.muscle || "全身";
  const description = exercise?.cues
    || item.notes
    || "先用稳定、可控的轨迹完成动作，再逐步增加重量和训练量。";
  const period = state.equipmentStatsPeriod || "90";
  const metric = state.equipmentStatsMetric || "volume";
  const metricMeta = equipmentDetailMetricMeta(metric);
  const todayValue = localDateInputValue(new Date());
  const periodLabel = stats.window.label;

  const pointsMarkup = points.map((point, index) => `
    <div class="detail-point">
      <span class="detail-point-index">${index + 1}</span>
      <p>${esc(point)}</p>
    </div>
  `).join("");

  const periodOptions = [
    { key: "7", label: "7天" },
    { key: "30", label: "30天" },
    { key: "90", label: "90天" },
    { key: "all", label: "全部" },
    { key: "custom", label: "自定义" }
  ];

  const metricOptions = [
    { key: "volume", label: "容量" },
    { key: "sets", label: "组数" },
    { key: "maxWeight", label: "最大重量" },
    { key: "oneRepMax", label: "1RM 预测" }
  ];

  const periodControls = `
    <div class="detail-period-label">统计周期</div>
    <div class="detail-period-tabs">
      ${periodOptions.map((option) => `
        <button class="${period === option.key ? "active" : ""}" onclick="app.equipmentDetailPeriod('${option.key}')">${option.label}</button>
      `).join("")}
    </div>
    ${period === "custom" ? `
      <div class="detail-custom-range">
        <label>开始<input type="date" value="${state.equipmentStatsCustomStart}" max="${todayValue}" onchange="app.equipmentDetailCustomStart(this.value)"></label>
        <span>—</span>
        <label>结束<input type="date" value="${state.equipmentStatsCustomEnd}" max="${todayValue}" onchange="app.equipmentDetailCustomEnd(this.value)"></label>
      </div>
      ${stats.window.invalid ? `<div class="detail-period-error">开始日期不能晚于结束日期。</div>` : ""}
    ` : ""}
  `;

  const metricControls = `
    <div class="detail-metric-tabs">
      ${metricOptions.map((option) => `
        <button class="${metric === option.key ? "active" : ""}" onclick="app.equipmentDetailMetric('${option.key}')">${option.label}</button>
      `).join("")}
    </div>
  `;

  const chartMarkup = equipmentDetailLineChart(stats);

  const summaryMarkup = `
    <div class="detail-stat-grid detail-stat-records">
      <div>
        <span>容量记录</span>
        <strong>${stats.sessions ? stats.volume.toLocaleString() : "—"}</strong>
        <small>kg · 累计</small>
      </div>
      <div>
        <span>重量记录</span>
        <strong>${stats.sessions ? (stats.maxWeight > 0 ? equipmentFormatWeight(stats.maxWeight) : "自重") : "—"}</strong>
        <small>kg · 单组最重</small>
      </div>
      <div>
        <span>1RM 预测</span>
        <strong>${stats.sessions && stats.best1RM > 0 ? equipmentFormatWeight(stats.best1RM) : "—"}</strong>
        <small>kg · Epley</small>
      </div>
    </div>
  `;

  return `
    <div class="stack equipment-detail-screen">
      ${headerBack(
        isPreview ? "动作详情" : "器械详情",
        isPreview ? "app.backTo('equipment')" : "app.equipmentLibraryOpen()"
      )}

      <div class="detail-quick-card">
        <div class="detail-quick-title">
          <span class="detail-quick-glyph">${equipGlyph(item)}</span>
          <span>${esc(item.name)}</span>
        </div>
        <div class="detail-quick-actions">
          <button onclick="app.equipmentDetailScroll('detail-points')" aria-label="动作要点">
            ${ICONS.checklist}<span>要点</span>
          </button>
          <button onclick="app.equipmentDetailScroll('detail-stats')" aria-label="训练历史">
            ${ICONS.clock}<span>历史</span>
          </button>
          <button onclick="app.equipmentDetailScroll('detail-stats')" aria-label="训练图表">
            ${ICONS.chart}<span>图表</span>
          </button>
          ${isPreview ? "" : `
            <button id="detail-pin" class="${pinned ? "active" : ""}" onclick="app.equipmentDetailPin('${item.id}')" aria-label="${pinned ? "取消置顶" : "置顶器械"}">
              ${ICONS.pin}<span>置顶</span>
            </button>
          `}
        </div>
      </div>

      <div class="detail-hero">
        <div class="detail-eyebrow">动作学习预览</div>
        <h1 class="detail-title">${esc(item.name)}</h1>
        <p class="detail-description">${esc(description)}</p>
        <div class="detail-tags">
          <span>${muscle}</span>
          <span>${item.equip}</span>
          ${item.video ? "<span class=\"ready\">教学视频</span>" : "<span>视频准备中</span>"}
        </div>
      </div>

      ${equipmentDetailSection(
        "01",
        "视频讲解",
        "先看动作讲解，再看后面要点，会更容易抓住发力顺序。",
        `<div class="detail-video-card ${item.video ? "ready" : ""}">
          <div class="detail-video-glyph">${equipGlyph(item)}</div>
          <div class="detail-video-play">▶</div>
          <div class="detail-video-copy">
            <strong>${item.video ? "点一下播放动作讲解" : "教学视频准备中"}</strong>
            <span>${item.video ? "先看讲解，再开始今天的训练。" : (isPreview ? "这个动作的官方示范视频还在准备中。" : "这件器械的官方示范视频还在准备中。")}</span>
          </div>
          <span class="detail-video-badge">${item.video ? "官方教学视频" : "视频待上线"}</span>
        </div>`
      )}

      ${equipmentDetailSection(
        "02",
        "动作轨迹",
        "先用轨迹示意建立动作路径，再在训练中把速度放慢。",
        `<div class="detail-motion-board">
          <span class="detail-motion-line line-one"></span>
          <span class="detail-motion-line line-two"></span>
          <span class="detail-motion-line line-three"></span>
          <div class="detail-motion-glyph">${equipGlyph(item)}</div>
          <div class="detail-motion-copy">
            <strong>保持轨迹稳定</strong>
            <span>起始位置、发力方向和还原速度，比盲目加重量更重要。</span>
          </div>
          <span class="detail-motion-expand">↗</span>
        </div>`
      )}

      ${equipmentDetailSection(
        "03",
        "多角度示范",
        "示范素材准备中。先用要点确认起始位置和身体角度。",
        `<div class="detail-angle-grid">
          ${["正面", "侧面", "发力", "细节"].map((label, index) => `
            <div class="detail-angle ${index > 1 ? "locked" : ""}">
              <div class="detail-angle-art">${index > 1 ? "◌" : equipGlyph(item)}</div>
              <span>${label}</span>
            </div>
          `).join("")}
        </div>
        <div class="detail-mini-note">示范素材准备中；先用下面的动作要点确认起始位置和发力顺序。</div>`
      )}

      ${equipmentDetailSection(
        "04",
        "动作要点",
        "下面的要点来自动作库和你的器械备注。",
        `<div class="detail-point-list">${pointsMarkup}</div>
         <div class="detail-tip">${item.notes ? `器械备注：${esc(item.notes)}` : "先用轻重量确认动作路线，再逐步接近目标负荷。"}</div>`,
        "detail-points"
      )}

      ${equipmentDetailSection(
        "05",
        "训练肌群",
        `主要训练 ${muscle}，协同稳定由 ${support.join("、")} 参与。`,
        `${equipmentDetailMuscleMap(item)}`
      )}

      ${equipmentDetailSection(
        "06",
        "训练数据",
        stats.window.invalid
          ? "开始日期不能晚于结束日期。"
          : stats.sessions
            ? `${periodLabel} · ${stats.sessions} 次训练 / ${stats.sets} 组${stats.last ? `，最近一次 ${stats.last}` : ""}。`
            : "所选周期还没有这个动作的训练记录。",
        `${summaryMarkup}
        <div class="detail-chart-heading">
          <div>
            <span>记录趋势</span>
            <strong>${metricMeta.label}</strong>
          </div>
          <span class="detail-chart-current">${stats.points.length ? equipmentFormatWeight(equipmentDetailMetricValue(stats.points[stats.points.length - 1], metric)) : "—"} ${metricMeta.unit}</span>
        </div>
        ${periodControls}
        ${metricControls}
        ${chartMarkup}
        <div class="detail-chart-note">每个点代表一次有该动作的训练记录。1RM 为 Epley 公式估算，仅用于趋势对比，不等于实测极限。</div>`,
        "detail-stats"
      )}

      <div class="detail-coach-card">
        <div class="detail-coach-avatar">AI</div>
        <div class="grow">
          <div class="detail-coach-title">动作细节还不确定？</div>
          <div class="detail-coach-copy">让教练结合你的计划，解释起始位置、发力顺序和替代动作。</div>
        </div>
        <button class="detail-coach-action" onclick="${item.slug ? `app.askCoach('${item.slug}')` : "app.tab('coach')"}">问教练</button>
      </div>

      ${isPreview ? "" : `<button class="detail-delete" onclick="app.deleteEquipItem('${item.id}')">从器械库删除</button>`}
      <div class="detail-disclaimer">出现关节刺痛、麻木或肿胀时请停止动作并咨询专业人士。教学视频和示范素材由官方动作库提供。</div>
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

/* ---------------- Profile ---------------- */

function profileScreen() {
  const p = state.profile;
  return `
    <div class="stack">
      <div class="row" style="justify-content:flex-end">
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

      <div class="card" onclick="app.equipmentLibraryOpen('profile')" style="cursor:pointer">
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

/* ---------------- Custom workout compose ---------------- */

function workoutRepOptions(current) {
  const options = Array.from({ length: 30 }, (_, index) => String(index + 1));
  const normalized = String(parseReps(current));
  return options.includes(normalized) ? options : [normalized, ...options];
}

function workoutRestOptions(current) {
  const options = [0, 30, 45, 60, 75, 90, 120, 150, 180];
  const normalized = Number(current) || 0;
  return options.includes(normalized) ? options : [...options, normalized].sort((a, b) => a - b);
}

function workoutPickerOptions(key, current) {
  if (key === "sets") {
    return Array.from({ length: 10 }, (_, index) => ({
      value: String(index + 1),
      label: String(index + 1)
    }));
  }
  if (key === "reps") {
    return workoutRepOptions(current).map((value) => ({ value, label: value }));
  }
  return workoutRestOptions(current).map((value) => ({
    value: String(value),
    label: String(value)
  }));
}

function workoutPickerTitle(key) {
  return {
    sets: "组数 · 组",
    reps: "每组次数 · 次",
    rest: "组间休息 · 秒"
  }[key] || "选择数值";
}

function pickerFieldButton({ value, onclick, label }) {
  return `
    <button class="picker-field" type="button" onclick="${onclick}" aria-label="${label}">
      <span>${value}</span>
      <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true">
        <path d="m5 6 3-3 3 3M5 10l3 3 3-3"/>
      </svg>
    </button>
  `;
}

function numberPickerSheet() {
  const picker = state.numberPicker;
  if (!picker) return "";
  const selectedIndex = Math.max(0, picker.options.findIndex((option) => String(option.value) === String(picker.value)));
  const selected = picker.options[selectedIndex] || picker.options[0];

  return `
    <div class="number-picker-backdrop no-drag" onclick="app.closeNumberPicker()">
      <section class="number-picker-sheet no-drag" role="dialog" aria-modal="true" aria-label="${picker.title}" onclick="event.stopPropagation()">
        <header class="number-picker-head">
          <button class="number-picker-cancel" onclick="app.closeNumberPicker()">取消</button>
          <div class="number-picker-heading">
            <span>${picker.title}</span>
            <strong id="number-picker-current">${selected?.label || ""}</strong>
          </div>
          <button class="number-picker-confirm" onclick="app.confirmNumberPicker()">确认</button>
        </header>
        <div class="number-picker-wheel-wrap">
          <div class="number-picker-center" aria-hidden="true"></div>
          <div class="number-picker-wheel" id="number-picker-wheel">
            <div class="number-picker-spacer" aria-hidden="true"></div>
            ${picker.options.map((option, index) => `
              <button class="number-picker-option ${index === selectedIndex ? "selected" : ""}" data-index="${index}" data-value="${option.value}" onclick="app.scrollNumberPicker(${index})">${option.label}</button>
            `).join("")}
            <div class="number-picker-spacer" aria-hidden="true"></div>
          </div>
        </div>
      </section>
    </div>
  `;
}

function setupNumberPicker() {
  const picker = state.numberPicker;
  const wheel = document.getElementById("number-picker-wheel");
  if (!picker || !wheel) return;

  const itemHeight = 46;
  const options = picker.options;
  const currentIndex = Math.max(0, options.findIndex((option) => String(option.value) === String(picker.value)));
  let selectedIndex = currentIndex;

  const updateSelection = (index) => {
    const bounded = Math.max(0, Math.min(options.length - 1, index));
    selectedIndex = bounded;
    state.numberPicker.value = options[bounded].value;
    wheel.querySelectorAll(".number-picker-option").forEach((option, optionIndex) => {
      option.classList.toggle("selected", optionIndex === bounded);
    });
    const current = document.getElementById("number-picker-current");
    if (current) current.textContent = options[bounded].label;
  };

  wheel.scrollTop = currentIndex * itemHeight;
  wheel.addEventListener("scroll", () => {
    updateSelection(Math.round(wheel.scrollTop / itemHeight));
  }, { passive: true });

  // Let the browser lay out the sheet before positioning the wheel.
  requestAnimationFrame(() => {
    wheel.scrollTop = currentIndex * itemHeight;
    updateSelection(currentIndex);
  });
}

function setupComposeDrag() {
  const list = document.querySelector(".compose-list");
  if (!list || list.dataset.dragReady === "1") return;
  list.dataset.dragReady = "1";
  let drag = null;

  const clearTarget = () => {
    list.querySelectorAll(".compose-exercise.drop-target").forEach((card) => {
      card.classList.remove("drop-target");
    });
  };

  list.addEventListener("pointerdown", (event) => {
    const handle = event.target.closest("[data-compose-drag]");
    if (!handle) return;
    const card = handle.closest(".compose-exercise");
    if (!card) return;
    event.preventDefault();
    drag = {
      pointerId: event.pointerId,
      source: Number(card.dataset.composeIndex),
      target: Number(card.dataset.composeIndex),
      card
    };
    card.classList.add("dragging");
    handle.setPointerCapture?.(event.pointerId);
  });

  list.addEventListener("pointermove", (event) => {
    if (!drag || event.pointerId !== drag.pointerId) return;
    const scroller = list.closest(".compose-scroll");
    const bounds = scroller?.getBoundingClientRect();
    if (scroller && bounds) {
      if (event.clientY < bounds.top + 56) scroller.scrollTop -= 12;
      else if (event.clientY > bounds.bottom - 56) scroller.scrollTop += 12;
    }
    const target = document.elementFromPoint(event.clientX, event.clientY)?.closest(".compose-exercise");
    clearTarget();
    if (!target) return;
    const targetIndex = Number(target.dataset.composeIndex);
    if (Number.isInteger(targetIndex)) {
      drag.target = targetIndex;
      if (targetIndex !== drag.source) target.classList.add("drop-target");
    }
  });

  const finish = (event) => {
    if (!drag || event.pointerId !== drag.pointerId) return;
    const { source, target, card } = drag;
    drag = null;
    clearTarget();
    card.classList.remove("dragging");
    if (source !== target) app.workoutDraftMoveTo(source, target);
  };

  list.addEventListener("pointerup", finish);
  list.addEventListener("pointercancel", finish);
}

function renderKeepingComposeScroll() {
  const scrollTop = document.querySelector(".compose-scroll")?.scrollTop || 0;
  render();
  requestAnimationFrame(() => {
    const scroller = document.querySelector(".compose-scroll");
    if (scroller) scroller.scrollTop = scrollTop;
  });
}

function workoutComposeTotals(draft) {
  const exercises = Array.isArray(draft?.exercises) ? draft.exercises : [];
  const sets = exercises.reduce((sum, item) => sum + (Number(item.sets) || 0), 0);
  const restMinutes = exercises.reduce(
    (sum, item) => sum + (Number(item.sets) || 0) * (Number(item.rest) || 0) / 60,
    0
  );
  return {
    exercises: exercises.length,
    sets,
    minutes: Math.max(15, Math.round(restMinutes + exercises.length * 3))
  };
}

function updateComposeSummary() {
  const totals = workoutComposeTotals(state.workoutDraft);
  const sets = document.getElementById("compose-total-sets");
  const minutes = document.getElementById("compose-total-minutes");
  const footer = document.getElementById("compose-footer-summary");
  if (sets) sets.textContent = String(totals.sets);
  if (minutes) minutes.textContent = String(totals.minutes);
  if (footer) footer.textContent = `${totals.sets} 组 · 约 ${totals.minutes} 分钟`;
}

function workoutComposeScreen() {
  const draft = state.workoutDraft;
  if (!draft || !Array.isArray(draft.exercises)) return equipmentPickerScreen();
  const totals = workoutComposeTotals(draft);
  const isPlan = draft.source === "plan";

  return `
    <div class="workout-compose">
      <header class="workout-topbar">
        <button class="icon-btn" onclick="app.closeWorkoutCompose()" aria-label="${isPlan ? "返回首页" : "返回动作库"}">‹</button>
        <div class="workout-title">安排训练</div>
        <span class="workout-topbar-spacer" aria-hidden="true"></span>
      </header>

      <div class="compose-scroll">
      <section class="compose-hero">
        <div class="compose-kicker">${isPlan ? "今日训练" : "自选训练"}</div>
        <div class="h2">${isPlan ? esc(draft.title || "今日训练") : "先排顺序，再开始"}</div>
        <p class="small muted compose-copy">${isPlan ? "今天的动作顺序、组数和重量都可以先调整；开始后仍可随时修改本次目标。" : "动作顺序、组数、次数、重量都可以先改；开始后仍可在训练页临时调整。"}</p>
        <div class="compose-stats">
          <span><strong>${totals.exercises}</strong> 个动作</span>
          <span><strong id="compose-total-sets">${totals.sets}</strong> 组</span>
          <span>约 <strong id="compose-total-minutes">${totals.minutes}</strong> 分钟</span>
        </div>
      </section>

      <div class="compose-eyebrow">
        <span>训练顺序</span>
        <span class="tiny faint">按住左侧手柄拖动排序</span>
      </div>

      <div class="compose-list">
        ${draft.exercises.length ? draft.exercises.map((item, index) => {
          const info = EX[item.slug] || { name: item.slug, muscle: "", equip: "" };
          return `
            <article class="compose-exercise" data-compose-index="${index}">
              <div class="compose-exercise-head">
                <span class="compose-drag-handle" data-compose-drag role="button" tabindex="0" aria-label="拖动排序" title="拖动排序">
                  <svg viewBox="0 0 12 20" fill="currentColor" aria-hidden="true"><circle cx="3" cy="4" r="1.2"/><circle cx="9" cy="4" r="1.2"/><circle cx="3" cy="10" r="1.2"/><circle cx="9" cy="10" r="1.2"/><circle cx="3" cy="16" r="1.2"/><circle cx="9" cy="16" r="1.2"/></svg>
                </span>
                <span class="compose-order">${String(index + 1).padStart(2, "0")}</span>
                <div class="grow compose-exercise-name">
                  <strong>${esc(info.name)}</strong>
                  <span>${info.muscle || "动作"}${info.equip ? ` · ${info.equip}` : ""}</span>
                </div>
                <div class="compose-move-group">
                  <button class="compose-icon-btn danger" onclick="app.workoutDraftRemove(${index})" aria-label="移除 ${esc(info.name)}">×</button>
                </div>
              </div>

              <div class="compose-fields">
                <div class="compose-field">
                  <span>组数 <em>组</em></span>
                  ${pickerFieldButton({
                    value: String(Number(item.sets) || 1),
                    onclick: `app.openDraftPicker(${index}, 'sets')`,
                    label: "选择组数"
                  })}
                </div>
                <div class="compose-field">
                  <span>每组次数 <em>次</em></span>
                  ${pickerFieldButton({
                    value: String(parseReps(item.reps)),
                    onclick: `app.openDraftPicker(${index}, 'reps')`,
                    label: "选择每组次数"
                  })}
                </div>
                <div class="compose-field">
                  <span>目标重量 <em>kg</em></span>
                  <input class="weight-input" type="number" inputmode="decimal" min="0" step="0.5" value="${Number(item.weight) || 0}" onchange="app.workoutDraftWeight(${index}, this.value)" aria-label="目标重量 kg">
                </div>
                <div class="compose-field">
                  <span>组间休息 <em>秒</em></span>
                  ${pickerFieldButton({
                    value: String(Number(item.rest) || 0),
                    onclick: `app.openDraftPicker(${index}, 'rest')`,
                    label: "选择组间休息"
                  })}
                </div>
              </div>
            </article>
          `;
        }).join("") : `
          <div class="compose-empty">
            <div class="compose-empty-icon">${ICONS.dumbbell}</div>
            <strong>还没有动作</strong>
            <span>返回动作库重新选择。</span>
          </div>
        `}
      </div>
      </div>

      <div class="compose-footer">
        <div class="compose-footer-copy">
          <strong id="compose-footer-summary">${totals.sets} 组 · 约 ${totals.minutes} 分钟</strong>
          <span>重量为 0 表示自重；开始后仍可继续调整。</span>
        </div>
        <button class="btn btn-primary" onclick="app.startWorkoutDraft()" ${draft.exercises.length ? "" : "disabled"}>开始本次训练</button>
      </div>
    </div>
  `;
}

function adjustedWorkoutExercises(workout, day) {
  if (!day || !Array.isArray(day.exercises)) return [];
  const adjustments = workout?.adjustments && typeof workout.adjustments === "object"
    ? workout.adjustments
    : {};
  return day.exercises.map((exercise) => ({
    ...exercise,
    ...(adjustments[exercise.id] || {})
  }));
}

function workoutAdjustSheet() {
  const workout = state.workout;
  const day = workoutDay(workout);
  const draft = state.workoutAdjustDraft;
  if (!workout || !day || !draft) return "";
  const base = day.exercises[workout.index];
  const info = base ? EX[base.slug] : null;
  const done = (Array.isArray(workout.logs) ? workout.logs : [])
    .filter((log) => base && log.slug === base.slug).length;

  return `
    <div class="workout-adjust-backdrop no-drag" onclick="app.closeWorkoutAdjust()">
      <section class="workout-adjust-sheet no-drag" role="dialog" aria-modal="true" aria-label="调整本次训练" onclick="event.stopPropagation()">
        <div class="sheet-grabber" aria-hidden="true"></div>
        <div class="between">
          <div>
            <div class="compose-kicker">本次训练</div>
            <div class="h3">${info ? esc(info.name) : "调整当前动作"}</div>
          </div>
          <button class="compose-icon-btn" onclick="app.closeWorkoutAdjust()" aria-label="关闭调整">×</button>
        </div>
        <p class="small muted workout-adjust-copy">只调整这次训练的目标，不会改动长期计划。已完成 ${done} 组，降低目标组数会自动进入下一个动作。</p>

        <div class="compose-fields workout-adjust-fields">
          <div class="compose-field">
            <span>目标组数 <em>组</em></span>
            ${pickerFieldButton({
              value: String(draft.sets),
              onclick: "app.openAdjustPicker('sets')",
              label: "选择目标组数"
            })}
          </div>
          <div class="compose-field">
            <span>每组次数 <em>次</em></span>
            ${pickerFieldButton({
              value: String(parseReps(draft.reps)),
              onclick: "app.openAdjustPicker('reps')",
              label: "选择每组次数"
            })}
          </div>
          <div class="compose-field">
            <span>目标重量 <em>kg</em></span>
            <input class="weight-input" type="number" inputmode="decimal" min="0" step="0.5" value="${Number(draft.weight) || 0}" onchange="app.workoutAdjustWeight(this.value)" aria-label="目标重量 kg">
          </div>
          <div class="compose-field">
            <span>组间休息 <em>秒</em></span>
            ${pickerFieldButton({
              value: String(draft.rest),
              onclick: "app.openAdjustPicker('rest')",
              label: "选择组间休息"
            })}
          </div>
        </div>

        <button class="btn btn-primary" style="margin-top:16px" onclick="app.saveWorkoutAdjust()">保存调整</button>
      </section>
    </div>
  `;
}

/* ---------------- Workout ---------------- */

function workoutDay(workout) {
  if (!workout) return null;
  return state.plan.days.find((item) => item.id === workout.dayId)
    || (state.workoutCustomDay && state.workoutCustomDay.id === workout.dayId
      ? state.workoutCustomDay
      : null);
}

function workoutScreen() {
  const workout = state.workout;
  if (!workout) return home();
  const day = workoutDay(workout);
  if (!day || !Array.isArray(day.exercises) || day.exercises.length === 0) return home();

  // 旧版本 localStorage / 中断恢复可能留下不完整状态。先修复索引和日志，
  // 避免渲染时抛错后只剩头部和底部操作条。
  if (!Array.isArray(workout.logs)) workout.logs = [];
  if (!Number.isInteger(workout.index) || workout.index < 0) workout.index = 0;
  if (!Number.isInteger(workout.setIndex) || workout.setIndex < 0) workout.setIndex = 0;
  const exercises = adjustedWorkoutExercises(workout, day);
  if (workout.index >= exercises.length) return workoutSummary(day);

  const exercise = exercises[workout.index];
  if (!exercise) return workoutSummary(day);
  const info = EX[exercise.slug] || {
    name: exercise.slug || "当前动作",
    equip: "",
    cues: "动作资料暂时无法加载，可以继续记录本组训练。"
  };
  const logs = Array.isArray(workout.logs) ? workout.logs : [];
  const done = logs.length;
  const total = exercises.reduce((sum, item) => sum + item.sets, 0);
  const ratio = Math.min(100, Math.round((done / Math.max(1, total)) * 100));
  const setsDone = workout.setIndex >= exercise.sets;
  const actionLabel = setsDone
    ? (workout.index < day.exercises.length - 1 ? "下一个动作" : "查看训练总结")
    : `完成第 ${workout.setIndex + 1} 组`;
  const action = setsDone ? "app.nextExercise()" : "app.completeSet()";

  return `
    <div class="workout-screen">
      <header class="workout-topbar">
        <button class="icon-btn" onclick="app.exitWorkout()" aria-label="结束训练">✕</button>
        <div class="workout-title">训练中</div>
        <span class="workout-topbar-spacer" aria-hidden="true"></span>
      </header>

      <div class="workout-progress-strip">
        <div class="workout-progress"><span>${done}/${total} 组</span><span>${workout.index + 1}/${day.exercises.length} 动作</span></div>
        <div class="bar"><span style="width:${ratio}%"></span></div>
      </div>

      <div class="workout-scroll">
        <div class="workout-content">
      <div class="card">
        <div class="between">
          <div class="badge">动作 ${workout.index + 1}/${day.exercises.length}</div>
          <div class="tiny faint">${info.equip}</div>
        </div>
        <div class="h2" style="margin-top:9px">${info.name}</div>
        <div class="small accent" style="margin-top:4px">${exercise.sets} 组 × ${exercise.reps} 次${exercise.weight > 0 ? ` · ${exercise.weight} kg` : " · 自重"}</div>
        <div class="small muted workout-copy" style="margin-top:10px;line-height:1.65">${info.cues}</div>
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
          <div class="row gap8">
            <span class="tiny muted">RPE ${Number(exercise.rpe || 7.5).toFixed(1)}</span>
            <button class="link" onclick="app.openWorkoutAdjust()">调整</button>
          </div>
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

      ${logs.length ? `
        <div class="card">
          <div class="h3" style="margin-bottom:6px">本次已完成</div>
          ${logs.map((log) => `
            <div class="set-line">
              <span class="small muted">${EX[log.slug]?.name || log.slug} · 第 ${log.set} 组</span>
              <span class="small">${log.weight > 0 ? log.weight + "kg × " : "自重 × "}${log.reps}</span>
            </div>
          `).join("")}
        </div>
      ` : ""}
        </div>
      </div>

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
      <div class="page-header row between">
        <button class="icon-btn" onclick="app.exitWorkout()">✕</button>
        <div class="h3">训练总结</div>
        <span class="header-spacer" aria-hidden="true"></span>
      </div>

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

      <div class="card">
        <div class="form-label">训练心得（可选）</div>
        <textarea rows="3" placeholder="今天状态、动作感受、下次注意什么…" oninput="app.workoutNote(this.value)">${esc(workout.notes || "")}</textarea>
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
          <div class="form-label" style="margin-top:12px">训练心得</div>
          <textarea rows="3" onchange="app.sessionField('notes', this.value)" placeholder="今天状态、动作感受…">${esc(session.notes || "")}</textarea>
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
        ${session.notes ? `<div class="tiny muted" style="margin-top:12px;line-height:1.6"><span class="accent">训练心得</span><br>${esc(session.notes)}</div>` : ""}
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

/* ---------------- Workout history ---------------- */

function historyScreen() {
  const sessions = state.sessions;
  const totalVolume = sessions.reduce((sum, session) => sum + session.volume, 0);
  const totalMinutes = sessions.reduce((sum, session) => sum + session.duration, 0);
  return `
    <div class="stack">
      ${headerBack("训练记录", "app.closeHistory()")}
      <div class="card">
        <div class="h2">训练数据</div>
        <div class="row gap8" style="margin-top:12px">
          <div class="metric"><div class="value">${sessions.length}</div><div class="label">训练次数</div></div>
          <div class="metric"><div class="value">${Math.round(totalVolume).toLocaleString()}</div><div class="label">总容量 kg</div></div>
          <div class="metric"><div class="value">${totalMinutes}</div><div class="label">总分钟</div></div>
        </div>
        <div class="tiny faint" style="margin-top:10px;line-height:1.6">训练容量 = 组数 × 重量 × 次数，用来观察长期趋势，不是训练好坏评分。</div>
      </div>

      <div class="card">
        <div class="h3" style="margin-bottom:8px">全部训练</div>
        ${sessions.length ? sessions.map((session) => `
          <div class="recent-row" onclick="app.openSession('${session.id}')">
            <div class="grow">
              <div class="small strong">${session.title}</div>
              <div class="tiny faint">${session.date}${session.notes ? " · 有心得" : ""}</div>
            </div>
            <div style="text-align:right">
              <div class="small accent" style="font-weight:650">${session.volume} kg</div>
              <div class="tiny faint">${session.duration} 分钟</div>
            </div>
            <div class="faint">›</div>
          </div>
        `).join("") : `<div class="tiny muted" style="padding:10px 0">还没有训练记录。</div>`}
      </div>
    </div>
  `;
}

/* ---------------- drag to scroll (desktop preview) ---------------- */

let dragClickSuppressedUntil = 0;

window.addEventListener("click", (event) => {
  if (performance.now() >= dragClickSuppressedUntil) return;
  event.preventDefault();
  event.stopPropagation();
  dragClickSuppressedUntil = 0;
}, true);

function suppressPreviewClick() {
  // 只吞掉拖拽结束后的那一次 click，避免影响下一次正常点击。
  dragClickSuppressedUntil = performance.now() + 120;
}

function enableDragScroll(container) {
  if (!container || container.dataset.dragScrollReady === "1") return;
  container.dataset.dragScrollReady = "1";

  container.addEventListener("pointerdown", (event) => {
    if (event.pointerType !== "mouse" && event.pointerType !== "pen") return;
    if (event.button !== 0) return;
    if (event.target.closest("input, textarea, select, [contenteditable='true'], .no-drag")) return;
    // 已选动作层打开时，底层页面不再响应拖拽，避免短列表拖拽穿透。
    if (container.id === "app" && document.querySelector(".equipment-selection-popover")) return;
    if (
      container.scrollHeight <= container.clientHeight + 1
      && container.scrollWidth <= container.clientWidth + 1
    ) {
      return;
    }

    const startX = event.clientX;
    const startY = event.clientY;
    const startTop = container.scrollTop;
    const startLeft = container.scrollLeft;
    const pointerId = event.pointerId;
    let moved = false;

    const move = (moveEvent) => {
      if (moveEvent.pointerId !== pointerId) return;
      const dx = moveEvent.clientX - startX;
      const dy = moveEvent.clientY - startY;
      if (!moved && Math.abs(dx) + Math.abs(dy) < 4) return;
      moved = true;
      moveEvent.preventDefault();
      container.scrollTop = startTop - dy;
      container.scrollLeft = startLeft - dx;
      document.body.classList.add("dragging-scroll");
    };

    const end = (endEvent) => {
      if (endEvent.pointerId !== pointerId) return;
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", end);
      window.removeEventListener("pointercancel", end);
      document.body.classList.remove("dragging-scroll");
      if (moved) suppressPreviewClick();
    };

    window.addEventListener("pointermove", move, { passive: false });
    window.addEventListener("pointerup", end);
    window.addEventListener("pointercancel", end);
    event.stopPropagation();
  }, { passive: true });
}

let equipmentScrollFrame = 0;
let equipmentToolsObserver = null;
let equipmentScrollLock = null;

function syncEquipmentLayout() {
  const root = document.getElementById("app");
  if (!root) return;
  const tools = root.querySelector(".equipment-sticky-tools");
  if (!tools) {
    root.style.removeProperty("--equipment-tools-height");
    return;
  }
  root.style.setProperty("--equipment-tools-height", `${tools.offsetHeight}px`);
}

function setupEquipmentLayout() {
  syncEquipmentLayout();
  const tools = document.querySelector(".equipment-sticky-tools");
  if (!tools) return;
  if (typeof ResizeObserver === "undefined") return;
  if (equipmentToolsObserver) equipmentToolsObserver.disconnect();
  equipmentToolsObserver = new ResizeObserver(() => syncEquipmentLayout());
  equipmentToolsObserver.observe(tools);
}

function syncEquipmentScrollState() {
  const root = document.getElementById("app");
  if (!root) return;
  const onEquipment = (state.screen === "tabs" && state.tab === "equipment")
    || state.screen === "planExercisePicker";
  const selectionOpen = onEquipment && state.equipSelectionOpen;

  // 锁定底层滚动位置：即使浏览器/触摸事件漏到底层，也不会带着页面移动。
  if (selectionOpen) {
    if (equipmentScrollLock === null) equipmentScrollLock = root.scrollTop;
    if (root.scrollTop !== equipmentScrollLock) root.scrollTop = equipmentScrollLock;
  } else {
    equipmentScrollLock = null;
  }

  const wasScrolled = root.classList.contains("equipment-scrolled");
  const shouldBeScrolled = onEquipment && (wasScrolled ? root.scrollTop > 2 : root.scrollTop > 18);
  root.classList.toggle("equipment-scrolled", shouldBeScrolled);
}

function setupEquipmentScrollState() {
  const root = document.getElementById("app");
  if (!root || root.dataset.equipmentScrollReady === "1") return;
  root.dataset.equipmentScrollReady = "1";
  root.addEventListener("scroll", () => {
    if (equipmentScrollFrame) return;
    equipmentScrollFrame = requestAnimationFrame(() => {
      equipmentScrollFrame = 0;
      syncEquipmentScrollState();
    });
  }, { passive: true });
  syncEquipmentScrollState();
}

function setupLibrarySwipeRows() {
  document.querySelectorAll(".library-swipe-row").forEach((row) => {
    if (row.dataset.swipeReady === "1") return;
    row.dataset.swipeReady = "1";

    const content = row.querySelector(".library-row");
    if (!content) return;

    let startX = 0;
    let startY = 0;
    let offset = 0;
    let horizontal = false;
    let dragging = false;

    const setOffset = (value) => {
      offset = Math.max(-84, Math.min(0, value));
      content.style.transform = `translateX(${offset}px)`;
    };

    const settle = (open) => {
      row.classList.toggle("is-open", open);
      content.style.transition = "transform 200ms cubic-bezier(0.22, 0.8, 0.24, 1)";
      setOffset(open ? -84 : 0);
      setTimeout(() => {
        content.style.transition = "";
      }, 220);
    };

    content.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return;
      startX = event.clientX;
      startY = event.clientY;
      offset = row.classList.contains("is-open") ? -84 : 0;
      horizontal = false;
      dragging = true;
      content.style.transition = "";
      if (event.pointerType !== "touch") {
        content.setPointerCapture?.(event.pointerId);
      }
    });

    content.addEventListener("pointermove", (event) => {
      if (!dragging) return;
      const dx = event.clientX - startX;
      const dy = event.clientY - startY;

      if (!horizontal) {
        if (Math.abs(dx) < 7 && Math.abs(dy) < 7) return;
        if (Math.abs(dx) <= Math.abs(dy)) {
          dragging = false;
          return;
        }
        horizontal = true;
      }

      event.preventDefault();
      setOffset((row.classList.contains("is-open") ? -84 : 0) + dx);
    }, { passive: false });

    const finish = () => {
      if (!dragging) return;
      dragging = false;

      if (!horizontal) {
        // 已展开时点一下整行先收起，不直接进入详情。
        if (row.classList.contains("is-open")) {
          settle(false);
          row.dataset.suppressClick = "1";
          setTimeout(() => {
            row.dataset.suppressClick = "0";
          }, 220);
        }
        return;
      }

      const open = offset < -34;
      if (open) {
        document.querySelectorAll(".library-swipe-row.is-open").forEach((other) => {
          if (other === row) return;
          other.classList.remove("is-open");
          const otherContent = other.querySelector(".library-row");
          if (otherContent) {
            otherContent.style.transition = "transform 180ms ease";
            otherContent.style.transform = "translateX(0)";
            setTimeout(() => {
              otherContent.style.transition = "";
            }, 200);
          }
        });
      }

      settle(open);
      row.dataset.suppressClick = "1";
      setTimeout(() => {
        row.dataset.suppressClick = "0";
      }, 220);
    };

    content.addEventListener("pointerup", finish);
    content.addEventListener("pointercancel", finish);
    content.addEventListener("click", (event) => {
      if (row.dataset.suppressClick === "1" || row.classList.contains("is-open")) {
        event.preventDefault();
        event.stopImmediatePropagation();
        if (row.classList.contains("is-open") && row.dataset.suppressClick !== "1") {
          settle(false);
        }
      }
    }, true);
  });
}

function containSelectionListScroll() {
  const list = document.querySelector(".equipment-selection-list");
  if (!list || list.dataset.scrollContained === "1") return;
  list.dataset.scrollContained = "1";

  list.addEventListener("wheel", (event) => {
    const atTop = list.scrollTop <= 0 && event.deltaY < 0;
    const atBottom = event.deltaY > 0
      && list.scrollTop + list.clientHeight >= list.scrollHeight - 1;
    const cannotScroll = list.scrollHeight <= list.clientHeight + 1;
    if (cannotScroll || atTop || atBottom) {
      event.preventDefault();
    }
  }, { passive: false });

  let touchStartY = 0;
  list.addEventListener("touchstart", (event) => {
    touchStartY = event.touches[0]?.clientY ?? 0;
  }, { passive: true });

  list.addEventListener("touchmove", (event) => {
    const y = event.touches[0]?.clientY ?? touchStartY;
    const pullingDown = y > touchStartY;
    const atTop = list.scrollTop <= 0;
    const atBottom = list.scrollTop + list.clientHeight >= list.scrollHeight - 1;
    const cannotScroll = list.scrollHeight <= list.clientHeight + 1;
    if (cannotScroll || (atTop && pullingDown) || (atBottom && !pullingDown)) {
      event.preventDefault();
    }
  }, { passive: false });
}

document.addEventListener("wheel", (event) => {
  if (!document.querySelector(".equipment-selection-popover")) return;
  if (!event.target.closest(".equipment-selection-list")) {
    event.preventDefault();
  }
}, { passive: false });

document.addEventListener("touchmove", (event) => {
  if (!document.querySelector(".equipment-selection-popover")) return;
  if (!event.target.closest(".equipment-selection-list")) {
    event.preventDefault();
  }
}, { passive: false });

function setupDragScroll() {
  const root = document.getElementById("app");
  if (!root) return;
  enableDragScroll(root);
  root.querySelectorAll(
    ".chat-scroll, .equipment-selection-list, .equipment-filter-scroll, .week-tabs, .suggestions, .coach-skill-bar"
  ).forEach(enableDragScroll);
  setupLibrarySwipeRows();
  containSelectionListScroll();
  setupEquipmentScrollState();
  setupEquipmentLayout();
  syncEquipmentScrollState();
}

/* ---------------- render ---------------- */

let lastRouteKey = "";

function render() {
  if (!state.onboarded) state.screen = "onboarding";
  if (state.onboarded && state.screen === "onboarding") state.screen = "tabs";

  const root = document.getElementById("app");
  if (!root) return;

  document.querySelector(".device")?.classList.toggle(
    "camera-mode",
    state.authenticated && state.screen === "equipmentCamera"
  );
  const selectionOpen = state.authenticated
    && state.screen === "tabs"
    && state.tab === "equipment"
    && state.equipSelectionOpen;
  document.body.classList.toggle("selection-open", selectionOpen);
  document.documentElement.classList.toggle("selection-open", selectionOpen);

  if (!state.authenticated) {
    const loginRoute = "login";
    const loginChanged = lastRouteKey !== loginRoute;
    lastRouteKey = loginRoute;
    root.innerHTML = loginScreen() + legalModal();
    root.className = "app no-tabs" + (loginChanged ? " route-changed" : "");
    document.getElementById("tabbar").innerHTML = "";
    document.getElementById("tabbar").className = "tabbar hidden";
    if (loginChanged) {
      requestAnimationFrame(() => {
        root.scrollTop = 0;
        syncEquipmentLayout();
        syncEquipmentScrollState();
      });
    }
    setupDragScroll();
    return;
  }

  const routeKey = [
    state.screen,
    state.tab,
    state.planDayId || "",
    state.sessionId || "",
    state.equipmentItemId || "",
    state.selectedExercise || ""
  ].join("|");
  const routeChanged = routeKey !== lastRouteKey;
  lastRouteKey = routeKey;

  let html = "";
  if (state.screen === "onboarding") html = onboarding();
  else if (state.screen === "tabs") {
    if (state.tab === "home") html = home();
    else if (state.tab === "plan") html = planScreen();
    else if (state.tab === "coach") html = coachScreen();
    else if (state.tab === "equipment") html = equipmentPickerScreen();
    else html = profileScreen();
  } else if (state.screen === "planDay") html = planDayScreen();
  else if (state.screen === "nutrition") html = nutritionScreen();
  else if (state.screen === "foodAdd") html = foodAddScreen();
  else if (state.screen === "foodCustom") html = foodCustomScreen();
  else if (state.screen === "foodPhoto") html = foodPhotoScreen();
  else if (state.screen === "paywall") html = paywallScreen();
  else if (state.screen === "profileEdit") html = profileEditScreen();
  else if (state.screen === "settings") html = settingsScreen();
  else if (state.screen === "workoutCompose") html = workoutComposeScreen();
  else if (state.screen === "workout") html = workoutScreen();
  else if (state.screen === "sessionDetail") html = sessionScreen();
  else if (state.screen === "sessionExercisePicker") html = equipmentPickerScreen();
  else if (state.screen === "history") html = historyScreen();
  else if (state.screen === "equipmentLibrary") html = equipmentLibraryScreen();
  else if (state.screen === "equipmentCamera") html = equipmentCameraScreen();
  else if (state.screen === "equipmentRecognition") html = equipmentRecognitionScreen();
  else if (state.screen === "equipmentItem") html = equipmentItemScreen();
  else if (state.screen === "planExercisePicker") html = equipmentPickerScreen();
  else if (state.screen === "bodyAnalysis") html = bodyAnalysisScreen();
  else html = home();

  root.innerHTML = html + legalModal()
    + (state.workoutAdjustOpen && state.screen === "workout" ? workoutAdjustSheet() : "")
    + (state.numberPicker ? numberPickerSheet() : "");
  root.className = "app"
    + (state.screen === "tabs" ? "" : " no-tabs")
    + (state.screen === "workout" ? " workout-mode" : "")
    + (state.screen === "workoutCompose" ? " compose-mode" : "")
    + (state.screen === "tabs" && state.tab === "coach" ? " chat-mode" : "")
    + (state.equipSelectionOpen && state.screen === "tabs" && state.tab === "equipment" ? " selection-open" : "")
    + (state.screen === "equipmentCamera" ? " camera-mode" : "")
    + (routeChanged ? " route-changed" : "");
  document.getElementById("tabbar").innerHTML = tabbar();
  document.getElementById("tabbar").className = "tabbar" + (state.onboarded && state.screen === "tabs" ? "" : " hidden");
  if (routeChanged) {
    requestAnimationFrame(() => {
      root.scrollTop = 0;
      syncEquipmentLayout();
      syncEquipmentScrollState();
    });
  }

  if (state.screen === "tabs" && state.tab === "coach") {
    setTimeout(() => {
      const chat = document.getElementById("chat-scroll");
      if (chat) chat.scrollTop = chat.scrollHeight;
    }, 20);
  }

  setupDragScroll();
  setupComposeDrag();
  setupNumberPicker();
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
    state.equipSelectionOpen = false;
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
    state.equipSelectionOpen = false;
    if (state.screen === "foodCustom") { state.foodCustomDraft = null; state.screen = "foodAdd"; }
    else if (state.screen === "foodAdd") state.screen = "nutrition";
    else if (state.screen === "history") { state.screen = "tabs"; state.tab = "home"; }
    else if (state.screen === "planDay") { state.screen = "tabs"; state.tab = "plan"; }
    else if (state.screen === "paywall") { state.screen = "tabs"; state.tab = "profile"; }
    else if (state.screen === "sessionDetail") { state.screen = "tabs"; state.tab = "home"; }
    else if (state.screen === "equipmentItem") { state.screen = "equipmentLibrary"; }
    else if (state.screen === "equipmentLibrary" || state.screen === "equipmentRecognition" || state.screen === "equipmentCamera") { state.screen = "tabs"; state.tab = "equipment"; }
    else if (state.screen === "bodyAnalysis") { state.screen = "tabs"; state.tab = "profile"; }
    else { state.screen = "tabs"; state.tab = "home"; }
    save();
    render();
  },

  backTo(tab) {
    state.screen = "tabs";
    state.tab = tab;
    state.equipSelectionOpen = false;
    save();
    render();
  },

  openPlanDay(id) {
    state.planDayId = id;
    state.screen = "planDay";
    state.equipSearchQuery = "";
    state.equipMuscle = "全部";
    state.equipFilter = "全部";
    save();
    render();
  },

  openPlanExercisePicker() {
    state.screen = "planExercisePicker";
    state.equipSearchQuery = "";
    state.equipMuscle = "全部";
    state.equipFilter = "全部";
    state.equipSelectionOpen = false;
    save();
    render();
  },

  closePlanExercisePicker() {
    state.screen = "planDay";
    state.equipSearchQuery = "";
    state.equipMuscle = "全部";
    state.equipFilter = "全部";
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
    if (!day || !Array.isArray(day.exercises) || !day.exercises.length) return;
    state.workoutDraft = {
      source: "plan",
      title: day.title || "今日训练",
      createdAt: Date.now(),
      exercises: day.exercises.map((exercise, index) => ({
        ...exercise,
        id: exercise.id || `plan-ex-${Date.now()}-${index}`,
        sets: Number(exercise.sets) || 3,
        reps: String(parseReps(exercise.reps)),
        weight: Math.max(0, Number(exercise.weight) || 0),
        rest: Math.max(0, Number(exercise.rest) || 0),
        rpe: Number(exercise.rpe) || 7.5
      }))
    };
    state.workoutCustomDay = null;
    state.workoutAdjustOpen = false;
    state.workoutAdjustDraft = null;
    state.screen = "workoutCompose";
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
    const day = workoutDay(workout);
    const exercise = adjustedWorkoutExercises(workout, day)[workout.index];
    if (!exercise) return;
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
    const day = workoutDay(workout);
    stopRestTimer();
    workout.rest = 0;
    workout.index += 1;
    workout.setIndex = 0;
    const exercises = adjustedWorkoutExercises(workout, day);
    if (workout.index < exercises.length) {
      const next = exercises[workout.index];
      workout.weight = next.weight;
      workout.reps = parseReps(next.reps);
    }
    save();
    render();
  },

  openWorkoutAdjust() {
    const workout = state.workout;
    const day = workoutDay(workout);
    const exercise = adjustedWorkoutExercises(workout, day)[workout.index];
    if (!exercise) return;
    state.workoutAdjustDraft = {
      id: exercise.id,
      sets: Math.max(1, Number(exercise.sets) || 1),
      reps: String(parseReps(exercise.reps)),
      weight: Math.max(0, Number(exercise.weight) || 0),
      rest: Math.max(0, Number(exercise.rest) || 0)
    };
    state.workoutAdjustOpen = true;
    save();
    render();
  },

  closeWorkoutAdjust() {
    state.workoutAdjustOpen = false;
    state.workoutAdjustDraft = null;
    save();
    render();
  },

  saveWorkoutAdjust() {
    const workout = state.workout;
    const day = workoutDay(workout);
    const draft = state.workoutAdjustDraft;
    const base = day?.exercises?.[workout?.index];
    if (!workout || !day || !draft || !base) return;
    workout.adjustments = workout.adjustments || {};
    workout.adjustments[base.id] = {
      sets: Math.max(1, Math.min(10, Number(draft.sets) || base.sets)),
      reps: String(Math.max(1, Math.min(30, Number(draft.reps) || parseReps(base.reps)))),
      weight: Math.max(0, Number(draft.weight) || 0),
      rest: Math.max(0, Math.min(300, Number(draft.rest) || 0))
    };
    workout.weight = workout.adjustments[base.id].weight;
    workout.reps = parseReps(workout.adjustments[base.id].reps);
    state.workoutAdjustOpen = false;
    state.workoutAdjustDraft = null;
    save();
    render();
    toast("已保存本次训练目标");
  },

  feeling(value) {
    if (state.workout) state.workout.feeling = value;
    save();
    render();
    toast("已记录训练感受");
  },

  workoutNote(value) {
    if (state.workout) state.workout.notes = value;
    save();
  },

  finishWorkout() {
    const workout = state.workout;
    if (!workout) return;
    const day = workoutDay(workout);
    const volume = workout.logs.reduce((sum, log) => sum + log.weight * log.reps, 0);
    const exercises = adjustedWorkoutExercises(workout, day);
    const items = exercises.map((exercise) => ({
      name: EX[exercise.slug]?.name || exercise.slug,
      weight: exercise.weight,
      reps: parseReps(exercise.reps),
      sets: workout.logs.filter((log) => log.slug === exercise.slug).length || exercise.sets
    }));
    state.sessions.unshift({
      id: `s${Date.now()}`,
      title: day.title,
      date: "刚刚",
      timestamp: Date.now(),
      duration: Math.max(1, Math.round((Date.now() - workout.startedAt) / 60000)),
      volume: Math.round(volume) || 1860,
      thisWeek: true,
      notes: String(workout.notes || "").trim(),
      items
    });
    state.workout = null;
    state.workoutCustomDay = null;
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
    state.workoutCustomDay = null;
    stopRestTimer();
    state.screen = "tabs";
    state.tab = "home";
    save();
    render();
  },

  openHistory() {
    state.screen = "history";
    save();
    render();
  },

  closeHistory() {
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
    state.screen = "sessionExercisePicker";
    state.equipSearchQuery = "";
    state.equipMuscle = "全部";
    state.equipFilter = "全部";
    save();
    render();
  },

  closeSessionExercisePicker() {
    state.screen = "sessionDetail";
    save();
    render();
  },

  addSessionExercise(slug) {
    const draft = state.sessionDraft;
    const exercise = EX[slug];
    if (!draft || !exercise) return;
    const exists = draft.items.some((item) => item.slug === slug || (!item.slug && item.name === exercise.name));
    if (!exists) {
      draft.items.push({
        slug,
        name: exercise.name,
        weight: Number(exercise.base) || 0,
        reps: 10,
        sets: 3
      });
      save();
      toast(`已添加 ${exercise.name}`);
    } else {
      toast("这个动作已在训练记录里");
    }
    state.screen = "sessionDetail";
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

  openExercise(slug) {
    state.selectedExercise = slug;
    state.equipmentItemId = null;
    state.screen = "equipmentItem";
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

  equipmentTabOpen() {
    state.screen = "tabs";
    state.tab = "equipment";
    state.equipSelectionOpen = false;
    save();
    render();
  },

  equipmentLibraryOpen(source = "equipment") {
    state.screen = "equipmentLibrary";
    state.equipLibraryFromProfile = source === "profile";
    state.equipSelectionOpen = false;
    save();
    render();
  },

  equipmentLibraryQuery(value) {
    state.equipLibraryQuery = value;
    save();

    const filtered = filteredEquipmentLibraryItems();
    const root = document.getElementById("library-list-root");
    if (root) root.innerHTML = equipmentLibraryResultsMarkup(filtered);
    setupLibrarySwipeRows();

    const count = document.getElementById("library-list-count");
    if (count) count.textContent = `${filtered.length} 件`;

    const clear = document.getElementById("library-search-clear");
    if (clear) clear.hidden = !String(value || "").trim();
  },

  equipmentLibraryClearQuery() {
    const input = document.getElementById("library-search");
    if (input) input.value = "";
    this.equipmentLibraryQuery("");
    input?.focus();
  },

  equipmentPickerToggle(slug) {
    if (state.equipSelected.includes(slug)) {
      state.equipSelected = state.equipSelected.filter((item) => item !== slug);
    } else {
      state.equipSelected = [...state.equipSelected, slug];
    }
    save();
    render();
  },

  equipmentPickerClear() {
    state.equipSelected = [];
    save();
    render();
  },

  equipmentSelectionToggle() {
    state.equipSelectionOpen = !state.equipSelectionOpen;
    save();
    render();
  },

  equipmentSelectionClose() {
    state.equipSelectionOpen = false;
    save();
    render();
  },

  equipmentSelectionMakePlan() {
    if (!state.equipSelected.length) return;
    const selected = state.equipSelected
      .map((slug) => ({ slug, ...EX[slug] }))
      .filter((item) => item.name);
    if (!selected.length) return;

    state.workoutDraft = {
      source: "custom",
      title: "自选训练",
      createdAt: Date.now(),
      exercises: selected.map((item, index) => ({
        id: `draft-ex-${Date.now()}-${index}`,
        slug: item.slug,
        sets: 3,
        reps: "10",
        weight: Number(item.base) || 0,
        rest: 60,
        rpe: 7.5
      }))
    };
    state.equipSelectionOpen = false;
    state.screen = "workoutCompose";
    save();
    render();
  },

  closeWorkoutCompose() {
    const source = state.workoutDraft?.source;
    state.workoutDraft = null;
    state.screen = "tabs";
    state.tab = source === "plan" ? "home" : "equipment";
    save();
    render();
  },

  workoutDraftMoveTo(index, target) {
    const draft = state.workoutDraft;
    if (!draft || !Array.isArray(draft.exercises)) return;
    if (index === target || index < 0 || target < 0 || index >= draft.exercises.length || target >= draft.exercises.length) return;
    const next = [...draft.exercises];
    const [moved] = next.splice(index, 1);
    next.splice(target, 0, moved);
    draft.exercises = next;
    save();
    renderKeepingComposeScroll();
  },

  workoutDraftRemove(index) {
    const draft = state.workoutDraft;
    if (!draft || !Array.isArray(draft.exercises) || !draft.exercises[index]) return;
    const [removed] = draft.exercises.splice(index, 1);
    state.equipSelected = state.equipSelected.filter((slug) => slug !== removed.slug);
    save();
    renderKeepingComposeScroll();
  },

  openDraftPicker(index, key) {
    const item = state.workoutDraft?.exercises?.[index];
    if (!item) return;
    const current = key === "reps" ? parseReps(item.reps) : item[key];
    state.numberPicker = {
      context: "draft",
      index,
      key,
      title: workoutPickerTitle(key),
      options: workoutPickerOptions(key, current),
      value: String(current ?? "")
    };
    save();
    render();
  },

  openAdjustPicker(key) {
    const draft = state.workoutAdjustDraft;
    if (!draft) return;
    const current = key === "reps" ? parseReps(draft.reps) : draft[key];
    state.numberPicker = {
      context: "adjust",
      key,
      title: workoutPickerTitle(key),
      options: workoutPickerOptions(key, current),
      value: String(current ?? "")
    };
    save();
    render();
  },

  closeNumberPicker() {
    state.numberPicker = null;
    save();
    render();
  },

  scrollNumberPicker(index) {
    const wheel = document.getElementById("number-picker-wheel");
    if (!wheel) return;
    wheel.scrollTo({ top: index * 46, behavior: "smooth" });
  },

  confirmNumberPicker() {
    const picker = state.numberPicker;
    if (!picker) return;
    const value = picker.value;
    const numeric = picker.key === "sets" || picker.key === "rest";
    const parsed = numeric ? Number(value) || 0 : String(value || "").trim();

    if (picker.context === "draft") {
      const item = state.workoutDraft?.exercises?.[picker.index];
      if (item) {
        if (picker.key === "sets") item.sets = Math.max(1, Math.min(10, Math.round(parsed)));
        else if (picker.key === "reps") item.reps = String(Math.max(1, Math.min(30, Number(parsed) || 10)));
        else if (picker.key === "rest") item.rest = Math.max(0, Math.min(300, Math.round(parsed)));
      }
      state.numberPicker = null;
      save();
      updateComposeSummary();
      renderKeepingComposeScroll();
      return;
    }

    if (picker.context === "adjust" && state.workoutAdjustDraft) {
      if (picker.key === "sets") state.workoutAdjustDraft.sets = Math.max(1, Math.min(10, Math.round(parsed)));
      else if (picker.key === "reps") state.workoutAdjustDraft.reps = String(Math.max(1, Math.min(30, Number(parsed) || 10)));
      else if (picker.key === "rest") state.workoutAdjustDraft.rest = Math.max(0, Math.min(300, Math.round(parsed)));
    }
    state.numberPicker = null;
    save();
    render();
  },

  workoutDraftWeight(index, value) {
    const item = state.workoutDraft?.exercises?.[index];
    if (!item) return;
    item.weight = Math.max(0, roundHalf(Number(value) || 0));
    save();
  },

  workoutAdjustWeight(value) {
    if (!state.workoutAdjustDraft) return;
    state.workoutAdjustDraft.weight = Math.max(0, roundHalf(Number(value) || 0));
    save();
  },

  startWorkoutDraft() {
    const draft = state.workoutDraft;
    if (!draft || !Array.isArray(draft.exercises) || !draft.exercises.length) return;
    const exercises = draft.exercises
      .map((item, index) => {
        const info = EX[item.slug];
        if (!info) return null;
        return {
          id: item.id || `combo-ex-${Date.now()}-${index}`,
          slug: item.slug,
          sets: Math.max(1, Math.min(10, Number(item.sets) || 3)),
          reps: String(parseReps(item.reps)),
          weight: Math.max(0, Number(item.weight) || 0),
          rest: Math.max(0, Math.min(300, Number(item.rest) || 0)),
          rpe: Number(item.rpe) || 7.5
        };
      })
      .filter(Boolean);
    if (!exercises.length) return toast("至少保留一个动作");

    const source = draft.source || "custom";
    const day = {
      id: `session-${Date.now()}`,
      week: 1,
      weekday: 7,
      title: draft.title || (source === "plan" ? "今日训练" : "自选训练"),
      focus: [...new Set(exercises.map((item) => EX[item.slug].muscle))],
      exercises
    };
    state.workoutCustomDay = day;
    const first = day.exercises[0];
    state.workout = {
      dayId: day.id,
      index: 0,
      setIndex: 0,
      weight: first.weight,
      reps: parseReps(first.reps),
      logs: [],
      adjustments: {},
      rest: 0,
      startedAt: Date.now(),
      feeling: 4,
      notes: ""
    };
    state.workoutDraft = null;
    if (source !== "plan") {
      state.equipSelected = [];
    }
    state.equipSelectionOpen = false;
    state.screen = "workout";
    save();
    render();
  },

  equipmentSelectionAddToLibrary() {
    const selected = state.equipSelected
      .map((slug) => ({ slug, ...EX[slug] }))
      .filter((item) => item.name);
    if (!selected.length) return;

    const existing = new Set(state.equipmentLibrary.map((item) => item.slug).filter(Boolean));
    let added = 0;
    selected.forEach((item) => {
      if (existing.has(item.slug)) return;
      existing.add(item.slug);
      state.equipmentLibrary.push({
        id: `e${Date.now()}-${added}`,
        name: item.name,
        slug: item.slug,
        muscle: item.muscle,
        equip: item.equip,
        video: false,
        notes: "从已选动作加入"
      });
      added += 1;
    });

    state.equipSelected = [];
    state.equipSelectionOpen = false;
    save();
    render();
    toast(added > 0 ? `已加入器械库 ${added} 个动作` : "这些动作已经在器械库");
  },

  equipmentPickerMuscle(value) {
    state.equipMuscle = value;
    state.equipSearchQuery = "";
    save();
    render();
  },

  equipmentPickerFilter(value) {
    state.equipFilter = value;
    state.equipSearchQuery = "";
    save();
    render();
  },

  equipmentPickerQuery(value) {
    state.equipSearchQuery = value;
    const searching = !!String(value || "").trim();
    const grid = document.getElementById("equipment-picker-grid");
    if (grid) grid.innerHTML = equipmentPickerGrid();
    const count = document.getElementById("equipment-grid-count");
    if (count) count.textContent = equipmentPickerExercises().length;
    const scope = document.getElementById("equipment-search-scope");
    if (scope) scope.hidden = !searching;
    const clear = document.getElementById("equipment-search-clear");
    if (clear) clear.hidden = !searching;
    document.getElementById("equipment-picker-root")?.classList.toggle("searching", searching);
    document.querySelectorAll(".muscle-side-item").forEach((button) => {
      const active = !searching && button.textContent.trim() === state.equipMuscle;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    document.querySelectorAll(".equipment-filter").forEach((button) => {
      const active = !searching && button.textContent.trim() === state.equipFilter;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    requestAnimationFrame(syncEquipmentLayout);
    save();
  },

  equipmentPickerClearQuery() {
    state.equipSearchQuery = "";
    save();
    render();
    requestAnimationFrame(() => document.getElementById("equipment-picker-search")?.focus());
  },

  equipmentRecognitionOpen() {
    state.screen = "equipmentCamera";
    state.equipRecognitionPhoto = false;
    state.equipSelectionOpen = false;
    state.equipRecognitionCandidates = [];
    save();
    render();
  },

  equipmentCapturePhoto() {
    state.equipRecognitionPhoto = true;
    state.equipRecognitionCandidates = [];
    state.screen = "equipmentRecognition";
    save();
    render();
  },

  equipmentRecognitionPhoto() {
    state.screen = "equipmentCamera";
    state.equipRecognitionPhoto = false;
    state.equipRecognitionCandidates = [];
    save();
    render();
  },

  equipmentRecognitionScan() {
    if (!state.equipRecognitionPhoto) return toast("先拍一张器械照片");
    state.equipRecognitionCandidates = [
      { slug: "lat_pulldown", confidence: 0.91 },
      { slug: "seated_row", confidence: 0.64 },
      { slug: "face_pull", confidence: 0.48 }
    ];
    save();
    render();
  },

  equipmentRecognitionSave(slug) {
    if (!state.equipmentLibrary.some((entry) => entry.slug === slug)) {
      const ex = EX[slug];
      state.equipmentLibrary.push({
        id: `e${Date.now()}`,
        name: ex.name,
        slug,
        muscle: ex.muscle,
        equip: ex.equip,
        video: false,
        notes: "来自器械识别"
      });
    }
    if (!state.equipSelected.includes(slug)) {
      state.equipSelected.push(slug);
    }
    save();
    render();
    toast("已加入已选动作");
  },

  openEquipItem(id) {
    state.equipmentItemId = id;
    state.selectedExercise = null;
    state.screen = "equipmentItem";
    save();
    render();
  },

  equipmentDetailScroll(id) {
    const app = document.getElementById("app");
    const target = document.getElementById(id);
    if (!app || !target) return;
    const top = app.scrollTop + target.getBoundingClientRect().top - app.getBoundingClientRect().top - 120;
    app.scrollTo({ top, behavior: "smooth" });
  },

  equipmentDetailPin(id) {
    const pinned = new Set(state.pinnedEquipIds || []);
    if (pinned.has(id)) {
      pinned.delete(id);
      toast("已取消置顶");
    } else {
      pinned.add(id);
      toast("已置顶这件器械");
    }
    state.pinnedEquipIds = [...pinned];
    save();
    render();
  },

  equipmentDetailPeriod(period) {
    if (["7", "30", "90", "all", "custom"].includes(period)) {
      state.equipmentStatsPeriod = period;
      save();
      render();
    }
  },

  equipmentDetailMetric(metric) {
    if (["volume", "sets", "maxWeight", "oneRepMax"].includes(metric)) {
      state.equipmentStatsMetric = metric;
      save();
      render();
    }
  },

  equipmentDetailCustomStart(value) {
    state.equipmentStatsCustomStart = value;
    save();
    render();
  },

  equipmentDetailCustomEnd(value) {
    state.equipmentStatsCustomEnd = value;
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

  deleteEquipItem(id) {
    if (!confirm("从器械库删除这件器械？")) return;
    state.equipmentLibrary = state.equipmentLibrary.filter((item) => item.id !== id);
    state.equipmentItemId = null;
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
  state.screen = "tabs";
  state.tab = "equipment";
}
if (previewParams.has("equipPhoto")) {
  state.onboarded = true;
  state.screen = "equipmentRecognition";
  state.equipRecognitionPhoto = true;
  state.equipRecognitionCandidates = [];
}

render();
