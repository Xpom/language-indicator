; Обновления: проверка последнего релиза на GitHub, сообщение «Доступна vX», установка.
; Решение «что делать» — чистая функция Updater.Decide (покрыта тестами); остальное — сеть и система.
;
; Релиз засчитывается, только если release.json подписан ключом Release.publicKey и его версия
; совпадает с тегом. Установщик ставится, только если его размер и SHA-256 совпали с release.json.
class Updater {
    static api := "https://api.github.com/repos/Xpom/language-indicator/releases/latest"
    static firstCheckMs := 60 * 1000
    static checkEveryMs := 24 * 3600 * 1000
    static idleNeedMs := 5 * 60 * 1000

    static Texts := {
        available: "Доступна версия {}. Нажмите, чтобы открыть, что нового.",
        updated: "Обновлено до версии {}. Нажмите, чтобы открыть, что нового.",
        title: "Language Indicator",
    }

    static app := ""
    static hooks := ""          ; {changed: () — состояние сменилось, settingsOpen: () → открыто ли окно настроек}
    ; status: idle | checking | current | available | downloading | installing | error
    static state := {status: "idle", version: "", notesUrl: "", error: ""}
    static found := ""          ; {version, notesUrl, files: Map(вид → {name, size, sha256}), urls: Map(имя → адрес)}
    static startupCheck := true  ; первый найденный релиз после запуска ставится, не дожидаясь простоя
    static trayUrl := ""

    ; Что делать с найденным релизом.
    ; s: {current, available, auto, portable, admin, idleMs, startup, settingsOpen, notified, busy}
    ; none — ничего; notify — сообщить в трее; install — ставить сейчас; wait — ставить позже (простой).
    static Decide(s) {
        if s.busy || s.available = "" || Release.Compare(s.available, s.current) <= 0
            return "none"
        ; Сами ставим только установленную программу с автообновлением и правами администратора:
        ; иначе установщик спросил бы UAC, пока человека нет за компьютером
        if s.portable || !s.auto || !s.admin
            return s.notified = s.available ? "none" : "notify"
        if s.settingsOpen
            return "wait"
        return s.startup || s.idleMs >= Updater.idleNeedMs ? "install" : "wait"
    }

    static Start(app, hooks) {
        Updater.app := app, Updater.hooks := hooks
        OnMessage(0x404, (wParam, lParam, *) => Updater.TrayClick(lParam))
        Updater.ShowUpdated()
        SetTimer(() => Updater.Check(), -Updater.firstCheckMs)
        SetTimer(() => Updater.Check(), Updater.checkEveryMs)
        SetTimer(() => Updater.Apply(), 60 * 1000)     ; ждём простоя для автообновления
    }

    static Portable() => !A_IsCompiled || FileExist(A_ScriptDir "\portable")

    ; Версия выросла с прошлого запуска — значит, только что обновились
    static ShowUpdated() {
        s := Updater.app.settings, v := Updater.app.version
        if s.update.lastRunVersion = v
            return
        if s.update.lastRunVersion != "" && Release.Compare(v, s.update.lastRunVersion) > 0
            Updater.Tray(Format(Updater.Texts.updated, v), "https://github.com/Xpom/language-indicator/releases/tag/v" v)
        s.update.lastRunVersion := v
        SettingsFile.Save(s, Updater.app.settingsPath)
    }

    static Check() {
        if Updater.state.status ~= "^(checking|downloading|installing)$"
            return
        Updater.SetState("checking")
        feed := Updater.app.settings.update.feed || Updater.api
        Http.Get(feed, (ok, status, body) => Updater.OnLatest(ok, body))
    }

    static OnLatest(ok, body) {
        if !ok
            return Updater.SetState("error", , "net")
        try {
            j := Json.Parse(StrGet(body, "UTF-8"))
            tag := j["tag_name"], notes := j["html_url"]
            urls := Map()
            for a in j["assets"]
                urls[a["name"]] := a["browser_download_url"]
        } catch
            return Updater.SetState("error", , "format")
        version := RegExReplace(tag, "^v")
        if Release.Compare(version, Updater.app.version) <= 0
            return Updater.SetState("current")
        if !urls.Has("release.json") || !urls.Has("release.json.sig")
            return Updater.SetState("error", , "format")
        Http.Get(urls["release.json"], (ok1, s1, data) =>
            Http.Get(urls["release.json.sig"], (ok2, s2, sig) => Updater.OnManifest(ok1 && ok2, data, sig, version, notes, urls)))
    }

    static OnManifest(ok, data, sig, version, notes, urls) {
        if !ok
            return Updater.SetState("error", , "net")
        if !Release.Verify(data, sig)
            return Updater.SetState("error", , "signature")
        try r := Release.Parse(StrGet(data, "UTF-8"))
        catch
            return Updater.SetState("error", , "format")
        if r.version != version
            return Updater.SetState("error", , "signature")
        Updater.found := {version: version, notesUrl: notes, files: r.files, urls: urls}
        Updater.SetState("available", version, , notes)
        Updater.Apply()
    }

    ; Решить и сделать: сообщить, поставить или подождать
    static Apply() {
        f := Updater.found, s := Updater.app.settings
        action := Updater.Decide({
            current: Updater.app.version, available: f ? f.version : "",
            auto: s.autoUpdate, portable: Updater.Portable(), admin: A_IsAdmin,
            idleMs: A_TimeIdlePhysical, startup: Updater.startupCheck,
            settingsOpen: (Updater.hooks.settingsOpen)(), notified: s.update.notifiedVersion,
            busy: Updater.state.status ~= "^(downloading|installing)$",
        })
        if f
            Updater.startupCheck := false
        switch action {
            case "notify":
                Updater.Tray(Format(Updater.Texts.available, f.version), f.notesUrl)
                s.update.notifiedVersion := f.version
                SettingsFile.Save(s, Updater.app.settingsPath)
            case "install":
                Updater.Install()
        }
    }

    ; Скачать установщик, сверить с release.json и запустить в тихом режиме.
    ; Установщик сам штатно закроет индикатор (/quit) и запустит новую версию.
    static Install() {
        f := Updater.found
        if !f || Updater.Portable() || !f.files.Has("setup") || !f.urls.Has(f.files["setup"].name)
            return
        if Updater.state.status ~= "^(downloading|installing)$"
            return
        setup := f.files["setup"]
        Updater.SetState("downloading", f.version, , f.notesUrl)
        Http.Get(f.urls[setup.name], (ok, status, body) => Updater.OnSetup(ok, body, setup), 10 * 60 * 1000)
    }

    static OnSetup(ok, body, setup) {
        f := Updater.found
        if !ok
            return Updater.SetState("error", f.version, "net", f.notesUrl)
        if body.Size != setup.size || Release.Sha256(body) != setup.sha256
            return Updater.SetState("error", f.version, "signature", f.notesUrl)
        dir := A_Temp "\LanguageIndicator\update"
        path := dir "\" setup.name
        try {
            DirCreate(dir)
            file := FileOpen(path, "w")
            file.RawWrite(body)
            file.Close()
            Updater.SetState("installing", f.version, , f.notesUrl)
            Run((A_IsAdmin ? "" : "*RunAs ") '"' path '" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART')
        } catch
            Updater.SetState("error", f.version, "install", f.notesUrl)
    }

    static SetState(status, version := Updater.state.version, error := "", notesUrl := Updater.state.notesUrl) {
        Updater.state := {status: status, version: version, notesUrl: notesUrl, error: error}
        (Updater.hooks.changed)()
    }

    ; Сообщение в трее; клик по нему открывает url
    static Tray(text, url) {
        Updater.trayUrl := url
        TrayTip(text, Updater.Texts.title, "Iconi")
    }

    static TrayClick(lParam) {
        if (lParam & 0xFFFF) = 0x405 && Updater.trayUrl != ""     ; NIN_BALLOONUSERCLICK
            Run(Updater.trayUrl)
    }
}
