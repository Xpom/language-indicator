; Тесты ядра: снимок + настройки -> размещения.

AllFlags(code) => true
NoFlags(code) => false

; Каретка шириной 2 и высотой 20 в точке (100, 200)
CaretRect() => {x: 100, y: 200, w: 2, h: 20}

Snap(hkl := 0x04190419, caret?, dpi := 96) => {hkl: hkl, caret: IsSet(caret) ? caret : CaretRect(), caretDpi: dpi,
    mouse: "", mouseDpi: 96, fullscreen: ""}

; Курсор IBEAM: hotspot (300, 400), видимая «I» 9×20 в точке (296, 390)
GlyphRect() => {x: 296, y: 390, w: 9, h: 20}
MouseSnap(mouse, dpi := 96) => {hkl: 0x04190419, caret: "", caretDpi: 96, mouse: mouse, mouseDpi: dpi, fullscreen: ""}
IBeam(glyph?) => {ibeam: true, hot: {x: 300, y: 400}, glyph: IsSet(glyph) ? glyph : GlyphRect()}

DecideMouse(mouse, dpi := 96, settings?) {
    p := Core.Decide(MouseSnap(mouse, dpi), IsSet(settings) ? settings : DefaultSettings(), AllFlags).mouse
    return IsObject(p) ? {x: p.x, y: p.y, w: p.w, h: p.h} : p
}

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

; --- флажок у мыши ---

Test("мышь: по умолчанию справа снизу от видимой «I», отступ 3",
    (*) => AssertEq(DecideMouse(IBeam()), {x: 308, y: 413, w: 16, h: 12}))

Test("мышь: границ глифа нет — якорь hotspot",
    (*) => AssertEq(DecideMouse(IBeam("")), {x: 303, y: 403, w: 16, h: 12}))

Test("мышь: курсор не IBEAM — скрыто",
    (*) => AssertEq(DecideMouse({ibeam: false, hot: {x: 300, y: 400}, glyph: ""}), ""))

Test("мышь: курсора нет в снимке — скрыто", (*) => AssertEq(DecideMouse(""), ""))

MouseSide(side) {
    s := DefaultSettings()
    s.mouse.side := side
    return DecideMouse(IBeam(), 96, s)
}
Test("мышь: снизу — по левому краю «I»", (*) => AssertEq(MouseSide("bottom"), {x: 296, y: 413, w: 16, h: 12}))
Test("мышь: слева — по центру «I»", (*) => AssertEq(MouseSide("left"), {x: 277, y: 394, w: 16, h: 12}))

Test("мышь: DPI 150%", (*) => AssertEq(DecideMouse(IBeam(), 144), {x: 310, y: 415, w: 24, h: 18}))

MouseDisabled() {
    s := DefaultSettings()
    s.mouse.enabled := false
    return DecideMouse(IBeam(), 96, s)
}
Test("мышь: индикатор выключен — скрыто", (*) => AssertEq(MouseDisabled(), ""))

Test("мышь и каретка независимы: каретки нет, флажок у мыши есть",
    (*) => AssertEq(Core.Decide(MouseSnap(IBeam()), DefaultSettings(), AllFlags).caret, ""))

Test("мышь: тот же флаг, что у каретки (раскладка активного окна)",
    (*) => AssertEq(Core.Decide(MouseSnap(IBeam()), DefaultSettings(), AllFlags).mouse.flag, "ru"))

; --- полноэкранный режим ---

; Каретка (100, 200) и мышь (300, 400) на мониторе 0..1920×0..1080; второй монитор справа
Monitor1() => {x: 0, y: 0, w: 1920, h: 1080}
Monitor2() => {x: 1920, y: 0, w: 1920, h: 1080}

DecideFullscreen(fs, hide := true) {
    sn := Snap()
    sn.mouse := IBeam()
    sn.fullscreen := fs
    s := DefaultSettings()
    s.hideFullscreen := hide
    r := Core.Decide(sn, s, AllFlags)
    return {caret: IsObject(r.caret), mouse: IsObject(r.mouse)}
}

Test("полноэкранный: окно на мониторе флажков — оба скрыты",
    (*) => AssertEq(DecideFullscreen(Monitor1()), {caret: false, mouse: false}))
Test("полноэкранный: окно на другом мониторе — флажки видны",
    (*) => AssertEq(DecideFullscreen(Monitor2()), {caret: true, mouse: true}))
Test("полноэкранный: опция выключена — флажки видны",
    (*) => AssertEq(DecideFullscreen(Monitor1(), false), {caret: true, mouse: true}))
Test("полноэкранного окна нет — флажки видны",
    (*) => AssertEq(DecideFullscreen(""), {caret: true, mouse: true}))

; --- размер по высоте каретки ---

; Каретка высотой h логических пикселей, режим «по высоте»: 70%, пределы 8..32
CaretSized(h, dpi := 96, mode := "caret") {
    s := DefaultSettings()
    s.caret.sizeMode := mode
    scale := dpi / 96
    p := Core.Decide({hkl: 0x04190419, caret: {x: 100, y: 200, w: 2, h: Round(h * scale)}, caretDpi: dpi,
        mouse: IBeam(), mouseDpi: dpi, fullscreen: ""}, s, AllFlags)
    return {caret: p.caret.h, mouse: p.mouse.h}
}

Test("размер по каретке: 70% от высоты 20 = 14", (*) => AssertEq(CaretSized(20).caret, 14))
Test("размер по каретке: высокая каретка упирается в максимум 32", (*) => AssertEq(CaretSized(60).caret, 32))
Test("размер по каретке: низкая каретка упирается в минимум 8", (*) => AssertEq(CaretSized(5).caret, 8))
Test("размер по каретке: DPI 150% — считается в логических пикселях", (*) => AssertEq(CaretSized(20, 144).caret, 21))
Test("размер по каретке: флажок у мыши не меняется", (*) => AssertEq(CaretSized(60).mouse, 12))
Test("размер фиксированный: высота каретки не влияет", (*) => AssertEq(CaretSized(60, 96, "fixed").caret, 12))
