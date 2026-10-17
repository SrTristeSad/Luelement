$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$engineRoot = Join-Path $root 'android-engine'
$dist = Join-Path $root 'dist'
$tools = Join-Path $root '.tools'
$gradleVersion = '8.9'
$gradleZip = Join-Path $tools "gradle-$gradleVersion-bin.zip"
$gradleHome = Join-Path $tools "gradle-$gradleVersion"
$gradleBat = Join-Path $gradleHome 'bin\gradle.bat'
$gradleUrl = "https://services.gradle.org/distributions/gradle-$gradleVersion-bin.zip"
$outputApk = Join-Path $engineRoot 'app\build\outputs\apk\debug\app-debug.apk'
$targetApk = Join-Path $dist 'Luelement-Engine-0.1.0-dev-arm64.apk'

function Require-Command([string] $Name, [string] $Message) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw $Message
    }
    return $command
}

Write-Host '[1/6] Verificando Java...'
$java = Require-Command 'java' 'Java/JDK 17 nao encontrado no PATH. Instale o JDK 17 ou configure JAVA_HOME.'
$javaVersionText = (& $java.Source -version 2>&1 | Select-Object -First 1) -join ''
Write-Host "      $javaVersionText"

Write-Host '[2/6] Localizando Android SDK...'
$sdkCandidates = @(
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT,
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
) | Where-Object { $_ -and (Test-Path $_) }

if ($sdkCandidates.Count -eq 0) {
    throw 'Android SDK nao encontrado. Instale pelo Android Studio e configure ANDROID_HOME ou ANDROID_SDK_ROOT.'
}

$androidSdk = $sdkCandidates[0]
$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
Write-Host "      SDK: $androidSdk"

$platform35 = Join-Path $androidSdk 'platforms\android-35'
if (-not (Test-Path $platform35)) {
    throw 'Android SDK Platform 35 nao esta instalada. Instale "Android SDK Platform 35" pelo SDK Manager.'
}

Write-Host '[3/6] Preparando Gradle fixo...'
New-Item -ItemType Directory -Force -Path $tools | Out-Null
if (-not (Test-Path $gradleBat)) {
    if (-not (Test-Path $gradleZip)) {
        Write-Host "      Baixando Gradle $gradleVersion..."
        Invoke-WebRequest -Uri $gradleUrl -OutFile $gradleZip -UseBasicParsing
    }

    Write-Host '      Extraindo Gradle...'
    Expand-Archive -Path $gradleZip -DestinationPath $tools -Force
}

if (-not (Test-Path $gradleBat)) {
    throw "Gradle nao encontrado apos a preparacao: $gradleBat"
}

Write-Host '[4/6] Limpando saida anterior...'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
if (Test-Path $targetApk) {
    Remove-Item -Force $targetApk
}

Write-Host '[5/6] Compilando companion Android...'
Write-Host '      O Gradle tambem baixa as bibliotecas nativas pinadas do Elementum.'
& $gradleBat --no-daemon -p $engineRoot ':app:assembleDebug'
if ($LASTEXITCODE -ne 0) {
    throw "Gradle terminou com codigo $LASTEXITCODE"
}

if (-not (Test-Path $outputApk)) {
    throw "APK esperado nao foi gerado: $outputApk"
}

Write-Host '[6/6] Copiando APK para dist...'
Copy-Item -Force $outputApk $targetApk
$sizeMiB = [Math]::Round((Get-Item $targetApk).Length / 1MB, 2)

Write-Host ''
Write-Host 'Build concluido:' -ForegroundColor Green
Write-Host "  $targetApk"
Write-Host "  Tamanho: $sizeMiB MiB"
Write-Host ''
Write-Host 'Instale esse APK no Android junto com o AddKo e depois instale o pacote Luelement .addko.'
