; Language Indicator — флажок текущей раскладки у каретки и у текстового курсора мыши.
; Ключ /no-elevate — не поднимать права (для отладки).
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

#Include src\Locale.ahk
#Include src\Settings.ahk
#Include src\Core.ahk
#Include src\Probes.ahk
#Include src\Gdip.ahk
#Include src\Overlay.ahk

HasArg(name) {
    for a in A_Args
        if a = name
            return true
    return false
}

; Без прав администратора UIPI не даёт читать каретку и раскладку в повышенных окнах.
if !A_IsAdmin && !HasArg("/no-elevate") {
    try {
        Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
        ExitApp
    }
    ; UAC отклонён — работаем без прав
}

; Per-monitor DPI v2: все координаты и размеры — в физических пикселях
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

App.Start()

class App {
    static settings := ""
    static flagFiles := Map()
    static paused := false
    ; Общий снимок: каретку и раскладку обновляет CaretTick, курсор — MouseTick
    static snap := {hkl: 0, caret: "", caretDpi: 96, mouse: "", mouseDpi: 96}

    static Start() {
        ; Файл настроек создаётся со значениями по умолчанию, чтобы его было что править руками
        path := A_ScriptDir "\settings.ini"
        if !FileExist(path)
            SettingsFile.Save(DefaultSettings(), path)
        App.settings := SettingsFile.Load(path)
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
        App.snap.caret := caret
        App.snap.caretDpi := IsObject(caret) ? MonitorProbe.DpiAt(caret.x, caret.y) : 96
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
