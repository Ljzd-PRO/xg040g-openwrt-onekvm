[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$VmName,
    [Parameter(Mandatory)]
    [string]$TaskPrefix,
    [Parameter(Mandatory)]
    [string]$CaptureScript,
    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 4)

$connectAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\vmconnect.exe" `
    -Argument "localhost $VmName"
Register-ScheduledTask -TaskName "$TaskPrefix-VMConnect" -Action $connectAction `
    -Principal $principal -Settings $settings -Force | Out-Null

$captureAction = New-ScheduledTaskAction `
    -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$CaptureScript`" -VMName `"$VmName`" -OutputPath `"$OutputPath`""
Register-ScheduledTask -TaskName "$TaskPrefix-Capture" -Action $captureAction `
    -Principal $principal -Settings $settings -Force | Out-Null

Get-ScheduledTask -TaskName "$TaskPrefix-VMConnect", "$TaskPrefix-Capture"
