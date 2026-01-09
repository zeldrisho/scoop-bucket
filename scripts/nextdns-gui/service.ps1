# Check for admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "NextDNS Service setup requires administrator rights."
    Write-Host "Please run this script as administrator." -ForegroundColor Yellow
    exit 1
}

# Get current directory
$dir = $PSScriptRoot
Write-Host "Setting up NextDNS Service..." -ForegroundColor Cyan
Write-Host "Directory: $dir"

# Check for service executable
$servicePath = "$dir\NextDNSService.exe"
if (-not (Test-Path $servicePath)) {
    Write-Error "NextDNSService.exe not found at: $servicePath"
    exit 1
}

# Check for driver INF file
$driverPath = "$dir\Driver\NextDNSEngine.inf"
if (-not (Test-Path $driverPath)) {
    Write-Error "NextDNSEngine.inf not found at: $driverPath"
    exit 1
}

# Install the driver
Write-Host "`nInstalling NextDNS Driver..." -ForegroundColor Cyan
try {
    $pnpOutput = pnputil.exe /add-driver "$driverPath" /install
    Write-Host $pnpOutput
    Write-Host "Driver installed successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to install driver: $_"
    exit 1
}

# Remove existing service if it exists
$existingService = Get-Service -Name "NextDNSService" -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "`nRemoving existing NextDNS Service..."
    Stop-Service -Name "NextDNSService" -Force -ErrorAction SilentlyContinue
    sc.exe delete "NextDNSService" | Out-Null
    Start-Sleep -Seconds 2
}

# Create new service
Write-Host "Creating NextDNS Service..."
try {
    New-Service -Name "NextDNSService" -BinaryPathName "$servicePath" -DisplayName "NextDNS Service" -ErrorAction Stop | Out-Null
    Write-Host "Service created successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to create service: $_"
    exit 1
}

# Start the service
Write-Host "Starting NextDNS Service..."
try {
    Start-Service -Name "NextDNSService" -ErrorAction Stop
    Write-Host "Service started successfully." -ForegroundColor Green
} catch {
    Write-Warning "Failed to start service: $_"
    Write-Host "You can manually start the service later." -ForegroundColor Yellow
}

Write-Host "`nNextDNS Service and Driver setup completed successfully!" -ForegroundColor Green
