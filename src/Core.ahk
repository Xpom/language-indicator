; Ядро: чистые функции «снимок → что показать». Окна, курсор и экран не трогает.
;
; Снимок:     {hkl, caret: {x, y, w, h} | "", caretDpi}   — координаты в физических пикселях
; Размещение: {flag, text, x, y, w, h, alpha}              — flag = "" значит картинки нет, показать text

class Core {
    ; hasFlag: code -> true/false, есть ли картинка флага
    ; Возвращает {caret: размещение | ""}
    static Decide(snap, settings, hasFlag) {
        result := {caret: ""}
        cs := settings.caret
        if !cs.enabled || !IsObject(snap.caret)
            return result
        ind := Core.MapLayout(snap.hkl, hasFlag)
        if ind.flag = "" && ind.text = ""
            return result
        scale := snap.caretDpi / 96
        h := Round(cs.size * scale)
        w := Round(cs.size * 4 / 3 * scale)
        pos := Core.Place(snap.caret, cs.side, Round(cs.gap * scale), w, h)
        result.caret := {flag: ind.flag, text: ind.text, x: pos.x, y: pos.y, w: w, h: h,
            alpha: Round(settings.opacity * 255 / 100)}
        return result
    }

    ; HKL -> {flag: "ru" | "", text: "RU"}
    ; Язык берётся из младшего слова HKL, флаг — по стране локали.
    static MapLayout(hkl, hasFlag) {
        ; LANGID 0 Windows понимает как «язык пользователя по умолчанию» — для нас это «раскладка неизвестна»
        name := (hkl & 0xFFFF) ? Locale.NameFromLangId(hkl & 0xFFFF) : ""
        country := StrLower(Locale.Country(name))
        flag := (country ~= "^[a-z]{2}$" && hasFlag(country)) ? country : ""
        return {flag: flag, text: StrUpper(Locale.Language(name))}
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
