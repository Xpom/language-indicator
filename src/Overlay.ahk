; Окно-слой с флажком: поверх всех, прозрачно для кликов, не активируется, нет в панели задач и Alt+Tab.
; Перерисовывается только когда меняется картинка (флаг, размер, прозрачность), иначе просто двигается.

class FlagOverlay {
    __New(flagsDir) {
        this.flagsDir := flagsDir
        this.images := Map()   ; код флага -> GpBitmap* исходной картинки
        ; WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_NOACTIVATE; ToolWindow убирает из Alt+Tab
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08080020")
        this.hwnd := this.gui.Hwnd
        this.visible := false
        this.look := ""        ; ключ нарисованной картинки
        this.x := "", this.y := ""
    }

    ; p — размещение из Core.Decide или "" (спрятать)
    Update(p) {
        if !IsObject(p) {
            this.Hide()
            return
        }
        look := p.flag "|" p.text "|" p.w "|" p.h "|" p.alpha "|" p.radius "|" p.bg "|" p.font "|" p.scale
        if look != this.look {
            this.Render(p)
            this.look := look
            DllCall("SetWindowPos", "ptr", this.hwnd, "ptr", -1, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x13)   ; поверх, без сдвига
        } else if p.x != this.x || p.y != this.y {
            ; HWND_TOPMOST, SWP_NOSIZE | SWP_NOACTIVATE: заодно поднимаем над другими окнами «поверх всех»
            DllCall("SetWindowPos", "ptr", this.hwnd, "ptr", -1, "int", p.x, "int", p.y, "int", 0, "int", 0, "uint", 0x11)
        }
        this.x := p.x, this.y := p.y
        if !this.visible {
            ; Геометрия та же, что у UpdateLayeredWindow, иначе Show подставит свой размер
            this.gui.Show(Format("NA x{} y{} w{} h{}", p.x, p.y, p.w, p.h))
            this.visible := true
        }
    }

    Hide() {
        if this.visible
            this.gui.Hide()
        this.visible := false
    }

    ; Код языка строго по центру плашки w×h: буквы переводятся в контур, и по его границам
    ; (а не по строке шрифта с её пустыми полями) контур ставится в центр. Кегль — p.scale %
    ; высоты; если код не влезает по ширине, контур сжимается. Без фона — белые буквы
    ; с тёмной обводкой, иначе цвет букв контрастный к фону.
    static DrawCode(g, p, w, h) {
        bold := p.font = "Segoe UI"
        if DllCall("gdiplus\GdipCreateFontFamilyFromName", "str", p.font, "ptr", 0, "ptr*", &family := 0) != 0 {
            DllCall("gdiplus\GdipCreateFontFamilyFromName", "str", "Segoe UI", "ptr", 0, "ptr*", &family := 0)
            bold := true
        }
        DllCall("gdiplus\GdipCreateStringFormat", "int", 0x1000, "int", 0, "ptr*", &format := 0)      ; NoWrap
        DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &path := 0)
        layout := Buffer(16, 0)                                                                        ; 0×0 — без переносов и обрезки
        DllCall("gdiplus\GdipAddPathString", "ptr", path, "str", p.text, "int", -1, "ptr", family, "int", bold ? 1 : 0,
            "float", h * p.scale / 100, "ptr", layout, "ptr", format)
        b := Buffer(16)
        DllCall("gdiplus\GdipGetPathWorldBounds", "ptr", path, "ptr", b, "ptr", 0, "ptr", 0)
        bx := NumGet(b, 0, "float"), by := NumGet(b, 4, "float"), bw := NumGet(b, 8, "float"), bh := NumGet(b, 12, "float")
        k := bw > w * 0.86 ? w * 0.86 / bw : 1
        DllCall("gdiplus\GdipCreateMatrix2", "float", k, "float", 0, "float", 0, "float", k,
            "float", w / 2 - (bx + bw / 2) * k, "float", h / 2 - (by + bh / 2) * k, "ptr*", &m := 0)
        DllCall("gdiplus\GdipTransformPath", "ptr", path, "ptr", m)
        if p.bg = "none" {
            DllCall("gdiplus\GdipCreatePen1", "uint", 0xB0000000, "float", Max(1, h / 8), "int", 2, "ptr*", &pen := 0)
            DllCall("gdiplus\GdipSetPenLineJoin", "ptr", pen, "int", 2)   ; скруглённые стыки
            DllCall("gdiplus\GdipDrawPath", "ptr", g, "ptr", pen, "ptr", path)
            DllCall("gdiplus\GdipDeletePen", "ptr", pen)
        }
        DllCall("gdiplus\GdipCreateSolidFill", "uint", FlagOverlay.Ink(p.bg), "ptr*", &brush := 0)
        DllCall("gdiplus\GdipFillPath", "ptr", g, "ptr", brush, "ptr", path)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", brush)
        DllCall("gdiplus\GdipDeleteMatrix", "ptr", m)
        DllCall("gdiplus\GdipDeletePath", "ptr", path)
        DllCall("gdiplus\GdipDeleteStringFormat", "ptr", format)
        DllCall("gdiplus\GdipDeleteFontFamily", "ptr", family)
    }

    ; Цвет букв: тёмный на светлом фоне, белый на тёмном и без фона
    static Ink(bg) {
        if bg = "none"
            return 0xFFFFFFFF
        n := Integer("0x" SubStr(bg, 2))
        return 0.299 * (n >> 16) + 0.587 * (n >> 8 & 0xFF) + 0.114 * (n & 0xFF) > 160 ? 0xFF1D2430 : 0xFFFFFFFF
    }

    Image(code) {
        if !this.images.Has(code)
            this.images[code] := Gdip.LoadBitmap(this.flagsDir "\" code ".png")
        return this.images[code]
    }

    Render(p) {
        w := p.w, h := p.h
        hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
        ; BITMAPINFOHEADER, 32 бита, сверху вниз
        bi := Buffer(40, 0)
        NumPut("uint", 40, "int", w, "int", -h, "ushort", 1, "ushort", 32, bi)
        hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", 0, "ptr", 0, "uint", 0, "ptr")
        obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
        DllCall("gdiplus\GdipCreateFromHDC", "ptr", hdc, "ptr*", &g := 0)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", g, "int", 4)          ; AntiAlias
        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", g, "int", 7)      ; HighQualityBicubic
        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", g, "int", 4)        ; Half

        r := p.radius
        path := Gdip.RoundRectPath(0, 0, w, h, r)
        scaled := 0, brush := 0
        if p.flag != "" {
            ; Картинку сначала масштабируем в w×h, затем заливаем ею скруглённый контур —
            ; так углы сглажены (клип по контуру сглаживания не даёт).
            DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", 0, "int", 0xE200B, "ptr", 0, "ptr*", &scaled)
            DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", scaled, "ptr*", &sg := 0)
            DllCall("gdiplus\GdipSetInterpolationMode", "ptr", sg, "int", 7)
            DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", sg, "int", 4)
            DllCall("gdiplus\GdipDrawImageRectI", "ptr", sg, "ptr", this.Image(p.flag), "int", 0, "int", 0, "int", w, "int", h)
            DllCall("gdiplus\GdipDeleteGraphics", "ptr", sg)
            DllCall("gdiplus\GdipCreateTexture", "ptr", scaled, "int", 4, "ptr*", &brush := 0)   ; WrapModeClamp
            DllCall("gdiplus\GdipFillPath", "ptr", g, "ptr", brush, "ptr", path)
        } else {
            ; Текстовая плашка: подложка того же размера и формы (если есть фон) и код языка
            if p.bg != "none" {
                DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFF000000 | Integer("0x" SubStr(p.bg, 2)), "ptr*", &brush)
                DllCall("gdiplus\GdipFillPath", "ptr", g, "ptr", brush, "ptr", path)
            }
            FlagOverlay.DrawCode(g, p, w, h)
        }
        Gdip.DeletePath(path)

        ; Тонкая полупрозрачная рамка, чтобы белые полосы не терялись на белом фоне
        if p.flag != "" || p.bg != "none" {
            DllCall("gdiplus\GdipCreatePen1", "uint", 0x59000000, "float", 1, "int", 2, "ptr*", &pen := 0)
            border := Gdip.RoundRectPath(0.5, 0.5, w - 1, h - 1, Max(0, r - 0.5))
            DllCall("gdiplus\GdipDrawPath", "ptr", g, "ptr", pen, "ptr", border)
            Gdip.DeletePath(border)
            DllCall("gdiplus\GdipDeletePen", "ptr", pen)
        }

        pt := Buffer(8), size := Buffer(8), src := Buffer(8, 0), blend := Buffer(4)
        NumPut("int", p.x, "int", p.y, pt)
        NumPut("int", w, "int", h, size)
        ; BLENDFUNCTION: AC_SRC_OVER, 0, общая альфа, AC_SRC_ALPHA
        NumPut("uchar", 0, "uchar", 0, "uchar", p.alpha, "uchar", 1, blend)
        DllCall("UpdateLayeredWindow", "ptr", this.hwnd, "ptr", 0, "ptr", pt, "ptr", size,
            "ptr", hdc, "ptr", src, "uint", 0, "ptr", blend, "uint", 2)        ; ULW_ALPHA

        if brush
            DllCall("gdiplus\GdipDeleteBrush", "ptr", brush)
        if scaled
            Gdip.DisposeImage(scaled)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", g)
        DllCall("SelectObject", "ptr", hdc, "ptr", obm)
        DllCall("DeleteObject", "ptr", hbm)
        DllCall("DeleteDC", "ptr", hdc)
    }
}
