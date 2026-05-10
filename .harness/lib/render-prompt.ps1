function Invoke-RenderPrompt {
    param(
        [string]$Template,
        [hashtable]$Substitutions = @{}
    )

    if ($Template -eq '') { return '' }

    $lines = ($Template -replace "`r`n", "`n") -split "`n"
    $output = foreach ($line in $lines) {
        $rendered = $line
        foreach ($key in $Substitutions.Keys) {
            $rendered = $rendered -replace [regex]::Escape("{{$key}}"), $Substitutions[$key]
        }
        # Replace remaining unresolved {{...}} placeholders with empty string
        $rendered = $rendered -replace '\{\{[A-Z_0-9]+\}\}', ''
        # Drop line if it is blank after substitution
        if ($rendered.Trim() -eq '') { continue }
        $rendered
    }
    return ($output -join "`n")
}
