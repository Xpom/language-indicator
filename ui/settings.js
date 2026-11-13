// Окно настроек. Страница только показывает и меняет настройки: состояние присылает AHK,
// каждое изменение уходит в AHK строкой «set<Tab>путь<Tab>значение» (см. src\SettingsPage.ahk).
"use strict";

const host = window.chrome && window.chrome.webview;
// Открыта в обычном браузере (для вёрстки) — работаем на образце состояния
const DEMO = {
  type: "state", autostart: 1, layout: { flag: "ru", text: "RU" },
  settings: {
    opacity: 85, hideFullscreen: 1, pollMs: 50, mousePollMs: 15,
    caret: { enabled: 1, show: "flag", side: "bottom", gap: 3, size: 12, methods: { win32: 1, msaa: 1, uia: 1 }, sizeMode: "fixed", sizeRatio: 70, sizeMin: 8, sizeMax: 32 },
    mouse: { enabled: 1, show: "flag", side: "bottom-right", gap: 3, size: 12 },
    layouts: {},
  },
  layouts: [
    { hkl: "04190419", name: "Русский (Россия)", auto: { flag: "ru", text: "RU" }, flag: "", text: "" },
    { hkl: "04090409", name: "Английский (США)", auto: { flag: "us", text: "EN" }, flag: "gb", text: "" },
  ],
  flags: ["by", "de", "eu", "fr", "gb", "gb-eng", "kz", "ru", "ua", "us"],
};

const T = {
  title: "Индикатор раскладки", more: "Дополнительно", minimize: "Свернуть", close: "Закрыть",
  caret: "Каретка", mouse: "Мышь", shown: "Показывать", hidden: "Скрыто",
  gap: "Отступ", auto: "Автозапуск", autoOn: "С Windows", autoOff: "Выключен", opacity: "Непрозрачность",
  showFlag: "Показывать флаг", showCode: "Показывать код языка",
  sizeCaret: "Размер флажка у каретки", sizeMouse: "Размер флажка у мыши",
  general: "Общие", full: "Прятать в полноэкранных", layouts: "Раскладки", methods: "Искать", poll: "Опрос, мс",
  pick: "Нажмите, чтобы выбрать другой флаг", reset: "Как обычно", none: "Без флага", search: "Страна или код…", nothing: "Ничего не нашлось",
  sides: { "top-left": "Сверху слева", top: "Сверху", "top-right": "Сверху справа", left: "Слева", right: "Справа", "bottom-left": "Снизу слева", bottom: "Снизу", "bottom-right": "Снизу справа" },
};
const t = k => T[k];

// Свои значки: читаются и на белом, и на цветном
const I = {
  caret: `<svg class="i" viewBox="0 0 24 24"><path d="M3 18 7.5 6 12 18M4.7 14h5.6"/><path d="M18 4v16M15.5 4h5M15.5 20h5"/></svg>`,
  mouse: `<svg class="i" viewBox="0 0 24 24"><rect x="6" y="3" width="12" height="18" rx="6"/><path d="M12 3v6"/></svg>`,
  tick: `<svg class="tick" viewBox="2.6 5.2 18.8 13.6"><path d="M4 12.6l5 4.8L20 6.6"/></svg>`,
  ibeam: `<svg width="9" height="20" viewBox="0 0 9 20" fill="none" stroke="currentColor" stroke-width="1.4"><path d="M1 1h2.5a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H1M8 1H5.5a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1H8"/></svg>`,
};
const G = { flag: "", gear: "", min: "", close: "", gap: "", auto: "", opacity: "" ,
  full: "\uE740", poll: "\uE916", reset: "\uE777", down: "\uE70D", search: "\uE721", x: "\uE711", tick: "\uE73E" };
const SIDES = ["top-left", "top", "top-right", "left", null, "right", "bottom-left", "bottom", "bottom-right"];
// Пределы контролов (в ini пределы шире — см. SettingsFile.Fields)
const SIZE = [8, 32], GAP = [0, 12], OPACITY = [10, 100], POLL = [15, 200], MOUSE_POLL = [10, 100];

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
// Ширина плашки кода — как Core.CodeWidth
const codeWidth = (h, text) => Math.max(h * 4 / 3, h * (0.42 * text.length + 0.5));
function putFlag(box, ind, a) {
  if (!ind.enabled) return;
  const lay = state.layout, flag = ind.show === "code" ? "" : lay.flag, h = ind.size;
  const w = Math.round(flag ? h * 4 / 3 : codeWidth(h, lay.text)), [x, y] = place(ind.side, a.x, a.y, a.w, a.h, w, h, ind.gap);
  const f = document.createElement("div");
  f.className = "flag";
  Object.assign(f.style, { left: x + "px", top: y + "px", width: w + "px", height: h + "px", opacity: get("opacity") / 100, borderRadius: "2px" });
  if (flag) f.style.backgroundImage = `url(${flagUrl(flag)})`;
  else f.innerHTML = `<span class="ct" style="font-size:${Math.round(h * .62)}px">${lay.text}</span>`;
  box.appendChild(f);
}
function preview(pv) {
  pv.innerHTML = `<div class="line">Привет<span class="caret"></span></div><span class="ibeam">${I.ibeam}</span>`;
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
  </div>`;
}

function bindMain(app) {
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
      <div class="r"><span class="ico">${G.full}</span>${t("full")}<span class="sp"></span><div class="toggle ${s.hideFullscreen ? "on" : ""}" id="hf"></div></div>`)}
    ${sec("layouts", `<span class="ico">${G.flag}</span>`, t("layouts"), state.layouts.map(lay).join(""))}
    ${sec("caret", I.caret, t("caret"), `
      <div class="r">${t("methods")}<span class="sp"></span>${["win32", "msaa", "uia"].map(m => cb(c.methods[m], m)).join("")}</div>
      ${poll("cpoll", s.pollMs, POLL)}`)}
    ${sec("mouse", I.mouse, t("mouse"), poll("mpoll", s.mousePollMs, MOUSE_POLL))}
  </div>`;
}

function bindSide(app) {
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
  if (EXTRA[lang] && EXTRA[lang][code]) return EXTRA[lang][code];
  try { return new Intl.DisplayNames([lang], { type: "region" }).of(code.toUpperCase()); } catch { return code; }
}

function openGallery(l) {
  const lang = "ru", cur = layoutFlag(l);
  const names = c => [c, countryName(c, "ru"), countryName(c, "en")].join(" ").toLowerCase();
  const sorted = [...state.flags].sort((a, b) => countryName(a, lang).localeCompare(countryName(b, lang), lang));
  const ov = document.getElementById("overlay");
  ov.innerHTML = `<div class="gal-back"><div class="gal">
    <div class="gal-head"><span class="who">${flagImg(cur)}${l.name}</span>
      <label class="gal-search"><span class="ico">${G.search}</span><input id="gq" placeholder="${t("search")}" autocomplete="off"></label>
      <button class="ico" id="gx">${G.x}</button></div>
    <div class="gal-grid" id="gg">
      <div class="cell ${cur === "-" ? "sel" : ""}" data-f="-" data-n="${t("none").toLowerCase()} none"><span class="nof"></span><b>—</b><span>${t("none")}</span></div>
      ${sorted.map(c => `<div class="cell ${c === cur ? "sel" : ""}" data-f="${c}" data-n="${names(c)}" title="${countryName(c, lang)}"><img loading="lazy" src="${flagUrl(c)}"><b>${c}</b><span>${countryName(c, lang)}</span></div>`).join("")}
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
