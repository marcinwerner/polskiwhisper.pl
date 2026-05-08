#!/usr/bin/env pwsh
# PolskiWhisperWin - build MSI installer (PowerShell + WiX)
# Copyright © 2026 Marcin Werner. Licensed under the MIT License.
#
# Wymagania:
#   - WiX Toolset v4 (zainstaluj: dotnet tool install --global wix)
#   - .NET 8 SDK
#   - Build z scripts/build.ps1 -Publish (publish dir musi istnieć)

param(
    [ValidateSet('win-x64', 'win-arm64')]
    [string]$Runtime = 'win-x64',

    [string]$Version = '0.1.0'
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent $ScriptRoot
$PublishDir = Join-Path $RepoRoot "publish\$Runtime"
$InstallerDir = Join-Path $RepoRoot 'installer'
$OutputDir = Join-Path $RepoRoot 'dist'

Write-Host "PolskiWhisperWin installer build" -ForegroundColor Cyan
Write-Host "  Runtime: $Runtime" -ForegroundColor Gray
Write-Host "  Version: $Version" -ForegroundColor Gray
Write-Host ""

# Sprawdź WiX.
$wix = Get-Command wix -ErrorAction SilentlyContinue
if ($null -eq $wix) {
    Write-Error "WiX toolset nie jest zainstalowany. Zainstaluj: dotnet tool install --global wix"
    exit 1
}

if (-not (Test-Path $PublishDir)) {
    Write-Error "Brak publish output. Uruchom najpierw: scripts/build.ps1 -Configuration Release -Runtime $Runtime -Publish"
    exit 1
}

# Sprawdź WiX project file.
$WixProject = Join-Path $InstallerDir 'PolskiWhisperWin.wxs'
if (-not (Test-Path $WixProject)) {
    Write-Error "Nie znaleziono WiX project: $WixProject"
    exit 1
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$msiOutput = Join-Path $OutputDir "PolskiWhisper-$Version-$Runtime.msi"

Write-Host "Buduję MSI..." -ForegroundColor Yellow
& wix build $WixProject `
    -define "Version=$Version" `
    -define "PublishDir=$PublishDir" `
    -define "Platform=$Runtime" `
    -arch ($(if ($Runtime -eq 'win-arm64') { 'arm64' } else { 'x64' })) `
    -out $msiOutput

if ($LASTEXITCODE -ne 0) {
    Write-Error "WiX build nieudany."
    exit 1
}

Write-Host ""
Write-Host "MSI utworzone: $msiOutput" -ForegroundColor Green

# Również stwórz portable ZIP (alt download).
$zipOutput = Join-Path $OutputDir "PolskiWhisper-$Version-$Runtime-portable.zip"
Write-Host "Pakuję portable ZIP..." -ForegroundColor Yellow
Compress-Archive -Path "$PublishDir\*" -DestinationPath $zipOutput -Force
Write-Host "ZIP utworzone: $zipOutput" -ForegroundColor Green

Write-Host ""
Write-Host "Build artifacts:" -ForegroundColor Cyan
Get-ChildItem -Path $OutputDir | Format-Table Name, @{Name='Size MB';Expression={[Math]::Round($_.Length/1MB, 2)}}
