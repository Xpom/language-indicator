# Тестовая виртуалка

Тесты по программам идут в отдельной ВМ Hyper-V, а не на рабочей машине: там ставятся программы из [чеклиста](app-checklist.md), и каждый прогон начинается с одного и того же снимка. Скрипты — в `tests/vm/`, исполнитель внутри ВМ — в `tests/apps/`.

Всё ниже — из PowerShell **администратора** на хосте, из корня репозитория.

## Создать машину

1. Образ — Windows 11 Enterprise Evaluation (90 дней, без ключа): [Evaluation Center](https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise) → ISO 64-bit (en-US), положить в `P:\VM\iso\`.
2. Создать ВМ и поставить Windows без участия человека (15–30 минут):
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests\vm\New-TestVM.ps1 -Iso P:\VM\iso\Win11_26H2_EnterpriseEval_x64_en-us.iso
   ```
   Что получится: ВМ `LI-Test` в `P:\VM` (2 ядра, 8 ГБ, диск 80 ГБ, Secure Boot и TPM), пользователь `tester` — администратор с автовходом, раскладки EN и RU, UAC без запроса, без автообновлений Windows, экран не гаснет. Пароль `tester` случайный, лежит в `P:\VM\LI-Test.credential.xml` (зашифрован для пользователя хоста, в git не попадает). Файл ответов — `tests/vm/autounattend.xml`.
3. Поставить программы и сделать снимок `clean`:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests\vm\Install-TestApps.ps1
   ```
   Список — в начале скрипта (winget). Office — руками в окне ВМ (`vmconnect localhost LI-Test`), потом снимок заново: `Install-TestApps.ps1 -OnlyCheckpoint`.

Через 90 дней оценочная Windows перестаёт работать — машину удалить (`Remove-VM LI-Test`, папку `P:\VM\LI-Test`) и создать снова теми же командами.

## Прогон

```powershell
powershell -ExecutionPolicy Bypass -File build\build.ps1 -Suffix test.1     # сборка в dist\app
powershell -ExecutionPolicy Bypass -File tests\vm\Invoke-AppTests.ps1      # откат, прогон, отчёт
```

Скрипт откатывает ВМ к снимку `clean`, копирует `dist\app` (как портабельную) и `tests\apps`, запускает исполнитель в сеансе `tester` и ждёт файла `done`. Результаты — в `P:\VM\runs\<время>\`: `report.md` (таблица шагов со ссылками на снимки), `results.jsonl`, `trace.jsonl` (запись индикатора `/trace`), снимки экрана. Код выхода 0 — все шаги прошли. `-KeepRunning` оставляет ВМ включённой, чтобы посмотреть руками.

## Сценарии

`tests/apps/scenarios.ahk` — одна программа на строку: как запустить, какое окно ждать, что нажать перед набором, нужен ли флажок у каретки. В каждом сценарии исполнитель переключает раскладку на EN и на RU, набирает текст и по последней записи индикатора проверяет: каретка найдена, флаг совпадает с раскладкой. Добавить программу — дописать строку (и пакет в `Install-TestApps.ps1`).

## Что остаётся ручным

Смотреть снимки (флажок не налез, зазор), а также сценарии из раздела «Сценарии, которые не про программу» в чеклисте: UAC с окном согласия, два монитора, игры. Масштаб 150% можно включить и в ВМ.
