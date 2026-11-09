; Окно настроек без надписей: значки Segoe MDL2, текст — только во всплывающих подсказках.
; Изменения сразу применяются к app.settings, и флажки перерисовываются на лету. Пока окно
; активно, флажки показываются у образцов каретки и курсора в сетках выбора стороны.
; ✓ сохраняет в ini и включает/выключает автозапуск; ✕, Esc и закрытие окна — откат из ini.

class SettingsWindow {
    ; Все тексты окна — здесь
    static Texts := {
        title: "Language Indicator",
        caretShow: "Флажок у каретки",
        mouseShow: "Флажок у текстового курсора мыши",
        caretIcon: "Каретка — место ввода текста",
        mouseIcon: "Курсор мыши «I» над текстом",
        side: "Поставить флажок сюда",
        caretSize: "Размер флажка у каретки",
        mouseSize: "Размер флажка у мыши",
        caretGap: "Отступ флажка от каретки",
        mouseGap: "Отступ флажка от курсора",
        opacity: "Непрозрачность флажков",
        fullscreen: "Прятать флажки в полноэкранных приложениях (игры, видео)",
        autostart: "Запускать вместе с Windows",
        ok: "Сохранить",
        advanced: "Дополнительно: раскладки, поиск каретки, опрос, размер по высоте каретки",
        cancel: "Отменить изменения",
        autostartFailed: "Не удалось изменить автозапуск: для этого программа должна работать с правами администратора.",
    }

    static Glyphs := {
        caret: 0xE8AC, mouse: 0xE962, size: 0xE8E9, gap: 0xE799, opacity: 0xE793,
        fullscreen: 0xE740, autostart: 0xE7E8, ok: 0xE73E, cancel: 0xE711, flag: 0xE7C1, advanced: 0xE713,
    }

    ; Сетка 3×3: сторона -> [строка, столбец]; центр — образец каретки или курсора
    static Grid := Map(
        "top-left", [0, 0], "top", [0, 1], "top-right", [0, 2],
        "left", [1, 0], "right", [1, 2],
        "bottom-left", [2, 0], "bottom", [2, 1], "bottom-right", [2, 2],
    )

    static gui := ""
    static app := ""
    static tips := Map()        ; hwnd контрола -> подсказка
    static cells := Map()       ; "caret" / "mouse" -> Map(сторона -> Text)
    static anchors := Map()     ; "caret" / "mouse" -> образец, у которого показывается флажок
    static tipHwnd := 0
    static hideTipTimer := ""
    static slides := Map()      ; hwnd ползунка -> функция применения значения
    static scrollFn := ""
    static mouseMoveFn := ""
    static autostartBox := ""

    ; app: {settings, settingsPath}
    static Open(app) {
        if SettingsWindow.gui {
            SettingsWindow.gui.Show()
            return
        }
        SettingsWindow.app := app
        s := app.settings
        T := SettingsWindow.Texts
        g := Gui("+AlwaysOnTop -MinimizeBox", T.title)
        g.BackColor := "FFFFFF"
        g.OnEvent("Close", (*) => SettingsWindow.Cancel())
        g.OnEvent("Escape", (*) => SettingsWindow.Cancel())
        SettingsWindow.gui := g
        SettingsWindow.tips := Map()
        SettingsWindow.slides := Map()

        SettingsWindow.Card(g, "caret", s.caret, 12)
        SettingsWindow.Card(g, "mouse", s.mouse, 232)

        ; Общие настройки
        y := 286
        SettingsWindow.Icon(g, "opacity", 20, y, 14, T.opacity)
        sl := g.AddSlider(Format("x48 y{} w170 h28 Range10-100 ToolTip NoTicks", y - 2), s.opacity)
        SettingsWindow.OnSlide(sl, v => s.opacity := v, T.opacity)
        SettingsWindow.Toggle(g, "fullscreen", 250, y, s.hideFullscreen, v => s.hideFullscreen := v, T.fullscreen)
        SettingsWindow.autostartBox := SettingsWindow.Toggle(g, "autostart", 340, y, Autostart.IsEnabled(), v => 0, T.autostart)

        ; Шестерёнка, ✓ и ✕
        g.SetFont("s12", "Segoe MDL2 Assets")
        adv := g.AddButton("x16 y334 w52 h34", Chr(SettingsWindow.Glyphs.advanced))
        adv.OnEvent("Click", (*) => AdvancedWindow.Open(SettingsWindow.app, SettingsWindow.gui))
        SettingsWindow.tips[adv.Hwnd] := T.advanced
        ok := g.AddButton("x324 y334 w52 h34 Default", Chr(SettingsWindow.Glyphs.ok))
        ok.OnEvent("Click", (*) => SettingsWindow.Ok())
        SettingsWindow.tips[ok.Hwnd] := T.ok
        cancel := g.AddButton("x384 y334 w52 h34", Chr(SettingsWindow.Glyphs.cancel))
        cancel.OnEvent("Click", (*) => SettingsWindow.Cancel())
        SettingsWindow.tips[cancel.Hwnd] := T.cancel

        OnMessage(0x200, SettingsWindow.mouseMoveFn := ObjBindMethod(SettingsWindow, "OnMouseMove"))
        g.Show("w452 h382")
        ok.Focus()
    }

    ; Карточка индикатора: значок, вкл/выкл, сетка стороны с образцом в центре, размер, отступ
    static Card(g, kind, s, ox) {
        T := SettingsWindow.Texts
        oy := 10, w := 208
        SettingsWindow.Icon(g, kind, ox + 14, oy + 18, 16, T.%kind "Icon"%)
        g.SetFont("s9", "Segoe UI")
        box := g.AddCheckbox(Format("x{} y{} w18 h20 Checked{}", ox + w - 34, oy + 24, s.enabled ? 1 : 0))
        box.OnEvent("Click", (c, *) => s.enabled := c.Value)
        SettingsWindow.tips[box.Hwnd] := T.%kind "Show"%

        ; Сетка 3×3 (SS_NOTIFY 0x100: без него статик прозрачен для мыши и клик уходит рамке)
        cw := 44, ch := 36, gx := ox + (w - 3 * cw) // 2, gy := oy + 60
        cells := Map()
        g.SetFont("s11 cFFFFFF", "Segoe MDL2 Assets")
        for side, rc in SettingsWindow.Grid {
            cell := g.AddText(Format("x{} y{} w{} h{} +Border +Center +0x200 +0x100", gx + rc[2] * cw, gy + rc[1] * ch, cw - 2, ch - 2))
            cell.OnEvent("Click", SettingsWindow.SideClick.Bind(SettingsWindow, kind, s, side))
            SettingsWindow.tips[cell.Hwnd] := T.side
            cells[side] := cell
        }
        SettingsWindow.cells[kind] := cells
        SettingsWindow.PaintCells(kind, s.side)

        ; Образец в центральной клетке: у каретки — тонкая чёрная полоска, у мыши — «I»
        cx := gx + cw, cy := gy + ch
        if kind = "caret" {
            anchor := g.AddText(Format("x{} y{} w2 h22 +Background000000", cx + cw // 2 - 2, cy + (ch - 24) // 2))
        } else {
            g.SetFont("s15 c000000", "Consolas")
            anchor := g.AddText(Format("x{} y{} w12 h24 +Center", cx + (cw - 14) // 2, cy + (ch - 26) // 2), "I")
        }
        SettingsWindow.anchors[kind] := anchor

        ; Размер и отступ
        y := oy + 186
        SettingsWindow.Icon(g, "size", ox + 12, y, 13, T.%kind "Size"%)
        sl := g.AddSlider(Format("x{} y{} w{} h28 Range8-40 ToolTip NoTicks", ox + 40, y - 2, w - 52), s.size)
        SettingsWindow.OnSlide(sl, v => s.size := v, T.%kind "Size"%)
        y += 36
        SettingsWindow.Icon(g, "gap", ox + 12, y, 13, T.%kind "Gap"%)
        sl := g.AddSlider(Format("x{} y{} w{} h28 Range0-20 ToolTip NoTicks", ox + 40, y - 2, w - 52), s.gap)
        SettingsWindow.OnSlide(sl, v => s.gap := v, T.%kind "Gap"%)
        ; Рамка — последней: иначе она выше клеток по порядку окон и перехватывает клики
        g.AddGroupBox(Format("x{} y{} w{} h264", ox, oy, w))
    }

    static Icon(g, name, x, y, size, tip) {
        g.SetFont("s" size " c404040", "Segoe MDL2 Assets")
        icon := g.AddText(Format("x{} y{} w{} h{} +Center", x, y, size * 2 + 4, size * 2), Chr(SettingsWindow.Glyphs.%name%))
        SettingsWindow.tips[icon.Hwnd] := tip
        return icon
    }

    ; Галка со значком вместо подписи
    static Toggle(g, name, x, y, value, apply, tip) {
        g.SetFont("s14 c404040", "Segoe MDL2 Assets")
        box := g.AddCheckbox(Format("x{} y{} w52 h28 Checked{}", x, y - 2, value ? 1 : 0), Chr(SettingsWindow.Glyphs.%name%))
        box.OnEvent("Click", (c, *) => apply(c.Value))
        SettingsWindow.tips[box.Hwnd] := tip
        return box
    }

    ; Ползунок применяет значение и при перетаскивании, и при отпускании
    static OnSlide(sl, apply, tip) {
        sl.OnEvent("Change", (c, *) => apply(c.Value))
        SettingsWindow.slides[sl.Hwnd] := apply
        SettingsWindow.tips[sl.Hwnd] := tip
        if !SettingsWindow.scrollFn
            OnMessage(0x114, SettingsWindow.scrollFn := ObjBindMethod(SettingsWindow, "OnScroll"))   ; WM_HSCROLL
    }

    static OnScroll(wParam, lParam, msg, hwnd) {
        if SettingsWindow.slides.Has(lParam)
            SettingsWindow.slides[lParam](SendMessage(0x400, 0, 0, lParam))                     ; TBM_GETPOS
    }

    static SideClick(kind, s, side, *) {
        s.side := side
        SettingsWindow.PaintCells(kind, side)
    }

    static PaintCells(kind, selected) {
        for side, cell in SettingsWindow.cells[kind] {
            on := side = selected
            cell.Opt(on ? "+Background0078D7" : "+BackgroundF2F2F2")
            cell.Value := on ? Chr(SettingsWindow.Glyphs.flag) : ""
            cell.Redraw()
        }
    }

    static OnMouseMove(wParam, lParam, msg, hwnd) {
        if !SettingsWindow.gui
            return
        tip := SettingsWindow.tips.Has(hwnd) ? SettingsWindow.tips[hwnd] : ""
        if hwnd = SettingsWindow.tipHwnd
            return
        SettingsWindow.tipHwnd := hwnd
        if tip = "" {
            ToolTip()
            return
        }
        ToolTip(tip)
        if !SettingsWindow.hideTipTimer
            SettingsWindow.hideTipTimer := ObjBindMethod(SettingsWindow, "HideTipWhenAway")
        SetTimer(SettingsWindow.hideTipTimer, 250)
    }

    ; Подсказка гаснет, когда мышь ушла с контрола с подсказкой
    static HideTipWhenAway() {
        MouseGetPos(, , , &under, 2)
        if under != SettingsWindow.tipHwnd {
            ToolTip()
            SettingsWindow.tipHwnd := 0
            SetTimer(, 0)
        }
    }

    ; Прямоугольник образца на экране, пока окно настроек активно, иначе ""
    static PreviewAnchor(kind) {
        g := SettingsWindow.gui
        adv := AdvancedWindow.gui
        ; Окно могут уничтожить между тиками — тогда .Hwnd бросает «Gui has no window»
        try {
            if !g || !(WinActive("ahk_id " g.Hwnd) || adv && WinActive("ahk_id " adv.Hwnd))
                return ""
            anchor := SettingsWindow.anchors[kind].Hwnd
        } catch
            return ""
        r := Buffer(16)
        DllCall("GetWindowRect", "ptr", anchor, "ptr", r)
        return {x: NumGet(r, 0, "int"), y: NumGet(r, 4, "int"),
            w: NumGet(r, 8, "int") - NumGet(r, 0, "int"), h: NumGet(r, 12, "int") - NumGet(r, 4, "int")}
    }

    static Ok() {
        app := SettingsWindow.app
        SettingsFile.Save(app.settings, app.settingsPath)
        want := SettingsWindow.autostartBox.Value
        if want != Autostart.IsEnabled() && !Autostart.Set(want)
            MsgBox(SettingsWindow.Texts.autostartFailed, SettingsWindow.Texts.title, "Icon! 0x40000")
        SettingsWindow.Close()
    }

    static Cancel() {
        app := SettingsWindow.app
        app.settings := SettingsFile.Load(app.settingsPath)
        SettingsWindow.Close()
        app.StartTimers()
    }

    static Close() {
        ; Ссылку обнуляем до Destroy: тик таймера между строками не должен увидеть уничтоженное окно
        g := SettingsWindow.gui
        SettingsWindow.gui := ""
        AdvancedWindow.Close()
        OnMessage(0x200, SettingsWindow.mouseMoveFn, 0)
        ToolTip()
        SettingsWindow.tipHwnd := 0
        g.Destroy()
    }
}
