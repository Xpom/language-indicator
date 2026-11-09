; Адаптеры к системе: только чтение состояния, без решений.
; Координаты — физические пиксели (поток в режиме per-monitor DPI v2).

class LayoutProbe {
    ; HKL раскладки активного окна (младшие 32 бита), 0 если окна нет
    static Foreground() {
        hwnd := DllCall("GetForegroundWindow", "ptr")
        if !hwnd
            return 0
        tid := DllCall("GetWindowThreadProcessId", "ptr", hwnd, "ptr", 0, "uint")
        return DllCall("GetKeyboardLayout", "uint", tid, "ptr") & 0xFFFFFFFF
    }
}

class CaretProbe {
    ; Каретка Win32 активного окна: {x, y, w, h} на экране или ""
    static Win32() {
        hwnd := DllCall("GetForegroundWindow", "ptr")
        if !hwnd
            return ""
        tid := DllCall("GetWindowThreadProcessId", "ptr", hwnd, "ptr", 0, "uint")
        ; GUITHREADINFO: cbSize, flags, 6 HWND (последний — hwndCaret), RECT rcCaret
        gti := Buffer(8 + 6 * A_PtrSize + 16, 0)
        NumPut("uint", gti.Size, gti)
        if !DllCall("GetGUIThreadInfo", "uint", tid, "ptr", gti)
            return ""
        hwndCaret := NumGet(gti, 8 + 5 * A_PtrSize, "ptr")
        if !hwndCaret
            return ""
        rc := 8 + 6 * A_PtrSize
        left := NumGet(gti, rc, "int"), top := NumGet(gti, rc + 4, "int")
        right := NumGet(gti, rc + 8, "int"), bottom := NumGet(gti, rc + 12, "int")
        if bottom <= top
            return ""
        pt := Buffer(8)
        NumPut("int", left, "int", top, pt)
        if !DllCall("ClientToScreen", "ptr", hwndCaret, "ptr", pt)
            return ""
        return {x: NumGet(pt, 0, "int"), y: NumGet(pt, 4, "int"), w: Max(right - left, 1), h: bottom - top}
    }
}

class CursorProbe {
    static ibeam := DllCall("LoadCursor", "ptr", 0, "ptr", 32513, "ptr")   ; IDC_IBEAM
    static shapes := Map()   ; HCURSOR -> {hotX, hotY, box: {x, y, w, h} | ""} — box в координатах картинки

    ; {ibeam, hot: {x, y}, glyph: {x, y, w, h} на экране | ""}
    static Current() {
        ; CURSORINFO: cbSize, flags, hCursor, POINT
        ci := Buffer(16 + A_PtrSize, 0)
        NumPut("uint", ci.Size, ci)
        if !DllCall("GetCursorInfo", "ptr", ci)
            return ""
        flags := NumGet(ci, 4, "uint")
        hCursor := NumGet(ci, 8, "ptr")
        x := NumGet(ci, 8 + A_PtrSize, "int"), y := NumGet(ci, 12 + A_PtrSize, "int")
        if !(flags & 1) || hCursor != CursorProbe.ibeam   ; CURSOR_SHOWING
            return {ibeam: false, hot: {x: x, y: y}, glyph: ""}
        shape := CursorProbe.Shape(hCursor)
        glyph := IsObject(shape.box)
            ? {x: x - shape.hotX + shape.box.x, y: y - shape.hotY + shape.box.y, w: shape.box.w, h: shape.box.h}
            : ""
        return {ibeam: true, hot: {x: x, y: y}, glyph: glyph}
    }

    static Shape(hCursor) {
        if CursorProbe.shapes.Has(hCursor)
            return CursorProbe.shapes[hCursor]
        shape := {hotX: 0, hotY: 0, box: ""}
        ; ICONINFO: fIcon, xHotspot, yHotspot, hbmMask, hbmColor
        ii := Buffer(8 + 3 * A_PtrSize, 0)
        if DllCall("GetIconInfo", "ptr", hCursor, "ptr", ii) {
            shape.hotX := NumGet(ii, 4, "uint"), shape.hotY := NumGet(ii, 8, "uint")
            maskOfs := A_PtrSize = 8 ? 16 : 12
            hbmMask := NumGet(ii, maskOfs, "ptr"), hbmColor := NumGet(ii, maskOfs + A_PtrSize, "ptr")
            try shape.box := CursorProbe.VisibleBox(hbmMask, hbmColor)
            if hbmMask
                DllCall("DeleteObject", "ptr", hbmMask)
            if hbmColor
                DllCall("DeleteObject", "ptr", hbmColor)
        }
        CursorProbe.shapes[hCursor] := shape
        return shape
    }

    ; Границы видимых пикселей курсора. Монохромный курсор: маска двойной высоты
    ; (сверху AND, снизу XOR), пиксель виден, если AND = 0 или XOR ≠ 0.
    ; Цветной: по альфе цветной картинки, а если альфы нет — по AND-маске.
    static VisibleBox(hbmMask, hbmColor) {
        mask := CursorProbe.Pixels(hbmMask)
        if !IsObject(mask)
            return ""
        mono := !hbmColor
        w := mask.w, h := mono ? mask.h // 2 : mask.h
        color := hbmColor ? CursorProbe.Pixels(hbmColor) : ""
        useAlpha := false
        if IsObject(color)
            Loop color.w * color.h
                if NumGet(color.buf, (A_Index - 1) * 4, "uint") >> 24 {
                    useAlpha := true
                    break
                }
        minX := w, minY := h, maxX := -1, maxY := -1
        Loop h {
            y := A_Index - 1
            Loop w {
                x := A_Index - 1
                andOn := NumGet(mask.buf, (y * w + x) * 4, "uint") & 0xFFFFFF
                if mono
                    visible := !andOn || NumGet(mask.buf, ((y + h) * w + x) * 4, "uint") & 0xFFFFFF
                else if useAlpha
                    visible := NumGet(color.buf, (y * w + x) * 4, "uint") >> 24
                else
                    visible := !andOn
                if visible {
                    minX := Min(minX, x), maxX := Max(maxX, x)
                    minY := Min(minY, y), maxY := Max(maxY, y)
                }
            }
        }
        return maxX < 0 ? "" : {x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1}
    }

    ; Пиксели битмапа как 32 бита сверху вниз: {w, h, buf} или ""
    static Pixels(hbm) {
        bm := Buffer(16 + 2 * A_PtrSize, 0)   ; BITMAP
        if !DllCall("GetObject", "ptr", hbm, "int", bm.Size, "ptr", bm)
            return ""
        w := NumGet(bm, 4, "int"), h := NumGet(bm, 8, "int")
        bi := Buffer(40 + 256 * 4, 0)   ; BITMAPINFO с запасом под палитру
        NumPut("uint", 40, "int", w, "int", -h, "ushort", 1, "ushort", 32, bi)
        buf := Buffer(w * h * 4, 0)
        hdc := DllCall("GetDC", "ptr", 0, "ptr")
        lines := DllCall("GetDIBits", "ptr", hdc, "ptr", hbm, "uint", 0, "uint", h, "ptr", buf, "ptr", bi, "uint", 0, "int")
        DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)
        return lines ? {w: w, h: h, buf: buf} : ""
    }
}

class MonitorProbe {
    ; DPI монитора, на котором точка (x, y); 96 = 100%
    static DpiAt(x, y) {
        hmon := DllCall("MonitorFromPoint", "int64", (y << 32) | (x & 0xFFFFFFFF), "uint", 2, "ptr")
        if DllCall("shcore\GetDpiForMonitor", "ptr", hmon, "int", 0, "uint*", &dpiX := 0, "uint*", &dpiY := 0) != 0
            return 96
        return dpiX
    }
}
