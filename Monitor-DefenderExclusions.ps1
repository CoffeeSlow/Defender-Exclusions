if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator. Exiting..."
    exit
}

$logFile = Join-Path $PSScriptRoot "DefenderExclusions_ChangeLog.txt"
$pollInterval = 2

$regBase = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions"
$categories = @{
    Paths       = "$regBase\Paths"
    Extensions  = "$regBase\Extensions"
    Processes   = "$regBase\Processes"
    IpAddresses = "$regBase\IpAddresses"
}

function Get-ExclusionSnapshot {
    $snapshot = @{}
    foreach ($cat in $categories.Keys) {
        $path = $categories[$cat]
        if (Test-Path $path) {
            $props = Get-ItemProperty -Path $path
            $items = @()
            foreach ($prop in $props.PSObject.Properties) {
                if ($prop.Name -notlike "PS*") {
                    $items += $prop.Value
                }
            }
            $snapshot[$cat] = $items | Sort-Object
        }
        else {
            $snapshot[$cat] = @()
        }
    }
    return $snapshot
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $entry
}

function Compare-Snapshots {
    param($old, $new)
    foreach ($cat in $categories.Keys) {
        $oldItems = @($old[$cat])
        $newItems = @($new[$cat])

        $added = Compare-Object -ReferenceObject $oldItems -DifferenceObject $newItems | Where-Object { $_.SideIndicator -eq "=>" } | Select-Object -ExpandProperty InputObject
        $removed = Compare-Object -ReferenceObject $oldItems -DifferenceObject $newItems | Where-Object { $_.SideIndicator -eq "<=" } | Select-Object -ExpandProperty InputObject

        foreach ($item in $added) {
            $msg = "ADDED [$cat]: $item"
            Write-Host "  [ADDED]    [$cat] $item" -ForegroundColor Green
            Write-Log $msg
        }

        foreach ($item in $removed) {
            $msg = "REMOVED [$cat]: $item"
            Write-Host "  [REMOVED]  [$cat] $item" -ForegroundColor Red
            Write-Log $msg
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Defender Exclusions Monitor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Polling interval: ${pollInterval}s" -ForegroundColor DarkGray
Write-Host "  Log file: $logFile" -ForegroundColor DarkGray
Write-Host "  Press Ctrl+C to stop" -ForegroundColor DarkGray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Capturing baseline..." -ForegroundColor Yellow
$previous = Get-ExclusionSnapshot

$total = 0
foreach ($cat in $categories.Keys) {
    $count = $previous[$cat].Count
    $total += $count
    if ($count -gt 0) {
        Write-Host "  [$cat] ($count items)" -ForegroundColor DarkGray
        foreach ($item in $previous[$cat]) {
            Write-Host "    - $item" -ForegroundColor DarkGray
        }
    }
}
Write-Host ""
Write-Host "Monitoring for changes (total: $total exclusions)..." -ForegroundColor Green
Write-Host ""

trap {
    Write-Host ""
    Write-Host "Monitor stopped." -ForegroundColor Yellow
    break
}

while ($true) {
    try {
        Start-Sleep -Seconds $pollInterval
        $current = Get-ExclusionSnapshot
        Compare-Snapshots -old $previous -new $current
        $previous = $current
    }
    catch {
        Write-Host "  [ERROR] $_" -ForegroundColor Red
    }
}
