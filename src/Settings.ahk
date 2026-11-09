; Настройки. Размеры и отступы — логические пиксели (для масштаба 100%).

DefaultSettings() {
    return {
        opacity: 85,        ; %
        pollMs: 50,         ; опрос каретки и раскладки
        mousePollMs: 15,    ; опрос курсора: флажок у мыши должен поспевать за ней
        caret: {
            enabled: true,
            side: "bottom", ; см. Core.Place
            gap: 3,
            size: 12,       ; высота флажка; ширина = высота * 4/3
            methods: {win32: true, msaa: true, uia: true},   ; способы поиска каретки, по порядку
        },
        mouse: {
            enabled: true,
            side: "bottom-right",
            gap: 3,
            size: 12,
        },
        layouts: Map(),     ; полный HKL -> {flag, text}; пустое поле = автоматически
    }
}

; settings.ini (UTF-16, чтобы годились любые символы в кодах):
;   [General]  opacity
;   [Caret]    enabled, side, gap, size
;   [Mouse]    enabled, side, gap, size
;   [Advanced] pollMs, mousePollMs, caretWin32, caretMsaa, caretUia
;   [Layouts]  04090409=gb|EN — полный HKL в hex = флаг|код
; Отсутствующее или негодное значение заменяется значением по умолчанию.
class SettingsFile {
    static sides := ["bottom", "top", "left", "right", "bottom-right", "bottom-left", "top-right", "top-left"]

    static Load(path) {
        s := DefaultSettings()
        if !FileExist(path)
            return s
        s.opacity := SettingsFile.Num(path, "General", "opacity", s.opacity, 10, 100)
        s.pollMs := SettingsFile.Num(path, "Advanced", "pollMs", s.pollMs, 15, 1000)
        s.mousePollMs := SettingsFile.Num(path, "Advanced", "mousePollMs", s.mousePollMs, 10, 200)
        for section, ind in Map("Caret", s.caret, "Mouse", s.mouse) {
            ind.enabled := SettingsFile.Bool(path, section, "enabled", ind.enabled)
            ind.side := SettingsFile.Side(path, section, "side", ind.side)
            ind.gap := SettingsFile.Num(path, section, "gap", ind.gap, 0, 50)
            ind.size := SettingsFile.Num(path, section, "size", ind.size, 6, 64)
        }
        m := s.caret.methods
        m.win32 := SettingsFile.Bool(path, "Advanced", "caretWin32", m.win32)
        m.msaa := SettingsFile.Bool(path, "Advanced", "caretMsaa", m.msaa)
        m.uia := SettingsFile.Bool(path, "Advanced", "caretUia", m.uia)
        s.layouts := SettingsFile.LoadLayouts(path)
        return s
    }

    static Save(s, path) {
        if FileExist(path)
            FileDelete(path)
        FileAppend("", path, "UTF-16")
        IniWrite(s.opacity, path, "General", "opacity")
        for section, ind in Map("Caret", s.caret, "Mouse", s.mouse) {
            IniWrite(ind.enabled ? 1 : 0, path, section, "enabled")
            IniWrite(ind.side, path, section, "side")
            IniWrite(ind.gap, path, section, "gap")
            IniWrite(ind.size, path, section, "size")
        }
        IniWrite(s.pollMs, path, "Advanced", "pollMs")
        IniWrite(s.mousePollMs, path, "Advanced", "mousePollMs")
        IniWrite(s.caret.methods.win32 ? 1 : 0, path, "Advanced", "caretWin32")
        IniWrite(s.caret.methods.msaa ? 1 : 0, path, "Advanced", "caretMsaa")
        IniWrite(s.caret.methods.uia ? 1 : 0, path, "Advanced", "caretUia")
        for hkl, o in s.layouts
            IniWrite(o.flag "|" o.text, path, "Layouts", Format("{:08X}", hkl))
    }

    static Read(path, section, key) => Trim(IniRead(path, section, key, ""))

    static Num(path, section, key, default, lo, hi) {
        v := SettingsFile.Read(path, section, key)
        return (IsInteger(v) && v >= lo && v <= hi) ? Integer(v) : default
    }

    static Bool(path, section, key, default) {
        switch SettingsFile.Read(path, section, key) {
            case "1", "true", "yes", "on":  return true
            case "0", "false", "no", "off": return false
        }
        return default
    }

    static Side(path, section, key, default) {
        v := StrLower(SettingsFile.Read(path, section, key))
        for side in SettingsFile.sides
            if v = side
                return side
        return default
    }

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
