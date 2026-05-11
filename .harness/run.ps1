#Requires -Version 7
<#
.SYNOPSIS
    Generic Docker agent harness entry point for Windows / PowerShell.
.PARAMETER SmokeTest
    Run the smoke-test prompt (validates plumbing without spending agent tokens).
.PARAMETER Issue
    Issue number. Skips plan and runs the implement agent directly.
.PARAMETER Resume
    Resume implement on an existing branch for the given -Issue. Fails if no
    matching branch exists. Cannot be used without -Issue.
.EXAMPLE
    pwsh ./.harness/run.ps1 -SmokeTest
    pwsh ./.harness/run.ps1 -Issue 30
    pwsh ./.harness/run.ps1 -Issue 30 -Resume
#>
[CmdletBinding()]
param(
    [switch]$SmokeTest,
    [int]$Issue,
    [switch]$Resume
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$HarnessRoot = $PSScriptRoot
$RepoRoot    = Split-Path $HarnessRoot -Parent

. "$HarnessRoot/lib/load-config.ps1"
. "$HarnessRoot/lib/render-prompt.ps1"
. "$HarnessRoot/lib/image-cache.ps1"
. "$HarnessRoot/lib/branch-claim.ps1"

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

# ── Select prompt, claim branch, build substitutions ──────────────────────────

$branchName     = ''
$implementModel = ''
$maxTurns       = ''

if ($SmokeTest) {
    $promptFile = "$HarnessRoot/prompts/smoke-test.md"
    $logFile    = "$HarnessRoot/logs/smoke-test.log"
    $runLabel   = 'smoke-test'
    $subs       = @{}
} elseif ($Issue) {
    $promptFile = "$HarnessRoot/prompts/implement.md"
    $logFile    = "$HarnessRoot/logs/issue-$Issue.log"
    $runLabel   = "issue-$Issue"

    # Derive kebab slug from issue title (used to form the branch name)
    $issueTitle = (gh issue view $Issue --repo $cfg.tracker.repo --json title --jq '.title') 2>&1
    $slug = ($issueTitle -replace '[^A-Za-z0-9]+', '-').ToLower().Trim('-')
    if ($slug.Length -gt 40) { $slug = $slug.Substring(0, 40).TrimEnd('-') }

    # Atomic branch claim — exits with error if already claimed and no -Resume
    Step "Claiming branch"
    try {
        $branchName = Invoke-BranchClaim `
            -Prefix      $cfg.branch_prefix `
            -IssueNumber $Issue `
            -Slug        $slug `
            -Resume:$Resume
    } catch {
        Fail "$_" "pwsh ./.harness/run.ps1 -Issue $Issue -Resume"
    }
    Write-Host "  Branch: $branchName" -ForegroundColor Green

    $implementModel = $cfg.agents.implement.model
    $maxTurns       = $cfg.agents.implement.max_turns

    # Resolve substitution values from config (missing paths drop their line via render-prompt)
    $docsPrdDir     = if ($cfg.docs -is [hashtable])      { $cfg.docs.prd_dir }         else { '' }
    $docsContext    = if ($cfg.docs -is [hashtable])      { $cfg.docs.context }          else { '' }
    $docsAdrDir     = if ($cfg.docs -is [hashtable])      { $cfg.docs.adr_dir }          else { '' }
    $testsBlock     = if ($cfg.tests -is [hashtable])     { $cfg.tests.block }           else { '' }
    $typecheckBlock = if ($cfg.typecheck -is [hashtable]) { $cfg.typecheck.block }       else { '' }
    $commitStyle    = if ($cfg.commit -is [hashtable])    { $cfg.commit.style }          else { '' }

    $subs = @{
        ISSUE           = "$Issue"
        BRANCH          = $branchName
        DOCS_PRD_DIR    = $docsPrdDir
        DOCS_CONTEXT    = $docsContext
        DOCS_ADR_DIR    = $docsAdrDir
        TESTS_BLOCK     = $testsBlock
        TYPECHECK_BLOCK = $typecheckBlock
        COMMIT_STYLE    = $commitStyle
    }
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

# Build the claude invocation. For implement runs, pass --model and --max-turns.
$claudeInvocation = if ($implementModel -and $maxTurns) {
    "claude --model $implementModel --max-turns $maxTurns -p `"`$(cat /workspace/.harness/.current-prompt.md)`""
} else {
    'claude -p "$(cat /workspace/.harness/.current-prompt.md)"'
}

# Pass the token by reference (no `=value`) so it doesn't appear in
# the host process listing. Docker reads it from our environment.
$dockerArgs = @(
    'run', '--rm',
    '--volume', "${RepoRoot}:/workspace",
    '--env',    'CLAUDE_CODE_OAUTH_TOKEN',
    '--workdir', '/workspace',
    $imageName,
    'bash', '-lc', $claudeInvocation
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

# Rate-limit detection: surface a ready-made resume command
if (-not $ok -and $Issue -and (Test-Path $logFile)) {
    $logContent = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
    if ($logContent -match 'Rate limit exceeded|usage_limit_exceeded') {
        Write-Host ''
        Write-Host '  Rate limit hit. Resume with:' -ForegroundColor Yellow
        Write-Host "  pwsh ./.harness/run.ps1 -Issue $Issue -Resume" -ForegroundColor Yellow
    }
}

exit $exitCode
