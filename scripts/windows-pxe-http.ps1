[CmdletBinding()]
param(
    [ValidateSet('Start', 'Status', 'Stop', 'Remove')]
    [string]$Action = 'Status',
    [string]$Address = '10.40.0.2',
    [int]$Port = 8080,
    [string]$DocumentRoot = 'C:\nuc-firpe\http',
    [string]$TaskName = 'XG040G-PXE-HTTP'
)

$ErrorActionPreference = 'Stop'

if ($Action -eq 'Status') {
    Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue |
        Select-Object TaskName, State
    Get-NetTCPConnection -LocalAddress $Address -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object LocalAddress, LocalPort, OwningProcess
    return
}

if ($Action -eq 'Stop') {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    return
}

if ($Action -eq 'Remove') {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    return
}

$python = (Get-Command python.exe -ErrorAction Stop).Source
if (-not (Test-Path $DocumentRoot -PathType Container)) {
    throw "PXE HTTP document root not found: $DocumentRoot"
}

$taskAction = New-ScheduledTaskAction -Execute $python -Argument (
    "-m http.server $Port --bind $Address --directory `"$DocumentRoot`""
)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Settings $settings `
    -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName

Start-Sleep -Seconds 2
$listener = Get-NetTCPConnection -LocalAddress $Address -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $listener) { throw "PXE HTTP server did not listen on ${Address}:$Port" }
$listener | Select-Object LocalAddress, LocalPort, OwningProcess
