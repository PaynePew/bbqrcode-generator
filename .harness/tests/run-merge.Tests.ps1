BeforeAll {
    $script:RunScript  = "$PSScriptRoot/../run.ps1"
    $script:RunContent = Get-Content $script:RunScript -Raw
    . "$PSScriptRoot/../lib/load-config.ps1"
}

Describe 'run.ps1 merge phase — parameters' {
    It 'declares a -SkipMerge switch parameter' {
        $script:RunContent | Should -Match '\[switch\]\$SkipMerge'
    }

    It 'documents -SkipMerge in the synopsis block' {
        $script:RunContent | Should -Match 'SkipMerge'
    }
}

Describe 'run.ps1 merge phase — config wiring' {
    It 'reads agents.merge.model from config' {
        $script:RunContent | Should -Match "agents\.merge\.model|agents\['merge'\]"
    }

    It 'reads agents.merge.max_turns from config' {
        $script:RunContent | Should -Match "agents\.merge\.max_turns|agents\['merge'\]"
    }
}

Describe 'run.ps1 merge phase — separate docker run' {
    It 'contains at least three docker run invocation sites (implement, review, merge)' {
        $matches = [regex]::Matches($script:RunContent, "docker\s+@docker")
        $matches.Count | Should -BeGreaterOrEqual 3
    }

    It 'contains a merge phase step label' {
        $script:RunContent | Should -Match 'Merge phase|merge phase'
    }
}

Describe 'run.ps1 merge phase — final summary box' {
    It 'contains a unified final summary box header' {
        $script:RunContent | Should -Match 'Pipeline result|final summary'
    }

    It 'shows per-phase status with checkmark symbol for success' {
        $script:RunContent | Should -Match ([regex]::Escape('✓ COMPLETE'))
    }

    It 'shows per-phase status with cross symbol for failure' {
        $script:RunContent | Should -Match ([regex]::Escape('✗'))
    }

    It 'shows SKIPPED status for skipped phases' {
        $script:RunContent | Should -Match ([regex]::Escape('⊝ SKIPPED'))
    }

    It 'includes branch name in summary' {
        $script:RunContent | Should -Match 'branch'
    }

    It 'includes PR URL in summary when available' {
        $script:RunContent | Should -Match 'prUrl|PR'
    }

    It 'includes a next-step or resume command in summary' {
        $script:RunContent | Should -Match 'next|resume'
    }
}
