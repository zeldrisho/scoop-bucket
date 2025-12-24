# Check for admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error "ProtonVPN Service setup requires administrator rights."
    Write-Host "Please run this script as administrator." -ForegroundColor Yellow
    exit 1
}

# Get current directory
$dir = $PSScriptRoot

# Get version from subdirectory name (e.g., "v4.3.11")
$versionDir = Get-ChildItem -Path $dir -Directory | Where-Object { $_.Name -match '^v([\d.]+)$' } | Select-Object -First 1
if (-not $versionDir) {
    Write-Error "Version directory not found in $dir"
    exit 1
}
$version = $versionDir.Name.TrimStart('v')

Write-Host "Setting up ProtonVPN Service..." -ForegroundColor Cyan
Write-Host "Directory: $dir"
Write-Host "Version: $version"

# Create the service
$servicePath = "$dir\$($versionDir.Name)\ProtonVPNService.exe"
if (-not (Test-Path $servicePath)) {
    Write-Error "ProtonVPNService.exe not found at: $servicePath"
    exit 1
}

# Remove existing service if it exists
$existingService = Get-Service -Name "ProtonVPN Service" -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Removing existing ProtonVPN Service..."
    Stop-Service -Name "ProtonVPN Service" -Force -ErrorAction SilentlyContinue
    sc.exe delete "ProtonVPN Service" | Out-Null
    Start-Sleep -Seconds 2
}

# Create new service
Write-Host "Creating ProtonVPN Service..."
try {
    New-Service -Name "ProtonVPN Service" -BinaryPathName "$servicePath" -StartupType Manual -DependsOn 'Tcpip' -DisplayName "ProtonVPN Service" -ErrorAction Stop | Out-Null
    Write-Host "Service created successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to create service: $_"
    exit 1
}

# Modify shortcut to run as administrator
$shortcut = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Scoop Apps\Proton\Proton VPN.lnk"
if (Test-Path $shortcut) {
    Write-Host "Modifying shortcut to run as administrator..."
    try {
        $bytes = [System.IO.File]::ReadAllBytes($shortcut)
        $bytes[0x15] = $bytes[0x15] -bor 0x20
        [System.IO.File]::WriteAllBytes($shortcut, $bytes)
        Write-Host "Shortcut modified successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to modify shortcut: $_"
    }
} else {
    Write-Warning "Shortcut not found at: $shortcut"
}

Write-Host "`nProtonVPN Service setup completed successfully!" -ForegroundColor Green
Write-Host "You can now start the ProtonVPN application." -ForegroundColor Cyan
