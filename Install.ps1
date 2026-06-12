#Requires -Version 5.1

# ============================================================
#  ACME LIVE INSTALLER
#  Auto-elevates to admin if needed
# ============================================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # Save this script to a temp file
    $scriptContent = @'
#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# ============================================================
#  CONFIGURATION
# ============================================================
$AppName     = "acmelive"
$ServiceName = "AcmeClient"
$InstallDir  = "$env:LOCALAPPDATA\Acme\$AppName"
$TempZip     = "$env:TEMP\$AppName.zip"
$TempExtract = "$env:TEMP\$AppName-extract"
$DownloadUrl = "http://web.acmetech.com.np/acmeupdate/acmelive/acmelive.zip"

# ============================================================
#  HELPERS
# ============================================================
function Write-Step { param([string]$msg) Write-Host "`n  --> $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "      [OK] $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "      [!!] $msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$msg) Write-Host "      [XX] $msg" -ForegroundColor Red }

function Write-Banner {
    $border = "=" * 54
    Write-Host ""
    Write-Host "  $border"             -ForegroundColor DarkCyan
    Write-Host "    Acme Installer  |  $(Get-Date -Format 'yyyy-MM-dd  HH:mm:ss')" -ForegroundColor White
    Write-Host "  $border"             -ForegroundColor DarkCyan
    Write-Host ""
}

# ============================================================
#  MAIN INSTALLATION
# ============================================================
Write-Banner

try {

    # ----------------------------------------------------------
    # 1. DOWNLOAD PACKAGE
    # ----------------------------------------------------------
    Write-Step "Downloading package..."
    Write-Host "      URL : $DownloadUrl" -ForegroundColor DarkGray

    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($DownloadUrl, $TempZip)

    $sizeMB = [math]::Round((Get-Item $TempZip).Length / 1MB, 2)
    Write-Ok "Download complete  ($sizeMB MB  ->  $TempZip)"


    # ----------------------------------------------------------
    # 2. REMOVE OLD SERVICE  (only after download succeeds)
    # ----------------------------------------------------------
    Write-Step "Checking for existing service..."

    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -eq "Running") {
            Write-Host "      Stopping service..." -ForegroundColor DarkGray
            try   { Stop-Service -Name $ServiceName -Force -ErrorAction Stop; Write-Ok "Service stopped." }
            catch { Write-Warn "Could not stop service: $($_.Exception.Message)" }
        }
        Write-Host "      Removing service..." -ForegroundColor DarkGray
        sc.exe delete $ServiceName | Out-Null
        Write-Ok "Service removed."
    }
    else {
        Write-Ok "No existing service — nothing to remove."
    }


    # ----------------------------------------------------------
    # 3. EXTRACT PACKAGE
    # ----------------------------------------------------------
    Write-Step "Extracting package..."

    if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
    Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
    Write-Ok "Extracted to  $TempExtract"


    # ----------------------------------------------------------
    # 4. INSTALL FILES
    # ----------------------------------------------------------
    Write-Step "Installing files to  $InstallDir ..."

    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
    Copy-Item "$TempExtract\*" $InstallDir -Recurse -Force
    Write-Ok "Files copied."


    # ----------------------------------------------------------
    # 5. LOCATE acmelive.exe
    # ----------------------------------------------------------
    Write-Step "Locating main executable..."

    $ExePath = Join-Path $InstallDir "$AppName.exe"
    if (-not (Test-Path $ExePath)) { throw "Executable not found: $ExePath" }
    Write-Ok "Found  $ExePath"


    # ----------------------------------------------------------
    # 6. RUN acmelive.exe install
    # ----------------------------------------------------------
    Write-Step "Running acmelive.exe install command..."

    $proc = Start-Process -FilePath $ExePath -ArgumentList "install" -Wait -PassThru
    if ($proc.ExitCode -ne 0) { throw "acmelive install exited with code $($proc.ExitCode)" }
    Write-Ok "acmelive install completed."


    # ----------------------------------------------------------
    # 7. ADD TO PATH
    # ----------------------------------------------------------
    Write-Step "Adding to PATH..."

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$InstallDir", "User")
        $env:Path += ";$InstallDir"
        Write-Ok "Added to PATH  ->  $InstallDir"
    } else {
        Write-Ok "Already in PATH — skipping."
    }


    # ----------------------------------------------------------
    # DONE
    # ----------------------------------------------------------
    Write-Host ""
    Write-Host "  =============================================" -ForegroundColor DarkCyan
    Write-Host "   Installation complete!  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
    Write-Host "  =============================================" -ForegroundColor DarkCyan
    Write-Host ""

}
catch {
    Write-Host ""
    Write-Fail "Installation failed: $($_.Exception.Message)"
    Write-Host ""
}
finally {
    Write-Step "Cleaning up temporary files..."
    Remove-Item $TempZip     -Force          -ErrorAction SilentlyContinue
    Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok "Cleanup done."
    Write-Host ""
}

Read-Host "  Press Enter to close"
'@

    $tmpFile = "$env:TEMP\AcmeInstall-admin.ps1"
    $scriptContent | Out-File -FilePath $tmpFile -Encoding UTF8 -Force

    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    Write-Host ""

    # Launch admin window and wait
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File `"$tmpFile`"" -Wait

    exit
}

# Script is already running as admin, so just run the embedded script directly
$ErrorActionPreference = "Stop"

# ============================================================
#  CONFIGURATION
# ============================================================
$AppName     = "acmelive"
$ServiceName = "AcmeClient"
$InstallDir  = "$env:LOCALAPPDATA\Acme\$AppName"
$TempZip     = "$env:TEMP\$AppName.zip"
$TempExtract = "$env:TEMP\$AppName-extract"
$DownloadUrl = "http://web.acmetech.com.np/acmeupdate/acmelive/acmelive.zip"

# ============================================================
#  HELPERS
# ============================================================
function Write-Step { param([string]$msg) Write-Host "`n  --> $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "      [OK] $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "      [!!] $msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$msg) Write-Host "      [XX] $msg" -ForegroundColor Red }

function Write-Banner {
    $border = "=" * 54
    Write-Host ""
    Write-Host "  $border"             -ForegroundColor DarkCyan
    Write-Host "    Acme Installer  |  $(Get-Date -Format 'yyyy-MM-dd  HH:mm:ss')" -ForegroundColor White
    Write-Host "  $border"             -ForegroundColor DarkCyan
    Write-Host ""
}

# ============================================================
#  MAIN INSTALLATION
# ============================================================
Write-Banner

try {

    # ----------------------------------------------------------
    # 1. DOWNLOAD PACKAGE
    # ----------------------------------------------------------
    Write-Step "Downloading package..."
    Write-Host "      URL : $DownloadUrl" -ForegroundColor DarkGray

    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($DownloadUrl, $TempZip)

    $sizeMB = [math]::Round((Get-Item $TempZip).Length / 1MB, 2)
    Write-Ok "Download complete  ($sizeMB MB  ->  $TempZip)"


    # ----------------------------------------------------------
    # 2. REMOVE OLD SERVICE  (only after download succeeds)
    # ----------------------------------------------------------
    Write-Step "Checking for existing service..."

    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -eq "Running") {
            Write-Host "      Stopping service..." -ForegroundColor DarkGray
            try   { Stop-Service -Name $ServiceName -Force -ErrorAction Stop; Write-Ok "Service stopped." }
            catch { Write-Warn "Could not stop service: $($_.Exception.Message)" }
        }
        Write-Host "      Removing service..." -ForegroundColor DarkGray
        sc.exe delete $ServiceName | Out-Null
        Write-Ok "Service removed."
    }
    else {
        Write-Ok "No existing service — nothing to remove."
    }


    # ----------------------------------------------------------
    # 3. EXTRACT PACKAGE
    # ----------------------------------------------------------
    Write-Step "Extracting package..."

    if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
    Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
    Write-Ok "Extracted to  $TempExtract"


    # ----------------------------------------------------------
    # 4. INSTALL FILES
    # ----------------------------------------------------------
    Write-Step "Installing files to  $InstallDir ..."

    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
    Copy-Item "$TempExtract\*" $InstallDir -Recurse -Force
    Write-Ok "Files copied."


    # ----------------------------------------------------------
    # 5. LOCATE acmelive.exe
    # ----------------------------------------------------------
    Write-Step "Locating main executable..."

    $ExePath = Join-Path $InstallDir "$AppName.exe"
    if (-not (Test-Path $ExePath)) { throw "Executable not found: $ExePath" }
    Write-Ok "Found  $ExePath"


    # ----------------------------------------------------------
    # 6. RUN acmelive.exe install
    # ----------------------------------------------------------
    Write-Step "Running acmelive.exe install command..."

    $proc = Start-Process -FilePath $ExePath -ArgumentList "install" -Wait -PassThru
    if ($proc.ExitCode -ne 0) { throw "acmelive install exited with code $($proc.ExitCode)" }
    Write-Ok "acmelive install completed."


    # ----------------------------------------------------------
    # 7. ADD TO PATH
    # ----------------------------------------------------------
    Write-Step "Adding to PATH..."

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$InstallDir", "User")
        $env:Path += ";$InstallDir"
        Write-Ok "Added to PATH  ->  $InstallDir"
    } else {
        Write-Ok "Already in PATH — skipping."
    }


    # ----------------------------------------------------------
    # DONE
    # ----------------------------------------------------------
    Write-Host ""
    Write-Host "  =============================================" -ForegroundColor DarkCyan
    Write-Host "   Installation complete!  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
    Write-Host "  =============================================" -ForegroundColor DarkCyan
    Write-Host ""

}
catch {
    Write-Host ""
    Write-Fail "Installation failed: $($_.Exception.Message)"
    Write-Host ""
}
finally {
    Write-Step "Cleaning up temporary files..."
    Remove-Item $TempZip     -Force          -ErrorAction SilentlyContinue
    Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok "Cleanup done."
    Write-Host ""
}

Read-Host "  Press Enter to close"
