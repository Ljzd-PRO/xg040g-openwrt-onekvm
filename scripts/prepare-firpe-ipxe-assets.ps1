[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$HttpRoot
)

$ErrorActionPreference = 'Stop'

$assets = @(
    [pscustomobject]@{
        Name = 'wimboot'
        RelativePath = 'wimboot'
        Uri = 'https://github.com/ipxe/wimboot/releases/download/v2.9.0/wimboot'
        Sha256 = '5f067ccdc4d084d5bf77b6c853bd0f8402dfc2b4cd1b103d358993ae97fae8e3'
    },
    [pscustomobject]@{
        Name = 'PXEBCD'
        RelativePath = 'firpe\PXEBCD'
        Uri = 'https://raw.githubusercontent.com/NiKiZe/wimboot-bcd/52bf5b2b10124684c8a440c1b31d82faa3d7510c/PXEBCD'
        Sha256 = 'cdfbe2ed2be42e15ee4832f2c73893607db2ca4c95c34df9e0b61568845b4de2'
    }
)

New-Item -ItemType Directory -Path $HttpRoot -Force | Out-Null

foreach ($asset in $assets) {
    $destination = Join-Path $HttpRoot $asset.RelativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    $temporary = "$destination.download"
    Invoke-WebRequest -UseBasicParsing -Uri $asset.Uri -OutFile $temporary
    $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $asset.Sha256) {
        Remove-Item -LiteralPath $temporary -Force
        throw "SHA256 mismatch for $($asset.Name): $actual"
    }
    Move-Item -LiteralPath $temporary -Destination $destination -Force
    [pscustomobject]@{ Name = $asset.Name; Sha256 = $actual; Path = $destination }
}
