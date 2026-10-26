/* FitAI Web Preview module: demo data, builders, and domain helpers. */

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

const FOOD_FIBER = {
  "燕麦（干）": 10.6, "米饭": 0.3, "糙米饭": 1.8, "红薯": 3.0, "全麦面包": 6.0,
  "包子": 1.5, "饺子": 1.8, "炒饭": 1.2, "便利店饭团": 1.2,
  "鸡胸肉": 0, "鸡蛋": 0, "牛肉": 0, "三文鱼": 0, "豆腐": 2.3, "牛奶": 0,
  "无糖酸奶": 0, "乳清蛋白粉": 0, "西兰花": 2.6, "菠菜": 2.2, "番茄": 1.2,
  "苹果": 2.4, "香蕉": 2.6, "蓝莓": 2.4, "坚果": 7.0, "橄榄油": 0,
  "拿铁": 0, "可乐": 0, "奶茶": 0.5, "螺蛳粉": 2.0, "桂林米粉": 1.2,
  "兰州拉面": 1.5, "酸辣粉": 1.2, "凉皮": 1.0, "牛肉面": 1.5, "麻辣烫": 2.5,
  "麻辣香锅": 2.2, "火锅": 2.0, "烧烤": 1.2, "炸鸡": 0.8, "汉堡": 1.8,
  "薯条": 3.0, "煎饼果子": 2.0, "肉夹馍": 1.5, "小笼包": 1.2, "蛋糕": 0.8
};

FOODS.forEach((food) => {
  food.fiber = Number.isFinite(Number(FOOD_FIBER[food.name]))
    ? Number(FOOD_FIBER[food.name])
    : Math.round(Math.max(0, Number(food.c) || 0) * 0.05 * 10) / 10;
});

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
  crown: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="m4 8 4 3 4-6 4 6 4-3-2 10H6z"/><path d="M6 21h12"/></svg>',
  trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V4h6v3M7 7l1 13h8l1-13"/><path d="M10 11v5M14 11v5"/></svg>',
  utensils: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M7 3v8M4 3v5a3 3 0 0 0 6 0V3M7 11v10M16 3c2 2 2 5 2 8s-.7 3-2 3-2-.3-2-3 .7-6 2-8Z"/><path d="M16 14v7"/></svg>',
  image: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="10" r="2"/><path d="m4 18 5-5 3 3 2-2 6 5"/></svg>',
  heart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M20.8 5.6a5.5 5.5 0 0 0-7.8 0L12 6.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 22l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z"/></svg>',
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
      f: Math.round(food.f * factor * 10) / 10,
      fiber: Math.round((food.fiber || 0) * factor * 10) / 10
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

function todayKey() {
  return localDateInputValue(new Date());
}

function parseDateKey(key) {
  const [year, month, day] = String(key || todayKey()).split("-").map(Number);
  return new Date(year, month - 1, day);
}

function addDays(date, amount) {
  const next = new Date(date);
  next.setDate(next.getDate() + amount);
  return next;
}

function startOfWeekMonday(date = new Date()) {
  const next = new Date(date);
  next.setHours(0, 0, 0, 0);
  const offset = (next.getDay() + 6) % 7;
  return addDays(next, -offset);
}

function monthKey(date = new Date()) {
  return localDateInputValue(date).slice(0, 7);
}

function monthLabel(key) {
  const [year, month] = key.split("-").map(Number);
  return `${year}年${month}月`;
}

function weekdayLabel(date) {
  return ["日", "一", "二", "三", "四", "五", "六"][date.getDay()];
}

function dateLabel(key) {
  const date = parseDateKey(key);
  return `${date.getMonth() + 1}月${date.getDate()}日 · 周${weekdayLabel(date)}`;
}

function planStartMonday() {
  const createdAt = Number(state.plan?.createdAt);
  return startOfWeekMonday(Number.isFinite(createdAt) && createdAt > 0 ? new Date(createdAt) : new Date());
}

function currentPlanWeekNumber() {
  const start = planStartMonday();
  const current = startOfWeekMonday(new Date());
  const weeks = Math.floor((current - start) / 604800000) + 1;
  return Math.max(1, Math.min(Number(state.plan?.weeks) || 4, weeks));
}

function planDayDateKey(day) {
  const base = planStartMonday();
  return localDateInputValue(addDays(base, (Number(day.week) - 1) * 7 + Number(day.weekday) - 1));
}

function planDayForDateKey(key) {
  return state.plan.days.find((day) => planDayDateKey(day) === key) || null;
}

function sessionDateKey(session) {
  if (Number.isFinite(Number(session.timestamp))) {
    return localDateInputValue(new Date(Number(session.timestamp)));
  }
  const match = String(session.date || "").match(/(\d{1,2})月(\d{1,2})日/);
  if (!match) return todayKey();
  return localDateInputValue(new Date(new Date().getFullYear(), Number(match[1]) - 1, Number(match[2])));
}

function sessionsForDateKey(key) {
  return state.sessions.filter((session) => sessionDateKey(session) === key);
}

function foodLogsForDateKey(key) {
  return state.foodLogs.filter((log) => (log.date || todayKey()) === key);
}

function sortedSessionsNewest() {
  return state.sessions
    .slice()
    .sort((left, right) => Number(right.timestamp || 0) - Number(left.timestamp || 0));
}

function currentWeekSessions() {
  const start = startOfWeekMonday(new Date());
  const end = addDays(start, 7);
  return state.sessions.filter((session) => {
    const timestamp = Number(session.timestamp);
    const date = timestamp ? new Date(timestamp) : parseDateKey(sessionDateKey(session));
    return date >= start && date < end;
  });
}

function sessionListRow(session, origin = "home") {
  return `
    <div class="recent-row" onclick="app.openSession('${session.id}', '${origin}')">
      <div class="grow">
        <div class="small strong">${esc(String(session.title || "").slice(0, 40))}</div>
        <div class="tiny faint">${esc(session.date || sessionDateLabel(session.timestamp))}</div>
      </div>
      <div style="text-align:right">
        <div class="small accent" style="font-weight:650">${Math.round(Number(session.volume) || 0).toLocaleString()} kg</div>
        <div class="tiny faint">${session.duration} 分钟</div>
      </div>
      <div class="faint">›</div>
    </div>
  `;
}

function sessionDateLabel(timestamp) {
  const date = new Date(timestamp);
  return `${date.getMonth() + 1}月${date.getDate()}日 ${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}

function updateFieldCounter(id, value, limit) {
  const counter = document.getElementById(id);
  if (counter) counter.textContent = `${String(value || "").slice(0, limit).length}/${limit}`;
}

function greetingText() {
  const hour = new Date().getHours();
  if (hour < 5) return "夜深了";
  if (hour < 9) return "早上好";
  if (hour < 12) return "上午好";
  if (hour < 14) return "中午好";
  if (hour < 18) return "下午好";
  return "晚上好";
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
  const reps = profile.goal === "增肌" ? "8" : profile.goal === "减脂" ? "12" : profile.goal === "提升体能" ? "15" : "10";
  const sets = profile.goal === "增肌" ? 4 : 3;
  const rest = profile.goal === "增肌" ? 90 : profile.goal === "减脂" ? 45 : 60;
  const days = [];
  for (let week = 1; week <= 4; week += 1) {
    templates.forEach((template, slot) => {
      days.push({
        id: `w${week}d${template.weekday}`,
        week,
        weekday: template.weekday,
        slot,
        title: template.title,
        focus: template.focus,
        exercises: template.slugs.map((slug) => {
          const ex = EX[slug];
          const weight = ex.base ? roundHalf(ex.base * (1 + 0.025 * (week - 1))) : 0;
          return {
            slug,
            sets,
            reps: String(parseReps(ex.fixedReps || reps)),
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
    createdAt: Date.now(),
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
      reps: String(parseReps(exercise.fixedReps || "10")),
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

