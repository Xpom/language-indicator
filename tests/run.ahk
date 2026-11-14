; Мини-раннер: выполняет зарегистрированные тесты, печатает итог в stdout,
; код выхода 0 — всё прошло, 1 — есть падения.
#Requires AutoHotkey v2.0
#NoTrayIcon

#Include ..\src\Locale.ahk
#Include ..\src\Settings.ahk
#Include ..\src\Core.ahk
#Include ..\src\Json.ahk
#Include ..\src\Release.ahk
#Include ..\src\Http.ahk
#Include ..\src\Updater.ahk

global Tests := []
Test(name, fn) => Tests.Push({name: name, fn: fn})

AssertEq(actual, expected, what := "") {
    a := Show(actual), e := Show(expected)
    if a != e
        throw Error((what ? what ": " : "") "ожидалось " e ", получено " a)
}

AssertThrows(fn) {
    try fn()
    catch
        return
    throw Error("ожидалось исключение")
}

Show(v) {
    if !IsObject(v)
        return v is String ? '"' v '"' : String(v)
    parts := []
    for k, val in (v is Map ? v : v.OwnProps())
        parts.Push(Show(k) ": " Show(val))
    out := ""
    for i, p in parts
        out .= (i > 1 ? ", " : "") p
    return "{" out "}"
}

Print(s) => FileAppend(s "`n", "*", "UTF-8-RAW")

#Include CoreTests.ahk
#Include SettingsTests.ahk
#Include JsonTests.ahk
#Include ReleaseTests.ahk
#Include UpdaterTests.ahk

failed := 0
for t in Tests {
    try {
        t.fn.Call()
        Print("ok   " t.name)
    } catch as e {
        failed++
        Print("FAIL " t.name " — " e.Message)
    }
}
Print(Tests.Length - failed " из " Tests.Length " прошло")
ExitApp(failed ? 1 : 0)
