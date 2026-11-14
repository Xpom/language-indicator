# Language Indicator

Флажок текущей раскладки клавиатуры прямо там, куда вы смотрите: у текстовой каретки и у курсора мыши в виде «I». Больше не нужно гадать, на каком языке вы сейчас напечатаете.

*A tiny Windows keyboard-layout indicator: a flag (or a language code) next to the text caret and the I-beam mouse cursor.*

- Флаг или код языка (`RU`, `EN`…) — отдельно для каретки и для мыши.
- Сторона, размер, отступ, непрозрачность, скругление углов, цвет и шрифт кода.
- Свой флаг и свой код для любой раскладки.
- Работает в обычных программах, браузерах, Office, Electron, консоли.
- Прячется в полноэкранных играх и видео.
- Окно настроек на русском и английском, следует светлой и тёмной теме Windows.

## Установка

Скачайте последнюю версию на странице [Releases](https://github.com/Xpom/language-indicator/releases/latest):

- **`LanguageIndicator-Setup-X.Y.Z.exe`** — установщик. Ставит программу в Program Files, добавляет её в меню «Пуск» и в «Приложения». Настройки хранятся в `%AppData%\LanguageIndicator`.
- **`LanguageIndicator-X.Y.Z-portable.zip`** — портабельная версия. Распакуйте в любую папку и запустите `LanguageIndicator.exe`. Настройки хранятся рядом с программой.

Нужны Windows 10 или 11 (64-бит). Для окна настроек нужен WebView2 Runtime: в Windows 11 он есть всегда, в Windows 10 обычно ставится вместе с Edge.

### «Windows защитила ваш компьютер»

Программа пока не подписана сертификатом разработчика, поэтому SmartScreen может предупредить при первом запуске. Нажмите **«Подробнее» → «Выполнить в любом случае»**. Исходный код открыт, а сборки делает GitHub Actions прямо из этого репозитория. Как программа будет подписываться — в разделе [Code signing policy](#code-signing-policy).

### Права администратора

При запуске программа просит права администратора. Без них Windows не даёт узнать раскладку и положение каретки в окнах, запущенных от администратора. Если отказаться, программа работает, но в таких окнах флажка не будет.

## Настройки

Двойной клик по значку в трее или пункт «Настройки». Каждое изменение сохраняется сразу. Шестерёнка в заголовке открывает дополнительные настройки: язык окна, раскладки и флаги, способы поиска каретки.

## Обновления

Программа раз в сутки проверяет, нет ли новой версии на странице Releases. С галочкой «Автообновление» (плитка «О проекте») она сама ставит новую версию — при запуске или когда вы 5 минут не трогаете клавиатуру и мышь — и сообщает «Обновлено до vX». Без галочки она один раз сообщает о новой версии, а поставить её можно кнопкой «Обновить». Портабельная версия только сообщает.

Каждый релиз сопровождает `release.json`, подписанный ключом проекта (ECDSA P-256). Программа ставит обновление, только если подпись верна, а размер и SHA-256 установщика совпадают с описанием.

## Приватность

Программа ничего не отправляет о вас и о том, что вы печатаете. Она не читает текст: ей нужны только раскладка и координаты каретки. Единственное обращение в сеть — проверка обновлений: обычный запрос к `api.github.com` и скачивание файлов релиза с GitHub.

## Code signing policy

*Политика подписи кода. Программа пока не подписана: заявка в SignPath Foundation подаётся, раздел написан под её условия.*

Free code signing provided by [SignPath.io](https://about.signpath.io/), certificate by [SignPath Foundation](https://signpath.org/).

- Only binaries built by [GitHub Actions](.github/workflows/release.yml) from the source code of this repository are signed: `LanguageIndicator.exe` and the installer `LanguageIndicator-Setup-X.Y.Z.exe`.
- Every release is approved for signing manually.
- Third-party components bundled with the program (see [License](#лицензия)) are open source under the MIT licence and are not signed with this project's certificate.

**Team roles**

- Committers and reviewers: [Xpom](https://github.com/Xpom)
- Approvers: [Xpom](https://github.com/Xpom)

All team members use multi-factor authentication for GitHub and SignPath.

**Privacy policy**

This program does not collect or transfer any personal data and never reads the text you type: it only needs the current keyboard layout and the caret position. Its only network activity is checking for updates: a request to `api.github.com` for the latest release of this repository and, when an update is installed, downloading the release files from GitHub. No identifiers or usage data are sent. See also [GitHub's privacy statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement).

## Сборка из исходников

Нужны [AutoHotkey v2](https://www.autohotkey.com/) и [Inno Setup 6](https://jrsoftware.org/isinfo.php).

```bash
AutoHotkey64.exe LanguageIndicator.ahk                        # запустить из исходников
powershell -ExecutionPolicy Bypass -File build\build.ps1      # exe, архив и установщик в dist\
AutoHotkey64.exe /ErrorStdOut tests\run.ahk                    # тесты
```

## Лицензия

[MIT](LICENSE). Сторонние компоненты:

- флаги — [flag-icons](https://github.com/lipis/flag-icons) (MIT);
- обёртка WebView2 — [thqby/ahk2_lib](https://github.com/thqby/ahk2_lib) (MIT).
