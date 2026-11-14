# Сборка Language Indicator: exe, портабельный архив и установщик в dist\.
#   powershell -ExecutionPolicy Bypass -File build\build.ps1
# Нужны AutoHotkey v2 (база для exe) и Inno Setup 6; Ahk2Exe скрипт скачивает сам в build\.tools.
# Пути к инструментам можно задать переменными окружения AHK_BASE и ISCC.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $root 'dist'
$tools = Join-Path $PSScriptRoot '.tools'

# Ahk2Exe закреплён на версии и контрольной сумме
$ahk2exeUrl = 'https://github.com/AutoHotkey/Ahk2Exe/releases/download/Ahk2Exe1.1.37.02a2/Ahk2Exe1.1.37.02a2.zip'
$ahk2exeSha = 'c29b8c3a5124850d79fc9e66e2ca79677c377d7f31631ad3022ba159c5d9e3be'

function First-Existing($paths) {
    foreach ($p in $paths) { if ($p -and (Test-Path $p)) { return $p } }
    return $null
}

# --- версия: App.version и директива Ahk2Exe должны совпадать ---
$main = Get-Content (Join-Path $root 'LanguageIndicator.ahk') -Raw -Encoding UTF8
$version = [regex]::Match($main, 'static version := "([^"]+)"').Groups[1].Value
$exeVersion = [regex]::Match($main, ';@Ahk2Exe-SetVersion (\S+)').Groups[1].Value
if (-not $version) { throw 'Не нашёл App.version' }
if ($version -ne $exeVersion) { throw "App.version $version не совпадает с ;@Ahk2Exe-SetVersion $exeVersion" }
Write-Host "Версия $version"

# --- инструменты ---
$ahk2exe = Join-Path $tools 'Ahk2Exe.exe'
if (-not (Test-Path $ahk2exe)) {
    New-Item -ItemType Directory -Force $tools | Out-Null
    $zip = Join-Path $tools 'Ahk2Exe.zip'
    Invoke-WebRequest $ahk2exeUrl -OutFile $zip -UseBasicParsing
    if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $ahk2exeSha) { Remove-Item $zip; throw 'Ahk2Exe: контрольная сумма не совпала' }
    Expand-Archive $zip $tools -Force
    Remove-Item $zip
}
$base = First-Existing @($env:AHK_BASE, "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe")
if (-not $base) { throw 'Не нашёл AutoHotkey64.exe (задайте AHK_BASE)' }
$iscc = First-Existing @($env:ISCC, "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe", "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe")
if (-not $iscc) { throw 'Не нашёл ISCC.exe из Inno Setup 6 (задайте ISCC)' }

# --- папка программы ---
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
$app = Join-Path $dist 'app'
New-Item -ItemType Directory -Force $app | Out-Null
$exe = Join-Path $app 'LanguageIndicator.exe'
$p = Start-Process $ahk2exe -ArgumentList @('/in', "`"$root\LanguageIndicator.ahk`"", '/out', "`"$exe`"", '/base', "`"$base`"", '/silent', 'verbose') -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 0 -or -not (Test-Path $exe)) { throw "Ahk2Exe завершился с кодом $($p.ExitCode)" }

Copy-Item (Join-Path $root 'ui') $app -Recurse
Copy-Item (Join-Path $root 'flags') $app -Recurse
New-Item -ItemType Directory -Force "$app\lib" | Out-Null
Copy-Item "$root\lib\LICENSE-ahk2_lib.txt" "$app\lib\"
Copy-Item "$root\LICENSE" "$app\LICENSE.txt"

# --- портабельный архив: та же папка и метка portable ---
$port = Join-Path $dist 'portable\LanguageIndicator'
New-Item -ItemType Directory -Force $port | Out-Null
Copy-Item "$app\*" $port -Recurse
Set-Content (Join-Path $port 'portable') 'Настройки этой копии хранятся рядом с программой, в settings.ini.' -Encoding UTF8
$zipName = "LanguageIndicator-$version-portable.zip"
# tar из Windows, а не Compress-Archive: тот в PowerShell 5.1 пишет пути с обратными слэшами
& "$env:SystemRoot\System32\tar.exe" -a -c -f (Join-Path $dist $zipName) -C (Join-Path $dist 'portable') LanguageIndicator
if ($LASTEXITCODE -ne 0) { throw "tar завершился с кодом $LASTEXITCODE" }
Remove-Item (Join-Path $dist 'portable') -Recurse -Force

# --- установщик ---
& $iscc "/DAppVersion=$version" "/DSourceDir=$app" "/O$dist" (Join-Path $PSScriptRoot 'installer.iss') | Out-Host
if ($LASTEXITCODE -ne 0) { throw "ISCC завершился с кодом $LASTEXITCODE" }

Get-ChildItem $dist -File | ForEach-Object { Write-Host ("{0}  {1:N0} байт" -f $_.Name, $_.Length) }
