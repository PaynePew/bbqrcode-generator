BeforeAll {
    . "$PSScriptRoot/../lib/branch-claim.ps1"
}

Describe 'Invoke-BranchClaim' {
    It 'creates a new branch and returns its name when no matching branch exists' {
        $script:created = $null
        $result = Invoke-BranchClaim -Prefix 'kanban-issue' -IssueNumber 42 -Slug 'my-feature' `
            -ListBranches   { @() } `
            -CreateBranch   { param($n) $script:created = $n }

        $result           | Should -Be 'kanban-issue42-my-feature'
        $script:created   | Should -Be 'kanban-issue42-my-feature'
    }

    It 'throws "already claimed" when a matching branch exists and Resume is not set' {
        {
            Invoke-BranchClaim -Prefix 'kanban-issue' -IssueNumber 42 -Slug 'my-feature' `
                -ListBranches { 'kanban-issue42-existing-slug' } `
                -CreateBranch { param($n) }
        } | Should -Throw '*already claimed*'
    }

    It 'checks out the existing branch and returns its name when Resume is set' {
        $script:checkedOut = $null
        $result = Invoke-BranchClaim -Prefix 'kanban-issue' -IssueNumber 42 -Slug 'ignored' -Resume `
            -ListBranches    { 'kanban-issue42-existing-slug' } `
            -CheckoutBranch  { param($n) $script:checkedOut = $n }

        $result               | Should -Be 'kanban-issue42-existing-slug'
        $script:checkedOut    | Should -Be 'kanban-issue42-existing-slug'
    }

    It 'throws when Resume is set but no matching branch exists' {
        {
            Invoke-BranchClaim -Prefix 'kanban-issue' -IssueNumber 42 -Slug 'my-feature' -Resume `
                -ListBranches   { @() } `
                -CheckoutBranch { param($n) }
        } | Should -Throw '*Cannot resume*'
    }
}
