; Окно настроек: HTML-страница ui\settings.html в WebView2 внутри AHK-окна без рамки.
; Страница только показывает и меняет настройки; применяет и сохраняет их AHK.
;
; Страница -> AHK: строки, поля через табуляцию
;   ready                — страница загрузилась, пришлите состояние
;   set <путь> <значение> — изменить настройку (путь из SettingsFile.Fields)
;   autostart <1|0>      — включить или выключить автозапуск
;   size <w> <h>         — размер содержимого в CSS-пикселях, окно подстраивается
;   min | close          — кнопки заголовка
; AHK -> странице: JSON {type: "state", settings, autostart}
; Каждое изменение сразу применяется к app.settings и с короткой задержкой пишется в ini.

#Include ..\lib\WebView2\WebView2.ahk

class SettingsPage {
    static Texts := {
        title: "Language Indicator",
        noRuntime: "Для окна настроек нужен Microsoft Edge WebView2 Runtime. Он входит в Windows 10 и 11; если его нет, установите его с сайта Microsoft.`n`nИндикатор продолжает работать, настройки можно править в settings.ini.",
        autostartFailed: "Не удалось изменить автозапуск: для этого программа должна работать с правами администратора.",
    }
    static host := "app.language-indicator.example"
    static saveDelay := 400

    static gui := ""
    static wvc := ""
    static wv := ""
    static app := ""
    static onMessage := ""
    static saveFn := ""

    ; app: {settings, settingsPath, StartTimers()}
    static Open(app) {
        if SettingsPage.gui {
            WinActivate(SettingsPage.gui)
            return
        }
        SettingsPage.app := app
        g := Gui("-Caption +Border -DPIScale", SettingsPage.Texts.title)
        bg := SettingsPage.Background()
        g.BackColor := Format("{:06X}", bg)
        g.OnEvent("Close", (*) => SettingsPage.Close())
        g.OnEvent("Size", (*) => SettingsPage.wvc && SettingsPage.wvc.Fill())
        scale := SettingsPage.ScaleAtMouse()
        g.Show(Format("w{} h{}", Round(360 * scale), Round(560 * scale)))
        SettingsPage.gui := g
        try {
            wvc := WebView2.CreateControllerAsync(g.Hwnd, 0, A_AppData "\..\Local\LanguageIndicator\WebView2").await2()
        } catch {
            SettingsPage.gui := ""
            g.Destroy()
            MsgBox(SettingsPage.Texts.noRuntime, SettingsPage.Texts.title, "Icon!")
            return
        }
        SettingsPage.wvc := wvc
        ; COREWEBVIEW2_COLOR — байты A, R, G, B: фон до отрисовки страницы, без белой вспышки
        wvc.DefaultBackgroundColor := (bg & 0xFF) << 24 | (bg >> 8 & 0xFF) << 16 | (bg >> 16 & 0xFF) << 8 | 0xFF
        wv := wvc.CoreWebView2
        SettingsPage.wv := wv
        st := wv.Settings
        st.AreDevToolsEnabled := HasArg("/devtools")
        st.AreDefaultContextMenusEnabled := HasArg("/devtools")
        st.IsZoomControlEnabled := false
        st.IsStatusBarEnabled := false
        st.AreBrowserAcceleratorKeysEnabled := false
        ; Заголовок страницы с app-region: drag таскает окно. Свойство есть только в ICoreWebView2Settings9:
        ; на старом Runtime вызов по чужому слоту таблицы обрушил бы процесс, поэтому сначала спрашиваем интерфейс
        try {
            ComObjQuery(st, WebView2.Settings.IID_9)
            st.IsNonClientRegionSupportEnabled := true
        }
        wv.SetVirtualHostNameToFolderMapping(SettingsPage.host, A_ScriptDir, 1)
        SettingsPage.onMessage := wv.WebMessageReceived(ObjBindMethod(SettingsPage, "Receive"))
        SettingsPage.saveFn := ObjBindMethod(SettingsPage, "Save")
        wvc.Fill()
        wv.Navigate("https://" SettingsPage.host "/ui/settings.html")
    }

    static Close() {
        if !SettingsPage.gui
            return
        SettingsPage.Save()
        g := SettingsPage.gui, wvc := SettingsPage.wvc
        ; Сначала обнуляем ссылки: таймер или сообщение могли бы прийти в уничтожаемое окно
        SettingsPage.gui := SettingsPage.wvc := SettingsPage.wv := SettingsPage.onMessage := ""
        if wvc
            try wvc.Close()
        g.Destroy()
    }

    static Receive(sender, args) {
        parts := StrSplit(args.TryGetWebMessageAsString(), "`t")
        switch parts[1] {
            case "ready":
                SettingsPage.SendState()
            case "set":
                if parts.Length < 3 || !SettingsFile.Set(SettingsPage.app.settings, parts[2], parts[3]) {
                    SettingsPage.SendState()      ; отброшено — вернуть странице настоящее значение
                    return
                }
                if InStr(parts[2], "pollMs")
                    SettingsPage.app.StartTimers()
                SetTimer(SettingsPage.saveFn, -SettingsPage.saveDelay)
            case "autostart":
                if !Autostart.Set(parts[2] = "1")
                    MsgBox(SettingsPage.Texts.autostartFailed, SettingsPage.Texts.title, "Icon!")
                SettingsPage.SendState()
            case "size":
                SettingsPage.Resize(parts[2], parts[3])
            case "min":
                SettingsPage.gui.Minimize()
            case "close":
                ; Не из обработчика WebView2: Close уничтожает WebView2, который сейчас нас вызывает
                SetTimer(() => SettingsPage.Close(), -1)
        }
    }

    static SendState() {
        if SettingsPage.wv
            SettingsPage.wv.PostWebMessageAsJson(Json.Stringify({
                type: "state",
                settings: SettingsPage.app.settings,
                autostart: Autostart.IsEnabled(),
            }))
    }

    static Save() {
        SetTimer(SettingsPage.saveFn, 0)
        SettingsFile.Save(SettingsPage.app.settings, SettingsPage.app.settingsPath)
    }

    ; Размер окна по содержимому страницы; левый верхний угол остаётся на месте
    static Resize(cssW, cssH) {
        g := SettingsPage.gui
        scale := DllCall("GetDpiForWindow", "ptr", g.Hwnd, "uint") / 96
        WinGetPos(&x, &y, &w, &h, g)
        g.GetClientPos(, , &cw, &ch)
        WinMove(, , Round(cssW * scale) + w - cw, Round(cssH * scale) + h - ch, g)
    }

    ; Фон страницы (--bg в settings.css) для светлой или тёмной темы приложений Windows
    static Background() {
        light := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1)
        return light ? 0xE9EEF3 : 0x15181D
    }

    static ScaleAtMouse() {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        return MonitorProbe.DpiAt(mx, my) / 96
    }
}
