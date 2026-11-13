; Настройки. Размеры и отступы — логические пиксели (для масштаба 100%).

DefaultSettings() {
    return {
        opacity: 85,        ; %
        cornerRadius: 2,    ; скругление углов флага и плашки при высоте 12; растёт вместе с размером
        code: {             ; плашка с кодом языка
            bg: "#3c4043",  ; фон: #rrggbb или none — без фона, белый текст с тёмной обводкой
            font: "Segoe UI",
            scale: 62,      ; кегль, % высоты плашки
        },
        hideFullscreen: true,   ; прятать флажки на мониторе полноэкранного окна
        pollMs: 50,         ; опрос каретки и раскладки
        mousePollMs: 15,    ; опрос курсора: флажок у мыши должен поспевать за ней
        caret: {
            enabled: true,
            show: "flag",   ; flag — флаг раскладки; code — плашка с кодом языка
            side: "bottom", ; см. Core.Place
            gap: 3,
            size: 12,       ; высота флажка; ширина = высота * 4/3
            methods: {win32: true, msaa: true, uia: true},   ; способы поиска каретки, по порядку
            sizeMode: "fixed",  ; fixed — size; caret — sizeRatio % от высоты каретки в пределах sizeMin..sizeMax
            sizeRatio: 70,
            sizeMin: 8,
            sizeMax: 32,
        },
        mouse: {
            enabled: true,
            show: "flag",
            side: "bottom-right",
            gap: 3,
            size: 12,
        },
        layouts: Map(),     ; полный HKL -> {flag, text}; пустое поле = автоматически
    }
}

; settings.ini (UTF-16, чтобы годились любые символы в кодах):
;   [General]  opacity, hideFullscreen, cornerRadius
;   [Code]     bg, font, scale
;   [Caret]    enabled, show, side, gap, size
;   [Mouse]    enabled, show, side, gap, size
;   [Advanced] pollMs, mousePollMs, caretWin32, caretMsaa, caretUia,
;              caretSizeMode, caretSizeRatio, caretSizeMin, caretSizeMax
;   [Layouts]  04090409=gb|EN — полный HKL в hex = флаг|код
; Отсутствующее или негодное значение заменяется значением по умолчанию.
class SettingsFile {
    static sides := ["bottom", "top", "left", "right", "bottom-right", "bottom-left", "top-right", "top-left"]

    ; Все простые настройки: путь в объекте настроек, секция и ключ ini, вид значения.
    ; По этой таблице настройки читаются из ini, пишутся в него и меняются из окна настроек.
    ; Виды: num — целое в пределах [lo, hi]; bool; side — сторона из sides; enum — одно из слов lo;
    ;       color — #rrggbb или none; font — имя шрифта (латиница, цифры, пробел, - и _).
    static Fields := [
        ["opacity",             "General",  "opacity",        "num", 10, 100],
        ["hideFullscreen",      "General",  "hideFullscreen", "bool"],
        ["cornerRadius",        "General",  "cornerRadius",   "num", 0, 6],
        ["code.bg",             "Code",     "bg",             "color"],
        ["code.font",           "Code",     "font",           "font"],
        ["code.scale",          "Code",     "scale",          "num", 40, 90],
        ["caret.enabled",       "Caret",    "enabled",        "bool"],
        ["caret.show",          "Caret",    "show",           "enum", ["flag", "code"]],
        ["caret.side",          "Caret",    "side",           "side"],
        ["caret.gap",           "Caret",    "gap",            "num", 0, 50],
        ["caret.size",          "Caret",    "size",           "num", 6, 64],
        ["mouse.enabled",       "Mouse",    "enabled",        "bool"],
        ["mouse.show",          "Mouse",    "show",           "enum", ["flag", "code"]],
        ["mouse.side",          "Mouse",    "side",           "side"],
        ["mouse.gap",           "Mouse",    "gap",            "num", 0, 50],
        ["mouse.size",          "Mouse",    "size",           "num", 6, 64],
        ["pollMs",              "Advanced", "pollMs",         "num", 15, 1000],
        ["mousePollMs",         "Advanced", "mousePollMs",    "num", 10, 200],
        ["caret.methods.win32", "Advanced", "caretWin32",     "bool"],
        ["caret.methods.msaa",  "Advanced", "caretMsaa",      "bool"],
        ["caret.methods.uia",   "Advanced", "caretUia",       "bool"],
        ["caret.sizeMode",      "Advanced", "caretSizeMode",  "enum", ["fixed", "caret"]],
        ["caret.sizeRatio",     "Advanced", "caretSizeRatio", "num", 20, 200],
        ["caret.sizeMin",       "Advanced", "caretSizeMin",   "num", 6, 64],
        ["caret.sizeMax",       "Advanced", "caretSizeMax",   "num", 6, 64],
    ]

    static Load(path) {
        s := DefaultSettings()
        if !FileExist(path)
            return s
        for f in SettingsFile.Fields {
            v := SettingsFile.Parse(f, SettingsFile.Read(path, f[2], f[3]))
            if v != ""
                SettingsFile.Put(s, f[1], v)
        }
        SettingsFile.Normalize(s)
        s.layouts := SettingsFile.LoadLayouts(path)
        return s
    }

    static Save(s, path) {
        if FileExist(path)
            FileDelete(path)
        FileAppend("", path, "UTF-16")
        for f in SettingsFile.Fields {
            v := SettingsFile.Get(s, f[1])
            IniWrite(f[4] = "bool" ? (v ? 1 : 0) : v, path, f[2], f[3])
        }
        for hkl, o in s.layouts
            IniWrite(o.flag "|" o.text, path, "Layouts", Format("{:08X}", hkl))
    }

    ; Меняет одну настройку по пути из Fields (так её меняет окно настроек).
    ; value — строка или число; true — значение годное и записано, false — отброшено.
    static Set(s, key, value) {
        for f in SettingsFile.Fields {
            if f[1] != key
                continue
            v := SettingsFile.Parse(f, Trim(String(value)))
            if v = ""
                return false
            SettingsFile.Put(s, key, v)
            SettingsFile.Normalize(s)
            return true
        }
        return false
    }

    ; Переопределение раскладки из окна: флаг — имя картинки или "-" (без флага), код — до 4 знаков.
    ; Оба пустые — переопределение снимается. false — флаг негодный.
    static SetLayout(s, hkl, flag, text) {
        flag := StrLower(Trim(flag)), text := SubStr(Trim(StrReplace(text, "|")), 1, 4)
        if !(flag ~= "^[a-z0-9_-]*$")
            return false
        if flag = "" && text = ""
            s.layouts.Delete(hkl)
        else
            s.layouts[hkl] := {flag: flag, text: text}
        return true
    }

    ; Значение из строки по виду поля; "" — негодное
    static Parse(f, v) {
        switch f[4] {
            case "num":
                return (IsInteger(v) && v >= f[5] && v <= f[6]) ? Integer(v) : ""
            case "bool":
                switch StrLower(v) {
                    case "1", "true", "yes", "on":  return true
                    case "0", "false", "no", "off": return false
                }
                return ""
            case "color":
                v := StrLower(v)
                return v = "none" || v ~= "^#[0-9a-f]{6}$" ? v : ""
            case "font":
                return v ~= "^[A-Za-z0-9 _-]{1,40}$" ? v : ""
            case "side", "enum":
                for w in (f[4] = "side" ? SettingsFile.sides : f[5])
                    if v = w
                        return w
                return ""
        }
    }

    ; Связи между полями: максимум размера по каретке не меньше минимума
    static Normalize(s) {
        s.caret.sizeMax := Max(s.caret.sizeMin, s.caret.sizeMax)
    }

    static Get(s, path) {
        for name in StrSplit(path, ".")
            s := s.%name%
        return s
    }

    static Put(s, path, v) {
        names := StrSplit(path, ".")
        last := names.Pop()
        for name in names
            s := s.%name%
        s.%last% := v
    }

    static Read(path, section, key) => Trim(IniRead(path, section, key, ""))

    ; Строки «HKL=флаг|код». Флаг — имя картинки в flags (латиница, цифры, - и _).
    static LoadLayouts(path) {
        layouts := Map()
        try lines := IniRead(path, "Layouts")
        catch
            return layouts
        Loop Parse lines, "`n", "`r" {
            if !RegExMatch(A_LoopField, "^\s*([0-9A-Fa-f]{1,8})\s*=(.*)$", &m)
                continue
            parts := StrSplit(m[2], "|", " `t")
            flag := StrLower(parts[1])
            if !(flag ~= "^[a-z0-9_-]*$")
                flag := ""
            text := parts.Length >= 2 ? SubStr(parts[2], 1, 4) : ""
            if flag != "" || text != ""
                layouts[Integer("0x" m[1])] := {flag: flag, text: text}
        }
        return layouts
    }
}
