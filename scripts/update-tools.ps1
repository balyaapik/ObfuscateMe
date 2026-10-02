param(
    [string]$Destination
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Destination = Join-Path $RootDir "lib"
}

$VersionsFile = Join-Path $RootDir "tools\tool-versions.env"
if (-not (Test-Path $VersionsFile)) {
    throw "Missing $VersionsFile"
}

$values = @{}
Get-Content $VersionsFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line.Split("=", 2)
        if ($parts.Length -eq 2) {
            $values[$parts[0]] = $parts[1]
        }
    }
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null

function Get-AndVerifyTool {
    param(
        [string]$Url,
        [string]$Target,
        [string]$ExpectedSha256,
        [string]$Label
    )

    $temp = "$Target.tmp"
    Remove-Item $temp -Force -ErrorAction SilentlyContinue

    Write-Host "Downloading $Label..."
    Invoke-WebRequest -Uri $Url -OutFile $temp

    $actual = (Get-FileHash -Path $temp -Algorithm SHA256).Hash.ToLowerInvariant()
    $expected = $ExpectedSha256.ToLowerInvariant()
    if ($actual -ne $expected) {
        Remove-Item $temp -Force -ErrorAction SilentlyContinue
        throw "$Label checksum mismatch. Expected $expected, got $actual"
    }

    Move-Item -Path $temp -Destination $Target -Force
    Write-Host "$Label verified: $actual"
}

Get-AndVerifyTool -Url $values["APKTOOL_URL"] -Target (Join-Path $Destination "apktool.jar") -ExpectedSha256 $values["APKTOOL_SHA256"] -Label "Apktool $($values["APKTOOL_VERSION"])"
Get-AndVerifyTool -Url $values["UBER_SIGNER_URL"] -Target (Join-Path $Destination "uber-apk-signer.jar") -ExpectedSha256 $values["UBER_SIGNER_SHA256"] -Label "Uber APK Signer $($values["UBER_SIGNER_VERSION"])"

Write-Host ""
Write-Host "Installed Android tools into: $Destination"
& java -jar (Join-Path $Destination "apktool.jar") --version
& java -jar (Join-Path $Destination "uber-apk-signer.jar") --version
