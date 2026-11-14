# Прогон тестов по программам в тестовой ВМ: откат к снимку → копирование сборки и исполнителя →
# запуск в сеансе пользователя → сбор отчёта и снимков экрана. Запуск — из PowerShell администратора:
#   powershell -ExecutionPolicy Bypass -File tests\vm\Invoke-AppTests.ps1            # сборка из dist\app
#   powershell -ExecutionPolicy Bypass -File tests\vm\Invoke-AppTests.ps1 -App D:\x  # другая папка программы
# Результат — в $Root\runs\<время>\ (report.md, results.jsonl, trace.jsonl, *.png). Код выхода 0 — всё прошло.
param(
    [string] $App = (Join-Path $PSScriptRoot '..\..\dist\app'),
    [string] $Name = 'LI-Test',
    [string] $Root = 'P:\VM',
    [string] $Checkpoint = 'clean',
    [int] $TimeoutMin = 20,
    [switch] $KeepRunning
)
$ErrorActionPreference = 'Stop'
$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$App = Resolve-Path $App
if (-not (Test-Path "$App\LanguageIndicator.exe")) { throw "Нет $App\LanguageIndicator.exe — соберите: build\build.ps1 -Suffix test.N" }
$cred = Import-Clixml (Join-Path $Root "$Name.credential.xml")
$user = $cred.UserName

Write-Host "Откат $Name к снимку '$Checkpoint'"
Stop-VM -Name $Name -TurnOff -Force -ErrorAction SilentlyContinue
Restore-VMSnapshot -VMName $Name -Name $Checkpoint -Confirm:$false
Start-VM -Name $Name

$deadline = (Get-Date).AddMinutes(5)
while ($true) {
    try { $s = New-PSSession -VMName $Name -Credential $cred -ErrorAction Stop; break }
    catch { if ((Get-Date) -gt $deadline) { throw 'ВМ не отвечает по PowerShell Direct' }; Start-Sleep 5 }
}
try {
    # Программа (портабельная: метка portable — настройки рядом), исполнитель и то, что он подключает
    Invoke-Command -Session $s { Remove-Item C:\LI -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory C:\LI\repo\src, C:\LI\repo\tests | Out-Null }
    Copy-Item $App -Destination C:\LI\app -ToSession $s -Recurse
    Invoke-Command -Session $s { Set-Content C:\LI\app\portable '' }
    Copy-Item "$repo\src\Json.ahk" -Destination C:\LI\repo\src\ -ToSession $s
    Copy-Item "$repo\tests\apps" -Destination C:\LI\repo\tests\ -ToSession $s -Recurse

    # В сеансе пользователя (нужен рабочий стол): разовая задача Планировщика с интерактивным входом
    Invoke-Command -Session $s -ArgumentList $user {
        param($user)
        $ahk = @("$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe", "C:\Users\$user\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe") |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $ahk) { throw 'В ВМ нет AutoHotkey v2' }
        $action = New-ScheduledTaskAction -Execute $ahk -Argument '/ErrorStdOut C:\LI\repo\tests\apps\run.ahk C:\LI\app C:\LI\out'
        $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
        Register-ScheduledTask -TaskName 'LI-AppTests' -Action $action -Principal $principal -Force | Out-Null
        Start-ScheduledTask -TaskName 'LI-AppTests'
    }

    Write-Host 'Идёт прогон...'
    $deadline = (Get-Date).AddMinutes($TimeoutMin)
    while (-not (Invoke-Command -Session $s { Test-Path C:\LI\out\done })) {
        if ((Get-Date) -gt $deadline) { Write-Warning "Прогон не закончился за $TimeoutMin мин — забираю что есть"; break }
        Start-Sleep 5
    }

    $out = Join-Path $Root ("runs\" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
    New-Item -ItemType Directory -Force $out | Out-Null
    Copy-Item C:\LI\out\* -Destination $out -FromSession $s -Recurse
} finally {
    Remove-PSSession $s
    if (-not $KeepRunning) { Stop-VM -Name $Name -TurnOff -Force }
}

Write-Host "Результаты: $out"
if (Test-Path "$out\report.md") { Get-Content "$out\report.md" -Encoding UTF8 | Select-Object -Last 1 }
$done = Get-Content "$out\done" -ErrorAction SilentlyContinue
if ($done -match '^(\d+)/(\d+)$' -and $Matches[1] -eq $Matches[2] -and $Matches[2] -ne '0') { exit 0 } else { exit 1 }
