; Отладочный режим: ключ /trace <файл> — индикатор дописывает строку JSON (JSON Lines) всякий раз,
; когда меняется увиденное: окно, раскладка, каретка, показанный флажок. По нему тесты по программам
; сверяют, что нашлось, и его можно попросить у человека, присылающего ошибку.
; Заголовков и текста окон в записи нет — только имя exe и классы окон.
class Trace {
    static path := ""
    static last := ""

    ; Запись без времени — чистая функция от того, что увидели и что решили.
    ; win — {exe, class, focus} или ""; ind — {flag, text} из Core.MapLayout; result — из Core.Decide.
    ; Позиция флажка у мыши не пишется: она меняется с каждым движением, а считает её только Core.
    static Record(win, snap, ind, result) => Map(
        "win", IsObject(win) ? Map("exe", win.exe, "class", win.class, "focus", win.focus) : Json.JNull,
        "hkl", Format("{:08X}", snap.hkl),
        "flag", ind.flag,
        "text", ind.text,
        "caret", IsObject(snap.caret) ? Trace.Box(snap.caret, snap.caret.HasOwnProp("method") ? snap.caret.method : "") : Json.JNull,
        "ibeam", IsObject(snap.mouse) && snap.mouse.ibeam ? Json.JTrue : Json.JFalse,
        "shown", Map(
            "caret", IsObject(result.caret) ? Trace.Box(result.caret) : Json.JNull,
            "mouse", IsObject(result.mouse) ? Json.JTrue : Json.JFalse,
        ),
    )

    static Box(r, method := "") {
        m := Map("x", r.x, "y", r.y, "w", r.w, "h", r.h)
        if method != ""
            m["method"] := method
        return m
    }

    ; Дописывает запись, если она отличается от прошлой; к строке спереди добавляется время
    static Write(rec) {
        line := Json.Stringify(rec)
        if line = Trace.last
            return
        Trace.last := line
        t := FormatTime(, "yyyy-MM-ddTHH:mm:ss") "." A_MSec
        try FileAppend('{"t":"' t '",' SubStr(line, 2) "`n", Trace.path, "UTF-8-RAW")
    }

    ; Окно переднего плана: имя exe, класс окна и класс элемента с фокусом
    static Window() {
        hwnd := DllCall("GetForegroundWindow", "ptr")
        if !hwnd
            return ""
        try {
            w := {exe: WinGetProcessName(hwnd), class: WinGetClass(hwnd), focus: ""}
        } catch
            return ""
        try w.focus := WinGetClass(ControlGetFocus(hwnd))
        return w
    }
}
