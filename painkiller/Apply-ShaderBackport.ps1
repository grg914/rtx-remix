# Apply only to the GOG Painkiller RTX DXVK source baseline.
[CmdletBinding()]
param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'dxvk-remix'
$patch = Join-Path $root 'painkiller/patches/0001-selective-shader-optimizations.patch'
$baseline = '24af3f49cfd326e7d79de84632dfb07809ae286a'
function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$GitArgs)
    & git -C $source @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "git failed (exit $LASTEXITCODE): $GitArgs" }
}
if (!(Test-Path (Join-Path $source '.git'))) {
    throw 'Initialize the pinned submodule first: git submodule update --init dxvk-remix'
}
$head = (Invoke-Git rev-parse HEAD).Trim()
if ($head -ne $baseline) { throw "Unexpected DXVK revision: $head" }
$dirty = @(Invoke-Git status --porcelain --untracked-files=normal)
if ($dirty.Count -ne 0) { throw 'DXVK worktree must be clean; preserve your changes first.' }
Invoke-Git apply --check $patch
Write-Host 'Patch context check passed.'
if ($Apply) {
    Invoke-Git apply $patch
    Invoke-Git diff --check
    Invoke-Git diff --stat
    Write-Host 'Experimental source changes applied locally. Build and test before deployment.'
} else {
    Write-Host 'Dry run only. Use -Apply to modify the local submodule.'
}
