; Минимальная обёртка GDI+: старт, загрузка картинок, скруглённый прямоугольник.

class Gdip {
    static token := 0

    static Startup() {
        if Gdip.token
            return
        DllCall("LoadLibrary", "str", "gdiplus", "ptr")
        ; GdiplusStartupInput: версия 1, остальное по нулям
        si := Buffer(8 + 2 * A_PtrSize, 0)
        NumPut("uint", 1, si)
        if DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", si, "ptr", 0) != 0
            throw OSError("GdiplusStartup")
        Gdip.token := token
    }

    static Shutdown() {
        if Gdip.token
            DllCall("gdiplus\GdiplusShutdown", "ptr", Gdip.token)
        Gdip.token := 0
    }

    ; GpBitmap* из файла или 0
    static LoadBitmap(path) {
        bmp := 0
        DllCall("gdiplus\GdipCreateBitmapFromFile", "str", path, "ptr*", &bmp)
        return bmp
    }

    static ImageSize(img) {
        DllCall("gdiplus\GdipGetImageWidth", "ptr", img, "uint*", &w := 0)
        DllCall("gdiplus\GdipGetImageHeight", "ptr", img, "uint*", &h := 0)
        return {w: w, h: h}
    }

    static DisposeImage(img) => img && DllCall("gdiplus\GdipDisposeImage", "ptr", img)

    ; Замкнутый контур скруглённого прямоугольника (радиус r; 0 — прямые углы) — GpPath*
    static RoundRectPath(x, y, w, h, r) {
        DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &path := 0)
        if r <= 0 {
            DllCall("gdiplus\GdipAddPathRectangle", "ptr", path, "float", x, "float", y, "float", w, "float", h)
            return path
        }
        d := Min(2 * r, w, h)
        DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", x, "float", y, "float", d, "float", d, "float", 180, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", x + w - d, "float", y, "float", d, "float", d, "float", 270, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", x + w - d, "float", y + h - d, "float", d, "float", d, "float", 0, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", x, "float", y + h - d, "float", d, "float", d, "float", 90, "float", 90)
        DllCall("gdiplus\GdipClosePathFigure", "ptr", path)
        return path
    }

    static DeletePath(path) => DllCall("gdiplus\GdipDeletePath", "ptr", path)
}
