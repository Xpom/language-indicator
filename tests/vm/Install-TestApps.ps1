# Ставит в тестовую ВМ программы из docs/app-checklist.md (winget) и делает снимок «clean».
# Запуск — из PowerShell администратора на хосте, после New-TestVM.ps1:
#   powershell -ExecutionPolicy Bypass -File tests\vm\Install-TestApps.ps1
# Office ставится руками (лицензия), потом снимок пересоздаётся: -OnlyCheckpoint.
param(
    [string] $Name = 'LI-Test',
    [string] $Root = 'P:\VM',
    [string] $Checkpoint = 'clean',
    [switch] $OnlyCheckpoint
)
$ErrorActionPreference = 'Stop'
$cred = Import-Clixml (Join-Path $Root "$Name.credential.xml")

# Программы чеклиста. Нет в winget или нужна лицензия — в docs/test-vm.md.
$apps = @(
    'AutoHotkey.AutoHotkey'         # исполнитель тестов tests/apps
    'Google.Chrome'
    'Mozilla.Firefox'
    'Yandex.Browser'
    'Microsoft.VisualStudioCode'
    'Notepad++.Notepad++'
    'Git.Git'                       # Git Bash (mintty)
    'Microsoft.PowerShell'
    'FarManager.FarManager'
    'dotPDN.PaintDotNet'
    'HeidiSQL.HeidiSQL'
    'Telegram.TelegramDesktop'
    'Discord.Discord'
    'SlackTechnologies.Slack'
    'Obsidian.Obsidian'
    'Notion.Notion'
)

if (-not $OnlyCheckpoint) {
    if ((Get-VM $Name).State -ne 'Running') { Start-VM $Name }
    $failed = Invoke-Command -VMName $Name -Credential $cred -ArgumentList (, $apps) -ScriptBlock {
        param($apps)
        # В сеансе PowerShell Direct winget не в PATH — берём из пакета App Installer
        $winget = Get-ChildItem 'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe' |
            Sort-Object FullName | Select-Object -Last 1 -ExpandProperty FullName
        if (-not $winget) { throw 'Нет winget (App Installer) — обновите его из Microsoft Store в ВМ' }
        & $winget source update | Out-Null
        $failed = @()
        foreach ($id in $apps) {
            Write-Host "== $id"
            & $winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
            # -1978335189: уже установлено
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { $failed += "$id ($LASTEXITCODE)" }
        }
        $failed
    }
    if ($failed) { Write-Warning ("Не поставились: " + ($failed -join ', ')) }
}

# Снимок с работающей ВМ (стандартный, с памятью): откат к нему сразу даёт рабочий стол пользователя
Get-VMSnapshot -VMName $Name -Name $Checkpoint -ErrorAction SilentlyContinue | Remove-VMSnapshot
Checkpoint-VM -Name $Name -SnapshotName $Checkpoint
Write-Host "Снимок '$Checkpoint' готов"
