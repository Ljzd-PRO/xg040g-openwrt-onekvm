[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$VmName,
    [string]$HttpTaskName = 'XG040G-PXE-HTTP',
    [string]$HttpLog = 'C:\nuc-firpe\logs\pxe-http.log'
)

$ErrorActionPreference = 'Stop'

$vm = Get-VM -Name $VmName -ErrorAction Stop
if ($vm.State -ne 'Off') {
    Stop-VM -Name $VmName -TurnOff -Force
}

$task = Get-ScheduledTask -TaskName $HttpTaskName -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName $HttpTaskName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    if (Test-Path $HttpLog) {
        $archive = '{0}.{1}.previous' -f $HttpLog, (Get-Date -Format 'yyyyMMdd-HHmmss')
        Move-Item -LiteralPath $HttpLog -Destination $archive -Force
    }

    Start-ScheduledTask -TaskName $HttpTaskName
    $deadline = (Get-Date).AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 500
        $listener = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
    } until ($listener -or (Get-Date) -ge $deadline)
    if (-not $listener) { throw 'PXE HTTP server did not listen on port 8080.' }
}

Start-VM -Name $VmName
[pscustomobject]@{
    VmName = $VmName
    StartedAt = Get-Date -Format o
    State = (Get-VM -Name $VmName).State
    HttpLog = $HttpLog
}
