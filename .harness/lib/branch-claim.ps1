function Invoke-BranchClaim {
    param(
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][int]$IssueNumber,
        [Parameter(Mandatory)][string]$Slug,
        [switch]$Resume,
        [scriptblock]$ListBranches   = { git branch -a --format='%(refname:short)' },
        [scriptblock]$CreateBranch   = { param($n) git checkout -b $n },
        [scriptblock]$CheckoutBranch = { param($n) git checkout $n }
    )

    $branchName = "$Prefix$IssueNumber-$Slug"
    $pattern    = "$Prefix$IssueNumber-*"

    $existing = @(& $ListBranches) |
        Where-Object { $_.Trim() -like $pattern } |
        Select-Object -First 1

    if ($existing) {
        if (-not $Resume) {
            throw "Branch already claimed by another terminal. To continue this work, re-run with -Resume."
        }
        & $CheckoutBranch $existing.Trim()
        return $existing.Trim()
    }

    if ($Resume) {
        throw "No matching branch found for pattern '$pattern'. Cannot resume."
    }

    & $CreateBranch $branchName
    return $branchName
}
