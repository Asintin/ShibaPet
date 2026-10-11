# One-click build for the Unity Shiba desktop pet.
# Prerequisite: Unity Hub is signed in and Unity 2022.3 LTS is installed.
# Usage:  .\Build.ps1
#         (optionally) .\Build.ps1 -UnityExe "C:\Program Files\Unity\Hub\Editor\2022.3.20f1\Editor\Unity.exe"

param(
    [string]$UnityExe = ""
)

$ErrorActionPreference = "Stop"
$project = $PSScriptRoot

if (-not $UnityExe) {
    $editors = Get-ChildItem "C:\Program Files\Unity\Hub\Editor" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "2022.3*" } | Sort-Object Name -Descending
    foreach ($e in $editors) {
        $cand = Join-Path $e.FullName "Editor\Unity.exe"
        if (Test-Path $cand) { $UnityExe = $cand; break }
    }
}

if (-not $UnityExe -or -not (Test-Path $UnityExe)) {
    Write-Host "Unity Editor 2022.3 LTS not found." -ForegroundColor Red
    Write-Host "Sign in to Unity Hub, install 2022.3 LTS, or pass -UnityExe explicitly."
    Write-Host "  .\Build.ps1 -UnityExe 'C:\Program Files\Unity\Hub\Editor\2022.3.20f1\Editor\Unity.exe'"
    exit 1
}

$log = Join-Path $env:TEMP "shiba_build.log"
Write-Host "Unity   : $UnityExe"
Write-Host "Project : $project"
Write-Host "Building (first time may take a few minutes)..."

& $UnityExe -batchmode -nographics -quit -projectPath $project -executeMethod PetBuild.Build -logFile $log
$code = $LASTEXITCODE

if (Test-Path $log) {
    Get-Content $log -Tail 60 | ForEach-Object { Write-Host $_ }
}

$exe = Join-Path $project "Build\ShibaPet.exe"
if ($code -eq 0 -and (Test-Path $exe)) {
    Write-Host ""
    Write-Host "BUILD SUCCESS" -ForegroundColor Green
    Write-Host $exe
    Write-Host "Double-click ShibaPet.exe to run the transparent always-on-top pet."
    Write-Host ""
} elseif (Test-Path $log -and (Select-String -Path $log -Pattern "No valid Unity Editor license|license" -Quiet)) {
    Write-Host ""
    Write-Host "BUILD FAILED: Unity license is not activated." -ForegroundColor Red
    Write-Host "Sign in to Unity Hub and activate a Personal license, then retry."
    exit $code
} else {
    Write-Host ""
    Write-Host "BUILD FAILED. Log: $log" -ForegroundColor Red
    exit $code
}
