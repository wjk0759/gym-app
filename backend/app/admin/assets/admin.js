(() => {
  "use strict";

  const API = "/api/v1/admin";
  const PAGE_SIZE = 25;
  const TOKEN_KEY = "fitai_admin_token";

  const state = {
    token: localStorage.getItem(TOKEN_KEY) || "",
    view: "dashboard",
    env: "dev",
    users: { q: "", offset: 0 },
    plans: { q: "", status: "", offset: 0 },
    workouts: { q: "", offset: 0 },
    chats: { q: "", safety: false, offset: 0 },
    scans: { q: "", offset: 0 },
    exercises: { q: "", offset: 0 },
    videos: { q: "", status: "", items: [] },
    ai: { q: "", status: "", kind: "", offset: 0 },
    auditOffset: 0
  };

  const $ = (id) => document.getElementById(id);
  const loginScreen = $("login-screen");
  const adminApp = $("admin-app");
  const viewRoot = $("view-root");
  const modalRoot = $("modal-root");
  const toastEl = $("toast");

  const META = {
    dashboard: ["数据概览", "产品运行状态与最近活动"],
    users: ["用户", "用户档案、目标、训练与对话数据"],
    plans: ["训练计划", "查看和调整用户计划版本"],
    workouts: ["训练记录", "逐组训练数据、容量与完成情况"],
    chats: ["AI 对话", "查看对话内容与安全拦截"],
    scans: ["器械识别", "识别结果、置信度与模型来源"],
    exercises: ["动作库", "维护动作说明、禁忌症和器材信息"],
    videos: ["教学视频", "上传、审核、发布和管理动作示范视频"],
    ai: ["AI 使用", "DeepSeek 调用、技能使用、延迟和失败情况"],
    audit: ["操作日志", "管理员在后台执行的所有操作"]
  };

  function esc(value) {
    return String(value ?? "").replace(/[&<>"']/g, (ch) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[ch]));
  }

  function dateText(value, withTime = false) {
    if (!value) return "—";
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return esc(value);
    return withTime
      ? d.toLocaleString("zh-CN", { month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit" })
      : d.toLocaleDateString("zh-CN", { year: "numeric", month: "2-digit", day: "2-digit" });
  }

  function num(value) {
    return value === null || value === undefined || value === "" ? "—" : Number(value).toLocaleString("zh-CN");
  }

  function badge(text, tone = "") {
    return `<span class="badge ${tone}">${esc(text)}</span>`;
  }

  function toast(message, error = false) {
    toastEl.textContent = message;
    toastEl.className = "toast show" + (error ? " error" : "");
    clearTimeout(toastEl._timer);
    toastEl._timer = setTimeout(() => { toastEl.className = "toast"; }, 2400);
  }

  async function api(path, options = {}) {
    const isForm = options.body instanceof FormData;
    const response = await fetch(API + path, {
      ...options,
      headers: {
        ...(!isForm ? { "Content-Type": "application/json" } : {}),
        ...(state.token ? { "X-Admin-Token": state.token } : {}),
        ...(options.headers || {})
      }
    });
    if (response.status === 401) {
      logout();
      throw new Error("管理员口令已失效，请重新登录");
    }
    const body = await response.json().catch(() => null);
    if (!response.ok) {
      throw new Error((body && (body.detail || (body.error && body.error.message))) || `请求失败（${response.status}）`);
    }
    return body;
  }

  function showLogin(message = "") {
    adminApp.hidden = true;
    loginScreen.hidden = false;
    $("login-error").textContent = message;
    setTimeout(() => $("token-input")?.focus(), 30);
  }

  function enterApp() {
    loginScreen.hidden = true;
    adminApp.hidden = false;
    $("env-badge").textContent = state.env.toUpperCase();
    navigate(state.view);
  }

  function logout() {
    state.token = "";
    localStorage.removeItem(TOKEN_KEY);
    closeModal();
    showLogin();
  }

  function showModal(content, narrow = false) {
    modalRoot.innerHTML = `<div class="modal-backdrop" onclick="if(event.target===this)admin.closeModal()"><div class="modal ${narrow ? "narrow" : ""}">${content}</div></div>`;
  }

  function closeModal() { modalRoot.innerHTML = ""; }

  function modalHead(title, subtitle = "") {
    return `<div class="modal-head"><div><h2>${esc(title)}</h2>${subtitle ? `<p>${esc(subtitle)}</p>` : ""}</div><button class="modal-close" onclick="admin.closeModal()">×</button></div>`;
  }

  function loading() { viewRoot.innerHTML = `<div class="loading">正在加载…</div>`; }
  function errorView(error) { viewRoot.innerHTML = `<div class="error-state">${esc(error.message || error)}</div>`; }
  function empty(text) { return `<div class="empty-state"><strong>暂无数据</strong>${esc(text)}</div>`; }

  function pager(offset, total, handler, label = "列表") {
    const page = Math.floor(offset / PAGE_SIZE) + 1;
    const pages = Math.max(1, Math.ceil(total / PAGE_SIZE));
    return `<div class="pager"><span>${label} · 第 ${page}/${pages} 页 · 共 ${num(total)} 条</span>
      <button class="btn btn-sm" onclick="admin.${handler}(-1)" ${offset <= 0 ? "disabled" : ""}>上一页</button>
      <button class="btn btn-sm" onclick="admin.${handler}(1)" ${offset + PAGE_SIZE >= total ? "disabled" : ""}>下一页</button></div>`;
  }

  function statCard(label, value, hint, tone = "") {
    return `<div class="stat-card ${tone}"><div class="label">${esc(label)}</div><div class="value">${esc(value)}</div><div class="hint">${esc(hint)}</div></div>`;
  }

  function chart(daily) {
    const max = Math.max(1, ...daily.flatMap((d) => [d.users, d.workouts]));
    return `<div class="chart">${daily.map((d, i) => `
      <div class="chart-col" title="${d.date} · 新增用户 ${d.users} · 训练 ${d.workouts}">
        <div class="chart-bars">
          <span class="chart-bar" style="height:${Math.max(2, d.users / max * 100)}%"></span>
          <span class="chart-bar workouts" style="height:${Math.max(2, d.workouts / max * 100)}%"></span>
        </div>
        <div class="chart-label">${i % 2 === 0 ? d.date.slice(5) : ""}</div>
      </div>`).join("")}</div>
      <div class="chart-legend"><span><i style="background:rgba(92,219,140,.58)"></i>新增用户</span><span><i style="background:rgba(143,179,250,.58)"></i>训练记录</span></div>`;
  }

  function bars(items, key, countKey) {
    if (!items || !items.length) return `<div class="muted small">暂无数据</div>`;
    const max = Math.max(1, ...items.map((item) => item[countKey]));
    return `<div class="bar-list">${items.map((item) => `<div class="bar-line"><span>${esc(item[key] || "未知")}</span><div class="bar-track"><div class="bar-fill" style="width:${item[countKey] / max * 100}%"></div></div><span class="bar-num">${num(item[countKey])}</span></div>`).join("")}</div>`;
  }

  async function renderDashboard() {
    loading();
    const d = await api("/stats");
    viewRoot.innerHTML = `
      <div class="stat-grid">
        ${statCard("用户总数", num(d.users_total), `近 7 天新增 ${num(d.users_new_7d)} · 已建档 ${num(d.onboarded)}`, "accent")}
        ${statCard("近 7 日活跃", num(d.active_7d), `近 30 日活跃 ${num(d.active_30d)}`)}
        ${statCard("训练记录", num(d.sessions_total), `近 7 天 ${num(d.sessions_7d)} 次`)}
        ${statCard("活跃计划", num(d.programs_active), `累计计划 ${num(d.programs_total)} 个`)}
      </div>
      <div class="panel-grid">
        <div class="panel"><div class="panel-head"><div><h2>14 天趋势</h2><p>新增用户与训练记录</p></div><span class="badge blue">实时</span></div>${chart(d.daily)}</div>
        <div class="panel"><div class="panel-head"><div><h2>用户画像</h2><p>目标与器械分布</p></div></div>
          <div class="muted small" style="margin-bottom:8px">训练目标</div>${bars(d.goals.map((x) => ({ ...x, name: x.label })), "name", "count")}
          <div class="muted small" style="margin:16px 0 8px">器械类型</div>${bars(d.equipment, "type", "count")}
        </div>
      </div>
      <div class="stat-grid">
        ${statCard("AI 对话", num(d.chats_total), `${num(d.messages_total)} 条消息`)}
        ${statCard("安全拦截", num(d.safety_total), "需要人工关注的高风险消息", d.safety_total ? "warning" : "")}
        ${statCard("器械识别", num(d.scans_total), "服务端识别记录")}
        ${statCard("AI 异常", num(d.ai_errors), "非 ok 状态的 AI 任务", d.ai_errors ? "warning" : "")}
      </div>
      <div class="panel-grid">
        <div class="panel"><div class="panel-head"><div><h2>最近注册用户</h2><p>点击查看用户完整数据</p></div></div><div class="list">
          ${d.recent_users.length ? d.recent_users.map((u) => `<div class="list-row"><div><div class="primary">${esc(u.nickname)}</div><div class="secondary">${esc(u.id)}</div></div><div class="side">${dateText(u.created_at, true)}<br><button class="link-btn" onclick="admin.openUser('${u.id}')">查看</button></div></div>`).join("") : empty("还没有用户")}
        </div></div>
        <div class="panel"><div class="panel-head"><div><h2>最近训练</h2><p>最新服务端训练记录</p></div></div><div class="list">
          ${d.recent_workouts.length ? d.recent_workouts.map((x) => `<div class="list-row"><div><div class="primary">${esc(x.nickname)}</div><div class="secondary">${x.set_count} 组 · ${num(x.volume_kg)} kg 容量</div></div><div class="side">${dateText(x.started_at, true)}<br><button class="link-btn" onclick="admin.openWorkout('${x.id}')">详情</button></div></div>`).join("") : empty("还没有训练记录")}
        </div></div>
      </div>
      <div class="panel"><div class="panel-head"><div><h2>安全兜底消息</h2><p>胸痛、眩晕、孕期、术后等高风险提问</p></div>${badge(d.safety_total + " 条", d.safety_total ? "warning" : "")}</div><div class="list">
        ${d.recent_safety.length ? d.recent_safety.map((x) => `<div class="list-row"><div><div class="primary">${esc(x.nickname)} ${badge(x.safety_flag, "warning")}</div><div class="secondary">${esc(x.content)}</div></div><div class="side">${dateText(x.created_at, true)}</div></div>`).join("") : empty("暂无安全兜底记录")}
      </div></div>
      <div class="note warning" style="margin-top:14px">管理后台只展示服务端已同步的数据。当前饮食记录、体型分析和器械库主要保存在 App 本地；如需完整管理，需要先补设备端到服务端的数据同步接口。</div>
    `;
  }

  async function renderUsers() {
    loading();
    const d = await api(`/users?q=${encodeURIComponent(state.users.q)}&limit=${PAGE_SIZE}&offset=${state.users.offset}&include_deleted=true`);
    viewRoot.innerHTML = `
      <div class="toolbar">
        <input class="search" id="user-search" placeholder="搜索昵称、用户 ID 或手机号" value="${esc(state.users.q)}" onkeydown="if(event.key==='Enter')admin.searchUsers()">
        <button class="btn btn-primary btn-sm" onclick="admin.searchUsers()">搜索</button>
        <button class="btn btn-sm" onclick="admin.reloadUsers()">刷新</button><div class="spacer"></div><span class="muted small">共 ${num(d.total)} 位用户</span>
      </div>
      <div class="table-wrap"><table class="data-table"><thead><tr><th>用户</th><th>基础数据</th><th>目标</th><th>计划 / 训练</th><th>最近训练</th><th>状态</th><th>操作</th></tr></thead><tbody>
        ${d.items.length ? d.items.map((u) => `<tr>
          <td><div class="strong">${esc(u.nickname)}</div><div class="mono">${esc(u.id)}</div></td>
          <td>${u.age ? u.age + " 岁" : "—"} · ${u.height_cm ? u.height_cm + " cm" : "—"}<br><span class="mono">${u.weight_kg ? u.weight_kg + " kg · BMI " + (u.bmi ?? "—") : "—"}</span></td>
          <td>${u.goal_label ? badge(u.goal_label, "blue") : "—"}</td>
          <td>${num(u.plan_count)} 个计划<br><span class="muted">${num(u.workout_count)} 次训练</span></td>
          <td>${u.last_workout_at ? dateText(u.last_workout_at, true) : "—"}</td>
          <td>${u.deleted_at ? badge("已注销", "danger") : u.onboarded ? badge("已建档", "accent") : badge("未建档")}</td>
          <td><div class="actions"><button class="link-btn" onclick="admin.openUser('${u.id}')">查看</button>${u.deleted_at ? `<button class="link-btn" onclick="admin.restoreUser('${u.id}')">恢复</button>` : `<button class="link-btn danger" onclick="admin.softDeleteUser('${u.id}')">注销</button>`}</div></td>
        </tr>`).join("") : `<tr><td colspan="7" class="empty-cell">没有匹配的用户</td></tr>`}
      </tbody></table></div>${pager(state.users.offset, d.total, "pageUsers", "用户列表")}
    `;
  }

  async function openUser(id) {
    showModal(`${modalHead("加载中…")}<div class="modal-body"><div class="loading">正在加载用户数据…</div></div>`, true);
    try {
      const d = await api(`/users/${id}`);
      const p = d.profile || {};
      const goals = d.goals || [];
      const goal = goals.find((x) => x.status === "active") || goals[0];
      const deleted = Boolean(d.user.deleted_at);
      showModal(`
        ${modalHead(p.nickname || "未建档用户", `${d.user.id} · 注册于 ${dateText(d.user.created_at)}`)}
        <div class="modal-body">
          <div class="detail-grid">
            <div class="detail-section"><h3>基础档案</h3><div class="kv-grid">
              <div class="kv"><div class="k">昵称</div><div class="v">${esc(p.nickname || "—")}</div></div>
              <div class="kv"><div class="k">性别 / 年龄</div><div class="v">${esc(p.sex || "—")} · ${p.age ?? "—"}</div></div>
              <div class="kv"><div class="k">身高</div><div class="v">${p.height_cm ?? "—"} cm</div></div>
              <div class="kv"><div class="k">体重</div><div class="v">${p.weight_kg ?? "—"} kg</div></div>
              <div class="kv"><div class="k">BMI</div><div class="v">${p.bmi ?? "—"}</div></div>
              <div class="kv"><div class="k">训练经验</div><div class="v">${esc(p.experience || "—")}</div></div>
              <div class="kv"><div class="k">每周训练</div><div class="v">${p.weekly_days ?? "—"} 天</div></div>
              <div class="kv"><div class="k">单次时长</div><div class="v">${p.session_minutes ?? "—"} 分钟</div></div>
            </div>
            <div class="kv" style="margin-top:10px"><div class="k">可用器械</div><div class="chip-row">${(p.equipment || []).map((x) => badge(x)).join("") || "—"}</div></div>
            ${p.injuries && p.injuries.length ? `<div class="kv" style="margin-top:10px"><div class="k">伤病 / 疼痛</div><div class="v">${esc(p.injuries.join("、"))}</div></div>` : ""}
            </div>
            <div class="detail-section"><h3>当前目标</h3>${goal ? `<div class="kv-grid">
              <div class="kv"><div class="k">目标类型</div><div class="v">${esc(goal.type)}</div></div>
              <div class="kv"><div class="k">目标体重</div><div class="v">${goal.target_weight_kg ?? "—"} kg</div></div>
              <div class="kv"><div class="k">目标腰围</div><div class="v">${goal.target_waist_cm ?? "—"} cm</div></div>
              <div class="kv"><div class="k">目标日期</div><div class="v">${esc(goal.target_date || "—")}</div></div>
            </div>` : `<div class="muted small">尚未设置目标</div>`}
            <h3 style="margin-top:16px">概览</h3><div class="kv-grid">
              <div class="kv"><div class="k">训练</div><div class="v">${num(d.metrics.workouts)} 次</div></div>
              <div class="kv"><div class="k">总容量</div><div class="v">${num(d.metrics.volume_kg)} kg</div></div>
              <div class="kv"><div class="k">对话</div><div class="v">${num(d.metrics.chats)} 个</div></div>
              <div class="kv"><div class="k">器械识别</div><div class="v">${num(d.metrics.scans)} 次</div></div>
            </div></div>
          </div>
          <div class="detail-section" style="margin-top:14px"><h3>训练计划</h3>
            ${d.programs.length ? d.programs.map((x) => `<div class="list-row"><div><div class="primary">${esc(x.title)}</div><div class="secondary">v${x.version} · ${x.day_count} 个训练日 · ${esc(x.status)}</div></div><div class="side"><button class="link-btn" onclick="admin.openPlan('${x.id}')">查看</button></div></div>`).join("") : `<div class="muted small">暂无计划</div>`}
          </div>
          <div class="detail-grid" style="margin-top:14px">
            <div class="detail-section"><h3>最近训练</h3>${d.workouts.length ? d.workouts.slice(0, 6).map((x) => `<div class="list-row"><div><div class="primary">${dateText(x.started_at, true)}</div><div class="secondary">${x.set_count} 组 · ${num(x.volume_kg)} kg · ${x.duration_min ?? "—"} 分钟</div></div><div class="side"><button class="link-btn" onclick="admin.openWorkout('${x.id}')">详情</button></div></div>`).join("") : `<div class="muted small">暂无训练</div>`}</div>
            <div class="detail-section"><h3>最近对话</h3>${d.chats.length ? d.chats.slice(0, 6).map((x) => `<div class="list-row"><div><div class="primary">${esc(x.title)}</div><div class="secondary">${x.message_count} 条 · ${x.safety_count} 条安全拦截</div></div><div class="side"><button class="link-btn" onclick="admin.openChat('${x.id}')">查看</button></div></div>`).join("") : `<div class="muted small">暂无对话</div>`}</div>
          </div>
          <div class="note" style="margin-top:14px">饮食记录、体型照片分析和器械库当前主要保存在 App 本地，后台暂无法读取这些数据。</div>
          <div class="modal-actions"><button class="btn btn-primary" onclick="admin.exportUser('${d.user.id}')">导出用户数据</button>
            ${deleted ? `<button class="btn" onclick="admin.restoreUser('${d.user.id}')">恢复账号</button><button class="btn btn-danger" onclick="admin.purgeUser('${d.user.id}')">彻底删除</button>` : `<button class="btn btn-danger" onclick="admin.softDeleteUser('${d.user.id}')">注销账号</button>`}
            <div style="flex:1"></div>${deleted ? badge("已注销", "danger") : badge("正常", "accent")}
          </div>
        </div>`);
    } catch (error) {
      toast(error.message, true);
      closeModal();
    }
  }

  async function exportUser(id) {
    try {
      const d = await api(`/users/${id}/export`);
      const blob = new Blob([JSON.stringify(d, null, 2)], { type: "application/json" });
      const link = document.createElement("a");
      link.href = URL.createObjectURL(blob);
      link.download = `fitai-user-${id}.json`;
      link.click();
      URL.revokeObjectURL(link.href);
      toast("用户数据已导出");
    } catch (error) { toast(error.message, true); }
  }

  async function softDeleteUser(id) {
    if (!confirm("确认注销这个用户？数据仍保留，可在后台恢复。")) return;
    try { await api(`/users/${id}?purge=false`, { method: "DELETE" }); closeModal(); toast("用户已注销"); renderUsers(); }
    catch (error) { toast(error.message, true); }
  }

  async function purgeUser(id) {
    if (!confirm("彻底删除会清除档案、计划、训练和对话，且无法恢复。继续？")) return;
    if (!confirm("最后确认：真的要彻底删除这个用户吗？")) return;
    try { await api(`/users/${id}?purge=true`, { method: "DELETE" }); closeModal(); toast("用户已彻底删除"); renderUsers(); }
    catch (error) { toast(error.message, true); }
  }

  async function restoreUser(id) {
    try { await api(`/users/${id}/restore`, { method: "POST" }); closeModal(); toast("用户已恢复"); renderUsers(); }
    catch (error) { toast(error.message, true); }
  }

  async function renderPlans() {
    loading();
    const d = await api(`/programs?q=${encodeURIComponent(state.plans.q)}&status=${encodeURIComponent(state.plans.status)}&limit=${PAGE_SIZE}&offset=${state.plans.offset}`);
    viewRoot.innerHTML = `
      <div class="toolbar">
        <input class="search" id="plan-search" placeholder="搜索计划标题、昵称或用户 ID" value="${esc(state.plans.q)}" onkeydown="if(event.key==='Enter')admin.searchPlans()">
        <select id="plan-status" style="width:130px" onchange="admin.searchPlans()"><option value="" ${state.plans.status === "" ? "selected" : ""}>全部状态</option><option value="active" ${state.plans.status === "active" ? "selected" : ""}>使用中</option><option value="archived" ${state.plans.status === "archived" ? "selected" : ""}>已归档</option></select>
        <button class="btn btn-primary btn-sm" onclick="admin.searchPlans()">搜索</button><button class="btn btn-sm" onclick="admin.reloadPlans()">刷新</button><div class="spacer"></div><span class="muted small">共 ${num(d.total)} 个计划</span>
      </div>
      <div class="table-wrap"><table class="data-table"><thead><tr><th>计划</th><th>用户</th><th>版本</th><th>状态</th><th>周期</th><th>训练日</th><th>生成方式</th><th>操作</th></tr></thead><tbody>
        ${d.items.length ? d.items.map((x) => `<tr>
          <td><div class="strong">${esc(x.title)}</div><div class="mono">${esc(x.id)}</div></td>
          <td>${esc(x.nickname)}<br><span class="mono">${esc(x.user_id)}</span></td>
          <td>v${x.version}</td><td>${x.status === "active" ? badge("使用中", "accent") : badge(x.status)}</td>
          <td>${x.weeks} 周<br><span class="muted">${dateText(x.start_date)}</span></td>
          <td>${x.day_count} 天<br><span class="muted">${x.exercise_count} 个动作</span></td>
          <td>${esc(x.generated_by || "—")}<br><span class="muted">${esc(x.model_name || "—")}</span></td>
          <td><div class="actions"><button class="link-btn" onclick="admin.openPlan('${x.id}')">查看</button>${x.status === "active" ? `<button class="link-btn danger" onclick="admin.archivePlan('${x.id}')">归档</button>` : `<button class="link-btn" onclick="admin.activatePlan('${x.id}')">启用</button>`}</div></td>
        </tr>`).join("") : `<tr><td colspan="8" class="empty-cell">没有匹配的计划</td></tr>`}
      </tbody></table></div>${pager(state.plans.offset, d.total, "pagePlans", "计划列表")}
    `;
  }

  async function openPlan(id) {
    try {
      const p = await api(`/programs/${id}`);
      showModal(`
        ${modalHead(p.title, `${p.nickname} · v${p.version} · ${p.weeks} 周`)}
        <div class="modal-body">
          <div class="kv-grid">
            <div class="kv"><div class="k">状态</div><div class="v">${p.status === "active" ? badge("使用中", "accent") : badge(p.status)}</div></div>
            <div class="kv"><div class="k">开始日期</div><div class="v">${dateText(p.start_date)}</div></div>
            <div class="kv"><div class="k">生成方式</div><div class="v">${esc(p.generated_by || "—")} · ${esc(p.model_name || "—")}</div></div>
            <div class="kv"><div class="k">训练日</div><div class="v">${p.days.length} 天</div></div>
          </div>
          <div class="program-days" style="margin-top:16px">${p.days.map((day) => `
            <div class="program-day"><h4>第 ${day.week_index} 周 · 周${"一二三四五六日"[day.weekday - 1] || day.weekday} · ${esc(day.title)}</h4>
              ${day.exercises.map((item) => `<div class="program-exercise"><span>${esc(item.name_zh || item.slug)}</span><span class="target">${item.sets} 组 × ${esc(item.reps)}${item.weight_kg ? " · " + item.weight_kg + "kg" : ""} · RPE ${item.rpe ?? "—"}</span></div>`).join("")}
            </div>`).join("")}</div>
          <div class="modal-actions">${p.status === "active" ? `<button class="btn btn-danger" onclick="admin.archivePlan('${p.id}')">归档此计划</button>` : `<button class="btn btn-primary" onclick="admin.activatePlan('${p.id}')">设为使用中</button>`}</div>
        </div>`);
    } catch (error) { toast(error.message, true); closeModal(); }
  }

  async function archivePlan(id) {
    if (!confirm("确认归档这个计划？归档后用户当前计划会变为不可用状态。")) return;
    try { await api(`/programs/${id}/archive`, { method: "POST" }); closeModal(); toast("计划已归档"); renderPlans(); }
    catch (error) { toast(error.message, true); }
  }

  async function activatePlan(id) {
    if (!confirm("确认将这个计划设为该用户当前计划？其他使用中的计划会被归档。")) return;
    try { await api(`/programs/${id}/activate`, { method: "POST" }); closeModal(); toast("计划已启用"); renderPlans(); }
    catch (error) { toast(error.message, true); }
  }

  async function renderWorkouts() {
    loading();
    const d = await api(`/workouts?q=${encodeURIComponent(state.workouts.q)}&limit=${PAGE_SIZE}&offset=${state.workouts.offset}`);
    viewRoot.innerHTML = `
      <div class="toolbar"><input class="search" id="workout-search" placeholder="搜索用户昵称或用户 ID" value="${esc(state.workouts.q)}" onkeydown="if(event.key==='Enter')admin.searchWorkouts()"><button class="btn btn-primary btn-sm" onclick="admin.searchWorkouts()">搜索</button><button class="btn btn-sm" onclick="admin.reloadWorkouts()">刷新</button><div class="spacer"></div><span class="muted small">共 ${num(d.total)} 条记录</span></div>
      <div class="table-wrap"><table class="data-table"><thead><tr><th>用户</th><th>开始时间</th><th>时长</th><th>组数</th><th>容量</th><th>感受</th><th>操作</th></tr></thead><tbody>
        ${d.items.length ? d.items.map((x) => `<tr><td><div class="strong">${esc(x.nickname)}</div><div class="mono">${esc(x.user_id)}</div></td><td>${dateText(x.started_at, true)}<br><span class="mono">${esc(x.id)}</span></td><td>${x.duration_min ?? "—"} 分钟</td><td>${x.set_count}</td><td>${num(x.volume_kg)} kg</td><td>${x.feeling ?? "—"} / 5</td><td><div class="actions"><button class="link-btn" onclick="admin.openWorkout('${x.id}')">查看</button><button class="link-btn danger" onclick="admin.deleteWorkout('${x.id}')">删除</button></div></td></tr>`).join("") : `<tr><td colspan="7" class="empty-cell">没有匹配的训练记录</td></tr>`}
      </tbody></table></div>${pager(state.workouts.offset, d.total, "pageWorkouts", "训练记录")}
    `;
  }

  async function openWorkout(id) {
    try {
      const d = await api(`/workouts/${id}`);
      showModal(`${modalHead("训练记录详情", `${d.nickname} · ${dateText(d.started_at, true)}`)}<div class="modal-body">
        <div class="stat-grid" style="margin-bottom:14px">${statCard("完成组数", d.set_count, "含未完成组")}${statCard("总容量", num(d.volume_kg), "kg")}${statCard("时长", d.duration_min ?? "—", "分钟")}${statCard("训练感受", d.feeling ?? "—", "满分 5")}</div>
        <div class="table-wrap"><table class="data-table" style="min-width:480px"><thead><tr><th>动作</th><th>组</th><th>重量</th><th>次数</th><th>RPE</th><th>完成</th></tr></thead><tbody>${d.sets.map((x) => `<tr><td class="strong">${esc(x.slug)}</td><td>${x.set_index}</td><td>${x.weight_kg ?? "—"} kg</td><td>${x.reps ?? "—"}</td><td>${x.rpe ?? "—"}</td><td>${x.completed ? "✓" : "—"}</td></tr>`).join("") || `<tr><td colspan="6" class="empty-cell">没有组记录</td></tr>`}</tbody></table></div>
        <div class="modal-actions"><button class="btn btn-danger" onclick="admin.deleteWorkout('${d.id}')">删除这条记录</button></div>
      </div>`);
    } catch (error) { toast(error.message, true); }
  }

  async function deleteWorkout(id) {
    if (!confirm("确认删除这条训练记录？该操作不可恢复。")) return;
    try { await api(`/workouts/${id}`, { method: "DELETE" }); closeModal(); toast("训练记录已删除"); renderWorkouts(); }
    catch (error) { toast(error.message, true); }
  }

  async function renderChats() {
    loading();
    const d = await api(`/chats?q=${encodeURIComponent(state.chats.q)}&safety_only=${state.chats.safety}&limit=${PAGE_SIZE}&offset=${state.chats.offset}`);
    viewRoot.innerHTML = `
      <div class="toolbar"><input class="search" id="chat-search" placeholder="搜索昵称、标题或用户 ID" value="${esc(state.chats.q)}" onkeydown="if(event.key==='Enter')admin.searchChats()"><button class="btn btn-primary btn-sm" onclick="admin.searchChats()">搜索</button><button class="btn btn-sm ${state.chats.safety ? "btn-danger" : ""}" onclick="admin.toggleSafetyOnly()">只看安全拦截</button><button class="btn btn-sm" onclick="admin.reloadChats()">刷新</button><div class="spacer"></div><span class="muted small">共 ${num(d.total)} 个对话</span></div>
      <div class="table-wrap"><table class="data-table"><thead><tr><th>对话</th><th>用户</th><th>消息</th><th>安全拦截</th><th>最后一条</th><th>时间</th><th>操作</th></tr></thead><tbody>
        ${d.items.length ? d.items.map((x) => `<tr><td><div class="strong">${esc(x.title)}</div><div class="mono">${esc(x.id)}</div></td><td>${esc(x.nickname)}<br><span class="mono">${esc(x.user_id)}</span></td><td>${x.message_count}</td><td>${x.safety_count ? badge(x.safety_count + " 条", "warning") : "—"}</td><td style="max-width:270px">${esc(x.last_message || "—")}</td><td>${dateText(x.created_at, true)}</td><td><div class="actions"><button class="link-btn" onclick="admin.openChat('${x.id}')">查看</button><button class="link-btn danger" onclick="admin.deleteChat('${x.id}')">删除</button></div></td></tr>`).join("") : `<tr><td colspan="7" class="empty-cell">没有匹配的对话</td></tr>`}
      </tbody></table></div>${pager(state.chats.offset, d.total, "pageChats", "对话列表")}
    `;
  }

  async function openChat(id) {
    try {
      const d = await api(`/chats/${id}`);
      showModal(`${modalHead(d.title, `${d.nickname} · ${d.message_count} 条消息 · ${d.safety_count} 条安全拦截`)}<div class="modal-body">
        <div class="message-list">${d.messages.map((m) => `<div class="message-row ${m.role === "user" ? "user" : ""} ${m.safety_flag ? "safety" : ""}"><div class="message-meta"><span>${m.role === "user" ? "用户" : "AI 教练"} ${m.safety_flag ? badge(m.safety_flag, "warning") : ""}</span><span>${dateText(m.created_at, true)}</span></div><div class="message-content">${esc(m.content)}</div></div>`).join("")}</div>
        <div class="modal-actions"><button class="btn btn-danger" onclick="admin.deleteChat('${d.id}')">删除这个对话</button></div>
      </div>`);
    } catch (error) { toast(error.message, true); }
  }

  async function deleteChat(id) {
    if (!confirm("确认删除这个对话？该操作不可恢复。")) return;
    try { await api(`/chats/${id}`, { method: "DELETE" }); closeModal(); toast("对话已删除"); renderChats(); }
    catch (error) { toast(error.message, true); }
  }

  async function renderScans() {
    loading();
    const d = await api(`/scans?q=${encodeURIComponent(state.scans.q)}&limit=${PAGE_SIZE}&offset=${state.scans.offset}`);
    viewRoot.innerHTML = `
      <div class="toolbar"><input class="search" id="scan-search" placeholder="搜索用户昵称或用户 ID" value="${esc(state.scans.q)}" onkeydown="if(event.key==='Enter')admin.searchScans()"><button class="btn btn-primary btn-sm" onclick="admin.searchScans()">搜索</button><button class="btn btn-sm" onclick="admin.reloadScans()">刷新</button><div class="spacer"></div><span class="muted small">共 ${num(d.total)} 条识别记录</span></div>
      <div class="table-wrap"><table class="data-table"><thead><tr><th>用户</th><th>状态</th><th>模型</th><th>候选数</th><th>Top 结果</th><th>时间</th><th>操作</th></tr></thead><tbody>
        ${d.items.length ? d.items.map((x) => `<tr><td>${esc(x.nickname)}<br><span class="mono">${esc(x.user_id)}</span></td><td>${badge(x.status, x.status === "ok" ? "accent" : "")}</td><td>${esc(x.model || "—")}</td><td>${x.result_count}</td><td>${esc(x.top_result || "—")}</td><td>${dateText(x.created_at, true)}</td><td><div class="actions"><button class="link-btn" onclick="admin.openScan('${x.id}')">查看</button><button class="link-btn danger" onclick="admin.deleteScan('${x.id}')">删除</button></div></td></tr>`).join("") : `<tr><td colspan="7" class="empty-cell">没有识别记录</td></tr>`}
      </tbody></table></div>${pager(state.scans.offset, d.total, "pageScans", "识别记录")}
    `;
  }

  async function openScan(id) {
    try {
      const d = await api(`/scans/${id}`);
      showModal(`${modalHead("器械识别详情", `${d.nickname} · ${dateText(d.created_at, true)}`)}<div class="modal-body">
        <div class="kv-grid"><div class="kv"><div class="k">状态</div><div class="v">${badge(d.status, d.status === "ok" ? "accent" : "")}</div></div><div class="kv"><div class="k">模型</div><div class="v">${esc(d.model || "—")}</div></div></div>
        <div class="program-days" style="margin-top:14px">${d.result.map((x) => `<div class="program-day"><h4>${esc(x.name_zh || x.slug || "候选器械")} · ${Math.round((x.confidence || 0) * 100)}%</h4><div class="muted small">${esc(x.slug || "")} ${x.equipment ? "· " + esc(x.equipment) : ""}</div></div>`).join("") || `<div class="muted small">没有候选结果</div>`}</div>
        <div class="modal-actions"><button class="btn btn-danger" onclick="admin.deleteScan('${d.id}')">删除这条记录</button></div>
      </div>`);
    } catch (error) { toast(error.message, true); }
  }

  async function deleteScan(id) {
    if (!confirm("确认删除这条器械识别记录？")) return;
    try { await api(`/scans/${id}`, { method: "DELETE" }); closeModal(); toast("识别记录已删除"); renderScans(); }
    catch (error) { toast(error.message, true); }
  }

  async function renderExercises() {
    loading();
    const d = await api(`/exercises?q=${encodeURIComponent(state.exercises.q)}&limit=200&offset=${state.exercises.offset}`);
    viewRoot.innerHTML = `
      <div class="toolbar"><input class="search" id="exercise-search" placeholder="搜索动作、肌群或器械" value="${esc(state.exercises.q)}" onkeydown="if(event.key==='Enter')admin.searchExercises()"><button class="btn btn-primary btn-sm" onclick="admin.searchExercises()">搜索</button><button class="btn btn-sm" onclick="admin.reloadExercises()">刷新</button><div class="spacer"></div><span class="muted small">共 ${num(d.total)} 个动作</span></div>
      <div class="table-wrap"><table class="data-table"><thead><tr><th>动作</th><th>肌群</th><th>器械</th><th>难度</th><th>视频</th><th>禁忌症</th><th>操作</th></tr></thead><tbody>
        ${d.items.map((x) => `<tr><td><div class="strong">${esc(x.name_zh)}</div><div class="mono">${esc(x.slug)}</div></td><td>${esc(x.muscle_group)}</td><td>${esc(x.equipment)}</td><td>${x.difficulty}</td><td>${x.video_url ? badge("已配置", "accent") : badge("未配置")}</td><td>${(x.contraindications || []).length ? esc(x.contraindications.join("、")) : "—"}</td><td><button class="link-btn" onclick="admin.openExercise('${esc(x.slug)}')">编辑</button></td></tr>`).join("") || `<tr><td colspan="7" class="empty-cell">没有匹配的动作</td></tr>`}
      </tbody></table></div>
    `;
  }

  async function openExercise(slug) {
    try {
      const d = await api(`/exercises?q=${encodeURIComponent(slug)}&limit=10`);
      const x = d.items.find((item) => item.slug === slug);
      if (!x) throw new Error("动作不存在");
      showModal(`${modalHead(x.name_zh, x.slug)}<div class="modal-body">
        <form class="inline-form" onsubmit="event.preventDefault();admin.saveExercise('${esc(x.slug)}')">
          <div class="form-row two"><div><label>中文名</label><input id="ex-name-zh" value="${esc(x.name_zh)}"></div><div><label>英文名</label><input id="ex-name-en" value="${esc(x.name_en || "")}"></div></div>
          <div class="form-row two"><div><label>肌群</label><select id="ex-muscle">${["chest","back","legs","glutes","shoulders","arms","core","cardio"].map((v) => `<option ${x.muscle_group === v ? "selected" : ""}>${v}</option>`).join("")}</select></div><div><label>器械</label><select id="ex-equipment">${["bodyweight","dumbbell","barbell","machine","cable","band","kettlebell"].map((v) => `<option ${x.equipment === v ? "selected" : ""}>${v}</option>`).join("")}</select></div></div>
          <div class="form-row two"><div><label>难度 1–5</label><input id="ex-difficulty" type="number" min="1" max="5" value="${x.difficulty}"></div><div><label>禁忌症（逗号分隔）</label><input id="ex-contra" value="${esc((x.contraindications || []).join(", "))}"></div></div>
          <div class="form-row"><label>动作说明</label><textarea id="ex-instructions">${esc(x.instructions || "")}</textarea></div>
          <div class="form-row"><label>教学视频</label><div class="file-note">教学视频已统一迁移到「教学视频」模块，请先上传、预览并发布。</div></div>
          <div class="form-row"><label><input id="ex-compound" type="checkbox" style="width:auto;margin-right:7px" ${x.is_compound ? "checked" : ""}>复合动作</label></div>
          <div class="modal-actions"><button class="btn btn-primary" type="submit">保存修改</button><button class="btn" type="button" onclick="admin.closeModal()">取消</button></div>
        </form></div>`);
    } catch (error) { toast(error.message, true); }
  }

  async function saveExercise(slug) {
    try {
      await api(`/exercises/${encodeURIComponent(slug)}`, {
        method: "PATCH",
        body: JSON.stringify({
          name_zh: $("ex-name-zh").value.trim(),
          name_en: $("ex-name-en").value.trim() || null,
          muscle_group: $("ex-muscle").value,
          equipment: $("ex-equipment").value,
          difficulty: Number($("ex-difficulty").value),
          instructions: $("ex-instructions").value.trim() || null,
          contraindications: $("ex-contra").value.split(",").map((x) => x.trim()).filter(Boolean),
          is_compound: $("ex-compound").checked
        })
      });
      closeModal(); toast("动作已保存"); renderExercises();
    } catch (error) { toast(error.message, true); }
  }

  function videoStatusLabel(status) {
    return { published: "已发布", draft: "草稿", archived: "已归档" }[status] || status || "—";
  }

  function videoStatusBadge(status) {
    return badge(videoStatusLabel(status), status === "published" ? "accent" : status === "draft" ? "warning" : "");
  }

  function durationText(seconds) {
    if (!seconds) return "—";
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${String(secs).padStart(2, "0")}`;
  }

  async function uploadFile(file, kind) {
    const form = new FormData();
    form.append("file", file);
    form.append("kind", kind);
    return api("/videos/upload", { method: "POST", body: form });
  }

  async function renderVideos() {
    loading();
    const d = await api(`/videos?q=${encodeURIComponent(state.videos.q)}&status=${encodeURIComponent(state.videos.status)}&limit=200`);
    state.videos.items = d.items;
    viewRoot.innerHTML = `
      <div class="toolbar">
        <input class="search" id="video-search" placeholder="搜索动作或视频标题" value="${esc(state.videos.q)}" onkeydown="if(event.key==='Enter')admin.searchVideos()">
        <select id="video-status" style="width:130px" onchange="admin.searchVideos()">
          <option value="">全部状态</option>
          <option value="published" ${state.videos.status === "published" ? "selected" : ""}>已发布</option>
          <option value="draft" ${state.videos.status === "draft" ? "selected" : ""}>草稿</option>
          <option value="archived" ${state.videos.status === "archived" ? "selected" : ""}>已归档</option>
        </select>
        <button class="btn btn-primary btn-sm" onclick="admin.openVideoUpload()">上传视频</button>
        <button class="btn btn-sm" onclick="admin.reloadVideos()">刷新</button>
        <div class="spacer"></div><span class="muted small">共 ${num(d.total)} 条视频</span>
      </div>
      <div class="table-wrap"><table class="data-table"><thead><tr><th>动作 / 视频</th><th>状态</th><th>时长</th><th>来源与授权</th><th>更新时间</th><th>操作</th></tr></thead><tbody>
        ${d.items.map((x) => `<tr>
          <td><div class="strong">${esc(x.exercise_name || x.exercise_slug)}</div><div class="mono">${esc(x.exercise_slug)}</div><div class="small muted" style="margin-top:4px">${esc(x.title)}</div></td>
          <td>${videoStatusBadge(x.status)}</td>
          <td>${durationText(x.duration_seconds)}</td>
          <td><div class="small">${esc(x.source || "未填写来源")}</div><div class="small muted">${esc(x.license_note || "未填写授权")}${x.license_expires_at ? ` · 至 ${esc(x.license_expires_at)}` : ""}</div></td>
          <td class="muted small">${dateText(x.updated_at, true)}</td>
          <td><div class="actions"><button class="link-btn" onclick="admin.openVideo('${x.id}')">预览</button>${x.status === "published" ? `<button class="link-btn" onclick="admin.unpublishVideo('${x.id}')">下架</button>` : `<button class="link-btn" onclick="admin.publishVideo('${x.id}')">发布</button>`}<button class="link-btn" onclick="admin.editVideo('${x.id}')">编辑</button><button class="link-btn danger" onclick="admin.deleteVideo('${x.id}')">删除</button></div></td>
        </tr>`).join("") || `<tr><td colspan="6" class="empty-cell">暂无教学视频，先上传一条</td></tr>`}
      </tbody></table></div>
    `;
  }

  async function openVideoUpload() {
    try {
      const exercises = await api("/exercises?limit=300");
      showModal(`${modalHead("上传教学视频", "先保存为草稿，预览确认后再发布")}<div class="modal-body">
        <form class="inline-form" onsubmit="event.preventDefault();admin.saveVideoUpload()">
          <div class="form-row"><label>对应动作</label><select id="video-exercise" required>
            <option value="">选择动作</option>
            ${exercises.items.map((item) => `<option value="${esc(item.slug)}">${esc(item.name_zh)} · ${esc(item.slug)}</option>`).join("")}
          </select></div>
          <div class="form-row"><label>视频标题</label><input id="video-title" required maxlength="120" placeholder="例如：高位下拉标准动作示范"></div>
          <div class="form-row"><label>动作说明（选填）</label><textarea id="video-description" maxlength="2000" placeholder="提示动作重点、常见错误和安全注意事项"></textarea></div>
          <div class="form-row two">
            <div><label>视频文件</label><input id="video-file" type="file" accept="video/mp4,video/webm,video/quicktime" required></div>
            <div><label>封面图（选填）</label><input id="video-poster-file" type="file" accept="image/jpeg,image/png,image/webp"></div>
          </div>
          <div class="form-row two">
            <div><label>时长（秒，选填）</label><input id="video-duration" type="number" min="0" max="14400" placeholder="例如：48"></div>
            <div><label>来源 / 教练（选填）</label><input id="video-source" maxlength="80" placeholder="例如：练途动作库"></div>
          </div>
          <div class="form-row two">
            <div><label>授权说明（选填）</label><input id="video-license" maxlength="200" placeholder="例如：练途自制，已获教练授权"></div>
            <div><label>授权到期日（选填）</label><input id="video-license-expiry" type="date"></div>
          </div>
          <div class="form-row"><label><input id="video-publish-now" type="checkbox" style="width:auto;margin-right:7px">上传后立即发布</label></div>
          <div class="file-note">视频单个不超过 300MB，封面不超过 10MB。发布后会自动同步到动作库，App 只读取官方已发布视频。</div>
          <div class="modal-actions"><button class="btn btn-primary" type="submit" id="video-upload-btn">上传并保存</button><button class="btn" type="button" onclick="admin.closeModal()">取消</button></div>
        </form>
      </div>`);
    } catch (error) { toast(error.message, true); }
  }

  async function saveVideoUpload() {
    const button = $("video-upload-btn");
    try {
      const file = $("video-file").files[0];
      if (!file) throw new Error("请选择视频文件");
      const exerciseSlug = $("video-exercise").value;
      const title = $("video-title").value.trim();
      if (!exerciseSlug || !title) throw new Error("请选择动作并填写视频标题");
      button.disabled = true;
      button.textContent = "上传中…";
      const uploaded = await uploadFile(file, "video");
      const posterFile = $("video-poster-file").files[0];
      const poster = posterFile ? await uploadFile(posterFile, "poster") : null;
      const publishNow = $("video-publish-now").checked;
      await api("/videos", {
        method: "POST",
        body: JSON.stringify({
          exercise_slug: exerciseSlug,
          title,
          description: $("video-description").value.trim() || null,
          video_url: uploaded.url,
          poster_url: poster ? poster.url : null,
          duration_seconds: $("video-duration").value ? Number($("video-duration").value) : null,
          source: $("video-source").value.trim() || null,
          license_note: $("video-license").value.trim() || null,
          license_expires_at: $("video-license-expiry").value || null,
          status: publishNow ? "published" : "draft"
        })
      });
      closeModal();
      toast(publishNow ? "视频已上传并发布" : "视频已上传，当前为草稿");
      renderVideos();
    } catch (error) {
      toast(error.message, true);
      if (button) { button.disabled = false; button.textContent = "上传并保存"; }
    }
  }

  function openVideo(id) {
    const item = state.videos.items.find((x) => x.id === id);
    if (!item) return;
    showModal(`${modalHead(item.exercise_name || item.exercise_slug, item.title)}<div class="modal-body">
      <video class="video-player" controls playsinline preload="metadata" ${item.poster_url ? `poster="${esc(item.poster_url)}"` : ""} src="${esc(item.video_url)}"></video>
      <div class="kv-grid">
        <div class="kv"><div class="k">状态</div><div class="v">${videoStatusBadge(item.status)}</div></div>
        <div class="kv"><div class="k">动作 slug</div><div class="v mono">${esc(item.exercise_slug)}</div></div>
        <div class="kv"><div class="k">时长</div><div class="v">${durationText(item.duration_seconds)}</div></div>
        <div class="kv"><div class="k">来源</div><div class="v">${esc(item.source || "—")}</div></div>
        <div class="kv"><div class="k">授权</div><div class="v">${esc(item.license_note || "—")}</div></div>
        <div class="kv"><div class="k">授权到期</div><div class="v">${esc(item.license_expires_at || "—")}</div></div>
      </div>
      <div class="small muted" style="margin-top:12px;line-height:1.6">${esc(item.description || "暂无动作说明")}</div>
      <div class="modal-actions">
        <button class="btn btn-primary" onclick="admin.editVideo('${item.id}')">编辑信息</button>
        ${item.status === "published" ? `<button class="btn" onclick="admin.unpublishVideo('${item.id}')">下架</button>` : `<button class="btn" onclick="admin.publishVideo('${item.id}')">发布</button>`}
        <button class="btn btn-danger" onclick="admin.deleteVideo('${item.id}')">删除</button>
      </div>
    </div>`);
  }

  function editVideo(id) {
    const item = state.videos.items.find((x) => x.id === id);
    if (!item) return;
    showModal(`${modalHead("编辑教学视频", item.exercise_name || item.exercise_slug)}<div class="modal-body">
      <form class="inline-form" onsubmit="event.preventDefault();admin.saveVideoEdit('${item.id}')">
        <div class="form-row"><label>视频标题</label><input id="video-edit-title" required maxlength="120" value="${esc(item.title)}"></div>
        <div class="form-row"><label>动作说明</label><textarea id="video-edit-description" maxlength="2000">${esc(item.description || "")}</textarea></div>
        <div class="form-row two">
          <div><label>替换视频（选填）</label><input id="video-edit-file" type="file" accept="video/mp4,video/webm,video/quicktime"></div>
          <div><label>替换封面（选填）</label><input id="video-edit-poster" type="file" accept="image/jpeg,image/png,image/webp"></div>
        </div>
        <div class="form-row two">
          <div><label>时长（秒）</label><input id="video-edit-duration" type="number" min="0" max="14400" value="${item.duration_seconds ?? ""}"></div>
          <div><label>来源 / 教练</label><input id="video-edit-source" maxlength="80" value="${esc(item.source || "")}"></div>
        </div>
        <div class="form-row two">
          <div><label>授权说明</label><input id="video-edit-license" maxlength="200" value="${esc(item.license_note || "")}"></div>
          <div><label>授权到期日</label><input id="video-edit-license-expiry" type="date" value="${esc(item.license_expires_at || "")}"></div>
        </div>
        <div class="file-note">不选择新文件则保留现有视频和封面。发布状态请回到列表页操作。</div>
        <div class="modal-actions"><button class="btn btn-primary" type="submit" id="video-edit-btn">保存修改</button><button class="btn" type="button" onclick="admin.closeModal()">取消</button></div>
      </form>
    </div>`);
  }

  async function saveVideoEdit(id) {
    const button = $("video-edit-btn");
    try {
      const item = state.videos.items.find((x) => x.id === id);
      if (!item) throw new Error("视频不存在");
      const title = $("video-edit-title").value.trim();
      if (!title) throw new Error("请填写视频标题");
      button.disabled = true;
      button.textContent = "保存中…";
      const videoFile = $("video-edit-file").files[0];
      const posterFile = $("video-edit-poster").files[0];
      const video = videoFile ? await uploadFile(videoFile, "video") : null;
      const poster = posterFile ? await uploadFile(posterFile, "poster") : null;
      await api(`/videos/${id}`, {
        method: "PATCH",
        body: JSON.stringify({
          title,
          description: $("video-edit-description").value.trim() || null,
          video_url: video ? video.url : item.video_url,
          poster_url: poster ? poster.url : item.poster_url,
          duration_seconds: $("video-edit-duration").value ? Number($("video-edit-duration").value) : null,
          source: $("video-edit-source").value.trim() || null,
          license_note: $("video-edit-license").value.trim() || null,
          license_expires_at: $("video-edit-license-expiry").value || null
        })
      });
      closeModal();
      toast("教学视频已更新");
      renderVideos();
    } catch (error) {
      toast(error.message, true);
      if (button) { button.disabled = false; button.textContent = "保存修改"; }
    }
  }

  async function publishVideo(id) {
    try { await api(`/videos/${id}/publish`, { method: "POST" }); closeModal(); toast("视频已发布并同步到动作库"); renderVideos(); }
    catch (error) { toast(error.message, true); }
  }

  async function unpublishVideo(id) {
    if (!confirm("确认下架这条教学视频？App 将不再展示它。")) return;
    try { await api(`/videos/${id}/unpublish`, { method: "POST" }); closeModal(); toast("视频已下架"); renderVideos(); }
    catch (error) { toast(error.message, true); }
  }

  async function deleteVideo(id) {
    if (!confirm("确认删除这条教学视频？本地上传的文件也会删除，无法恢复。")) return;
    try { await api(`/videos/${id}`, { method: "DELETE" }); closeModal(); toast("视频已删除"); renderVideos(); }
    catch (error) { toast(error.message, true); }
  }

  async function renderAI() {
    loading();
    const overview = await api("/ai/overview?days=30");
    const jobs = await api(`/ai/jobs?q=${encodeURIComponent(state.ai.q)}&status=${encodeURIComponent(state.ai.status)}&kind=${encodeURIComponent(state.ai.kind)}&limit=100&offset=${state.ai.offset}`);
    const provider = overview.provider;
    const providerMode = provider.mode === "remote" ? "远程 AI" : "Mock 本地";
    const statusBadge = (status) => {
      const map = { ok: ["成功", "accent"], fallback: ["降级", "warning"], error: ["失败", "danger"] };
      const [label, tone] = map[status] || [status || "—", ""];
      return badge(label, tone);
    };
    const kindOptions = overview.by_kind.map((item) => `<option value="${esc(item.kind)}" ${state.ai.kind === item.kind ? "selected" : ""}>${esc(item.label)}</option>`).join("");
    viewRoot.innerHTML = `
      <div class="stat-grid">
        <div class="stat-card accent"><div class="label">AI 调用</div><div class="value">${num(overview.total)}</div><div class="hint">最近 30 天</div></div>
        <div class="stat-card"><div class="label">成功率</div><div class="value">${(overview.success_rate * 100).toFixed(1)}%</div><div class="hint">${num(overview.ok)} 成功 · ${num(overview.fallback)} 降级</div></div>
        <div class="stat-card"><div class="label">平均延迟</div><div class="value">${overview.avg_latency_ms ? num(overview.avg_latency_ms) : "—"}${overview.avg_latency_ms ? "ms" : ""}</div><div class="hint">仅统计远程调用</div></div>
        <div class="stat-card ${overview.errors ? "danger" : ""}"><div class="label">失败</div><div class="value">${num(overview.errors)}</div><div class="hint">Token ${num(overview.input_tokens)} / ${num(overview.output_tokens)}</div></div>
      </div>

      <div class="panel-grid">
        <div class="panel">
          <div class="between"><h3 style="margin:0">运行配置</h3>${badge(providerMode, provider.mode === "remote" ? "accent" : "warning")}</div>
          <div class="kv-grid" style="margin-top:14px">
            <div class="kv"><div class="k">Provider</div><div class="v">${esc(provider.provider || "—")}</div></div>
            <div class="kv"><div class="k">模型</div><div class="v">${esc(provider.model || "—")}</div></div>
            <div class="kv"><div class="k">API Key</div><div class="v">${provider.configured ? "已配置" : "未配置"}</div></div>
            <div class="kv"><div class="k">Base URL</div><div class="v mono">${esc(provider.base_url || "—")}</div></div>
          </div>
          <div class="note" style="margin-top:14px">会员用户使用远程 DeepSeek 教练；未开通会员或模型不可用时，App 自动回退到本地规则建议。</div>
        </div>
        <div class="panel">
          <h3 style="margin:0 0 12px">AI Skills</h3>
          ${overview.skills.map((skill) => `<div class="list-row"><div class="grow"><div class="primary">${esc(skill.name)} ${badge(skill.key, "")}</div><div class="secondary">${esc(skill.description)}</div></div><div class="side" style="text-align:right"><div class="strong">${num(skill.calls)} 次</div><div class="muted small">${skill.errors ? `${skill.errors} 异常` : skill.available ? "可用" : "Mock 模式"}</div></div></div>`).join("")}
        </div>
      </div>

      <div class="toolbar">
        <input class="search" id="ai-search" placeholder="搜索用户、场景、模型或错误" value="${esc(state.ai.q)}" onkeydown="if(event.key==='Enter')admin.searchAI()">
        <select id="ai-status" style="width:120px" onchange="admin.searchAI()"><option value="">全部状态</option><option value="ok" ${state.ai.status === "ok" ? "selected" : ""}>成功</option><option value="fallback" ${state.ai.status === "fallback" ? "selected" : ""}>降级</option></select>
        <select id="ai-kind" style="width:150px" onchange="admin.searchAI()"><option value="">全部场景</option>${kindOptions}</select>
        <button class="btn btn-sm" onclick="admin.reloadAI()">刷新</button>
        <div class="spacer"></div><span class="muted small">共 ${num(jobs.total)} 条调用</span>
      </div>
      <div class="table-wrap"><table class="data-table"><thead><tr><th>时间</th><th>用户</th><th>场景</th><th>模型</th><th>状态</th><th>延迟</th><th>错误</th></tr></thead><tbody>
        ${jobs.items.map((job) => `<tr><td>${dateText(job.created_at, true)}</td><td><div>${esc(job.nickname || "—")}</div><div class="mono">${esc((job.user_id || "").slice(0, 8))}</div></td><td><div class="strong">${esc(job.kind_label)}</div><div class="mono">${esc(job.kind)}</div></td><td>${esc(job.model || "—")}<br><span class="muted small">${esc(job.prompt_version || "—")}</span></td><td>${statusBadge(job.status)}</td><td>${job.latency_ms ? `${num(job.latency_ms)}ms` : "—"}</td><td class="muted small">${esc((job.error || "").slice(0, 160) || "—")}</td></tr>`).join("") || `<tr><td colspan="7" class="empty-cell">暂无 AI 调用记录。配置 DeepSeek 后，会员用户的计划和教练对话会出现在这里。</td></tr>`}
      </tbody></table></div>
      <div class="pager"><span>第 ${Math.floor(state.ai.offset / 100) + 1} 页</span><button class="btn btn-sm" onclick="admin.pageAI(-1)" ${state.ai.offset <= 0 ? "disabled" : ""}>上一页</button><button class="btn btn-sm" onclick="admin.pageAI(1)" ${state.ai.offset + 100 >= jobs.total ? "disabled" : ""}>下一页</button></div>
    `;
  }

  async function renderAudit() {
    loading();
    const d = await api(`/audit?limit=100&offset=${state.auditOffset}`);
    viewRoot.innerHTML = `
      <div class="toolbar"><button class="btn btn-sm" onclick="admin.reloadAudit()">刷新</button><div class="spacer"></div><span class="muted small">共 ${num(d.total)} 条操作</span></div>
      <div class="table-wrap"><table class="data-table"><thead><tr><th>时间</th><th>操作者</th><th>动作</th><th>对象</th><th>详情</th></tr></thead><tbody>
        ${d.items.map((x) => `<tr><td>${dateText(x.created_at, true)}</td><td>${esc(x.actor)}</td><td><span class="strong">${esc(x.action)}</span></td><td>${esc(x.target_type)}${x.target_id ? `<br><span class="mono">${esc(x.target_id)}</span>` : ""}</td><td class="mono">${esc(JSON.stringify(x.detail || {}))}</td></tr>`).join("") || `<tr><td colspan="5" class="empty-cell">暂无操作日志</td></tr>`}
      </tbody></table></div>
      <div class="pager"><span>第 ${Math.floor(state.auditOffset / 100) + 1} 页</span><button class="btn btn-sm" onclick="admin.pageAudit(-1)" ${state.auditOffset <= 0 ? "disabled" : ""}>上一页</button><button class="btn btn-sm" onclick="admin.pageAudit(1)" ${state.auditOffset + 100 >= d.total ? "disabled" : ""}>下一页</button></div>
    `;
  }

  async function navigate(view) {
    state.view = view;
    document.querySelectorAll(".nav-item").forEach((item) => item.classList.toggle("active", item.dataset.view === view));
    const meta = META[view] || META.dashboard;
    $("page-title").textContent = meta[0];
    $("page-subtitle").textContent = meta[1];
    try {
      if (view === "dashboard") await renderDashboard();
      else if (view === "users") await renderUsers();
      else if (view === "plans") await renderPlans();
      else if (view === "workouts") await renderWorkouts();
      else if (view === "chats") await renderChats();
      else if (view === "scans") await renderScans();
      else if (view === "exercises") await renderExercises();
      else if (view === "videos") await renderVideos();
      else if (view === "ai") await renderAI();
      else if (view === "audit") await renderAudit();
    } catch (error) { errorView(error); }
  }

  $("login-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const token = $("token-input").value.trim();
    if (!token) return;
    state.token = token;
    try {
      const data = await api("/auth/check");
      state.env = data.env || "dev";
      localStorage.setItem(TOKEN_KEY, token);
      enterApp();
    } catch (error) {
      state.token = "";
      $("login-error").textContent = error.message;
    }
  });

  $("logout-btn").addEventListener("click", logout);
  document.querySelectorAll(".nav-item").forEach((item) => item.addEventListener("click", () => navigate(item.dataset.view)));

  window.admin = {
    closeModal, openUser, exportUser, softDeleteUser, purgeUser, restoreUser,
    searchUsers() { state.users.q = $("user-search")?.value || ""; state.users.offset = 0; renderUsers().catch(errorView); },
    reloadUsers() { state.users.offset = 0; renderUsers().catch(errorView); },
    pageUsers(dir) { state.users.offset = Math.max(0, state.users.offset + dir * PAGE_SIZE); renderUsers().catch(errorView); },
    openPlan, archivePlan, activatePlan,
    searchPlans() { state.plans.q = $("plan-search")?.value || ""; state.plans.status = $("plan-status")?.value || ""; state.plans.offset = 0; renderPlans().catch(errorView); },
    reloadPlans() { state.plans.offset = 0; renderPlans().catch(errorView); },
    pagePlans(dir) { state.plans.offset = Math.max(0, state.plans.offset + dir * PAGE_SIZE); renderPlans().catch(errorView); },
    openWorkout, deleteWorkout,
    searchWorkouts() { state.workouts.q = $("workout-search")?.value || ""; state.workouts.offset = 0; renderWorkouts().catch(errorView); },
    reloadWorkouts() { state.workouts.offset = 0; renderWorkouts().catch(errorView); },
    pageWorkouts(dir) { state.workouts.offset = Math.max(0, state.workouts.offset + dir * PAGE_SIZE); renderWorkouts().catch(errorView); },
    openChat, deleteChat,
    searchChats() { state.chats.q = $("chat-search")?.value || ""; state.chats.offset = 0; renderChats().catch(errorView); },
    toggleSafetyOnly() { state.chats.safety = !state.chats.safety; state.chats.offset = 0; renderChats().catch(errorView); },
    reloadChats() { state.chats.offset = 0; renderChats().catch(errorView); },
    pageChats(dir) { state.chats.offset = Math.max(0, state.chats.offset + dir * PAGE_SIZE); renderChats().catch(errorView); },
    openScan, deleteScan,
    searchScans() { state.scans.q = $("scan-search")?.value || ""; state.scans.offset = 0; renderScans().catch(errorView); },
    reloadScans() { state.scans.offset = 0; renderScans().catch(errorView); },
    pageScans(dir) { state.scans.offset = Math.max(0, state.scans.offset + dir * PAGE_SIZE); renderScans().catch(errorView); },
    openExercise, saveExercise,
    searchExercises() { state.exercises.q = $("exercise-search")?.value || ""; state.exercises.offset = 0; renderExercises().catch(errorView); },
    reloadExercises() { state.exercises.offset = 0; renderExercises().catch(errorView); },
    openVideoUpload, saveVideoUpload, openVideo, editVideo, saveVideoEdit,
    publishVideo, unpublishVideo, deleteVideo,
    searchVideos() { state.videos.q = $("video-search")?.value || ""; state.videos.status = $("video-status")?.value || ""; renderVideos().catch(errorView); },
    reloadVideos() { renderVideos().catch(errorView); },
    searchAI() { state.ai.q = $("ai-search")?.value || ""; state.ai.status = $("ai-status")?.value || ""; state.ai.kind = $("ai-kind")?.value || ""; state.ai.offset = 0; renderAI().catch(errorView); },
    reloadAI() { state.ai.offset = 0; renderAI().catch(errorView); },
    pageAI(dir) { state.ai.offset = Math.max(0, state.ai.offset + dir * 100); renderAI().catch(errorView); },
    reloadAudit() { state.auditOffset = 0; renderAudit().catch(errorView); },
    pageAudit(dir) { state.auditOffset = Math.max(0, state.auditOffset + dir * 100); renderAudit().catch(errorView); }
  };

  if (state.token) {
    api("/auth/check").then((data) => { state.env = data.env || "dev"; enterApp(); }).catch(() => showLogin());
  } else {
    showLogin();
  }
})();
