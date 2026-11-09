; Справочник локалей Windows. Ответы зависят только от входа, поэтому годится для тестов.

class Locale {
    static LOCALE_SISO639LANGNAME := 0x59
    static LOCALE_SISO3166CTRYNAME := 0x5A

    ; 0x0419 -> "ru-RU"; неизвестный LANGID -> ""
    static NameFromLangId(langId) {
        buf := Buffer(85 * 2, 0)
        n := DllCall("LCIDToLocaleName", "uint", langId, "ptr", buf, "int", 85, "uint", 0, "int")
        return n ? StrGet(buf) : ""
    }

    ; "ru-RU" -> "RU"; у некоторых локалей регион числовой ("en-029" -> "029")
    static Country(name) => Locale.Info(name, Locale.LOCALE_SISO3166CTRYNAME)

    ; "ru-RU" -> "ru"
    static Language(name) => Locale.Info(name, Locale.LOCALE_SISO639LANGNAME)

    static Info(name, type) {
        if name = ""
            return ""
        buf := Buffer(20 * 2, 0)
        n := DllCall("GetLocaleInfoEx", "str", name, "uint", type, "ptr", buf, "int", 20, "int")
        return n ? StrGet(buf) : ""
    }
}
