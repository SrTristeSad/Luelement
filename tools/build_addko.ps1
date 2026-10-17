param(
    [string]$Version = "0.2.1-dev"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Dist = Join-Path $Root "dist"
$Stage = Join-Path $Dist "luelement-package"
$Zip = Join-Path $Dist "Luelement-$Version.zip"
$Output = Join-Path $Dist "Luelement-$Version.addko"

if (Test-Path $Stage) {
    Remove-Item $Stage -Recurse -Force
}
if (Test-Path $Zip) {
    Remove-Item $Zip -Force
}
if (Test-Path $Output) {
    Remove-Item $Output -Force
}

New-Item -ItemType Directory -Force -Path $Stage | Out-Null
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

$RequiredFiles = @(
    "manifest.json",
    "main.lua"
)

foreach ($File in $RequiredFiles) {
    $Source = Join-Path $Root $File
    if (-not (Test-Path $Source)) {
        throw "Arquivo obrigatório ausente: $File"
    }
    Copy-Item $Source (Join-Path $Stage $File)
}

$SourceDir = Join-Path $Root "src"
if (-not (Test-Path $SourceDir)) {
    throw "Diretório src ausente"
}
Copy-Item $SourceDir (Join-Path $Stage "src") -Recurse

Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $Zip -CompressionLevel Optimal
Move-Item $Zip $Output
Remove-Item $Stage -Recurse -Force

$Size = (Get-Item $Output).Length
if ($Size -gt 16MB) {
    Remove-Item $Output -Force
    throw "Pacote excede o limite atual do AddKo (16 MiB): $Size bytes"
}

Write-Host "Pacote criado: $Output"
Write-Host "Tamanho: $Size bytes"
