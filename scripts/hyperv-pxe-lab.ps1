[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Create', 'Status', 'Cleanup')]
    [string]$Action = 'Status',
    [string]$AdapterDescription = 'Intel(R) Ethernet Connection (17) I219-V',
    [string]$SwitchName = 'XG040G-PXE-PORT',
    [string]$UefiVmName = 'XG040G-PXE-UEFI-VERIFY',
    [string]$BiosVmName = 'XG040G-PXE-BIOS-VERIFY',
    [string]$HostAddress = '10.40.0.2',
    [string]$StateDirectory = 'C:\xg040g-pxe-lab'
)

$ErrorActionPreference = 'Stop'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this script from an elevated PowerShell session.'
    }
}

function Get-LabStatus {
    [pscustomobject]@{
        Switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
        UefiVm = Get-VM -Name $UefiVmName -ErrorAction SilentlyContinue
        BiosVm = Get-VM -Name $BiosVmName -ErrorAction SilentlyContinue
        Adapter = Get-NetAdapter | Where-Object InterfaceDescription -EQ $AdapterDescription
    }
}

if ($Action -eq 'Status') {
    Get-LabStatus | Format-List
    return
}

Assert-Administrator

if ($Action -eq 'Create') {
    $adapter = Get-NetAdapter | Where-Object InterfaceDescription -EQ $AdapterDescription
    if (-not $adapter) { throw "Physical adapter not found: $AdapterDescription" }

    New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
    if (-not (Test-Path "$StateDirectory\network-before.json")) {
        [pscustomobject]@{
            CapturedAt = Get-Date -Format o
            Adapter = $adapter | Select-Object Name, InterfaceDescription, Status, MacAddress
            Addresses = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue |
                Select-Object AddressFamily, IPAddress, PrefixLength, PrefixOrigin, SuffixOrigin
            Dns = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue |
                Select-Object AddressFamily, ServerAddresses
        } | ConvertTo-Json -Depth 5 | Set-Content "$StateDirectory\network-before.json" -Encoding utf8
    }

    if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
        New-VMSwitch -Name $SwitchName -NetAdapterName $adapter.Name -AllowManagementOS $true | Out-Null
    }

    $managementAdapter = Get-NetAdapter | Where-Object Name -EQ "vEthernet ($SwitchName)"
    if (-not $managementAdapter) { throw "Management vNIC not found for $SwitchName" }
    Set-NetIPInterface -InterfaceIndex $managementAdapter.ifIndex -AddressFamily IPv4 -Dhcp Disabled
    Get-NetIPAddress -InterfaceIndex $managementAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object IPAddress -NE $HostAddress |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    if (-not (Get-NetIPAddress -InterfaceIndex $managementAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object IPAddress -EQ $HostAddress)) {
        New-NetIPAddress -InterfaceIndex $managementAdapter.ifIndex -IPAddress $HostAddress -PrefixLength 24 | Out-Null
    }

    if (-not (Get-VM -Name $UefiVmName -ErrorAction SilentlyContinue)) {
        New-VM -Name $UefiVmName -Generation 2 -NoVHD -MemoryStartupBytes 4GB -SwitchName $SwitchName | Out-Null
        Set-VMProcessor -VMName $UefiVmName -Count 2
        Set-VMMemory -VMName $UefiVmName -DynamicMemoryEnabled $false
        $nic = Get-VMNetworkAdapter -VMName $UefiVmName
        Set-VMFirmware -VMName $UefiVmName -EnableSecureBoot Off -FirstBootDevice $nic
    }

    if (-not (Get-VM -Name $BiosVmName -ErrorAction SilentlyContinue)) {
        New-VM -Name $BiosVmName -Generation 1 -NoVHD -MemoryStartupBytes 2GB | Out-Null
        Set-VMProcessor -VMName $BiosVmName -Count 1
        Get-VMNetworkAdapter -VMName $BiosVmName -ErrorAction SilentlyContinue | Remove-VMNetworkAdapter
        Add-VMNetworkAdapter -VMName $BiosVmName -SwitchName $SwitchName -IsLegacy $true
    }

    Get-LabStatus | Format-List
    return
}

foreach ($name in @($UefiVmName, $BiosVmName)) {
    $vm = Get-VM -Name $name -ErrorAction SilentlyContinue
    if ($vm) {
        if ($vm.State -ne 'Off') { Stop-VM -Name $name -TurnOff -Force }
        Remove-VM -Name $name -Force
    }
}

$switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if ($switch) { Remove-VMSwitch -Name $SwitchName -Force }

$snapshotPath = "$StateDirectory\network-before.json"
if (Test-Path $snapshotPath) {
    $snapshot = Get-Content $snapshotPath -Raw | ConvertFrom-Json
    $adapter = Get-NetAdapter | Where-Object InterfaceDescription -EQ $AdapterDescription
    if ($adapter) {
        Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        $ipv4 = @($snapshot.Addresses | Where-Object AddressFamily -EQ 2)
        if ($ipv4.Count) {
            Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -Dhcp Disabled
            foreach ($address in $ipv4) {
                New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $address.IPAddress `
                    -PrefixLength $address.PrefixLength -ErrorAction SilentlyContinue | Out-Null
            }
        } else {
            Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -Dhcp Enabled
        }
    }
}

Write-Host "Removed Hyper-V PXE lab resources and restored the saved physical adapter addresses."
