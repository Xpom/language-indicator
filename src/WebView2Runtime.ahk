; Открытая замена WebView2Loader.dll: находит установленный WebView2 Runtime и создаёт окружение
; его же функцией. Повторяет то, что делает загрузчик Microsoft для установленного (не встроенного)
; Runtime стабильного канала; логика сверена с OpenWebView2Loader (jchv, ISC).
class WebView2Runtime {
    ; Ключ EdgeUpdate стабильного канала WebView2 Runtime; значение EBWebView — папка версии
    static clientState := "\Microsoft\EdgeUpdate\ClientState\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
    static fnPtr := 0

    ; Папка установленного Runtime: сначала установка для пользователя, потом для всех
    static Folder() {
        for key in ["HKCU\Software" WebView2Runtime.clientState, "HKLM\SOFTWARE\WOW6432Node" WebView2Runtime.clientState] {
            dir := RegRead(key, "EBWebView", "")
            if dir != "" && FileExist(WebView2Runtime.ClientDll(dir))
                return dir
        }
        return ""
    }

    static ClientDll(dir) => dir "\EBWebView\" (A_PtrSize = 8 ? "x64" : "x86") "\EmbeddedBrowserWebView.dll"

    ; Адрес функции с сигнатурой CreateCoreWebView2EnvironmentWithOptions — его принимает
    ; WebView2.CreateControllerAsync вместо пути к WebView2Loader.dll. Без Runtime — исключение.
    static CreateFn() {
        if WebView2Runtime.fnPtr
            return WebView2Runtime.fnPtr
        dir := WebView2Runtime.Folder()
        if dir = ""
            throw Error("WebView2 Runtime не установлен")
        ; Библиотека остаётся загруженной: окружение живёт внутри неё
        lib := DllCall("LoadLibrary", "str", WebView2Runtime.ClientDll(dir), "ptr")
        internal := lib ? DllCall("GetProcAddress", "ptr", lib, "astr", "CreateWebViewEnvironmentWithOptionsInternal", "ptr") : 0
        if !internal
            throw Error("WebView2 Runtime не загрузился: " dir)
        ; (папка браузера, папка данных, параметры, обработчик) → внутренняя функция:
        ; (проверять запущенный экземпляр = true, тип = установленный Runtime, папка данных, параметры, обработчик)
        create(browserFolder, dataDir, options, handler) =>
            DllCall(internal, "int", 1, "int", 0, "ptr", dataDir, "ptr", options, "ptr", WebView2Runtime.Wrap(handler), "int")
        return WebView2Runtime.fnPtr := CallbackCreate(create, , 4)
    }

    ; Runtime запрашивает у обработчика его интерфейс через QueryInterface, а обработчики
    ; lib/WebView2 на любой запрос отвечают E_NOINTERFACE. Обёртка отвечает честно и передаёт
    ; результат исходному обработчику — как EnvironmentCreatedRetryHandler в загрузчике Microsoft.
    static wrappers := []
    static Wrap(handler) {
        static vtbl := 0
        if !vtbl {
            vtbl := Buffer(4 * A_PtrSize)
            NumPut("ptr", CallbackCreate(QueryInterface, , 3), "ptr", CallbackCreate(Ref, , 1),
                "ptr", CallbackCreate(Ref, , 1), "ptr", CallbackCreate(Invoke, , 3), vtbl)
        }
        ComCall(1, handler, "uint")                 ; AddRef: исходный обработчик живёт до Invoke
        obj := Buffer(2 * A_PtrSize)
        NumPut("ptr", vtbl.Ptr, "ptr", handler, obj)
        ; Обёртки не освобождаются: Runtime может вызвать Release и после Invoke, а их всего по одной на окно
        WebView2Runtime.wrappers.Push(obj)
        return obj.Ptr

        QueryInterface(this, riid, ppv) {
            DllCall("ole32\StringFromGUID2", "ptr", riid, "ptr", buf := Buffer(78), "int", 39)
            iid := StrGet(buf)
            ; IUnknown и ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler
            if iid = "{00000000-0000-0000-C000-000000000046}" || iid = "{4E8A3389-C9D8-4BD2-B6B5-124FEE6CC14D}" {
                NumPut("ptr", this, ppv)
                return 0
            }
            NumPut("ptr", 0, ppv)
            return 0x80004002
        }
        Ref(this) => 1
        Invoke(this, result, env) {
            handler := NumGet(this, A_PtrSize, "ptr")
            ComCall(3, handler, "int", result, "ptr", env, "int")
            ComCall(2, handler, "uint")             ; Release
            return 0
        }
    }
}
