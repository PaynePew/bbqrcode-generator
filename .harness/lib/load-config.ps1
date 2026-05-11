function Import-HarnessConfig {
    param(
        [Parameter(Mandatory)][string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = @{}
    $currentParent = $null

    foreach ($line in (Get-Content $ConfigPath)) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }

        if ($line -match '^([A-Za-z][A-Za-z0-9_-]*): *(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            if ($value -eq '') {
                $config[$key] = @{}
                $currentParent = $key
            } else {
                $config[$key] = $value
                $currentParent = $null
            }
        } elseif ($line -match '^  ([A-Za-z][A-Za-z0-9_-]*): *(.+)$' -and $currentParent) {
            $childKey = $Matches[1]
            $childValue = $Matches[2].Trim()
            if ($config[$currentParent] -isnot [hashtable]) { $config[$currentParent] = @{} }
            $config[$currentParent][$childKey] = $childValue
        }
    }

    foreach ($key in @('image', 'branch_prefix')) {
        if (-not $config[$key]) {
            throw "Missing required config key '$key' in $ConfigPath."
        }
    }

    if (-not ($config['tracker'] -is [hashtable]) -or -not $config['tracker']['type']) {
        throw "Missing required config key 'tracker.type' in $ConfigPath."
    }
    if ($config['tracker']['type'] -ne 'github') {
        throw "tracker.type must be 'github' (v1 only supports github). Got: '$($config['tracker']['type'])' in $ConfigPath."
    }

    if ($config['defaults'] -isnot [hashtable]) { $config['defaults'] = @{} }
    if (-not $config['defaults']['model']) { $config['defaults']['model'] = 'claude-sonnet-4-6' }

    return $config
}
