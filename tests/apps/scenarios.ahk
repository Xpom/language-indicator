; Сценарии тестов по программам: одна программа — одна строка.
;   name    — имя в отчёте и в именах снимков
;   run     — команда запуска; window — окно, которое ждём активным (WinTitle)
;   exe     — процесс, который закрыть после сценария (иначе — запущенный pid)
;   prepare — что сделать перед набором (кликнуть в поле, открыть адресную строку…)
;   caret   — false, если флажка у каретки здесь быть не должно
;   settleMs — сколько ждать после появления окна (по умолчанию 1500)
; Браузеры открывают страницу с полем ввода в фокусе: data:-адрес, без сети.
TestPage := "data:text/html,<title>li-test</title><textarea autofocus style='width:90%25;height:200px'></textarea>"

Scenarios := [
    {name: "notepad", run: "notepad.exe", window: "ahk_exe Notepad.exe", exe: "Notepad.exe"},
    {name: "cmd", run: "cmd.exe", window: "ahk_exe cmd.exe", exe: "cmd.exe"},
    {name: "powershell", run: "powershell.exe", window: "ahk_exe powershell.exe", exe: "powershell.exe"},
    {name: "pwsh", run: "pwsh.exe", window: "ahk_exe pwsh.exe", exe: "pwsh.exe"},
    {name: "terminal", run: "wt.exe", window: "ahk_exe WindowsTerminal.exe", exe: "WindowsTerminal.exe", settleMs: 3000},
    {name: "explorer-address", run: "explorer.exe C:\Windows", window: "Windows ahk_class CabinetWClass",
        prepare: () => Send("!d"), settleMs: 2000},
    {name: "chrome", run: 'chrome.exe --no-first-run --no-default-browser-check "' TestPage '"',
        window: "li-test ahk_exe chrome.exe", exe: "chrome.exe", settleMs: 3000},
    {name: "chrome-address", run: 'chrome.exe --no-first-run --no-default-browser-check "' TestPage '"',
        window: "li-test ahk_exe chrome.exe", exe: "chrome.exe", settleMs: 3000, prepare: () => Send("^l")},
    {name: "edge", run: 'msedge.exe --no-first-run --no-default-browser-check "' TestPage '"',
        window: "li-test ahk_exe msedge.exe", exe: "msedge.exe", settleMs: 4000},
    {name: "firefox", run: 'firefox.exe "' TestPage '"', window: "li-test ahk_exe firefox.exe", exe: "firefox.exe", settleMs: 5000},
    {name: "notepad++", run: "notepad++.exe -multiInst -nosession", window: "ahk_exe notepad++.exe", exe: "notepad++.exe"},
    {name: "vscode", run: "code --new-window --disable-workspace-trust", window: "ahk_exe Code.exe", exe: "Code.exe",
        settleMs: 6000, prepare: () => Send("^n")},
    {name: "calculator", run: "calc.exe", window: "Calculator", exe: "CalculatorApp.exe", caret: false, settleMs: 3000},
]
