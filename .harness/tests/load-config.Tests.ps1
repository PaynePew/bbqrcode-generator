BeforeAll {
    . "$PSScriptRoot/../lib/load-config.ps1"
    $script:Fixtures = "$PSScriptRoot/fixtures"
}

Describe 'Import-HarnessConfig' {
    It 'loads a valid config and returns required keys' {
        $cfg = Import-HarnessConfig -ConfigPath "$script:Fixtures/valid-config.yml"
        $cfg.image        | Should -Be 'agent-harness:latest'
        $cfg.branch_prefix | Should -Be 'kanban-issue'
        $cfg.tracker.type | Should -Be 'github'
    }

    It 'applies default model when not specified' {
        $cfg = Import-HarnessConfig -ConfigPath "$script:Fixtures/minimal-config.yml"
        $cfg.defaults.model | Should -Be 'claude-sonnet-4-6'
    }

    It 'preserves explicit model override' {
        $cfg = Import-HarnessConfig -ConfigPath "$script:Fixtures/valid-config.yml"
        $cfg.defaults.model | Should -Be 'claude-opus-4-7'
    }

    It 'throws when image key is missing' {
        { Import-HarnessConfig -ConfigPath "$script:Fixtures/missing-image.yml" } |
            Should -Throw '*image*'
    }

    It 'throws when branch_prefix key is missing' {
        { Import-HarnessConfig -ConfigPath "$script:Fixtures/missing-branch-prefix.yml" } |
            Should -Throw '*branch_prefix*'
    }

    It 'throws when tracker.type key is missing' {
        { Import-HarnessConfig -ConfigPath "$script:Fixtures/missing-tracker-type.yml" } |
            Should -Throw '*tracker.type*'
    }

    It 'throws when tracker.type is not github' {
        { Import-HarnessConfig -ConfigPath "$script:Fixtures/invalid-tracker-type.yml" } |
            Should -Throw '*github*'
    }
}
