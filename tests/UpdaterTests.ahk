; Тесты решения об обновлении (Updater.Decide).

; Установленная программа с автообновлением и правами, человек работает, окно настроек закрыто
UpdState(over := {}) {
    s := {current: "0.1.0", available: "0.2.0", auto: true, portable: false, admin: true,
        idleMs: 0, startup: false, settingsOpen: false, notified: "", busy: false}
    for k, v in over.OwnProps()
        s.%k% := v
    return s
}

Test("Обновление: новой версии нет", (*) => AssertEq(Updater.Decide(UpdState({available: ""})), "none"))
Test("Обновление: та же версия", (*) => AssertEq(Updater.Decide(UpdState({available: "0.1.0"})), "none"))
Test("Обновление: релиз старше программы", (*) => AssertEq(Updater.Decide(UpdState({current: "0.3.0"})), "none"))
Test("Обновление: 0.10.0 новее 0.9.0", (*) => AssertEq(Updater.Decide(UpdState({current: "0.9.0", available: "0.10.0", startup: true})), "install"))

Test("Автообновление: при запуске — ставить", (*) => AssertEq(Updater.Decide(UpdState({startup: true})), "install"))
Test("Автообновление: человек печатает — ждать", (*) => AssertEq(Updater.Decide(UpdState({idleMs: 30000})), "wait"))
Test("Автообновление: 5 минут простоя — ставить", (*) => AssertEq(Updater.Decide(UpdState({idleMs: 300000})), "install"))
Test("Автообновление: открыто окно настроек — ждать", (*) => AssertEq(Updater.Decide(UpdState({idleMs: 600000, settingsOpen: true})), "wait"))
Test("Автообновление: уже скачивается — ничего", (*) => AssertEq(Updater.Decide(UpdState({startup: true, busy: true})), "none"))

Test("Без автообновления: сообщить", (*) => AssertEq(Updater.Decide(UpdState({auto: false})), "notify"))
Test("Без автообновления: уже сообщали об этой версии", (*) => AssertEq(Updater.Decide(UpdState({auto: false, notified: "0.2.0"})), "none"))
Test("Без автообновления: сообщали о прошлой — сообщить снова", (*) => AssertEq(Updater.Decide(UpdState({auto: false, notified: "0.1.5"})), "notify"))
Test("Портабельная: только сообщить", (*) => AssertEq(Updater.Decide(UpdState({portable: true, startup: true})), "notify"))
Test("Без прав администратора: только сообщить", (*) => AssertEq(Updater.Decide(UpdState({admin: false, startup: true})), "notify"))
