; JSON: Stringify — данные для окна настроек (страница сама присылает простые строки, см. SettingsPage);
; Parse — описание релиза и ответ GitHub API для проверки обновлений.

class Json {
    ; Объект → Map, массив → Array, true/false → 1/0, null → "". Негодный JSON — исключение.
    static Parse(text) {
        pos := 1
        v := Json.Value(text, &pos)
        Json.Space(text, &pos)
        if pos <= StrLen(text)
            throw ValueError("JSON: лишнее после значения в позиции " pos)
        return v
    }

    static Space(t, &pos) {
        while pos <= StrLen(t) && InStr(" `t`r`n", SubStr(t, pos, 1))
            pos++
    }

    static Value(t, &pos) {
        Json.Space(t, &pos)
        c := SubStr(t, pos, 1)
        switch c {
            case "{":
                m := Map(), pos++
                Json.Space(t, &pos)
                if SubStr(t, pos, 1) = "}"
                    return (pos++, m)
                loop {
                    Json.Space(t, &pos)
                    if SubStr(t, pos, 1) != '"'
                        throw ValueError("JSON: ожидался ключ в позиции " pos)
                    k := Json.String(t, &pos)
                    Json.Expect(t, &pos, ":")
                    m[k] := Json.Value(t, &pos)
                    if Json.Expect(t, &pos, ",}") = "}"
                        return m
                }
            case "[":
                a := [], pos++
                Json.Space(t, &pos)
                if SubStr(t, pos, 1) = "]"
                    return (pos++, a)
                loop {
                    a.Push(Json.Value(t, &pos))
                    if Json.Expect(t, &pos, ",]") = "]"
                        return a
                }
            case '"':
                return Json.String(t, &pos)
        }
        for word, value in Map("true", 1, "false", 0, "null", "")
            if SubStr(t, pos, StrLen(word)) == word
                return (pos += StrLen(word), value)
        if RegExMatch(t, "-?\d+(\.\d+)?([eE][-+]?\d+)?", &m, pos) && m.Pos = pos
            return (pos += m.Len, m[1] || m[2] ? Float(m[0]) : Integer(m[0]))
        throw ValueError("JSON: неожиданный символ в позиции " pos)
    }

    ; Следующий значимый символ должен быть одним из chars; возвращает его
    static Expect(t, &pos, chars) {
        Json.Space(t, &pos)
        c := SubStr(t, pos, 1)
        if c = "" || !InStr(chars, c, true)
            throw ValueError("JSON: ожидалось «" chars "» в позиции " pos)
        pos++
        return c
    }

    static String(t, &pos) {
        out := "", pos++
        loop {
            c := SubStr(t, pos, 1), pos++
            if c = ""
                throw ValueError("JSON: строка не закрыта")
            if c = '"'
                return out
            if c != "\" {
                out .= c
                continue
            }
            e := SubStr(t, pos, 1), pos++
            switch e, true {
                case "n": out .= "`n"
                case "r": out .= "`r"
                case "t": out .= "`t"
                case "b": out .= "`b"
                case "f": out .= "`f"
                case "u":
                    out .= Chr(Integer("0x" SubStr(t, pos, 4))), pos += 4
                default: out .= e
            }
        }
    }
    ; Объект, Map, массив, строка, число. true/false в AHK — числа 1/0, страница сама приводит их к булевым.
    static Stringify(v) {
        if v is Array {
            out := ""
            for item in v
                out .= (A_Index > 1 ? "," : "") Json.Stringify(item)
            return "[" out "]"
        }
        if v is Map {
            out := ""
            for k, item in v
                out .= (A_Index > 1 ? "," : "") Json.Str(String(k)) ":" Json.Stringify(item)
            return "{" out "}"
        }
        if IsObject(v) {
            out := ""
            for k, item in v.OwnProps()
                out .= (A_Index > 1 ? "," : "") Json.Str(k) ":" Json.Stringify(item)
            return "{" out "}"
        }
        return (v is Number) ? String(v) : Json.Str(v)
    }

    static Str(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, "`t", "\t")
        return '"' s '"'
    }
}
