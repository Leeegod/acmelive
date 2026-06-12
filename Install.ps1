# ============================================================
# SELF-ELEVATION (SAFE + RELIABLE)
# ============================================================
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$scriptUrl = "https://raw.githubusercontent.com/Leeegod/acmelive/main/Install.ps1"
$localFile = "$env:TEMP\acme_install.ps1"

# ALWAYS ensure local script exists
if (-not (Test-Path $localFile)) {
    Invoke-WebRequest $scriptUrl -OutFile $localFile
}

if (-not $isAdmin) {
    Write-Host "Requesting administrator permission..."

    Start-Process powershell -Verb RunAs -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy Bypass",
        "-File `"$localFile`""
    )

    exit
}

# ensure script continues from local file
if ($PSCommandPath -ne $localFile) {
    exit
}
$ErrorActionPreference = "Stop"

# ============================================================
# CONFIG
# ============================================================
$AppName     = "acmelive"
$ServiceName = "AcmeClient"

$InstallDir  = "$env:LOCALAPPDATA\Acme\$AppName"
$TempZip     = "$env:TEMP\$AppName.zip"
$TempExtract = "$env:TEMP\$AppName-extract"

$DownloadUrl = "http://web.acmetech.com.np/acmeupdate/acmelive.zip"

# ============================================================
# LOG
# ============================================================
function Log { param($m) Write-Host "[$(Get-Date -f 'HH:mm:ss')] $m" }

try {

    Log "Downloading package..."
    Invoke-WebRequest $DownloadUrl -OutFile $TempZip

    Log "Removing existing service (if any)..."

    $svc = Get-Service $ServiceName -ErrorAction SilentlyContinue

    if ($svc) {
        if ($svc.Status -eq "Running") {
            Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
        }
        sc.exe delete $ServiceName | Out-Null
        Log "Service removed"
    }

    Log "Extracting..."
    if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
    Expand-Archive $TempZip $TempExtract -Force

    Log "Installing files..."
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item "$TempExtract\*" $InstallDir -Recurse -Force

    # ========================================================
    # FIX: safer EXE detection (IMPORTANT)
    # ========================================================
    $ExePath = Get-ChildItem $InstallDir -Recurse -Filter "*.exe" |
               Where-Object { $_.Name -like "*acme*" } |
               Select-Object -First 1 -ExpandProperty FullName

    if (-not $ExePath) {
        throw "Main executable not found"
    }

    Log "Running install command..."
    $p = Start-Process $ExePath "install" -Wait -PassThru

    if ($p.ExitCode -ne 0) {
        throw "Install command failed: $($p.ExitCode)"
    }

    Log "Adding PATH..."
    $path = [Environment]::GetEnvironmentVariable("Path","User")

    if ($path -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$path;$InstallDir", "User")
    }

    Log "DONE"

}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Remove-Item $TempZip,$TempExtract -Force -Recurse -ErrorAction SilentlyContinue
}
