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
        if !IsObject(p) || p.flag = "" {
            this.Hide()
            return
        }
        look := p.flag "|" p.w "|" p.h "|" p.alpha
        if look != this.look {
            this.Render(p)
            this.look := look
        } else if p.x != this.x || p.y != this.y {
            ; SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
            DllCall("SetWindowPos", "ptr", this.hwnd, "ptr", 0, "int", p.x, "int", p.y, "int", 0, "int", 0, "uint", 0x15)
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

        ; Картинку сначала масштабируем в w×h, затем заливаем ею скруглённый контур —
        ; так углы сглажены (клип по контуру сглаживания не даёт).
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", 0, "int", 0xE200B, "ptr", 0, "ptr*", &scaled := 0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", scaled, "ptr*", &sg := 0)
        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", sg, "int", 7)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", sg, "int", 4)
        DllCall("gdiplus\GdipDrawImageRectI", "ptr", sg, "ptr", this.Image(p.flag), "int", 0, "int", 0, "int", w, "int", h)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", sg)
        DllCall("gdiplus\GdipCreateTexture", "ptr", scaled, "int", 4, "ptr*", &brush := 0)   ; WrapModeClamp

        r := Max(1, Round(h / 6))
        path := Gdip.RoundRectPath(0, 0, w, h, r)
        DllCall("gdiplus\GdipFillPath", "ptr", g, "ptr", brush, "ptr", path)
        Gdip.DeletePath(path)

        ; Тонкая полупрозрачная рамка, чтобы белые полосы не терялись на белом фоне
        DllCall("gdiplus\GdipCreatePen1", "uint", 0x59000000, "float", 1, "int", 2, "ptr*", &pen := 0)
        border := Gdip.RoundRectPath(0.5, 0.5, w - 1, h - 1, r)
        DllCall("gdiplus\GdipDrawPath", "ptr", g, "ptr", pen, "ptr", border)
        Gdip.DeletePath(border)

        pt := Buffer(8), size := Buffer(8), src := Buffer(8, 0), blend := Buffer(4)
        NumPut("int", p.x, "int", p.y, pt)
        NumPut("int", w, "int", h, size)
        ; BLENDFUNCTION: AC_SRC_OVER, 0, общая альфа, AC_SRC_ALPHA
        NumPut("uchar", 0, "uchar", 0, "uchar", p.alpha, "uchar", 1, blend)
        DllCall("UpdateLayeredWindow", "ptr", this.hwnd, "ptr", 0, "ptr", pt, "ptr", size,
            "ptr", hdc, "ptr", src, "uint", 0, "ptr", blend, "uint", 2)        ; ULW_ALPHA

        DllCall("gdiplus\GdipDeletePen", "ptr", pen)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", brush)
        Gdip.DisposeImage(scaled)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", g)
        DllCall("SelectObject", "ptr", hdc, "ptr", obm)
        DllCall("DeleteObject", "ptr", hbm)
        DllCall("DeleteDC", "ptr", hdc)
    }
}
