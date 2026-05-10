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
        # Skip comments and blank lines
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }

        if ($line -match '^([A-Za-z][A-Za-z0-9_-]*): *(.*)$') {
            $k = $Matches[1]; $v = $Matches[2].Trim()
            if ($v -eq '') {
                $config[$k] = @{}
                $currentParent = $k
            } else {
                $config[$k] = $v
                $currentParent = $null
            }
        } elseif ($line -match '^  ([A-Za-z][A-Za-z0-9_-]*): *(.+)$' -and $currentParent) {
            $ck = $Matches[1]; $cv = $Matches[2].Trim()
            if ($config[$currentParent] -isnot [hashtable]) { $config[$currentParent] = @{} }
            $config[$currentParent][$ck] = $cv
        }
    }

    # Validate required keys
    foreach ($key in @('image', 'branch_prefix')) {
        if (-not $config[$key]) {
            throw "Missing required config key: $key. Check .harness/config.yml."
        }
    }

    if (-not ($config['tracker'] -is [hashtable]) -or -not $config['tracker']['type']) {
        throw "Missing required config key: tracker.type. Check .harness/config.yml."
    }
    if ($config['tracker']['type'] -ne 'github') {
        throw "tracker.type must be 'github' (v1 only supports github). Got: $($config['tracker']['type'])"
    }

    # Apply defaults
    if ($config['defaults'] -isnot [hashtable]) { $config['defaults'] = @{} }
    if (-not $config['defaults']['model']) { $config['defaults']['model'] = 'claude-sonnet-4-6' }

    return $config
}
