#!/usr/bin/env pwsh
# PolskiWhisperWin - release script (tag + upload to GitHub Releases)
# Copyright © 2026 Marcin Werner. Licensed under the MIT License.
#
# Użycie:
#   .\scripts\release.ps1 -Version 0.1.0
#
# Wymagania:
#   - gh CLI (winget install GitHub.cli)
#   - Build artifacts w dist/ (z scripts/build-installer.ps1)

param(
    [Parameter(Mandatory)]
    [string]$Version,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent $ScriptRoot
$DistDir = Join-Path $RepoRoot 'dist'
$Tag = "win-v$Version"

Write-Host "PolskiWhisperWin release" -ForegroundColor Cyan
Write-Host "  Version: $Version" -ForegroundColor Gray
Write-Host "  Tag:     $Tag" -ForegroundColor Gray
Write-Host "  Dry run: $DryRun" -ForegroundColor Gray
Write-Host ""

# Sprawdź gh.
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($null -eq $gh) {
    Write-Error "gh CLI nie jest zainstalowane. winget install GitHub.cli"
    exit 1
}

# Sprawdź artefakty.
if (-not (Test-Path $DistDir)) {
    Write-Error "Brak dist/ - uruchom scripts/build-installer.ps1 najpierw."
    exit 1
}

$msiX64 = Get-ChildItem -Path $DistDir -Filter "PolskiWhisper-$Version-win-x64.msi"
$msiArm64 = Get-ChildItem -Path $DistDir -Filter "PolskiWhisper-$Version-win-arm64.msi" -ErrorAction SilentlyContinue
$zipX64 = Get-ChildItem -Path $DistDir -Filter "PolskiWhisper-$Version-win-x64-portable.zip"

if ($null -eq $msiX64) {
    Write-Error "Brak x64 MSI w dist/."
    exit 1
}

# Tag w git.
Write-Host "Krok 1/3: git tag $Tag" -ForegroundColor Yellow
if (-not $DryRun) {
    Push-Location (Split-Path $RepoRoot -Parent)
    try {
        git tag $Tag
        git push origin $Tag
    }
    finally {
        Pop-Location
    }
}

# CHANGELOG dla release notes.
$changelog = Join-Path $RepoRoot 'CHANGELOG.md'
$notes = ""
if (Test-Path $changelog) {
    # Bierzemy pierwszą sekcję ## (najnowsza).
    $lines = Get-Content $changelog
    $started = $false
    $sectionLines = @()
    foreach ($line in $lines) {
        if ($line -match "^## .*\[$Version\]") {
            $started = $true
            continue
        }
        if ($started -and $line -match "^## ") {
            break
        }
        if ($started) { $sectionLines += $line }
    }
    $notes = $sectionLines -join "`n"
}

# GitHub Release.
Write-Host "Krok 2/3: gh release create" -ForegroundColor Yellow

$assetArgs = @($msiX64.FullName, $zipX64.FullName)
if ($null -ne $msiArm64) { $assetArgs += $msiArm64.FullName }

if ($DryRun) {
    Write-Host "  [DRY RUN] gh release create $Tag --title 'PolskiWhisper Windows v$Version' ..." -ForegroundColor Magenta
    Write-Host "  Assets: $($assetArgs -join ', ')" -ForegroundColor Magenta
} else {
    & gh release create $Tag $assetArgs `
        --title "PolskiWhisper Windows v$Version" `
        --notes $notes `
        --repo marcinwerner/polskiwhisper.pl
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

Write-Host ""
Write-Host "Release utworzony: https://github.com/marcinwerner/polskiwhisper.pl/releases/tag/$Tag" -ForegroundColor Green
