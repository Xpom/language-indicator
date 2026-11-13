// Окно настроек. Страница только показывает и меняет настройки: состояние присылает AHK,
// каждое изменение уходит в AHK строкой «set<Tab>путь<Tab>значение» (см. src\SettingsPage.ahk).
"use strict";

const host = window.chrome && window.chrome.webview;
// Открыта в обычном браузере (для вёрстки) — работаем на образце состояния
const DEMO = {
  type: "state", autostart: 1,
  settings: {
    opacity: 85, hideFullscreen: 1, pollMs: 50, mousePollMs: 15,
    caret: { enabled: 1, side: "bottom", gap: 3, size: 12, methods: { win32: 1, msaa: 1, uia: 1 }, sizeMode: "fixed", sizeRatio: 70, sizeMin: 8, sizeMax: 32 },
    mouse: { enabled: 1, side: "bottom-right", gap: 3, size: 12 },
    layouts: {},
  },
};

const T = {
  title: "Индикатор раскладки", more: "Дополнительно", minimize: "Свернуть", close: "Закрыть",
  caret: "Каретка", mouse: "Мышь", shown: "Показывать", hidden: "Скрыто",
};
const t = k => T[k];

// Свои значки: читаются и на белом, и на цветном
const I = {
  caret: `<svg class="i" viewBox="0 0 24 24"><path d="M3 18 7.5 6 12 18M4.7 14h5.6"/><path d="M18 4v16M15.5 4h5M15.5 20h5"/></svg>`,
  mouse: `<svg class="i" viewBox="0 0 24 24"><rect x="6" y="3" width="12" height="18" rx="6"/><path d="M12 3v6"/></svg>`,
  tick: `<svg class="tick" viewBox="2.6 5.2 18.8 13.6"><path d="M4 12.6l5 4.8L20 6.6"/></svg>`,
};
const G = { flag: "", gear: "", min: "", close: "" };

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

// ---- Заголовок ----
function Titlebar() {
  return `<div class="titlebar"><span class="ico" style="color:var(--accent)">${G.flag}</span>${t("title")}<span class="sp"></span>
    <button class="ico" data-act="more" title="${t("more")}">${G.gear}</button>
    <button class="ico" data-act="min" title="${t("minimize")}">${G.min}</button>
    <button class="ico close" data-act="close" title="${t("close")}">${G.close}</button></div>`;
}

// ---- Основная колонка ----
function Main() {
  const s = state.settings;
  const chk = k => `<div class="card tile chk wide ${s[k].enabled ? "on" : ""}" data-chk="${k}">
      <span class="big-ico">${I[k]}</span><h4>${t(k)}</h4><small>${s[k].enabled ? t("shown") : t("hidden")}</small>${I.tick}</div>`;
  return `<div class="tiles">${chk("caret")}${chk("mouse")}</div>`;
}

function render() {
  const app = document.getElementById("app");
  app.innerHTML = `${Titlebar()}<div class="cols"><div id="main">${Main()}</div></div>`;
  app.querySelectorAll("[data-chk]").forEach(el => el.onclick = () => set(el.dataset.chk + ".enabled", !get(el.dataset.chk + ".enabled")));
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
