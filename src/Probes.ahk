; Адаптеры к системе: только чтение состояния, без решений.
; Координаты — физические пиксели (поток в режиме per-monitor DPI v2).

class LayoutProbe {
    ; HKL раскладки активного окна (младшие 32 бита), 0 если окна нет
    static Foreground() {
        hwnd := DllCall("GetForegroundWindow", "ptr")
        if !hwnd
            return 0
        ; Консоль (conhost): у окна подставной поток клиента (cmd, powershell), и раскладка
        ; для него — 0 или устаревшая. Настоящий поток окна (conhost) знает его окно IME.
        if WinGetClass(hwnd) = "ConsoleWindowClass" {
            ime := DllCall("imm32\ImmGetDefaultIMEWnd", "ptr", hwnd, "ptr")
            hwnd := ime ? ime : hwnd
        }
        tid := DllCall("GetWindowThreadProcessId", "ptr", hwnd, "ptr", 0, "uint")
        return DllCall("GetKeyboardLayout", "uint", tid, "ptr") & 0xFFFFFFFF
    }
}

; Владеющая ссылка на COM-интерфейс: Release при уничтожении. Годится для ComCall.
class ComPtr {
    __New(p) => this.Ptr := p
    __Delete() => this.Ptr && ObjRelease(this.Ptr)
}

Guid(s) {
    b := Buffer(16)
    DllCall("ole32\CLSIDFromString", "str", s, "ptr", b)
    return b
}

class CaretProbe {
    ; Каретка активного окна цепочкой Win32 → MSAA → UIA: {x, y, w, h} на экране или "".
    ; methods — {win32, msaa, uia}: какие способы включены.
    static Find(methods) {
        if methods.win32 && IsObject(c := CaretProbe.Win32())
            return c
        if methods.msaa && IsObject(c := CaretProbe.Msaa())
            return c
        if methods.uia && IsObject(c := CaretProbe.Uia())
            return c
        return ""
    }

    ; GUITHREADINFO потока активного окна: cbSize, flags, 6 HWND, RECT rcCaret — или ""
    static GuiThreadInfo() {
        hwnd := DllCall("GetForegroundWindow", "ptr")
        if !hwnd
            return ""
        tid := DllCall("GetWindowThreadProcessId", "ptr", hwnd, "ptr", 0, "uint")
        gti := Buffer(8 + 6 * A_PtrSize + 16, 0)
        NumPut("uint", gti.Size, gti)
        return DllCall("GetGUIThreadInfo", "uint", tid, "ptr", gti) ? gti : ""
    }

    ; Окно с фокусом ввода, а если его не узнать — активное окно
    static FocusWindow() {
        gti := CaretProbe.GuiThreadInfo()
        focus := IsObject(gti) ? NumGet(gti, 8 + A_PtrSize, "ptr") : 0
        return focus ? focus : DllCall("GetForegroundWindow", "ptr")
    }

    ; Системная каретка (Win32): Блокнот, WordPad, Проводник, диалоги
    static Win32() {
        gti := CaretProbe.GuiThreadInfo()
        if !IsObject(gti)
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

    ; Каретка через MSAA (OBJID_CARET): Chromium и Electron отдают её для экранных луп
    static Msaa() {
        static IID_IAccessible := Guid("{618736E0-3C3D-11CF-810C-00AA00389B71}")
        ; DllCall("oleacc\...") выгружает DLL сразу после вызова, а объект живёт на её коде — держим загруженной
        static oleacc := DllCall("LoadLibrary", "str", "oleacc", "ptr")
        hwnd := CaretProbe.FocusWindow()
        if !hwnd
            return ""
        p := 0
        if DllCall("oleacc\AccessibleObjectFromWindow", "ptr", hwnd, "uint", 0xFFFFFFF8, "ptr", IID_IAccessible, "ptr*", &p) != 0 || !p
            return ""
        acc := ComPtr(p)
        child := Buffer(24, 0)          ; VARIANT VT_I4 = CHILDID_SELF
        NumPut("ushort", 3, child)
        l := t := w := h := 0
        try ComCall(22, acc, "int*", &l, "int*", &t, "int*", &w, "int*", &h, "ptr", child)   ; accLocation
        catch
            return ""
        return h > 0 ? {x: l, y: t, w: Max(w, 1), h: h} : ""
    }

    ; Каретка через UI Automation: элемент с фокусом → TextPattern2.GetCaretRange
    ; (или TextPattern.GetSelection) → прямоугольник диапазона.
    static Uia() {
        uia := CaretProbe.UiaClient()
        if !uia
            return ""
        try {
            ComCall(8, uia, "ptr*", &p := 0)            ; GetFocusedElement
            if !p
                return ""
            range := CaretProbe.UiaCaretRange(ComPtr(p))
            return IsObject(range) ? CaretProbe.UiaCaretRect(range) : ""
        } catch
            return ""
    }

    static uiaInstance := ""

    static UiaClient() {
        if CaretProbe.uiaInstance = "" {
            client := 0
            try client := ComObject("{e22ad333-b25f-460c-83d0-0581107395c9}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")  ; CUIAutomation8
            catch
                try client := ComObject("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")  ; CUIAutomation
            CaretProbe.uiaInstance := client
            ScreenReaderFlag.Enable()
        }
        return CaretProbe.uiaInstance
    }

    static UiaCaretRange(el) {
        static IID_TextPattern2 := Guid("{506a921a-fcc9-409f-b23b-37eb74106872}")
        static IID_TextPattern := Guid("{32eba289-3583-42c9-9c59-3b6d9a1e9b6a}")
        p := 0
        try ComCall(14, el, "int", 10024, "ptr", IID_TextPattern2, "ptr*", &p)   ; GetCurrentPatternAs
        if p {
            tp := ComPtr(p)
            ComCall(10, tp, "int*", &active := 0, "ptr*", &r := 0)               ; GetCaretRange
            if r
                return active ? ComPtr(r) : (ObjRelease(r), "")
        }
        p := 0
        try ComCall(14, el, "int", 10014, "ptr", IID_TextPattern, "ptr*", &p)
        if !p
            return ""
        tp := ComPtr(p)
        ComCall(5, tp, "ptr*", &a := 0)                                           ; GetSelection
        if !a
            return ""
        ranges := ComPtr(a)
        ComCall(3, ranges, "int*", &n := 0)                                       ; get_Length
        if !n
            return ""
        ComCall(4, ranges, "int", 0, "ptr*", &r := 0)                             ; GetElement
        return r ? ComPtr(r) : ""
    }

    ; У пустого диапазона каретки прямоугольников обычно нет — тогда расширяем
    ; на символ вправо и берём его левый край, а в конце текста — влево и правый край.
    static UiaCaretRect(range) {
        rects := CaretProbe.UiaRects(range)
        if rects.Length
            return {x: rects[1].x, y: rects[1].y, w: 1, h: rects[1].h}
        for dir in [1, -1] {
            ComCall(3, range, "ptr*", &c := 0)                                    ; Clone
            probe := ComPtr(c)
            ; MoveEndpointByUnit(End/Start, TextUnit_Character, ±1)
            ComCall(14, probe, "int", dir = 1 ? 1 : 0, "int", 0, "int", dir, "int*", &moved := 0)
            if !moved
                continue
            rects := CaretProbe.UiaRects(probe)
            if rects.Length {
                r := dir = 1 ? rects[1] : rects[rects.Length]
                return {x: dir = 1 ? r.x : r.x + r.w, y: r.y, w: 1, h: r.h}
            }
        }
        return ""
    }

    ; GetBoundingRectangles: SAFEARRAY из double по четыре (left, top, width, height)
    static UiaRects(range) {
        out := []
        ComCall(10, range, "ptr*", &psa := 0)
        if !psa
            return out
        DllCall("oleaut32\SafeArrayGetUBound", "ptr", psa, "uint", 1, "int*", &ub := 0)
        DllCall("oleaut32\SafeArrayAccessData", "ptr", psa, "ptr*", &data := 0)
        Loop (ub + 1) // 4 {
            o := (A_Index - 1) * 32
            r := {x: Round(NumGet(data, o, "double")), y: Round(NumGet(data, o + 8, "double")),
                w: Round(NumGet(data, o + 16, "double")), h: Round(NumGet(data, o + 24, "double"))}
            if r.h > 0
                out.Push(r)
        }
        DllCall("oleaut32\SafeArrayUnaccessData", "ptr", psa)
        DllCall("oleaut32\SafeArrayDestroy", "ptr", psa)
        return out
    }
}

; Флаг «работает программа чтения экрана»: без него Chromium и Electron не включают
; доступность и UIA не видит их текст. Ставим один раз, на выходе возвращаем как было.
class ScreenReaderFlag {
    static Enable() {
        DllCall("SystemParametersInfo", "uint", 0x46, "uint", 0, "int*", &was := 0, "uint", 0)   ; SPI_GETSCREENREADER
        if was
            return
        DllCall("SystemParametersInfo", "uint", 0x47, "uint", 1, "ptr", 0, "uint", 2)   ; SPI_SETSCREENREADER, SPIF_SENDCHANGE
        OnExit((*) => DllCall("SystemParametersInfo", "uint", 0x47, "uint", 0, "ptr", 0, "uint", 2))
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

class FullscreenProbe {
    ; Монитор {x, y, w, h}, который целиком занят активным окном без заголовка (игра, видео,
    ; браузер по F11), или "". Развёрнутое обычное окно с заголовком не считается.
    static Foreground() {
        hwnd := DllCall("GetForegroundWindow", "ptr")
        if !hwnd
            return ""
        try {
            cls := WinGetClass(hwnd)
            style := WinGetStyle(hwnd)
        } catch
            return ""
        if cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd"   ; рабочий стол и панель задач
            return ""
        if (style & 0x00C00000) = 0x00C00000                               ; WS_CAPTION
            return ""
        wr := Buffer(16)
        DllCall("GetWindowRect", "ptr", hwnd, "ptr", wr)
        hmon := DllCall("MonitorFromWindow", "ptr", hwnd, "uint", 2, "ptr")
        mi := Buffer(40, 0)                                                ; MONITORINFO
        NumPut("uint", 40, mi)
        if !DllCall("GetMonitorInfo", "ptr", hmon, "ptr", mi)
            return ""
        ml := NumGet(mi, 4, "int"), mt := NumGet(mi, 8, "int"), mr := NumGet(mi, 12, "int"), mb := NumGet(mi, 16, "int")
        if NumGet(wr, 0, "int") <= ml && NumGet(wr, 4, "int") <= mt && NumGet(wr, 8, "int") >= mr && NumGet(wr, 12, "int") >= mb
            return {x: ml, y: mt, w: mr - ml, h: mb - mt}
        return ""
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
