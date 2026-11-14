// Окно настроек. Страница только показывает и меняет настройки: состояние присылает AHK,
// каждое изменение уходит в AHK строкой «set<Tab>путь<Tab>значение» (см. src\SettingsPage.ahk).
"use strict";

const host = window.chrome && window.chrome.webview;
// Открыта в обычном браузере (для вёрстки) — работаем на образце состояния
const DEMO = {
  type: "state", autostart: 1, layout: { flag: "ru", text: "RU" },
  settings: {
    opacity: 85, hideFullscreen: 1, pollMs: 50, mousePollMs: 15, cornerRadius: 2, uiLang: "auto", autoUpdate: 1,
    code: { bg: "#3c4043", font: "Segoe UI", scale: 62 },
    caret: { enabled: 1, show: "flag", side: "bottom", gap: 3, size: 12, methods: { win32: 1, msaa: 1, uia: 1 }, sizeMode: "fixed", sizeRatio: 70, sizeMin: 8, sizeMax: 32 },
    mouse: { enabled: 1, show: "flag", side: "bottom-right", gap: 3, size: 12 },
    layouts: {},
  },
  layouts: [
    { hkl: "04190419", name: "Русский (Россия)", auto: { flag: "ru", text: "RU" }, flag: "", text: "" },
    { hkl: "04090409", name: "Английский (США)", auto: { flag: "us", text: "EN" }, flag: "gb", text: "" },
  ],
  flags: ["by", "de", "eu", "fr", "gb", "gb-eng", "kz", "ru", "ua", "us"],
  systemLang: "ru",
  update: { status: "available", version: "0.2.0", error: "", portable: false },
  about: { version: "0.1.0", links: { site: "", github: "https://github.com/Xpom/language-indicator", youtube: "", coffee: "" } },
};

// Тексты окна по языкам. Переведены русский и английский; остальные языки показывают английский
const T = {
  ru: {
    title: "Индикатор раскладки", sample: "Привет", site: "Сайт", guide: "Инструкция", coffee: "Кофе", soon: "Скоро", autoUpd: "Автообновление", updCurrent: "Последняя версия", updChecking: "Проверяю…", updAvailable: "Доступна v{}", updDownloading: "Скачиваю v{}…", updInstalling: "Устанавливаю v{}…", updError: "Не удалось обновиться", updNow: "Обновить", updNotes: "Что нового", updCheck: "Проверить", updPortable: "Скачайте новую версию на GitHub", more: "Дополнительно", minimize: "Свернуть", close: "Закрыть",
    caret: "Каретка", mouse: "Мышь", shown: "Показывать", hidden: "Скрыто",
    gap: "Отступ", auto: "Автозапуск", autoOn: "С Windows", autoOff: "Выключен", opacity: "Непрозрачность",
    showFlag: "Показывать флаг", showCode: "Показывать код языка",
    sizeCaret: "Размер флажка у каретки", sizeMouse: "Размер флажка у мыши",
    radius: "Скругление углов", flagT: "Флажок", codeT: "Код", customColor: "Свой цвет", noBg: "Без фона", codeSize: "Размер букв",
    general: "Общие", uiLang: "Язык окна", here: "На этом компьютере", other: "Другие",
    full: "Прятать в полноэкранных", layouts: "Раскладки", methods: "Искать", poll: "Опрос, мс",
    pick: "Нажмите, чтобы выбрать другой флаг", reset: "Как обычно", none: "Без флага", search: "Страна или код…", nothing: "Ничего не нашлось",
    sides: { "top-left": "Сверху слева", top: "Сверху", "top-right": "Сверху справа", left: "Слева", right: "Справа", "bottom-left": "Снизу слева", bottom: "Снизу", "bottom-right": "Снизу справа" },
  },
  en: {
    title: "Language Indicator", sample: "Hello", site: "Website", guide: "Guide", coffee: "Coffee", soon: "Coming soon", autoUpd: "Auto-update", updCurrent: "Up to date", updChecking: "Checking…", updAvailable: "v{} is available", updDownloading: "Downloading v{}…", updInstalling: "Installing v{}…", updError: "Update failed", updNow: "Update", updNotes: "What's new", updCheck: "Check", updPortable: "Download the new version on GitHub", more: "Advanced", minimize: "Minimize", close: "Close",
    caret: "Caret", mouse: "Mouse", shown: "Shown", hidden: "Hidden",
    gap: "Gap", auto: "Autostart", autoOn: "With Windows", autoOff: "Off", opacity: "Opacity",
    showFlag: "Show the flag", showCode: "Show the language code",
    sizeCaret: "Flag size at the caret", sizeMouse: "Flag size at the mouse",
    radius: "Corner radius", flagT: "Flag", codeT: "Code", customColor: "Custom color", noBg: "No background", codeSize: "Letter size",
    general: "General", uiLang: "Window language", here: "On this PC", other: "Other",
    full: "Hide in fullscreen", layouts: "Layouts", methods: "Sources", poll: "Poll, ms",
    pick: "Click to pick another flag", reset: "Default", none: "No flag", search: "Country or code…", nothing: "Nothing found",
    sides: { "top-left": "Top left", top: "Top", "top-right": "Top right", left: "Left", right: "Right", "bottom-left": "Bottom left", bottom: "Bottom", "bottom-right": "Bottom right" },
  },
};
// Десять самых распространённых языков мира: код, название на самом языке
const UI_LANGS = [["en", "English"], ["zh", "中文"], ["hi", "हिन्दी"], ["es", "Español"], ["fr", "Français"], ["ar", "العربية"], ["bn", "বাংলা"], ["pt", "Português"], ["ru", "Русский"], ["ur", "اردو"]];
// Язык окна: выбранный, а для auto — язык Windows, если для него есть перевод, иначе английский
function lang() {
  const ui = state.settings.uiLang;
  if (ui && ui !== "auto") return ui;
  return T[state.systemLang] ? state.systemLang : "en";
}
const t = k => (T[lang()] || T.en)[k];
// Название языка на языке окна
function langName(code) {
  try {
    const n = new Intl.DisplayNames([lang()], { type: "language" }).of(code);
    return n.charAt(0).toLocaleUpperCase(lang()) + n.slice(1);
  } catch { return code; }
}

// Свои значки: читаются и на белом, и на цветном
const I = {
  caret: `<svg class="i" viewBox="0 0 24 24"><path d="M3 18 7.5 6 12 18M4.7 14h5.6"/><path d="M18 4v16M15.5 4h5M15.5 20h5"/></svg>`,
  mouse: `<svg class="i" viewBox="0 0 24 24"><rect x="6" y="3" width="12" height="18" rx="6"/><path d="M12 3v6"/></svg>`,
  tick: `<svg class="tick" viewBox="2.6 5.2 18.8 13.6"><path d="M4 12.6l5 4.8L20 6.6"/></svg>`,
  ibeam: `<svg width="9" height="20" viewBox="0 0 9 20" fill="none" stroke="currentColor" stroke-width="1.4"><path d="M1 1h2.5a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H1M8 1H5.5a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1H8"/></svg>`,
};
const G = { flag: "", gear: "", min: "", close: "", gap: "", auto: "", opacity: "" ,
  full: "\uE740", poll: "\uE916", reset: "\uE777", down: "\uE70D", search: "\uE721", x: "\uE711", tick: "\uE73E", code: "\uE8D2", lang: "\uE774", coffee: "\uEC32" };
const SIDES = ["top-left", "top", "top-right", "left", null, "right", "bottom-left", "bottom", "bottom-right"];
// Пределы контролов (в ini пределы шире — см. SettingsFile.Fields)
const SIZE = [8, 32], GAP = [0, 12], OPACITY = [10, 100], POLL = [15, 200], MOUSE_POLL = [10, 100], RADIUS = [0, 6], CODE_SCALE = [40, 90];
const FONTS = ["Segoe UI", "Segoe UI Semibold", "Bahnschrift", "Arial", "Verdana", "Tahoma", "Consolas", "Georgia"];
const BGS = ["none", "#3c4043", "#000000", "#ffffff", "#1a73e8", "#d93025", "#188038", "#f9ab00", "#9334e6"];

let state = null;
let adv = null;         // правая панель: null — закрыта; "general" | "caret" | "mouse" — какой раздел подсвечен

function send(...parts) {
  if (host) host.postMessage(parts.join("\t"));
}

function get(path) {
  return path.split(".").reduce((o, k) => o[k], state.settings);
}

// Меняет настройку сразу на странице и отправляет её в AHK
function set(path, value) {
  const keys = path.split("."), last = keys.pop();
  keys.reduce((o, k) => o[k], state.settings)[last] = value;
  render();
  send("set", path, typeof value === "boolean" ? (value ? 1 : 0) : value);
}

const flagUrl = code => `/flags/${code}.png`;
const pct = (v, [min, max]) => (v - min) / (max - min) * 100 + "%";
const track = (id, v, range) => `<div class="track" id="${id}"><div class="fill" style="width:${pct(v, range)}"></div><div class="knob" style="left:${pct(v, range)}"></div></div>`;

// Ползунок: тянем мышью по дорожке id. Слушаем окно, потому что render() пересоздаёт дорожку
function drag(id, axis, [min, max], path) {
  const el = document.getElementById(id);
  if (!el) return;
  const upd = e => {
    const r = document.getElementById(id).getBoundingClientRect();
    const k = axis === "x" ? (e.clientX - r.left) / r.width : 1 - (e.clientY - r.top) / r.height;
    const v = Math.round(min + Math.max(0, Math.min(1, k)) * (max - min));
    if (v !== get(path)) set(path, v);
  };
  el.onpointerdown = e => {
    e.preventDefault(); upd(e);
    const up = () => { removeEventListener("pointermove", upd); removeEventListener("pointerup", up); };
    addEventListener("pointermove", upd); addEventListener("pointerup", up);
  };
}

// ---- Предпросмотр: та же раскладка флажка, что Core.Place ----
function place(side, ax, ay, aw, ah, fw, fh, gap) {
  const L = ax - gap - fw, R = ax + aw + gap, Tp = ay - gap - fh, B = ay + ah + gap, mid = ay + (ah - fh) / 2;
  return { "top-left": [L, Tp], top: [ax, Tp], "top-right": [R, Tp], left: [L, mid], right: [R, mid], "bottom-left": [L, B], bottom: [ax, B], "bottom-right": [R, B] }[side];
}
// Вид плашки кода — как FlagOverlay: цвет букв по яркости фона, без фона — белые с обводкой
function codeStyle(h) {
  const c = state.settings.code, none = c.bg === "none";
  const n = none ? 0 : parseInt(c.bg.slice(1), 16), y = 0.299 * (n >> 16) + 0.587 * (n >> 8 & 255) + 0.114 * (n & 255);
  return `background:${none ? "transparent" : c.bg};box-shadow:${none ? "none" : "0 0 0 1px rgba(0,0,0,.35)"};` +
    `color:${!none && y > 160 ? "#1d2430" : "#fff"};text-shadow:${none ? "0 0 2px #000,0 0 2px #000,0 0 1px #000" : "none"};` +
    `font-family:'${c.font}';font-weight:${c.font === "Segoe UI" ? 700 : 400};font-size:${Math.round(h * c.scale / 100)}px;` +
    `border-radius:${state.settings.cornerRadius * h / 12}px`;
}
// Ширина плашки кода — как Core.CodeWidth
const codeWidth = (h, text) => Math.max(h * 4 / 3, h * (0.42 * text.length + 0.5));
function putFlag(box, ind, a) {
  if (!ind.enabled) return;
  const lay = state.layout, flag = ind.show === "code" ? "" : lay.flag, h = ind.size;
  const w = Math.round(flag ? h * 4 / 3 : codeWidth(h, lay.text)), [x, y] = place(ind.side, a.x, a.y, a.w, a.h, w, h, ind.gap);
  const f = document.createElement("div");
  f.className = "flag";
  if (!flag) f.style.cssText = codeStyle(h);
  Object.assign(f.style, { left: x + "px", top: y + "px", width: w + "px", height: h + "px", opacity: get("opacity") / 100 });
  if (flag) Object.assign(f.style, { backgroundImage: `url(${flagUrl(flag)})`, borderRadius: get("cornerRadius") * h / 12 + "px" });
  else f.innerHTML = `<span class="ct">${lay.text}</span>`;
  box.appendChild(f);
}
function preview(pv) {
  pv.innerHTML = `<div class="line">${t("sample")}<span class="caret"></span></div><span class="ibeam">${I.ibeam}</span>`;
  const m = pv.querySelector(".ibeam");
  m.style.left = (pv.clientWidth - 46) + "px";
  m.style.top = Math.max(14, pv.clientHeight - 48) + "px";
  const r = pv.getBoundingClientRect(), c = pv.querySelector(".caret").getBoundingClientRect(), mr = m.getBoundingClientRect();
  putFlag(pv, state.settings.caret, { x: c.left - r.left, y: c.top - r.top, w: 1, h: c.height });
  putFlag(pv, state.settings.mouse, { x: mr.left - r.left + mr.width / 2, y: mr.top - r.top, w: 0, h: mr.height });
}

// ---- Заголовок ----
function Titlebar() {
  return `<div class="titlebar"><span class="ico" style="color:var(--accent)">${G.flag}</span>${t("title")}<span class="sp"></span>
    <button class="ico ${adv ? "on" : ""}" data-more="general" title="${t("more")}">${G.gear}</button>
    <button class="ico" data-act="min" title="${t("minimize")}">${G.min}</button>
    <button class="ico close" data-act="close" title="${t("close")}">${G.close}</button></div>`;
}

// ---- Основная колонка ----
function Main() {
  const s = state.settings, off = k => s[k].enabled ? "" : "off";
  const chk = k => `<div class="card tile chk wide ${s[k].enabled ? "on" : ""}" data-chk="${k}">
      <span class="big-ico">${I[k]}</span><h4>${t(k)}</h4><small>${s[k].enabled ? t("shown") : t("hidden")}</small>${I.tick}</div>`;
  const lay = state.layout;
  const show = k => `<div class="card wide showrow ${off(k)}">
      <div class="pill" data-show="${k}">
        <span data-v="flag" class="${s[k].show !== "code" ? "sel" : ""}" title="${t("showFlag")}">${lay.flag ? `<img src="${flagUrl(lay.flag)}">` : `<b class="code-chip">?</b>`}</span>
        <span data-v="code" class="${s[k].show === "code" ? "sel" : ""}" title="${t("showCode")}"><b class="code-chip"><span class="ct">${lay.text}</span></b></span></div>
      <span class="ico gear ${adv === k ? "open" : ""}" data-more="${k}" title="${t("more")}">${G.gear}</span></div>`;
  const grid = k => `<div class="side-grid ${off(k)}" data-grid="${k}">${SIDES.map(side => side
      ? `<span data-side="${side}" class="${side === s[k].side ? "sel" : ""}" title="${t("sides")[side]}"></span>`
      : `<span class="mid">${I[k]}</span>`).join("")}</div>`;
  const vsl = k => `<div class="card vsl ${off(k)}" id="v-${k}" title="${t(k === "caret" ? "sizeCaret" : "sizeMouse")}">
      <div class="fill" style="height:${pct(s[k].size, SIZE)}"></div><div class="head">${I[k]}<span class="v">${s[k].size}px</span></div></div>`;
  const step = k => `<div class="stepper ${off(k)}"><span class="who">${I[k]}</span><button data-step="${k}" data-d="-1">−</button><span class="v">${s[k].gap}px</span><button data-step="${k}" data-d="1">+</button></div>`;
  return `<div class="tiles">
    ${chk("caret")}${chk("mouse")}
    ${show("caret")}${show("mouse")}
    <div class="card hero"><div class="pv" id="pv"></div><div class="pos">${grid("caret")}${grid("mouse")}</div></div>
    ${vsl("caret")}${vsl("mouse")}
    <div class="card tile wide"><div class="titled"><span class="ico big-ico" style="font-size:20px">${G.gap}</span><h4>${t("gap")}</h4></div>${step("caret")}${step("mouse")}</div>
    <div class="card tile wide auto" id="au"><div class="titled"><span class="ico big-ico">${G.auto}</span><h4>${t("auto")}</h4></div>
      <div class="row"><small>${state.autostart ? t("autoOn") : t("autoOff")}</small><div class="toggle ${state.autostart ? "on" : ""}"></div></div></div>
    <div class="card hsl full"><div class="head"><span class="ico">${G.opacity}</span><b>${t("opacity")}</b><span class="sp"></span><small>${s.opacity}%</small></div>${track("op", s.opacity, OPACITY)}</div>
    ${About()}
  </div>`;
}

// О проекте: ссылки открывает AHK во внешнем браузере; ссылки без адреса — «скоро»
function About() {
  const links = state.about.links;
  const a = (key, icon, label, cls = "") => `<a class="${cls} ${links[key] ? "" : "soon"}" data-link="${key}" title="${links[key] || t("soon")}">${icon}${label}</a>`;
  return `<div class="card about full">
    <div class="links">
      ${a("site", `<span class="ico">${G.lang}</span>`, t("site"))}
      ${a("github", `<svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38v-1.33c-2.23.48-2.7-1.07-2.7-1.07-.36-.92-.89-1.17-.89-1.17-.73-.5.06-.49.06-.49.8.06 1.23.83 1.23.83.72 1.22 1.87.87 2.33.66.07-.52.28-.87.5-1.07-1.78-.2-3.65-.89-3.65-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.6 7.6 0 0 1 4 0c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48v2.2c0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>`, "GitHub")}
      ${a("youtube", `<svg viewBox="0 0 24 24"><rect x="1" y="4.5" width="22" height="15" rx="4.5" fill="#ff0033"/><path d="M10 9v6l5.2-3z" fill="#fff"/></svg>`, t("guide"))}
      ${a("coffee", `<span class="ico">${G.coffee}</span>`, t("coffee"), "coffee")}
    </div>
    ${UpdateRow()}
    <div class="copy"><span>© 2026 Xpom</span><span>v${state.about.version}</span></div>
  </div>`;
}

// Обновления: галочка «Автообновление», состояние и кнопки. Ставит и проверяет AHK (Updater)
function UpdateRow() {
  const u = state.update || { status: "idle" }, v = s => t(s).replace("{}", u.version);
  const text = { checking: t("updChecking"), current: t("updCurrent"), available: v("updAvailable"),
    downloading: v("updDownloading"), installing: v("updInstalling"), error: t("updError") }[u.status] || "";
  const btn = (act, label, cls = "") => `<button class="upd-btn ${cls}" data-upd="${act}">${label}</button>`;
  let actions = "";
  if (u.status === "available" || (u.status === "error" && u.version)) {
    actions = btn("notes", t("updNotes")) + (u.portable ? "" : btn("now", t("updNow"), "primary"));
  } else if (!/^(checking|downloading|installing)$/.test(u.status)) {
    actions = btn("check", t("updCheck"));
  }
  return `<div class="upd">
    <label class="upd-auto"><input type="checkbox" id="autoUpd" ${state.settings.autoUpdate ? "checked" : ""}>${t("autoUpd")}</label>
    <div class="upd-line"><span class="upd-text ${u.status}">${text}${u.portable && u.status === "available" ? ` · ${t("updPortable")}` : ""}</span>${actions}</div>
  </div>`;
}

function bindMain(app) {
  const au = app.querySelector("#autoUpd");
  if (au) au.onchange = () => set("autoUpdate", au.checked ? 1 : 0);
  app.querySelectorAll("[data-upd]").forEach(el => el.onclick = () => send("update-" + el.dataset.upd));
  app.querySelectorAll("[data-link]").forEach(el => el.onclick = () => { if (state.about.links[el.dataset.link]) send("open", el.dataset.link); });
  app.querySelectorAll("[data-chk]").forEach(el => el.onclick = () => set(el.dataset.chk + ".enabled", !get(el.dataset.chk + ".enabled")));
  app.querySelectorAll("[data-show] [data-v]").forEach(el => el.onclick = () => set(el.parentNode.dataset.show + ".show", el.dataset.v));
  app.querySelectorAll("[data-grid] [data-side]").forEach(el => el.onclick = () => set(el.parentNode.dataset.grid + ".side", el.dataset.side));
  app.querySelectorAll("[data-step]").forEach(el => el.onclick = () => {
    const path = el.dataset.step + ".gap", v = get(path) + Number(el.dataset.d);
    if (v >= GAP[0] && v <= GAP[1]) set(path, v);
  });
  app.querySelector("#au").onclick = () => { state.autostart = !state.autostart; render(); send("autostart", state.autostart ? 1 : 0); };
  drag("v-caret", "y", SIZE, "caret.size");
  drag("v-mouse", "y", SIZE, "mouse.size");
  drag("op", "x", OPACITY, "opacity");
  preview(app.querySelector("#pv"));
}

// ---- Правая панель «Дополнительно» ----
const layoutFlag = l => l.flag || l.auto.flag;
const flagImg = code => code && code !== "-" ? `<img src="${flagUrl(code)}">` : `<span class="nof"></span>`;

function Side() {
  const s = state.settings, c = s.caret;
  const sec = (k, icon, title, body) => `<div class="card sec ${adv === k ? "focus" : ""} ${(k === "caret" || k === "mouse") && !s[k].enabled ? "off" : ""}" id="sec-${k}"><div class="sh">${icon}${title}</div>${body}</div>`;
  const cb = (on, m) => `<span class="chkbox ${on ? "on" : ""}" data-method="${m}"><i>${on ? G.tick : ""}</i>${({ win32: "Win32", msaa: "MSAA", uia: "UIA" })[m]}</span>`;
  const poll = (id, v, range) => `<div class="r"><span class="ico">${G.poll}</span>${t("poll")}${track(id, v, range)}<span class="v">${v}</span></div>`;
  const lay = l => `<div class="r lay"><span class="flag-btn" data-pick="${l.hkl}" title="${t("pick")}">${flagImg(layoutFlag(l))}<span class="ico">${G.down}</span></span>
      <span class="name" title="${l.name}">${l.name}</span>
      <input class="code" data-text="${l.hkl}" value="${l.text}" placeholder="${l.auto.text}" maxlength="4">
      <span class="ico reset ${l.flag || l.text ? "" : "none"}" data-reset="${l.hkl}" title="${t("reset")}">${G.reset}</span></div>`;
  return `<div class="adv">
    ${sec("general", `<span class="ico">${G.gear}</span>`, t("general"), `
      <div class="r"><span class="ico">${G.lang}</span>${t("uiLang")}<span class="sp"></span>${LangDropdown()}</div>
      <div class="r"><span class="ico">${G.flag}</span>${t("radius")}${track("rad", s.cornerRadius, RADIUS)}<span class="v">${s.cornerRadius}px</span></div>
      <div class="r"><span class="ico">${G.full}</span>${t("full")}<span class="sp"></span><div class="toggle ${s.hideFullscreen ? "on" : ""}" id="hf"></div></div>`)}
    ${Pair()}
    ${sec("layouts", `<span class="ico">${G.flag}</span>`, t("layouts"), state.layouts.map(lay).join(""))}
    ${sec("caret", I.caret, t("caret"), `
      <div class="r">${t("methods")}<span class="sp"></span>${["win32", "msaa", "uia"].map(m => cb(c.methods[m], m)).join("")}</div>
      ${poll("cpoll", s.pollMs, POLL)}`)}
    ${sec("mouse", I.mouse, t("mouse"), poll("mpoll", s.mousePollMs, MOUSE_POLL))}
  </div>`;
}

// Плитки «Флажок» и «Код» с крупными образцами; на «Коде» без подписей: фон, шрифт, размер букв
function Pair() {
  const s = state.settings, lay = state.layout, big = 39;
  const sw = b => `<span data-bg="${b}" class="${b === "none" ? "empty" : ""} ${b === s.code.bg ? "sel" : ""}" style="${b === "none" ? "" : "background:" + b}" title="${b === "none" ? t("noBg") : b}"></span>`;
  return `<div class="pair">
    <div class="card tile"><div class="titled"><span class="ico">${G.flag}</span><h4>${t("flagT")}</h4></div>
      <div class="pv-big">${lay.flag ? `<div class="f" style="border-radius:${s.cornerRadius * big / 12}px;background-image:url(${flagUrl(lay.flag)})"></div>` : ""}</div></div>
    <div class="card tile"><div class="titled"><span class="ico">${G.code}</span><h4>${t("codeT")}</h4></div>
      <div class="pv-big"><div class="c" style="${codeStyle(big)}"><span class="ct">${lay.text}</span></div></div>
      <div class="swatches">${BGS.map(sw).join("")}<label class="${BGS.includes(s.code.bg) ? "" : "sel"}" title="${t("customColor")}"><input type="color" id="bgc" value="${s.code.bg === "none" ? "#3c4043" : s.code.bg}"></label></div>
      <select class="sel-font" id="font">${FONTS.map(f => `<option ${f === s.code.font ? "selected" : ""} style="font-family:'${f}'">${f}</option>`).join("")}</select>
      <div class="fsr" title="${t("codeSize")}: ${s.code.scale}%"><span style="font-size:10px">A</span>${track("fs", s.code.scale, CODE_SCALE)}<span style="font-size:16px">A</span></div>
    </div></div>`;
}

// Язык окна: десять самых распространённых языков; языки раскладок компьютера — сверху
let ddOpen = false;
function LangDropdown() {
  const cur = lang(), mine = new Set(state.layouts.map(l => l.auto.text.toLowerCase()));
  const item = ([code, name]) => `<div class="it ${code === cur ? "sel" : ""}" data-lang="${code}">${name}<small>${langName(code)}</small></div>`;
  const here = UI_LANGS.filter(l => mine.has(l[0])), rest = UI_LANGS.filter(l => !mine.has(l[0]));
  return `<div class="dd"><div class="dd-btn" id="dd">${UI_LANGS.find(l => l[0] === cur)[1]}<span class="sp"></span><span class="ico">${G.down}</span></div>
    ${ddOpen ? `<div class="dd-list">${here.length ? `<div class="hd">${t("here")}</div>${here.map(item).join("")}<hr>` : ""}<div class="hd">${t("other")}</div>${rest.map(item).join("")}</div>` : ""}</div>`;
}

function bindSide(app) {
  app.querySelector("#dd").onclick = () => { ddOpen = !ddOpen; render(); };
  app.querySelectorAll("[data-lang]").forEach(el => el.onclick = e => { e.stopPropagation(); ddOpen = false; set("uiLang", el.dataset.lang); });
  drag("rad", "x", RADIUS, "cornerRadius");
  drag("fs", "x", CODE_SCALE, "code.scale");
  app.querySelectorAll("[data-bg]").forEach(el => el.onclick = () => set("code.bg", el.dataset.bg));
  app.querySelector("#bgc").onchange = e => set("code.bg", e.target.value);
  app.querySelector("#font").onchange = e => set("code.font", e.target.value);
  app.querySelector("#hf").onclick = () => set("hideFullscreen", !get("hideFullscreen"));
  app.querySelectorAll("[data-method]").forEach(el => el.onclick = () => set("caret.methods." + el.dataset.method, !get("caret.methods." + el.dataset.method)));
  drag("cpoll", "x", POLL, "pollMs");
  drag("mpoll", "x", MOUSE_POLL, "mousePollMs");
  const lay = hkl => state.layouts.find(l => l.hkl === hkl);
  app.querySelectorAll("[data-pick]").forEach(el => el.onclick = () => openGallery(lay(el.dataset.pick)));
  app.querySelectorAll("[data-text]").forEach(el => el.onchange = () => setLayout(lay(el.dataset.text), lay(el.dataset.text).flag, el.value.trim()));
  app.querySelectorAll("[data-reset]").forEach(el => el.onclick = () => setLayout(lay(el.dataset.reset), "", ""));
}

function setLayout(l, flag, text) {
  l.flag = flag;
  l.text = text;
  render();
  send("layout", l.hkl, flag, text);
}

// ---- Галерея всех флагов: поиск по коду и названию страны на русском и английском ----
const EXTRA = {
  ru: { arab: "Арабская лига", asean: "АСЕАН", cefta: "ЦЕФТА", eac: "Восточноафриканское сообщество", "es-ct": "Каталония", "es-ga": "Галисия", "es-pv": "Страна Басков", eu: "Евросоюз", "gb-eng": "Англия", "gb-nir": "Северная Ирландия", "gb-sct": "Шотландия", "gb-wls": "Уэльс", pc: "Тихоокеанское сообщество", "sh-ac": "Остров Вознесения", "sh-hl": "Остров Святой Елены", "sh-ta": "Тристан-да-Кунья", un: "ООН", xx: "Пустой флаг" },
  en: { arab: "Arab League", asean: "ASEAN", cefta: "CEFTA", eac: "East African Community", "es-ct": "Catalonia", "es-ga": "Galicia", "es-pv": "Basque Country", eu: "European Union", "gb-eng": "England", "gb-nir": "Northern Ireland", "gb-sct": "Scotland", "gb-wls": "Wales", pc: "Pacific Community", "sh-ac": "Ascension Island", "sh-hl": "Saint Helena", "sh-ta": "Tristan da Cunha", un: "United Nations", xx: "Blank flag" },
};
function countryName(code, lang) {
  const extra = EXTRA[lang] || EXTRA.en;
  if (extra[code]) return extra[code];
  try { return new Intl.DisplayNames([lang], { type: "region" }).of(code.toUpperCase()); } catch { return code; }
}

function openGallery(l) {
  const ui = lang(), cur = layoutFlag(l);
  const names = c => [c, countryName(c, "ru"), countryName(c, "en")].join(" ").toLowerCase();
  const sorted = [...state.flags].sort((a, b) => countryName(a, ui).localeCompare(countryName(b, ui), ui));
  const ov = document.getElementById("overlay");
  ov.innerHTML = `<div class="gal-back"><div class="gal">
    <div class="gal-head"><span class="who">${flagImg(cur)}${l.name}</span>
      <label class="gal-search"><span class="ico">${G.search}</span><input id="gq" placeholder="${t("search")}" autocomplete="off"></label>
      <button class="ico" id="gx">${G.x}</button></div>
    <div class="gal-grid" id="gg">
      <div class="cell ${cur === "-" ? "sel" : ""}" data-f="-" data-n="${t("none").toLowerCase()} none"><span class="nof"></span><b>—</b><span>${t("none")}</span></div>
      ${sorted.map(c => `<div class="cell ${c === cur ? "sel" : ""}" data-f="${c}" data-n="${names(c)}" title="${countryName(c, ui)}"><img loading="lazy" src="${flagUrl(c)}"><b>${c}</b><span>${countryName(c, ui)}</span></div>`).join("")}
      <div class="gal-empty" hidden>${t("nothing")}</div>
    </div></div></div>`;
  const q = ov.querySelector("#gq"), cells = [...ov.querySelectorAll(".cell")], empty = ov.querySelector(".gal-empty");
  const close = () => { ov.innerHTML = ""; };
  q.oninput = () => {
    const v = q.value.trim().toLowerCase();
    let n = 0;
    cells.forEach(c => { const ok = !v || c.dataset.f.startsWith(v) || c.dataset.n.includes(v); c.hidden = !ok; n += ok; });
    empty.hidden = n > 0;
  };
  q.onkeydown = e => {
    if (e.key === "Escape") close();
    if (e.key === "Enter") { const c = cells.find(c => !c.hidden); if (c) c.click(); }
  };
  // Флаг, совпадающий с автоматическим, — это не переопределение
  cells.forEach(c => c.onclick = () => { close(); setLayout(l, c.dataset.f === l.auto.flag ? "" : c.dataset.f, l.text); });
  ov.querySelector("#gx").onclick = close;
  ov.querySelector(".gal-back").onclick = e => { if (e.target.classList.contains("gal-back")) close(); };
  // scrollIntoView прокрутил бы и окно — крутим только сетку
  const gg = ov.querySelector("#gg"), sel = ov.querySelector(".cell.sel");
  if (sel) gg.scrollTop = sel.offsetTop - gg.clientHeight / 2 + sel.offsetHeight / 2;
  q.focus({ preventScroll: true });
}

function render() {
  const app = document.getElementById("app");
  document.documentElement.lang = lang();
  app.classList.toggle("wide", !!adv);
  app.innerHTML = `${Titlebar()}<div class="cols"><div id="main">${Main()}</div>${adv ? `<div id="side">${Side()}</div>` : ""}</div>`;
  bindMain(app);
  if (adv) bindSide(app);
  // Шестерёнка в заголовке открывает и закрывает панель; под плиткой — открывает свой раздел или закрывает его
  app.querySelectorAll("[data-more]").forEach(el => el.onclick = () => {
    const k = el.dataset.more;
    adv = adv && (el.tagName === "BUTTON" || adv === k) ? null : k;
    render();
  });
  app.querySelectorAll("[data-act]").forEach(el => el.onclick = () => send(el.dataset.act));
}

// Окно подстраивается под содержимое
new ResizeObserver(() => {
  const r = document.getElementById("app").getBoundingClientRect();
  send("size", Math.ceil(r.width), Math.ceil(r.height));
}).observe(document.getElementById("app"));

if (host) {
  host.addEventListener("message", e => {
    if (e.data && e.data.type === "state") { state = e.data; render(); }
  });
  send("ready");
} else {
  state = DEMO;
  render();
}
