; Тесты настроек (ini) и переопределений раскладок.

TempIni(content?) {
    path := A_Temp "\language-indicator-test.ini"
    if FileExist(path)
        FileDelete(path)
    if IsSet(content)
        FileAppend(content, path, "UTF-16")
    return path
}

; --- чтение и запись ---

Test("ini: файла нет — значения по умолчанию",
    (*) => AssertEq(SettingsFile.Load(TempIni()), DefaultSettings()))

Test("ini: пустой файл — значения по умолчанию",
    (*) => AssertEq(SettingsFile.Load(TempIni("")), DefaultSettings()))

Test("ini: мусорные значения — значения по умолчанию", (*) => AssertEq(SettingsFile.Load(TempIni("
(
[General]
opacity=abc
[Caret]
enabled=maybe
side=diagonal
gap=-5
size=1000
[Advanced]
pollMs=1
caretUia=2
[Layouts]
xyz=us|EN
04190419=../evil|RU
)")), GarbageExpected()))

; Значения по умолчанию, кроме переопределения 04190419: испорченный флаг отброшен, код остался
GarbageExpected() {
    s := DefaultSettings()
    s.layouts[0x04190419] := {flag: "", text: "RU"}
    return s
}

ChangedSettings() {
    s := DefaultSettings()
    s.opacity := 60
    s.pollMs := 100
    s.mousePollMs := 20
    s.caret.enabled := false
    s.caret.side := "top-left"
    s.caret.gap := 7
    s.caret.size := 20
    s.caret.methods.uia := false
    s.caret.sizeMode := "caret"
    s.caret.sizeRatio := 90
    s.caret.sizeMin := 10
    s.caret.sizeMax := 24
    s.mouse.side := "left"
    s.mouse.show := "code"
    s.mouse.size := 16
    s.layouts[0x04090409] := {flag: "gb", text: "EN"}
    s.layouts[0xF0020409] := {flag: "us", text: "DV"}
    s.layouts[0x04190419] := {flag: "", text: "РУ"}
    return s
}

SaveLoad(s) {
    path := TempIni()
    SettingsFile.Save(s, path)
    return SettingsFile.Load(path)
}

Test("ini: сохранить и прочитать — то же самое", (*) => AssertEq(SaveLoad(ChangedSettings()), ChangedSettings()))
Test("ini: значения по умолчанию переживают сохранение", (*) => AssertEq(SaveLoad(DefaultSettings()), DefaultSettings()))

Test("ini: ручная правка в нижнем регистре и с пробелами", (*) => AssertEq(SettingsFile.Load(TempIni("
(
[Caret]
side = Bottom-Right
enabled = false
[Layouts]
04090409 = GB | EN
)")).caret.side, "bottom-right"))

; --- переопределения в ядре ---

Overrides() => Map(
    0x04090409, {flag: "gb", text: ""},
    0xF0020409, {flag: "", text: "DV"},
    0x04190419, {flag: "missing", text: "РУ"},
)
OnlyRealFlags(code) => code = "gb" || code = "us" || code = "ru"

Test("переопределение: US -> флаг GB, код автоматический",
    (*) => AssertEq(Core.MapLayout(0x04090409, OnlyRealFlags, Overrides()), {flag: "gb", text: "EN"}))
Test("переопределение: Дворак отличается от US — свой код, флаг автоматический",
    (*) => AssertEq(Core.MapLayout(0xF0020409, OnlyRealFlags, Overrides()), {flag: "us", text: "DV"}))
Test("переопределение: картинки нет — текстовая плашка со своим кодом",
    (*) => AssertEq(Core.MapLayout(0x04190419, OnlyRealFlags, Overrides()), {flag: "", text: "РУ"}))
Test("переопределение: только по полному HKL — другой вариант раскладки не задет",
    (*) => AssertEq(Core.MapLayout(0xF0030409, OnlyRealFlags, Overrides()), {flag: "us", text: "EN"}))

DecideWithOverrides() {
    s := DefaultSettings()
    s.layouts := Overrides()
    p := Core.Decide(Snap(0x04190419), s, OnlyRealFlags).caret
    return {flag: p.flag, text: p.text}
}
Test("Decide: переопределения из настроек доходят до размещения",
    (*) => AssertEq(DecideWithOverrides(), {flag: "", text: "РУ"}))

; --- изменение одной настройки из окна ---

SetAndShow(key, value) {
    s := DefaultSettings()
    ok := SettingsFile.Set(s, key, value)
    return ok ": " Show(SettingsFile.Get(s, key))
}

Test("Set: годное число", (*) => AssertEq(SetAndShow("caret.size", "20"), "1: 20"))
Test("Set: число вне пределов отброшено", (*) => AssertEq(SetAndShow("opacity", 5), "0: 85"))
Test("Set: булево", (*) => AssertEq(SetAndShow("mouse.enabled", "false"), "1: 0"))
Test("Set: сторона в любом регистре", (*) => AssertEq(SetAndShow("caret.side", "Top-Left"), '1: "top-left"'))
Test("Set: вложенный путь", (*) => AssertEq(SetAndShow("caret.methods.uia", 0), "1: 0"))
Test("Set: show — только flag или code", (*) => AssertEq(SetAndShow("caret.show", "emoji"), '0: "flag"'))
Test("Set: неизвестный ключ", (*) => AssertEq(SettingsFile.Set(DefaultSettings(), "layouts", "x"), false))
Test("Set: максимум не меньше минимума", (*) => (s := DefaultSettings(), SettingsFile.Set(s, "caret.sizeMin", 40),
    AssertEq(s.caret.sizeMax, 40)))

; --- переопределение раскладки из окна ---

LayoutAfter(flag, text) {
    s := DefaultSettings()
    ok := SettingsFile.SetLayout(s, 0x04190419, flag, text)
    return ok ": " Show(s.layouts)
}

Test("SetLayout: флаг и код", (*) => AssertEq(LayoutAfter("GB", " EN "), '1: {68748313: {"flag": "gb", "text": "EN"}}'))
Test("SetLayout: без флага", (*) => AssertEq(LayoutAfter("-", ""), '1: {68748313: {"flag": "-", "text": ""}}'))
Test("SetLayout: код обрезается до 4 знаков, | убирается", (*) => AssertEq(LayoutAfter("", "AB|CDEF"), '1: {68748313: {"flag": "", "text": "ABCD"}}'))
Test("SetLayout: негодный флаг отброшен", (*) => AssertEq(LayoutAfter("../x", "RU"), "0: {}"))
Test("SetLayout: оба пустые — переопределение снято", (*) => (s := DefaultSettings(), s.layouts[0x04190419] := {flag: "gb", text: ""},
    SettingsFile.SetLayout(s, 0x04190419, "", ""), AssertEq(s.layouts.Count, 0)))
