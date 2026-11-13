# language-indicator

Индикатор раскладки на AutoHotkey v2: флажок текущего языка у каретки и у курсора мыши (IBEAM), окно настроек.

Спека — issue #1, тикеты — его sub-issues.

## Запуск и тесты

AutoHotkey v2 стоит в `C:\Program Files\AutoHotkey\v2`.

```bash
"/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" LanguageIndicator.ahk               # сам поднимает права (UAC)
"/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" LanguageIndicator.ahk /no-elevate   # без UAC, для отладки
MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" LanguageIndicator.ahk /no-elevate /settings   # сразу открыть окно настроек (+ /devtools — инструменты разработчика)
MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tests/run.ahk | cat   # тесты, код выхода 0 = всё прошло
```

Останавливать индикатор — штатно, как пункт «Выход» в трее (WM_COMMAND 65405 скрытому окну AHK). `Stop-Process`/`taskkill /F` оставляют в трее значок-призрак до наведения мыши.

```ahk
DetectHiddenWindows(true)
PostMessage(0x111, 65405, 0, , "LanguageIndicator.ahk ahk_class AutoHotkey")
```

В Git Bash ключи вида `/ErrorStdOut` без `MSYS_NO_PATHCONV=1` превращаются в путь, и AHK повисает с диалогом ошибки.

Ловушки AHK v2:
- Имена не чувствительны к регистру: параметр `caret` перекрывает функцию `Caret()`, свойство `App.tick` конфликтует с методом `App.Tick()`. Называй их по-разному.
- `DllCall("lib\Func")` для ещё не загруженной DLL загружает её на время вызова и сразу выгружает. Если вызов вернул COM-объект или указатель внутрь этой DLL (oleacc!), сначала сделай `LoadLibrary`, иначе — «Invalid memory read/write».
- Таймеры прерывают код между строками: закрывая окно, сначала обнуляй ссылку на него, потом `Destroy()`, иначе тик обратится к уничтоженному окну («Gui has no window»).
- Макросы WinAPI (`ImageList_RemoveAll`) — не функции DLL: вызывай то, во что они раскрываются (`ImageList_Remove(il, -1)`).
- WebView2 (`lib/WebView2/WebView2.ahk`): свойства новых интерфейсов (`Settings9` и т. п.) вызываются по слоту таблицы — на старом Runtime это падение процесса. Сначала `ComObjQuery(obj, IID_n)` в `try`. Цвет `DefaultBackgroundColor` — байты A, R, G, B (альфа только 0 или 255), иначе E_INVALIDARG. Не уничтожай WebView2 из его же обработчика события — отложи через `SetTimer(..., -1)`.
- `/ErrorStdOut` выводит только ошибки загрузки; ошибка во время работы открывает диалог, и процесс висит. Если индикатор «молчит», ищи окно `#32770` у его процесса.

## Устройство

- `src/Core.ahk` — ядро: чистая функция «снимок → размещения» (`Core.Decide`), маппинг раскладки, расчёт позиции. Системы не трогает, всё покрыто тестами.
- `src/Settings.ahk` — значения по умолчанию и `settings.ini`; простые настройки описаны таблицей `SettingsFile.Fields` (чтение, запись и изменение из окна) рядом со скриптом (UTF-16, в `.gitignore`; создаётся при первом запуске). Негодные значения заменяются значениями по умолчанию; `[Layouts]` — переопределения флага и кода по полному HKL.
- `src/Locale.ahk` — справочник локалей Windows (LANGID → страна/язык); детерминирован, используется в тестах.
- `src/Probes.ahk` — адаптеры: раскладка активного окна, каретка, DPI монитора. Без логики решений.
- `src/SettingsPage.ahk` + `ui/` — окно настроек: HTML-страница в WebView2 (`lib/WebView2`, thqby/ahk2_lib, MIT; `WebView2Loader.dll` из NuGet Microsoft.Web.WebView2). Страница шлёт строки `set<Tab>путь<Tab>значение`, AHK применяет через `SettingsFile.Set` и сразу пишет ini; AHK отдаёт состояние JSON-ом (`src/Json.ahk`). `ui/settings.html` открывается и в обычном браузере — на образце состояния, для вёрстки.
- `ui/settings.js` — вся страница: основная колонка плиток (каретка/мышь, флаг или код, предпросмотр, размер, отступ, автозапуск, непрозрачность, «О проекте») и правая панель «Дополнительно» (общие, флажок и код, раскладки с галереей флагов, каретка, мышь). Тексты — в словаре `T` (RU, EN; остальные языки показывают английский). Каждое изменение сразу уходит в AHK и пишется в ini, кнопок сохранения нет.
- `src/Autostart.ahk` — задача Планировщика из XML (наивысшие права, без лимита времени); создаётся только из процесса администратора.
- `src/Overlay.ahk`, `src/Gdip.ahk` — окно-слой с флажком (GDI+, попиксельная альфа). Код языка рисуется контуром букв и центрируется по границам контура, а не по строке шрифта.
- `flags/` — flag-icons (MIT) 4:3, отрендерены из SVG в PNG 96×72.
- Координаты — физические пиксели: поток работает в режиме per-monitor DPI v2.

## Agent skills

### Issue tracker

Задачи и спеки — в GitHub Issues репо Xpom/language-indicator (через `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Стандартные метки: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` и `docs/adr/` в корне. See `docs/agents/domain.md`.
