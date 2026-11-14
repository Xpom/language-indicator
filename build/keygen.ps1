# Пара ключей подписи релизов (ECDSA P-256). Запускается один раз:
#   powershell -ExecutionPolicy Bypass -File build\keygen.ps1 -Out <файл вне репозитория>
# Закрытый ключ (base64 BCRYPT_ECCPRIVATE_BLOB) пишется в -Out — его кладут в секрет GitHub
# RELEASE_SIGNING_KEY и хранят у себя. Открытый ключ печатается — его вписывают в Release.publicKey.
param([Parameter(Mandatory)] [string] $Out)
$ErrorActionPreference = 'Stop'
if (Test-Path $Out) { throw "$Out уже существует — не перезаписываю ключ" }
$params = New-Object System.Security.Cryptography.CngKeyCreationParameters
$params.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::AllowPlaintextExport
# Имя ключа — настоящий null: $null PowerShell превратил бы в "" и сохранил ключ в хранилище Windows
$key = [System.Security.Cryptography.CngKey]::Create([System.Security.Cryptography.CngAlgorithm]::ECDsaP256, [NullString]::Value, $params)
$private = $key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
$public = $key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
[IO.File]::WriteAllText($Out, [Convert]::ToBase64String($private))
Write-Host "Закрытый ключ: $Out"
Write-Host "Открытый ключ (Release.publicKey):"
[Convert]::ToBase64String($public)
