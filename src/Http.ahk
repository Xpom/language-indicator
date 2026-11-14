; Асинхронный HTTP GET без блокировки потока: таймеры флажков продолжают работать, пока идёт запрос.
; ServerXMLHTTP (WinHTTP), а не XMLHTTP (WinINet): ассеты релиза GitHub перенаправляет на другой домен
; (release-assets.githubusercontent.com), и XMLHTTP такой переход запрещает — Access is denied.
class Http {
    ; done(ok, status, body) вызывается один раз; body — Buffer с телом ответа (при ошибке пустой)
    static Get(url, done, timeoutMs := 60000) {
        body := Buffer(0)
        try {
            req := ComObject("MSXML2.ServerXMLHTTP.6.0")
            req.open("GET", url, true)
            req.setRequestHeader("Cache-Control", "no-cache")
            req.setRequestHeader("User-Agent", "LanguageIndicator")    ; без него GitHub API отвечает 403
            req.setRequestHeader("Accept", "application/vnd.github+json, */*")
            req.send()
        } catch {
            done(false, 0, body)
            return
        }
        start := A_TickCount
        poll() {
            try state := req.readyState
            catch
                state := -1
            if state = 4 {
                SetTimer(poll, 0)
                status := 0
                try status := req.status
                if status = 200 {
                    try body := Http.Bytes(req.responseBody)
                    catch
                        status := 0
                }
                done(status = 200, status, body)
            } else if state = -1 || A_TickCount - start > timeoutMs {
                SetTimer(poll, 0)
                try req.abort()
                done(false, 0, body)
            }
        }
        SetTimer(poll, 100)
    }

    ; SAFEARRAY байтов (responseBody) → Buffer
    static Bytes(arr) {
        n := arr.MaxIndex() + 1
        buf := Buffer(n)
        if n > 0 {
            psa := ComObjValue(arr)
            DllCall("oleaut32\SafeArrayAccessData", "ptr", psa, "ptr*", &p := 0)
            DllCall("RtlMoveMemory", "ptr", buf, "ptr", p, "uptr", n)
            DllCall("oleaut32\SafeArrayUnaccessData", "ptr", psa)
        }
        return buf
    }
}
