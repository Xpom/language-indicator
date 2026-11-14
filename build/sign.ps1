# Подпись файла закрытым ключом релизов: рядом появляется <файл>.sig — 64 байта r‖s (ECDSA P-256, SHA-256).
#   $env:RELEASE_SIGNING_KEY = '<base64>'; powershell -File build\sign.ps1 -File dist\release.json
# Ключ берётся только из переменной окружения и никуда не выводится.
param([Parameter(Mandatory)] [string] $File)
$ErrorActionPreference = 'Stop'
if (-not $env:RELEASE_SIGNING_KEY) { throw 'Нет RELEASE_SIGNING_KEY' }
$blob = [Convert]::FromBase64String($env:RELEASE_SIGNING_KEY.Trim())
$key = [System.Security.Cryptography.CngKey]::Import($blob, [System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
$ecdsa = New-Object System.Security.Cryptography.ECDsaCng($key)
$ecdsa.HashAlgorithm = [System.Security.Cryptography.CngAlgorithm]::Sha256
$sig = $ecdsa.SignData([IO.File]::ReadAllBytes((Resolve-Path $File)))
[IO.File]::WriteAllBytes("$((Resolve-Path $File).Path).sig", $sig)
Write-Host "Подписан $File ($($sig.Length) байт подписи)"
