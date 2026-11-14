; Language Indicator — флажок текущей раскладки у каретки и у текстового курсора мыши.
; Ключи: /no-elevate — не поднимать права (для отладки), /settings — сразу открыть настройки,
;        /quit — закрыть работающий индикатор, /devtools — инструменты разработчика в окне настроек.
#Requires AutoHotkey v2.0
;@Ahk2Exe-SetName Language Indicator
;@Ahk2Exe-SetDescription Language Indicator
;@Ahk2Exe-SetCompanyName Xpom
;@Ahk2Exe-SetCopyright (c) 2026 Xpom (MIT)
;@Ahk2Exe-SetVersion 0.1.3
#SingleInstance Force
Persistent

#Include src\Locale.ahk
#Include src\Settings.ahk
#Include src\Core.ahk
#Include src\Probes.ahk
#Include src\Gdip.ahk
#Include src\Overlay.ahk
#Include src\Autostart.ahk
#Include src\Json.ahk
#Include src\Release.ahk
#Include src\Http.ahk
#Include src\Updater.ahk
#Include src\SettingsPage.ahk

HasArg(name) {
    for a in A_Args
        if a = name
            return true
    return false
}

; /quit — штатно закрыть работающий индикатор (им пользуется установщик): #SingleInstance Force
; уже закрыл прежний экземпляр, без значка-призрака в трее, осталось выйти самому
if HasArg("/quit")
    ExitApp

; Без прав администратора UIPI не даёт читать каретку и раскладку в повышенных окнах.
if !A_IsAdmin && !HasArg("/no-elevate") {
    try {
        Run(A_IsCompiled ? '*RunAs "' A_ScriptFullPath '" /restart' : '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
        ExitApp
    }
    ; UAC отклонён — работаем без прав
}

; Per-monitor DPI v2: все координаты и размеры — в физических пикселях
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

App.Start()

class App {
    static version := "0.1.3"          ; при смене — и ;@Ahk2Exe-SetVersion вверху (сборка сверяет)
    static settings := ""
    static settingsPath := SettingsFile.PathFor(A_ScriptDir, A_IsCompiled, FileExist(A_ScriptDir "\portable"), A_AppData)
    static flagFiles := Map()
    static paused := false
    ; Общий снимок: каретку, раскладку и полноэкранность обновляет CaretTick, курсор — MouseTick
    static snap := {hkl: 0, caret: "", caretDpi: 96, mouse: "", mouseDpi: 96, fullscreen: ""}

    static Start() {
        ; Файл настроек создаётся со значениями по умолчанию, чтобы его было что править руками
        if !FileExist(App.settingsPath) {
            SplitPath(App.settingsPath, , &dir)
            DirCreate(dir)
            SettingsFile.Save(DefaultSettings(), App.settingsPath)
        }
        App.settings := SettingsFile.Load(App.settingsPath)
        Gdip.Startup()
        OnExit((*) => Gdip.Shutdown())
        App.caretOverlay := FlagOverlay(A_ScriptDir "\flags")
        App.mouseOverlay := FlagOverlay(A_ScriptDir "\flags")
        Loop Files A_ScriptDir "\flags\*.png"
            App.flagFiles[SubStr(A_LoopFileName, 1, -4)] := true
        App.caretTickFn := ObjBindMethod(App, "CaretTick")
        App.mouseTickFn := ObjBindMethod(App, "MouseTick")
        App.hasFlagFn := ObjBindMethod(App, "HasFlag")
        App.BuildTray()
        App.StartTimers()
        Updater.Start(App, {changed: () => SettingsPage.SendState(), settingsOpen: () => SettingsPage.IsOpen()})
        if HasArg("/settings")
            SettingsPage.Open(App)
    }

    static StartTimers() {
        SetTimer(App.caretTickFn, App.settings.pollMs)
        SetTimer(App.mouseTickFn, App.settings.mousePollMs)
    }

    static StopTimers() {
        SetTimer(App.caretTickFn, 0)
        SetTimer(App.mouseTickFn, 0)
    }

    static HasFlag(code) => App.flagFiles.Has(code)

    static CaretTick() {
        caret := CaretProbe.Find(App.settings.caret.methods)
        App.snap.hkl := LayoutProbe.Foreground()
        SettingsPage.LayoutTick(App.snap.hkl)
        App.snap.caret := caret
        App.snap.caretDpi := IsObject(caret) ? MonitorProbe.DpiAt(caret.x, caret.y) : 96
        App.snap.fullscreen := App.settings.hideFullscreen ? FullscreenProbe.Foreground() : ""
        App.Apply()
    }

    static MouseTick() {
        mouse := CursorProbe.Current()
        App.snap.mouse := mouse
        App.snap.mouseDpi := IsObject(mouse) ? MonitorProbe.DpiAt(mouse.hot.x, mouse.hot.y) : 96
        App.Apply()
    }

    static Apply() {
        result := Core.Decide(App.snap, App.settings, App.hasFlagFn)
        App.caretOverlay.Update(result.caret)
        App.mouseOverlay.Update(result.mouse)
    }

    static BuildTray() {
        A_IconTip := "Language Indicator"
        m := A_TrayMenu
        m.Delete()
        m.Add("Настройки", (*) => SettingsPage.Open(App))
        m.Default := "Настройки"         ; двойной клик по иконке
        m.Add()
        m.Add("Пауза", (*) => App.TogglePause())
        m.Add("Перезапуск", (*) => Reload())
        m.Add("Выход", (*) => ExitApp())
    }

    static TogglePause() {
        App.paused := !App.paused
        if App.paused {
            App.StopTimers()
            App.caretOverlay.Hide()
            App.mouseOverlay.Hide()
            A_TrayMenu.Check("Пауза")
        } else {
            App.StartTimers()
            A_TrayMenu.Uncheck("Пауза")
        }
    }
}
