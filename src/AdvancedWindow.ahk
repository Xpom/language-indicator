; Окно «Дополнительно» (шестерёнка в окне настроек): переопределения раскладок, способы поиска
; каретки, частота опроса, режим размера флажка у каретки. Здесь тексты допустимы.
; Изменения сразу применяются к app.settings, а сохраняются или откатываются кнопками ✓ / ✕
; основного окна настроек.

class AdvancedWindow {
    static Texts := {
        title: "Language Indicator — дополнительно",
        layouts: "Раскладки: флаг и код для каждой (пустое поле — как обычно)",
        colLayout: "Раскладка", colFlag: "Флаг", colCode: "Код", colSource: "",
        sourceOwn: "своё",
        noFlag: "—",
        code: "Код:",
        pickFlag: "Выбрать флаг…",
        withoutFlag: "Без флага",
        reset: "Как обычно",
        caret: "Поиск каретки (по порядку, пока не найдётся):",
        win32: "Win32", msaa: "MSAA", uia: "UI Automation",
        poll: "Опрос каретки и раскладки, мс:",
        size: "Размер флажка у каретки:",
        sizeFixed: "фиксированный — как в окне настроек",
        sizeCaret: "по высоте каретки:",
        sizeRatio: "% от высоты, от",
        sizeTo: "до",
        sizePx: "px",
        close: "Закрыть",
        picker: "Флаг для раскладки",
    }

    static gui := ""
    static app := ""
    static list := ""           ; ListView раскладок
    static rows := []           ; номер строки -> {hkl, name}
    static selected := 0        ; HKL выбранной раскладки
    static listImages := 0      ; ImageList 24×18 для таблицы
    static pickerImages := 0    ; ImageList 48×36 всех флагов — строится один раз
    static pickerCodes := []
    static picker := ""
    static preview := ""        ; картинка флага выбранной раскладки
    static code := ""           ; поле кода выбранной раскладки

    ; app: {settings, hasFlagFn, StartTimers}; owner — окно настроек
    static Open(app, owner) {
        if AdvancedWindow.gui {
            AdvancedWindow.gui.Show()
            return
        }
        AdvancedWindow.app := app
        s := app.settings
        T := AdvancedWindow.Texts
        g := Gui("+Owner" owner.Hwnd " -MinimizeBox", T.title)
        g.SetFont("s9", "Segoe UI")
        g.OnEvent("Close", (*) => AdvancedWindow.Close())
        g.OnEvent("Escape", (*) => AdvancedWindow.Close())
        AdvancedWindow.gui := g

        ; Раскладки
        g.AddText("xm w540", T.layouts)
        lv := g.AddListView("xm w540 r5 -Multi +Grid +LV0x10000 +0x40", [T.colLayout, T.colFlag, T.colCode, T.colSource])   ; LVS_EX_DOUBLEBUFFER
        AdvancedWindow.list := lv
        AdvancedWindow.listImages := DllCall("comctl32\ImageList_Create", "int", 24, "int", 18, "uint", 0x20, "int", 8, "int", 8, "ptr")
        lv.SetImageList(AdvancedWindow.listImages, 1)
        lv.OnEvent("ItemSelect", (ctl, row, selected) => selected && AdvancedWindow.Select(row))
        AdvancedWindow.rows := LayoutList.Installed()

        AdvancedWindow.preview := g.AddPicture("xm y+8 w48 h36 +Border")
        g.AddText("x+12 yp+9", T.code)
        AdvancedWindow.code := g.AddEdit("x+6 yp-3 w60 Limit4")
        AdvancedWindow.code.OnEvent("Change", (c, *) => AdvancedWindow.SetOverride(, Trim(c.Value)))
        g.AddButton("x+12 yp-1 w120", T.pickFlag).OnEvent("Click", (*) => AdvancedWindow.OpenPicker())
        g.AddButton("x+6 w100", T.withoutFlag).OnEvent("Click", (*) => AdvancedWindow.SetOverride("-"))
        g.AddButton("x+6 w100", T.reset).OnEvent("Click", (*) => AdvancedWindow.ResetOverride())

        ; Способы поиска каретки
        m := s.caret.methods
        g.AddText("xm y+20", T.caret)
        for name in ["win32", "msaa", "uia"] {
            box := g.AddCheckbox((A_Index = 1 ? "xm+12 y+6" : "x+20 yp") " Checked" (m.%name% ? 1 : 0), T.%name%)
            box.OnEvent("Click", AdvancedWindow.SetMethod.Bind(AdvancedWindow, name))
        }

        ; Частота опроса
        g.AddText("xm y+18", T.poll)
        g.AddEdit("x+8 yp-3 w64 Number")
        g.AddUpDown("Range15-1000 0x80", s.pollMs).OnEvent("Change", (c, *) => AdvancedWindow.SetPoll(c.Value))   ; UDS_NOTHOUSANDS

        ; Размер флажка у каретки
        c := s.caret
        g.AddText("xm y+18", T.size)
        fixed := g.AddRadio("xm+12 y+6 Group" (c.sizeMode = "fixed" ? " Checked" : ""), T.sizeFixed)
        fixed.OnEvent("Click", (*) => c.sizeMode := "fixed")
        byCaret := g.AddRadio("xm+12 y+8" (c.sizeMode = "caret" ? " Checked" : ""), T.sizeCaret)
        byCaret.OnEvent("Click", (*) => c.sizeMode := "caret")
        AdvancedWindow.Number(g, "x+6 yp-3", c.sizeRatio, 20, 200, v => c.sizeRatio := v)
        g.AddText("x+6 yp+3", T.sizeRatio)
        AdvancedWindow.Number(g, "x+6 yp-3", c.sizeMin, 6, 64, v => c.sizeMin := Min(v, c.sizeMax))
        g.AddText("x+6 yp+3", T.sizeTo)
        AdvancedWindow.Number(g, "x+6 yp-3", c.sizeMax, 6, 64, v => c.sizeMax := Max(v, c.sizeMin))
        g.AddText("x+6 yp+3", T.sizePx)

        g.AddButton("xm+440 y+20 w100 Default", T.close).OnEvent("Click", (*) => AdvancedWindow.Close())

        AdvancedWindow.Refresh()
        lv.ModifyCol(1, 300), lv.ModifyCol(2, 80), lv.ModifyCol(3, 60), lv.ModifyCol(4, "AutoHdr")
        if AdvancedWindow.rows.Length {
            lv.Modify(1, "Select Focus")
            AdvancedWindow.Select(1)    ; ItemSelect при программном выделении приходит не всегда
        }
        AdvancedWindow.ShowBeside(g, owner)
    }

    ; Рядом с окном настроек, а не поверх: там образцы с флажками живого предпросмотра
    static ShowBeside(g, owner) {
        g.Show("Hide")
        owner.GetPos(&ox, &oy, &ow)
        g.GetPos(, , &w)
        MonitorGetWorkArea(MonitorProbe.IndexAt(ox, oy), &left, , &right)
        x := ox + ow + 8 + w <= right ? ox + ow + 8 : Max(left, ox - w - 8)
        g.Show(Format("x{} y{}", x, oy))
    }

    ; Поле с цифрами и стрелками; apply получает значение при каждом изменении
    static Number(g, pos, value, lo, hi, apply) {
        g.AddEdit(pos " w52 Number")
        ud := g.AddUpDown(Format("Range{}-{}", lo, hi), value)
        ud.OnEvent("Change", (c, *) => apply(c.Value))
        return ud
    }

    static SetMethod(name, box, *) => AdvancedWindow.app.settings.caret.methods.%name% := box.Value

    static SetPoll(v) {
        AdvancedWindow.app.settings.pollMs := v
        AdvancedWindow.app.StartTimers()
    }

    ; Перерисовать таблицу: действующие флаг и код каждой раскладки с учётом переопределений
    static Refresh() {
        app := AdvancedWindow.app
        lv := AdvancedWindow.list
        layouts := app.settings.layouts
        DllCall("comctl32\ImageList_Remove", "ptr", AdvancedWindow.listImages, "int", -1)   ; -1 — удалить все
        lv.Opt("-Redraw")
        lv.Delete()
        for r in AdvancedWindow.rows {
            ind := Core.MapLayout(r.hkl, app.hasFlagFn, layouts)
            icon := ind.flag != "" ? AdvancedWindow.AddImage(AdvancedWindow.listImages, ind.flag, 24, 18) + 1 : 9999
            lv.Add("Icon" icon, r.name, ind.flag != "" ? ind.flag : AdvancedWindow.Texts.noFlag, ind.text,
                layouts.Has(r.hkl) ? AdvancedWindow.Texts.sourceOwn : "")
        }
        lv.Opt("+Redraw")
        for i, r in AdvancedWindow.rows
            if r.hkl = AdvancedWindow.selected
                lv.Modify(i, "Select Focus")
        AdvancedWindow.ShowSelected()
    }

    ; Добавить картинку флага в ImageList, вернуть её номер (с нуля)
    static AddImage(il, code, w, h) {
        hbm := LoadPicture(A_ScriptDir "\flags\" code ".png", "w" w " h" h)
        i := DllCall("comctl32\ImageList_Add", "ptr", il, "ptr", hbm, "ptr", 0, "int")
        DllCall("DeleteObject", "ptr", hbm)
        return i
    }

    static Select(row) {
        AdvancedWindow.selected := AdvancedWindow.rows[row].hkl
        AdvancedWindow.ShowSelected()
    }

    ; Картинка и поле кода выбранной раскладки. В поле — своё значение, а действующее — подсказкой.
    static ShowSelected() {
        hkl := AdvancedWindow.selected
        if !hkl
            return
        app := AdvancedWindow.app
        layouts := app.settings.layouts
        ind := Core.MapLayout(hkl, app.hasFlagFn, layouts)
        if ind.flag != ""
            AdvancedWindow.preview.Value := "*w48 *h36 " A_ScriptDir "\flags\" ind.flag ".png"
        AdvancedWindow.preview.Visible := ind.flag != ""
        own := layouts.Has(hkl) ? layouts[hkl].text : ""
        if AdvancedWindow.code.Value != own
            AdvancedWindow.code.Value := own
        SendMessage(0x1501, 1, StrPtr(Core.MapLayout(hkl, app.hasFlagFn).text), AdvancedWindow.code)   ; EM_SETCUEBANNER
    }

    ; Изменить переопределение выбранной раскладки; не переданное поле остаётся как было
    static SetOverride(flag?, text?) {
        hkl := AdvancedWindow.selected
        if !hkl
            return
        layouts := AdvancedWindow.app.settings.layouts
        o := layouts.Has(hkl) ? layouts[hkl] : {flag: "", text: ""}
        if IsSet(flag)
            o.flag := flag
        if IsSet(text)
            o.text := text
        if o.flag = "" && o.text = ""
            layouts.Delete(hkl)
        else
            layouts[hkl] := o
        AdvancedWindow.Refresh()
    }

    static ResetOverride() {
        layouts := AdvancedWindow.app.settings.layouts
        if layouts.Has(AdvancedWindow.selected)
            layouts.Delete(AdvancedWindow.selected)
        AdvancedWindow.code.Value := ""
        AdvancedWindow.Refresh()
    }

    ; Сетка всех флагов: клик — назначить выбранной раскладке
    static OpenPicker() {
        if !AdvancedWindow.selected
            return
        if !AdvancedWindow.pickerImages {
            il := DllCall("comctl32\ImageList_Create", "int", 48, "int", 36, "uint", 0x20, "int", 300, "int", 16, "ptr")
            ; По коду, а не в порядке файлов: там «gb-eng.png» раньше «gb.png» (дефис меньше точки)
            codes := ""
            Loop Files A_ScriptDir "\flags\*.png"
                codes .= SubStr(A_LoopFileName, 1, -4) "`n"
            for code in StrSplit(Sort(RTrim(codes, "`n")), "`n") {
                AdvancedWindow.AddImage(il, code, 48, 36)
                AdvancedWindow.pickerCodes.Push(code)
            }
            AdvancedWindow.pickerImages := il
        }
        p := Gui("+Owner" AdvancedWindow.gui.Hwnd " -MinimizeBox", AdvancedWindow.Texts.picker)
        p.SetFont("s9", "Segoe UI")
        lv := p.AddListView("w640 h420 Icon -Multi +0x40")   ; LVS_SHAREIMAGELISTS: список общий, живёт дольше окна
        lv.SetImageList(AdvancedWindow.pickerImages, 0)
        for i, code in AdvancedWindow.pickerCodes
            lv.Add("Icon" i, code)
        lv.OnEvent("Click", AdvancedWindow.Pick.Bind(AdvancedWindow, p))
        p.OnEvent("Escape", (*) => AdvancedWindow.ClosePicker())
        p.OnEvent("Close", (*) => AdvancedWindow.ClosePicker())
        AdvancedWindow.picker := p
        p.Show()
    }

    static Pick(p, lv, row) {
        if !row
            return
        AdvancedWindow.SetOverride(AdvancedWindow.pickerCodes[row])
        AdvancedWindow.ClosePicker()
    }

    static ClosePicker() {
        if AdvancedWindow.picker
            AdvancedWindow.picker.Destroy()
        AdvancedWindow.picker := ""
    }

    static Close() {
        g := AdvancedWindow.gui
        if !g
            return
        AdvancedWindow.gui := ""        ; до Destroy — см. SettingsWindow.Close
        AdvancedWindow.ClosePicker()
        g.Destroy()
        AdvancedWindow.selected := 0
        DllCall("comctl32\ImageList_Destroy", "ptr", AdvancedWindow.listImages)
        AdvancedWindow.listImages := 0
    }
}
