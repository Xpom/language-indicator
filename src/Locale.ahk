; Справочник локалей Windows. Ответы зависят только от входа, поэтому годится для тестов.

class Locale {
    static LOCALE_SLOCALIZEDDISPLAYNAME := 0x2
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

    ; "ru-RU" -> "Русский (Россия)" — на языке интерфейса Windows
    static DisplayName(name) => Locale.Info(name, Locale.LOCALE_SLOCALIZEDDISPLAYNAME)

    static Info(name, type) {
        if name = ""
            return ""
        buf := Buffer(128 * 2, 0)
        n := DllCall("GetLocaleInfoEx", "str", name, "uint", type, "ptr", buf, "int", 128, "int")
        return n ? StrGet(buf) : ""
    }
}
