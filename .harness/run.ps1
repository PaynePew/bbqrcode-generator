#Requires -Version 7
<#
.SYNOPSIS
    Generic Docker agent harness entry point for Windows / PowerShell.
.PARAMETER SmokeTest
    Run the smoke-test prompt (validates plumbing without spending agent tokens).
.PARAMETER Issue
    Issue number to pass to the implement prompt.
.EXAMPLE
    pwsh ./.harness/run.ps1 -SmokeTest
    pwsh ./.harness/run.ps1 -Issue 28
#>
[CmdletBinding()]
param(
    [switch]$SmokeTest,
    [int]$Issue
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$HarnessRoot = $PSScriptRoot
$RepoRoot    = Split-Path $HarnessRoot -Parent

. "$HarnessRoot/lib/load-config.ps1"
. "$HarnessRoot/lib/render-prompt.ps1"
. "$HarnessRoot/lib/image-cache.ps1"

# ── Helpers ────────────────────────────────────────────────────────────────────

function Fail([string]$Msg, [string]$Remedy = '') {
    Write-Host "ERROR: $Msg" -ForegroundColor Red
    if ($Remedy) { Write-Host "  Run: $Remedy" -ForegroundColor Yellow }
    exit 1
}

function Step([string]$Label) {
    Write-Host "── $Label " -ForegroundColor Cyan -NoNewline
    Write-Host ('─' * [Math]::Max(0, 50 - $Label.Length)) -ForegroundColor DarkGray
}

# ── Pre-flight checks ──────────────────────────────────────────────────────────

Step 'Pre-flight checks'

# 1. CLAUDE_CODE_OAUTH_TOKEN
$token = $env:CLAUDE_CODE_OAUTH_TOKEN
if (-not $token) {
    $envFile = "$HarnessRoot/.env.local"
    if (Test-Path $envFile) {
        foreach ($line in (Get-Content $envFile)) {
            if ($line -match '^CLAUDE_CODE_OAUTH_TOKEN=(.+)$') {
                $env:CLAUDE_CODE_OAUTH_TOKEN = $Matches[1].Trim()
                $token = $env:CLAUDE_CODE_OAUTH_TOKEN
                break
            }
        }
    }
}
if (-not $token) { Fail 'Missing CLAUDE_CODE_OAUTH_TOKEN.' 'claude setup-token' }

# 2. Docker daemon
docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Fail 'Docker daemon not running. Start Docker Desktop and retry.' }

# 3. gh auth
gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Fail 'Not authenticated with GitHub CLI.' 'gh auth login' }

# 4. git repo
if (-not (Test-Path "$RepoRoot/.git")) { Fail 'Not inside a git repository.' }

Write-Host '  All pre-flight checks passed.' -ForegroundColor Green

# ── Load config ────────────────────────────────────────────────────────────────

Step 'Loading config'
try {
    $cfg = Import-HarnessConfig -ConfigPath "$HarnessRoot/config.yml"
} catch {
    Fail "Config error: $_"
}
$imageName  = $cfg.image
$markerPath = "$HarnessRoot/.image-hash"
Write-Host "  image=$imageName  branch_prefix=$($cfg.branch_prefix)" -ForegroundColor DarkGray

# ── Image cache check / rebuild ────────────────────────────────────────────────

Step 'Image cache check'
if (Test-ImageRebuildNeeded -DockerfilePath "$HarnessRoot/Dockerfile" -MarkerPath $markerPath -ImageName $imageName) {
    Write-Host "  Rebuilding image: $imageName" -ForegroundColor Yellow
    docker build -t $imageName -f "$HarnessRoot/Dockerfile" "$RepoRoot"
    if ($LASTEXITCODE -ne 0) { Fail 'docker build failed.' }
    Save-ImageHash -DockerfilePath "$HarnessRoot/Dockerfile" -MarkerPath $markerPath
    Write-Host '  Image built and hash cached.' -ForegroundColor Green
} else {
    Write-Host '  Image up-to-date — no rebuild needed.' -ForegroundColor Green
}

# ── Select and render prompt ───────────────────────────────────────────────────

if ($SmokeTest) {
    $promptFile = "$HarnessRoot/prompts/smoke-test.md"
    $logFile    = "$HarnessRoot/logs/smoke-test.log"
    $runLabel   = 'smoke-test'
    $subs       = @{}
} elseif ($Issue) {
    $promptFile = "$HarnessRoot/prompts/implement.md"
    $logFile    = "$HarnessRoot/logs/issue-$Issue.log"
    $runLabel   = "issue-$Issue"
    $subs       = @{ ISSUE_NUMBER = "$Issue" }
} else {
    Fail 'Specify -SmokeTest or -Issue N.'
}

if (-not (Test-Path $promptFile)) { Fail "Prompt file not found: $promptFile" }

$rawPrompt      = Get-Content $promptFile -Raw
$renderedPrompt = Invoke-RenderPrompt -Template $rawPrompt -Substitutions $subs

# Write rendered prompt to a temp file mounted into the container
$promptMount = "$HarnessRoot/.current-prompt.md"
Set-Content -Path $promptMount -Value $renderedPrompt -Encoding UTF8

# ── Run container ──────────────────────────────────────────────────────────────

Step "Running $runLabel"
Write-Host "  Log → $logFile"

$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory $logDir | Out-Null }

# Pass the token by reference (no `=value`) so it doesn't appear in
# the host process listing. Docker reads it from our environment.
$dockerArgs = @(
    'run', '--rm',
    '--volume', "${RepoRoot}:/workspace",
    '--env',    'CLAUDE_CODE_OAUTH_TOKEN',
    '--workdir', '/workspace',
    $imageName,
    'bash', '-lc', 'claude -p "$(cat /workspace/.harness/.current-prompt.md)"'
)

try {
    & docker @dockerArgs 2>&1 | Tee-Object -FilePath $logFile
    $exitCode = $LASTEXITCODE
} finally {
    Remove-Item -ErrorAction SilentlyContinue $promptMount
}

# ── Summary ────────────────────────────────────────────────────────────────────

$ok     = $exitCode -eq 0
$color  = if ($ok) { 'Green' } else { 'Red' }
$status = if ($ok) { 'COMPLETE' } else { "FAILED (exit $exitCode)" }

Write-Host ''
Write-Host ('╔' + '═' * 50 + '╗') -ForegroundColor $color
Write-Host ("║  $runLabel — $status".PadRight(51) + '║') -ForegroundColor $color
Write-Host ('╚' + '═' * 50 + '╝') -ForegroundColor $color

if ($ok -and $SmokeTest) {
    Write-Host "  Log saved to: $logFile" -ForegroundColor DarkGray
}

exit $exitCode
