; JSON для окна настроек: AHK отдаёт странице данные. Разбирать JSON не нужно — страница
; присылает простые строки (см. SettingsPage).

class Json {
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
