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
};

const T = {
  title: "Индикатор раскладки", more: "Дополнительно", minimize: "Свернуть", close: "Закрыть",
  caret: "Каретка", mouse: "Мышь", shown: "Показывать", hidden: "Скрыто",
  gap: "Отступ", auto: "Автозапуск", autoOn: "С Windows", autoOff: "Выключен", opacity: "Непрозрачность",
  showFlag: "Показывать флаг", showCode: "Показывать код языка",
  sizeCaret: "Размер флажка у каретки", sizeMouse: "Размер флажка у мыши",
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
const G = { flag: "", gear: "", min: "", close: "", gap: "", auto: "", opacity: "" };
const SIDES = ["top-left", "top", "top-right", "left", null, "right", "bottom-left", "bottom", "bottom-right"];
// Пределы контролов (в ini пределы шире — см. SettingsFile.Fields)
const SIZE = [8, 32], GAP = [0, 12], OPACITY = [10, 100];

let state = null;

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
    <button class="ico" data-act="more" title="${t("more")}">${G.gear}</button>
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
      <span class="ico gear" data-more="${k}" title="${t("more")}">${G.gear}</span></div>`;
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

function render() {
  const app = document.getElementById("app");
  app.innerHTML = `${Titlebar()}<div class="cols"><div id="main">${Main()}</div></div>`;
  bindMain(app);
  app.querySelectorAll("[data-act]").forEach(el => el.onclick = () => {
    if (el.dataset.act === "min" || el.dataset.act === "close") send(el.dataset.act);
  });
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
