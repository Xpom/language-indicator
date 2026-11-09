# language-indicator

Индикатор раскладки на AutoHotkey v2: флажок текущего языка у каретки и у курсора мыши (IBEAM), окно настроек.

Спека — issue #1, тикеты — его sub-issues.

## Запуск и тесты

AutoHotkey v2 стоит в `C:\Program Files\AutoHotkey\v2`.

```bash
"/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" LanguageIndicator.ahk               # сам поднимает права (UAC)
"/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" LanguageIndicator.ahk /no-elevate   # без UAC, для отладки
MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tests/run.ahk | cat   # тесты, код выхода 0 = всё прошло
```

В Git Bash ключи вида `/ErrorStdOut` без `MSYS_NO_PATHCONV=1` превращаются в путь, и AHK повисает с диалогом ошибки.

## Устройство

- `src/Core.ahk` — ядро: чистая функция «снимок → размещения» (`Core.Decide`), маппинг раскладки, расчёт позиции. Системы не трогает, всё покрыто тестами.
- `src/Locale.ahk` — справочник локалей Windows (LANGID → страна/язык); детерминирован, используется в тестах.
- `src/Probes.ahk` — адаптеры: раскладка активного окна, каретка, DPI монитора. Без логики решений.
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
