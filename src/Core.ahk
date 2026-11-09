; Ядро: чистые функции «снимок → что показать». Окна, курсор и экран не трогает.
;
; Снимок: {hkl,
;          caret: {x, y, w, h} | "", caretDpi,
;          mouse: {ibeam, hot: {x, y}, glyph: {x, y, w, h} | ""} | "", mouseDpi,
;          fullscreen: {x, y, w, h} | ""}
;         координаты в физических пикселях; glyph — видимые границы «I» на экране;
;         fullscreen — монитор, который целиком занят активным окном без рамки
; Размещение: {flag, text, x, y, w, h, alpha} — flag = "" значит картинки нет, показать text

class Core {
    ; hasFlag: code -> true/false, есть ли картинка флага
    ; Возвращает {caret: размещение | "", mouse: размещение | ""}
    static Decide(snap, settings, hasFlag) {
        ind := Core.MapLayout(snap.hkl, hasFlag, settings.layouts)
        result := {
            caret: Core.PlaceIndicator(ind, snap.caret, settings.caret, snap.caretDpi, settings.opacity),
            mouse: Core.PlaceIndicator(ind, Core.MouseAnchor(snap.mouse), settings.mouse, snap.mouseDpi, settings.opacity),
        }
        ; Полноэкранное окно (игра, видео) прячет флажки на своём мониторе, но не на соседнем
        if settings.hideFullscreen && IsObject(snap.fullscreen) {
            for name in ["caret", "mouse"]
                if Core.CenterInside(result.%name%, snap.fullscreen)
                    result.%name% := ""
        }
        return result
    }

    static CenterInside(p, r) {
        if !IsObject(p)
            return false
        cx := p.x + p.w / 2, cy := p.y + p.h / 2
        return cx >= r.x && cx < r.x + r.w && cy >= r.y && cy < r.y + r.h
    }

    ; Якорь флажка у мыши: видимые границы «I», а если их нет — точка hotspot. Не IBEAM — "".
    static MouseAnchor(m) {
        if !IsObject(m) || !m.ibeam
            return ""
        return IsObject(m.glyph) ? m.glyph : {x: m.hot.x, y: m.hot.y, w: 0, h: 0}
    }

    ; s — настройки индикатора: {enabled, side, gap, size}
    static PlaceIndicator(ind, anchor, s, dpi, opacity) {
        if !s.enabled || !IsObject(anchor) || (ind.flag = "" && ind.text = "")
            return ""
        scale := dpi / 96
        h := Round(s.size * scale)
        w := Round(s.size * 4 / 3 * scale)
        pos := Core.Place(anchor, s.side, Round(s.gap * scale), w, h)
        return {flag: ind.flag, text: ind.text, x: pos.x, y: pos.y, w: w, h: h,
            alpha: Round(opacity * 255 / 100)}
    }

    ; HKL -> {flag: "ru" | "", text: "RU"}
    ; Сначала переопределение по полному HKL (overrides: Map HKL -> {flag, text},
    ; пустое поле — автоматически), иначе язык из младшего слова HKL и флаг по стране локали.
    ; Флаг без картинки превращается в "" — тогда показывается текстовая плашка.
    static MapLayout(hkl, hasFlag, overrides := Map()) {
        ; LANGID 0 Windows понимает как «язык пользователя по умолчанию» — для нас это «раскладка неизвестна»
        name := (hkl & 0xFFFF) ? Locale.NameFromLangId(hkl & 0xFFFF) : ""
        flag := StrLower(Locale.Country(name))
        flag := flag ~= "^[a-z]{2}$" ? flag : ""     ; регион бывает числовым: en-029
        text := StrUpper(Locale.Language(name))
        if overrides.Has(hkl) {
            o := overrides[hkl]
            flag := o.flag != "" ? o.flag : flag
            text := o.text != "" ? o.text : text
        }
        if !(flag ~= "^[a-z0-9_-]+$" && hasFlag(flag))
            flag := ""
        return {flag: flag, text: text}
    }

    ; Ставит прямоугольник w×h рядом с якорем a = {x, y, w, h} на расстоянии gap.
    ; side: bottom, top — левый край на вертикали левого края якоря;
    ;       left, right — по центру якоря по вертикали;
    ;       top-left, top-right, bottom-left, bottom-right — по диагонали от угла якоря.
    static Place(a, side, gap, w, h) {
        L := a.x, T := a.y, R := a.x + a.w, B := a.y + a.h
        midY := Round(a.y + (a.h - h) / 2)
        switch side {
            case "bottom":       return {x: L,           y: B + gap}
            case "top":          return {x: L,           y: T - gap - h}
            case "right":        return {x: R + gap,     y: midY}
            case "left":         return {x: L - gap - w, y: midY}
            case "bottom-right": return {x: R + gap,     y: B + gap}
            case "bottom-left":  return {x: L - gap - w, y: B + gap}
            case "top-right":    return {x: R + gap,     y: T - gap - h}
            case "top-left":     return {x: L - gap - w, y: T - gap - h}
        }
        throw ValueError("Неизвестная сторона: " side)
    }
}
