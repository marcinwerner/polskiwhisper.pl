#!/usr/bin/env pwsh
# PolskiWhisperWin - build script (PowerShell)
# Copyright © 2026 Marcin Werner. Licensed under the MIT License.
#
# Użycie:
#   .\scripts\build.ps1 -Configuration Release -Runtime win-x64
#
# Wymagania:
#   - .NET 8 SDK
#   - Windows App SDK 1.5+
#   - Windows 10/11

param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [ValidateSet('win-x64', 'win-arm64')]
    [string]$Runtime = 'win-x64',

    [switch]$RunTests,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent $ScriptRoot
$Solution = Join-Path $RepoRoot 'PolskiWhisperWin.sln'

Write-Host "PolskiWhisperWin build" -ForegroundColor Cyan
Write-Host "  Configuration: $Configuration" -ForegroundColor Gray
Write-Host "  Runtime:       $Runtime" -ForegroundColor Gray
Write-Host "  Solution:      $Solution" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $Solution)) {
    Write-Error "Nie znaleziono solution: $Solution"
    exit 1
}

# Restore NuGet packages.
Write-Host "Krok 1/4: dotnet restore..." -ForegroundColor Yellow
dotnet restore $Solution
if ($LASTEXITCODE -ne 0) { exit 1 }

# Build.
Write-Host "Krok 2/4: dotnet build..." -ForegroundColor Yellow
dotnet build $Solution -c $Configuration --no-restore
if ($LASTEXITCODE -ne 0) { exit 1 }

# Tests.
if ($RunTests) {
    Write-Host "Krok 3/4: dotnet test..." -ForegroundColor Yellow
    dotnet test $Solution -c $Configuration --no-build --logger "console;verbosity=normal"
    if ($LASTEXITCODE -ne 0) { exit 1 }
} else {
    Write-Host "Krok 3/4: pominięto testy (-RunTests aby uruchomić)" -ForegroundColor Gray
}

# Publish.
if ($Publish) {
    Write-Host "Krok 4/4: dotnet publish..." -ForegroundColor Yellow
    $publishDir = Join-Path $RepoRoot "publish\$Runtime"
    if (Test-Path $publishDir) { Remove-Item $publishDir -Recurse -Force }

    dotnet publish (Join-Path $RepoRoot 'src\PolskiWhisperWin\PolskiWhisperWin.csproj') `
        -c $Configuration `
        -r $Runtime `
        --self-contained true `
        -o $publishDir
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-Host ""
    Write-Host "Output: $publishDir" -ForegroundColor Green
} else {
    Write-Host "Krok 4/4: pominięto publish (-Publish aby uruchomić)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Build zakończony pomyślnie." -ForegroundColor Green
