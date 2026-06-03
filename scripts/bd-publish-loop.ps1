<#
.SYNOPSIS
  把本地 bd issues 「單向上推」到 GitHub Issues，讓 repo 上的協作者看到即時進度。
  可在 slice-workflow 執行的同時並行運作。

.WHY
  `bd github sync`（無參數）是『雙向 + --prefer-newer』。GitHub 上的舊狀態會被拉回來，
  把本地已關閉的 bead 重新開啟（2026-06-03 曾因此 revert 掉 6 個已關 slice + ttb epic）。
  本腳本一律 `--push-only --prefer-local`：只寫 GitHub、永不改本地，所以可安全地一邊跑 workflow 一邊發布。

.PARAMETER IntervalSeconds
  兩次推送間隔秒數。預設 60。傳 0 = 只推一次就結束（適合 workflow 跑完後手動收尾）。

.PARAMETER Issues
  只推這些 bead id（逗號分隔）。省略 = 推全部非關閉 bead。

.EXAMPLE
  # 背景週期發布（每 60s 推一次，Ctrl+C 結束）
  pwsh -File scripts/bd-publish-loop.ps1

.EXAMPLE
  # 只推一次
  pwsh -File scripts/bd-publish-loop.ps1 -IntervalSeconds 0

.EXAMPLE
  # 只推指定幾個 slice
  pwsh -File scripts/bd-publish-loop.ps1 -Issues "qr_code_generator-abc,qr_code_generator-def"
#>
param(
  [int]$IntervalSeconds = 60,
  [string]$Issues = ""
)

$ErrorActionPreference = "Continue"

# token 由 .beads/.env 自動載入（bd 內建），這裡不需要設環境變數。
$bdArgs = @("github", "sync", "--push-only", "--prefer-local")
if ($Issues -ne "") { $bdArgs += @("--issues", $Issues) }

function Invoke-Publish {
  $ts = Get-Date -Format "HH:mm:ss"
  Write-Host "[$ts] bd $($bdArgs -join ' ')" -ForegroundColor Cyan
  & bd @bdArgs
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[$ts] push 失敗 (exit $LASTEXITCODE)。401 時用 gh auth token 刷新 .beads/.env：" -ForegroundColor Yellow
    Write-Host "        Set-Content .beads/.env \"GITHUB_TOKEN=`$(gh auth token)\"" -ForegroundColor Yellow
  }
}

Invoke-Publish
if ($IntervalSeconds -le 0) { return }

Write-Host "週期發布中：每 ${IntervalSeconds}s 單向上推一次。Ctrl+C 結束。" -ForegroundColor Green
while ($true) {
  Start-Sleep -Seconds $IntervalSeconds
  Invoke-Publish
}
