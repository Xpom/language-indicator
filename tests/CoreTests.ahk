; Тесты ядра: снимок + настройки -> размещения.

AllFlags(code) => true
NoFlags(code) => false

; Каретка шириной 2 и высотой 20 в точке (100, 200)
CaretRect() => {x: 100, y: 200, w: 2, h: 20}

Snap(hkl := 0x04190419, caret?, dpi := 96) => {hkl: hkl, caret: IsSet(caret) ? caret : CaretRect(), caretDpi: dpi}

; --- маппинг раскладки ---

Test("маппинг: RU", (*) => AssertEq(Core.MapLayout(0x04190419, AllFlags), {flag: "ru", text: "RU"}))
Test("маппинг: US", (*) => AssertEq(Core.MapLayout(0x04090409, AllFlags), {flag: "us", text: "EN"}))
Test("маппинг: GB", (*) => AssertEq(Core.MapLayout(0x08090809, AllFlags), {flag: "gb", text: "EN"}))
Test("маппинг: UA", (*) => AssertEq(Core.MapLayout(0x04220422, AllFlags), {flag: "ua", text: "UK"}))
Test("маппинг: BY", (*) => AssertEq(Core.MapLayout(0x04230423, AllFlags), {flag: "by", text: "BE"}))
Test("маппинг: KZ", (*) => AssertEq(Core.MapLayout(0x043F043F, AllFlags), {flag: "kz", text: "KK"}))
Test("маппинг: вариант раскладки (Дворак) — флаг по языку",
    (*) => AssertEq(Core.MapLayout(0xF0020409, AllFlags), {flag: "us", text: "EN"}))
Test("маппинг: нет картинки — только текст",
    (*) => AssertEq(Core.MapLayout(0x04190419, NoFlags), {flag: "", text: "RU"}))
Test("маппинг: числовой регион (en-029) — только текст",
    (*) => AssertEq(Core.MapLayout(0x2409, AllFlags), {flag: "", text: "EN"}))

; --- позиция: каретка (100, 200, 2×20), флажок 16×12, отступ 3 ---

PlaceAt(side) => Core.Place(CaretRect(), side, 3, 16, 12)

Test("позиция: снизу — левый край на вертикали каретки", (*) => AssertEq(PlaceAt("bottom"), {x: 100, y: 223}))
Test("позиция: сверху", (*) => AssertEq(PlaceAt("top"), {x: 100, y: 185}))
Test("позиция: справа — по центру", (*) => AssertEq(PlaceAt("right"), {x: 105, y: 204}))
Test("позиция: слева — по центру", (*) => AssertEq(PlaceAt("left"), {x: 81, y: 204}))
Test("позиция: справа снизу", (*) => AssertEq(PlaceAt("bottom-right"), {x: 105, y: 223}))
Test("позиция: слева снизу", (*) => AssertEq(PlaceAt("bottom-left"), {x: 81, y: 223}))
Test("позиция: справа сверху", (*) => AssertEq(PlaceAt("top-right"), {x: 105, y: 185}))
Test("позиция: слева сверху", (*) => AssertEq(PlaceAt("top-left"), {x: 81, y: 185}))

; --- Decide ---

Test("Decide: по умолчанию флажок под кареткой, 16×12, отступ 3", (*) => AssertEq(
    Core.Decide(Snap(), DefaultSettings(), AllFlags).caret,
    {flag: "ru", text: "RU", x: 100, y: 223, w: 16, h: 12, alpha: 217}))

DecideAtDpi(dpi) {
    p := Core.Decide(Snap(, , dpi), DefaultSettings(), AllFlags).caret
    return {y: p.y, w: p.w, h: p.h}
}

Test("Decide: DPI 125%", (*) => AssertEq(DecideAtDpi(120), {y: 224, w: 20, h: 15}))
Test("Decide: DPI 150%", (*) => AssertEq(DecideAtDpi(144), {y: 225, w: 24, h: 18}))
Test("Decide: DPI 200%", (*) => AssertEq(DecideAtDpi(192), {y: 226, w: 32, h: 24}))

Test("Decide: нет каретки — скрыто",
    (*) => AssertEq(Core.Decide(Snap(, ""), DefaultSettings(), AllFlags).caret, ""))

DecideDisabled() {
    s := DefaultSettings()
    s.caret.enabled := false
    return Core.Decide(Snap(), s, AllFlags).caret
}
Test("Decide: индикатор выключен — скрыто", (*) => AssertEq(DecideDisabled(), ""))

Test("Decide: раскладка неизвестна — скрыто",
    (*) => AssertEq(Core.Decide(Snap(0), DefaultSettings(), AllFlags).caret, ""))

Test("Decide: нет картинки — размещение с текстом",
    (*) => AssertEq(Core.Decide(Snap(), DefaultSettings(), NoFlags).caret.flag, ""))
