BeforeAll {
    . "$PSScriptRoot/../lib/image-cache.ps1"
}

Describe 'Test-ImageRebuildNeeded' {
    BeforeEach {
        $script:Df     = [System.IO.Path]::GetTempFileName()
        $script:Marker = [System.IO.Path]::GetTempFileName() + '.hash'
        Set-Content $script:Df -Value 'FROM node:22-bookworm-slim'
        Remove-Item -ErrorAction SilentlyContinue $script:Marker
    }

    AfterEach {
        Remove-Item -ErrorAction SilentlyContinue $script:Df
        Remove-Item -ErrorAction SilentlyContinue $script:Marker
    }

    It 'returns true when marker does not exist' {
        Test-ImageRebuildNeeded -DockerfilePath $script:Df -MarkerPath $script:Marker |
            Should -Be $true
    }

    It 'returns false when Dockerfile is unchanged since last build' {
        Save-ImageHash -DockerfilePath $script:Df -MarkerPath $script:Marker
        Test-ImageRebuildNeeded -DockerfilePath $script:Df -MarkerPath $script:Marker |
            Should -Be $false
    }

    It 'returns true when Dockerfile has changed since last build' {
        Save-ImageHash -DockerfilePath $script:Df -MarkerPath $script:Marker
        Add-Content $script:Df -Value 'RUN echo changed'
        Test-ImageRebuildNeeded -DockerfilePath $script:Df -MarkerPath $script:Marker |
            Should -Be $true
    }

    It 'returns true when marker file is empty (corrupted)' {
        Set-Content $script:Marker -Value ''
        Test-ImageRebuildNeeded -DockerfilePath $script:Df -MarkerPath $script:Marker |
            Should -Be $true
    }
}
