function Test-ImageRebuildNeeded {
    param(
        [Parameter(Mandatory)][string]$DockerfilePath,
        [Parameter(Mandatory)][string]$MarkerPath
    )

    if (-not (Test-Path $DockerfilePath)) { return $true }
    if (-not (Test-Path $MarkerPath))     { return $true }

    $current = (Get-FileHash $DockerfilePath -Algorithm SHA256).Hash

    $stored = $null
    try { $stored = (Get-Content $MarkerPath -Raw -ErrorAction Stop).Trim() }
    catch { return $true }

    if ([string]::IsNullOrEmpty($stored)) { return $true }

    return ($current -ne $stored)
}

function Save-ImageHash {
    param(
        [Parameter(Mandatory)][string]$DockerfilePath,
        [Parameter(Mandatory)][string]$MarkerPath
    )
    $hash = (Get-FileHash $DockerfilePath -Algorithm SHA256).Hash
    Set-Content -Path $MarkerPath -Value $hash -NoNewline
}
