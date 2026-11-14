; Исполнитель тестов по программам — запускается в тестовой ВМ в сеансе пользователя (tests/vm/Invoke-AppTests.ps1).
;   AutoHotkey64.exe run.ahk <папка программы> <папка результатов>
; Запускает индикатор с /trace, проходит сценарии из scenarios.ahk и по записи индикатора
; проверяет, что каретка найдена и флаг соответствует раскладке окна. На каждый шаг — снимок экрана.
; Итог: report.md, results.jsonl, снимки *.png, в конце — файл done.
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include ..\..\src\Json.ahk
#Include scenarios.ahk

DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
SetTitleMatchMode(2)

appDir := A_Args.Length >= 1 ? A_Args[1] : A_ScriptDir "\..\..\dist\app"
outDir := A_Args.Length >= 2 ? A_Args[2] : A_Temp "\li-apps"
DirCreate(outDir)
FileDelete(outDir "\*.*")
global TracePath := outDir "\trace.jsonl"
global Results := []

Layouts := Map("en", 0x04090409, "ru", 0x04190419)
Flags := Map("en", "us", "ru", "ru")         ; что должен показать индикатор
DllCall("LoadKeyboardLayout", "str", "00000419", "uint", 1)

; Индикатор: портабельная сборка, настройки рядом; UAC в ВМ без запроса
Run('"' appDir '\LanguageIndicator.exe" /trace "' TracePath '"')
if !WaitFor(() => FileExist(TracePath), 15000)
    Fail("Индикатор не начал писать " TracePath)

for sc in Scenarios
    RunScenario(sc)

; Отчёт
passed := 0
report := "# Тесты по программам`n`n" FormatTime(, "yyyy-MM-dd HH:mm") "`n`n| Сценарий | Шаг | Итог | Окно | Каретка | Флаг | Снимок |`n|---|---|---|---|---|---|---|`n"
for r in Results {
    passed += r.ok
    report .= Format("| {} | {} | {} | {} | {} | {} | [png]({}) |`n", r.scenario, r.step, r.ok ? "✅" : "❌ " r.why,
        r.win, r.caret, r.flag, r.shot)
    FileAppend(Json.Stringify(Map("scenario", r.scenario, "step", r.step, "ok", r.ok ? Json.JTrue : Json.JFalse,
        "why", r.why, "win", r.win, "caret", r.caret, "flag", r.flag, "shot", r.shot)) "`n", outDir "\results.jsonl", "UTF-8-RAW")
}
report .= "`n" passed " из " Results.Length " шагов прошло`n"
FileAppend(report, outDir "\report.md", "UTF-8")
StopIndicator()
FileAppend(passed "/" Results.Length, outDir "\done", "UTF-8-RAW")
ExitApp(passed = Results.Length ? 0 : 1)

; --- сценарий: запустить, дождаться окна, для каждой раскладки — набрать, проверить, снять экран ---
RunScenario(sc) {
    try {
        Run(sc.run, , , &pid)
    } catch as e {
        Results.Push({scenario: sc.name, step: "запуск", ok: false, why: e.Message, win: "", caret: "", flag: "", shot: ""})
        return
    }
    if !WinWaitActive(sc.window, , 30) {
        Results.Push({scenario: sc.name, step: "окно", ok: false, why: "нет окна " sc.window, win: "", caret: "", flag: "", shot: Shot(sc.name "-noWindow")})
        CloseScenario(sc, pid)
        return
    }
    Sleep(sc.HasOwnProp("settleMs") ? sc.settleMs : 1500)
    if sc.HasOwnProp("prepare")
        sc.prepare.Call()
    for lang in ["en", "ru"] {
        SetLayout(Layouts[lang])
        Sleep(300)
        SendText(lang = "en" ? "abc " : "где ")
        Sleep(700)      ; индикатор опрашивает каждые 50 мс, запись — при изменении
        rec := LastRecord()
        step := "раскладка " lang
        shot := Shot(sc.name "-" lang)
        caret := IsObject(rec) && IsObject(rec["caret"]) ? rec["caret"]["method"] " " rec["caret"]["x"] "," rec["caret"]["y"] " " rec["caret"]["w"] "×" rec["caret"]["h"] : "нет"
        flag := IsObject(rec) ? rec["flag"] : ""
        win := IsObject(rec) && IsObject(rec["win"]) ? rec["win"]["exe"] " / " rec["win"]["focus"] : ""
        why := ""
        expectCaret := sc.HasOwnProp("caret") ? sc.caret : true
        if !IsObject(rec)
            why := "нет записи индикатора"
        else if expectCaret && !IsObject(rec["caret"])
            why := "каретка не найдена"
        else if !expectCaret && IsObject(rec["shown"]["caret"])
            why := "флажок у каретки, где его быть не должно"
        else if flag != Flags[lang]
            why := "флаг " flag ", ожидался " Flags[lang]
        Results.Push({scenario: sc.name, step: step, ok: why = "", why: why, win: win, caret: caret, flag: flag, shot: shot})
    }
    CloseScenario(sc, pid)
}

CloseScenario(sc, pid) {
    exe := sc.HasOwnProp("exe") ? sc.exe : ""
    if exe != ""
        while ProcessExist(exe)
            ProcessClose(exe)
    else if pid
        try ProcessClose(pid)
    Sleep(500)
}

; Раскладка активного окна: WM_INPUTLANGCHANGEREQUEST элементу с фокусом
SetLayout(hkl) {
    try PostMessage(0x50, 0, hkl, ControlGetFocus("A") || WinExist("A"))
    catch
        PostMessage(0x50, 0, hkl, , "A")
}

; Последняя запись индикатора
LastRecord() {
    try text := FileRead(TracePath, "UTF-8")
    catch
        return ""
    lines := StrSplit(Trim(text, "`n"), "`n")
    return lines.Length ? Json.Parse(lines[lines.Length]) : ""
}

; Снимок всего экрана в PNG (System.Drawing через PowerShell — без своих библиотек)
Shot(name) {
    name := RegExReplace(name, "[^\w.-]", "_") ".png"
    ps := "Add-Type -AssemblyName System.Windows.Forms,System.Drawing; "
        . "$b=[Windows.Forms.SystemInformation]::VirtualScreen; $i=New-Object Drawing.Bitmap $b.Width,$b.Height; "
        . "$g=[Drawing.Graphics]::FromImage($i); $g.CopyFromScreen($b.Location,[Drawing.Point]::Empty,$b.Size); "
        . "$i.Save('" outDir "\" name "')"
    RunWait('powershell -NoProfile -WindowStyle Hidden -Command "' ps '"', , "Hide")
    return name
}

StopIndicator() {
    DetectHiddenWindows(true)
    try PostMessage(0x111, 65405, 0, , "LanguageIndicator.exe ahk_class AutoHotkey")
}

WaitFor(cond, ms) {
    end := A_TickCount + ms
    while A_TickCount < end {
        if cond()
            return true
        Sleep(200)
    }
    return false
}

Fail(msg) {
    FileAppend("# Тесты по программам`n`n❌ " msg "`n", outDir "\report.md", "UTF-8")
    FileAppend("0/0", outDir "\done", "UTF-8-RAW")
    ExitApp(2)
}
