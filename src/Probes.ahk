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

class MonitorProbe {
    ; DPI монитора, на котором точка (x, y); 96 = 100%
    static DpiAt(x, y) {
        hmon := DllCall("MonitorFromPoint", "int64", (y << 32) | (x & 0xFFFFFFFF), "uint", 2, "ptr")
        if DllCall("shcore\GetDpiForMonitor", "ptr", hmon, "int", 0, "uint*", &dpiX := 0, "uint*", &dpiY := 0) != 0
            return 96
        return dpiX
    }
}
