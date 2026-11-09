# language-indicator

Индикатор раскладки на AutoHotkey v2: флажок текущего языка у каретки и у курсора мыши (IBEAM), окно настроек.

Спека — issue #1, тикеты — его sub-issues.

## Запуск и тесты

AutoHotkey v2 стоит в `C:\Program Files\AutoHotkey\v2`.

```bash
"/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" LanguageIndicator.ahk               # сам поднимает права (UAC)
"/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" LanguageIndicator.ahk /no-elevate   # без UAC, для отладки
"/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" LanguageIndicator.ahk /no-elevate /settings   # сразу открыть окно настроек
MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tests/run.ahk | cat   # тесты, код выхода 0 = всё прошло
```

В Git Bash ключи вида `/ErrorStdOut` без `MSYS_NO_PATHCONV=1` превращаются в путь, и AHK повисает с диалогом ошибки.

Ловушки AHK v2:
- Имена не чувствительны к регистру: параметр `caret` перекрывает функцию `Caret()`, свойство `App.tick` конфликтует с методом `App.Tick()`. Называй их по-разному.
- `DllCall("lib\Func")` для ещё не загруженной DLL загружает её на время вызова и сразу выгружает. Если вызов вернул COM-объект или указатель внутрь этой DLL (oleacc!), сначала сделай `LoadLibrary`, иначе — «Invalid memory read/write».
- Text-контрол без SS_NOTIFY (`+0x100`) прозрачен для мыши: клик уходит GroupBox под ним. GroupBox добавляй последним.
- Таймеры прерывают код между строками: закрывая окно, сначала обнуляй ссылку на него, потом `Destroy()`, иначе тик обратится к уничтоженному окну («Gui has no window»).
- Макросы WinAPI (`ImageList_RemoveAll`) — не функции DLL: вызывай то, во что они раскрываются (`ImageList_Remove(il, -1)`).
- `/ErrorStdOut` выводит только ошибки загрузки; ошибка во время работы открывает диалог, и процесс висит. Если индикатор «молчит», ищи окно `#32770` у его процесса.

## Устройство

- `src/Core.ahk` — ядро: чистая функция «снимок → размещения» (`Core.Decide`), маппинг раскладки, расчёт позиции. Системы не трогает, всё покрыто тестами.
- `src/Settings.ahk` — значения по умолчанию и `settings.ini` рядом со скриптом (UTF-16, в `.gitignore`; создаётся при первом запуске). Негодные значения заменяются значениями по умолчанию; `[Layouts]` — переопределения флага и кода по полному HKL.
- `src/Locale.ahk` — справочник локалей Windows (LANGID → страна/язык); детерминирован, используется в тестах.
- `src/Probes.ahk` — адаптеры: раскладка активного окна, каретка, DPI монитора. Без логики решений.
- `src/SettingsWindow.ahk` — окно настроек без надписей (значки Segoe MDL2, тексты собраны в `SettingsWindow.Texts`). Пока окно активно, флажки показываются у образцов в сетках — это живой предпросмотр; ✓ сохраняет ini, ✕ перечитывает его.
- `src/AdvancedWindow.ahk` — окно «Дополнительно» (шестерёнка): переопределения раскладок с сеткой флагов, способы поиска каретки, частота опроса, размер по высоте каретки. Тексты допустимы; сохранение и откат — кнопками основного окна.
- `src/Autostart.ahk` — задача Планировщика из XML (наивысшие права, без лимита времени); создаётся только из процесса администратора.
- `src/Overlay.ahk`, `src/Gdip.ahk` — окно-слой с флажком (GDI+, попиксельная альфа).
- `flags/` — flag-icons (MIT) 4:3, отрендерены из SVG в PNG 96×72.
- Координаты — физические пиксели: поток работает в режиме per-monitor DPI v2.

## Agent skills

### Issue tracker

Задачи и спеки — в GitHub Issues репо Xpom/language-indicator (через `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Стандартные метки: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` и `docs/adr/` в корне. See `docs/agents/domain.md`.
