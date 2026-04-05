if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator. Exiting..."
    exit
}

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

function Show-Exclusions {
    param($snapshot)
    $total = 0
    foreach ($cat in $categories.Keys) {
        $items = $snapshot[$cat]
        $count = $items.Count
        $total += $count
        if ($count -gt 0) {
            Write-Host "  [$cat] ($count)" -ForegroundColor Yellow
            foreach ($item in $items) {
                Write-Host "    - $item" -ForegroundColor White
            }
            Write-Host ""
        }
    }
    return $total
}

function Show-Changes {
    param($old, $new)
    foreach ($cat in $categories.Keys) {
        $oldItems = @($old[$cat])
        $newItems = @($new[$cat])

        $added = Compare-Object -ReferenceObject $oldItems -DifferenceObject $newItems | Where-Object { $_.SideIndicator -eq "=>" } | Select-Object -ExpandProperty InputObject
        $removed = Compare-Object -ReferenceObject $oldItems -DifferenceObject $newItems | Where-Object { $_.SideIndicator -eq "<=" } | Select-Object -ExpandProperty InputObject

        foreach ($item in $added) {
            Write-Host "  [ADDED]    [$cat] $item" -ForegroundColor Green
        }
        foreach ($item in $removed) {
            Write-Host "  [REMOVED]  [$cat] $item" -ForegroundColor Red
        }
    }
}

$sep = "=" * 50
$previous = Get-ExclusionSnapshot

trap {
    Write-Host "`nMonitor stopped." -ForegroundColor Yellow
    break
}

while ($true) {
    Clear-Host
    Write-Host $sep -ForegroundColor Cyan
    Write-Host "  Windows Defender Exclusions (Live)" -ForegroundColor Cyan
    Write-Host "  Refresh: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
    Write-Host $sep -ForegroundColor Cyan
    Write-Host ""

    $current = Get-ExclusionSnapshot

    if ($previous) {
        Show-Changes -old $previous -new $current
        Write-Host ""
    }

    $total = Show-Exclusions -snapshot $current
    Write-Host $sep -ForegroundColor Cyan
    Write-Host "  Total: $total exclusions | Refreshing every ${pollInterval}s | Ctrl+C to stop" -ForegroundColor DarkGray
    Write-Host $sep -ForegroundColor Cyan

    $previous = $current
    Start-Sleep -Seconds $pollInterval
}
