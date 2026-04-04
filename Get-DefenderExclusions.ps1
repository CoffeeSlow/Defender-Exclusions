if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator. Exiting..."
    exit
}
Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions" -Recurse | ForEach-Object {
    Write-Host "==============================================================" -ForegroundColor DarkCyan
    Write-Host "[$($_.PSPath)]" -ForegroundColor Yellow
    $properties = Get-ItemProperty -Path $_.PSPath
    foreach ($prop in $properties.PSObject.Properties) {
        Write-Host "$($prop.Name) = $($prop.Value)" -ForegroundColor Green
    }
}
