#Requires -Version 7
# Extracts and validates the <plan>...</plan> JSON block from claude stdout.

function Invoke-ParsePlan {
    param(
        [Parameter(Mandatory)][string]$Content
    )

    # Find all <plan>...</plan> blocks; use the last one if multiple appear.
    # Use $planMatches (not $matches) so we don't shadow the $Matches auto-variable.
    $planMatches = [regex]::Matches($Content, '(?s)<plan>(.*?)</plan>')

    if ($planMatches.Count -eq 0) {
        return @{ Error = 'No <plan> block found in content.' }
    }

    $jsonText = $planMatches[$planMatches.Count - 1].Groups[1].Value.Trim()

    $plan = $null
    try {
        $plan = $jsonText | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    } catch {
        return @{ Error = "Malformed JSON in <plan> block: $_" }
    }

    foreach ($key in @('top', 'alternatives', 'blocked')) {
        if (-not $plan.ContainsKey($key)) {
            return @{ Error = "Missing required key '$key' in plan JSON." }
        }
    }

    return @{ Plan = $plan }
}
