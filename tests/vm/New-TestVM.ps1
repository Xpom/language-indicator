# Создаёт тестовую ВМ Hyper-V и ставит в неё Windows 11 без участия человека (autounattend.xml).
# Запуск — из PowerShell администратора на хосте:
#   powershell -ExecutionPolicy Bypass -File tests\vm\New-TestVM.ps1 -Iso P:\VM\iso\Win11_...iso
# Пароль пользователя ВМ генерируется и хранится в $Root\$Name.credential.xml (DPAPI, только для
# текущего пользователя хоста) — в репозиторий не попадает. Там же лежат диск ВМ и ISO с файлом ответов.
param(
    [Parameter(Mandatory)] [string] $Iso,
    [string] $Name = 'LI-Test',
    [string] $Root = 'P:\VM',
    [string] $User = 'tester',
    [int] $Cpu = 2,
    [long] $MemoryGB = 8,
    [long] $DiskGB = 80
)
$ErrorActionPreference = 'Stop'

if (Get-VM -Name $Name -ErrorAction SilentlyContinue) { throw "ВМ $Name уже есть. Удалите её (Remove-VM) или задайте -Name." }
if (-not (Test-Path $Iso)) { throw "Нет образа $Iso" }

$dir = Join-Path $Root $Name
New-Item -ItemType Directory -Force $dir | Out-Null

# Учётная запись ВМ: пароль случайный, хранится зашифрованным для текущего пользователя хоста
$credFile = Join-Path $Root "$Name.credential.xml"
if (Test-Path $credFile) {
    $cred = Import-Clixml $credFile
} else {
    $chars = [char[]]'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    $bytes = New-Object byte[] 20
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $plain = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    $cred = New-Object Management.Automation.PSCredential($User, (ConvertTo-SecureString $plain -AsPlainText -Force))
    $cred | Export-Clixml $credFile
}
$password = $cred.GetNetworkCredential().Password

# Файл ответов — на отдельный маленький ISO: установщик ищет autounattend.xml в корне всех CD
$answerDir = Join-Path $dir 'answer'
New-Item -ItemType Directory -Force $answerDir | Out-Null
$xml = (Get-Content (Join-Path $PSScriptRoot 'autounattend.xml') -Raw -Encoding UTF8).
    Replace('{{USER}}', $User).Replace('{{PASSWORD}}', $password).Replace('{{COMPUTER}}', $Name.ToUpper())
[IO.File]::WriteAllText((Join-Path $answerDir 'autounattend.xml'), $xml, (New-Object Text.UTF8Encoding $false))

Add-Type -TypeDefinition @'
using System.IO;
using System.Runtime.InteropServices.ComTypes;
public static class IsoWriter {
    public static void Save(object image, string path) {
        var s = (IStream)image;
        var buf = new byte[65536];
        using (var f = File.Create(path)) {
            while (true) {
                var n = System.Runtime.InteropServices.Marshal.AllocHGlobal(4);
                try {
                    s.Read(buf, buf.Length, n);
                    int read = System.Runtime.InteropServices.Marshal.ReadInt32(n);
                    if (read == 0) break;
                    f.Write(buf, 0, read);
                } finally { System.Runtime.InteropServices.Marshal.FreeHGlobal(n); }
            }
        }
    }
}
'@
$answerIso = Join-Path $dir 'answer.iso'
$fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fsi.FileSystemsToCreate = 3    # ISO 9660 + Joliet
$fsi.VolumeName = 'ANSWER'
$fsi.Root.AddTree($answerDir, $false)
[IsoWriter]::Save($fsi.CreateResultImage().ImageStream, $answerIso)
Remove-Item -Recurse $answerDir     # пароль открытым текстом остаётся только внутри answer.iso — удаляется после установки

# ВМ: поколение 2, Secure Boot и TPM (нужны Windows 11), стандартные снимки — с памятью,
# чтобы откат возвращал уже вошедший в систему рабочий стол
$vhd = Join-Path $dir "$Name.vhdx"
New-VM -Name $Name -Generation 2 -MemoryStartupBytes ($MemoryGB * 1GB) -NewVHDPath $vhd -NewVHDSizeBytes ($DiskGB * 1GB) `
    -Path $Root -SwitchName 'Default Switch' | Out-Null
Set-VM -Name $Name -ProcessorCount $Cpu -StaticMemory -CheckpointType Standard -AutomaticCheckpointsEnabled $false `
    -AutomaticStopAction ShutDown
Set-VMKeyProtector -VMName $Name -NewLocalKeyProtector
Enable-VMTPM -VMName $Name
$dvd = Add-VMDvdDrive -VMName $Name -Path $Iso -Passthru
Add-VMDvdDrive -VMName $Name -Path $answerIso
Set-VMFirmware -VMName $Name -EnableSecureBoot On -SecureBootTemplate MicrosoftWindows -FirstBootDevice $dvd

Start-VM -Name $Name
# «Press any key to boot from CD»: нажимаем за человека первые секунды загрузки
$cs = Get-CimInstance -Namespace root\virtualization\v2 -ClassName Msvm_ComputerSystem -Filter "ElementName='$Name'"
$kb = Get-CimAssociatedInstance -InputObject $cs -ResultClassName Msvm_Keyboard
foreach ($i in 1..20) {
    Invoke-CimMethod -InputObject $kb -MethodName TypeKey -Arguments @{ keyCode = [uint32]0x20 } | Out-Null
    Start-Sleep -Milliseconds 500
}

Write-Host "Ставится Windows — обычно 15–30 минут. Ждём, пока ВМ ответит по PowerShell Direct..."
$deadline = (Get-Date).AddMinutes(90)
while ($true) {
    try {
        $ok = Invoke-Command -VMName $Name -Credential $cred -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
        if ($ok) { break }
    } catch { }
    if ((Get-Date) -gt $deadline) { throw 'Windows не поднялась за 90 минут — посмотрите окно ВМ (vmconnect)' }
    Start-Sleep -Seconds 30
}

# Ждём рабочий стол пользователя (автовход): процесс explorer в его сеансе
Invoke-Command -VMName $Name -Credential $cred -ScriptBlock {
    $end = (Get-Date).AddMinutes(15)
    while (-not (Get-Process explorer -IncludeUserName -ErrorAction SilentlyContinue | Where-Object UserName -like "*\$using:User")) {
        if ((Get-Date) -gt $end) { throw 'Нет рабочего стола пользователя' }
        Start-Sleep 10
    }
}

Get-VMDvdDrive -VMName $Name | Set-VMDvdDrive -Path $null
Remove-Item $answerIso
Write-Host "Готово: ВМ $Name, пользователь $User, пароль — в $credFile"
