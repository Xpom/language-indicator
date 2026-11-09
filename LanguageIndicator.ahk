; Language Indicator — флажок текущей раскладки у каретки.
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
    static settings := DefaultSettings()
    static flagFiles := Map()
    static paused := false

    static Start() {
        Gdip.Startup()
        OnExit((*) => Gdip.Shutdown())
        App.overlay := FlagOverlay(A_ScriptDir "\flags")
        Loop Files A_ScriptDir "\flags\*.png"
            App.flagFiles[SubStr(A_LoopFileName, 1, -4)] := true
        App.tickFn := ObjBindMethod(App, "Tick")
        App.hasFlagFn := ObjBindMethod(App, "HasFlag")
        App.BuildTray()
        SetTimer(App.tickFn, App.settings.pollMs)
    }

    static HasFlag(code) => App.flagFiles.Has(code)

    static Tick() {
        caret := CaretProbe.Win32()
        snap := {
            hkl: LayoutProbe.Foreground(),
            caret: caret,
            caretDpi: IsObject(caret) ? MonitorProbe.DpiAt(caret.x, caret.y) : 96,
        }
        result := Core.Decide(snap, App.settings, App.hasFlagFn)
        App.overlay.Update(result.caret)
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
            SetTimer(App.tickFn, 0)
            App.overlay.Hide()
            A_TrayMenu.Check("Пауза")
        } else {
            SetTimer(App.tickFn, App.settings.pollMs)
            A_TrayMenu.Uncheck("Пауза")
        }
    }
}
