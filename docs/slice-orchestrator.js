export const meta = {
  name: 'slice-orchestrator',
  description: 'bd ready → 每 issue 並行 build(implement+review，同一 worktree)→ 對抗驗證(嚴重度閘門) → 過閘門才 merge(預設只備妥分支，autoMerge:true 才自動合)',
  phases: [{ title: 'Plan' }, { title: 'Build' }, { title: 'Merge' }],
}

// ── args 容錯：物件 OR（誤傳的）JSON 字串都吃，避免覆寫被 typeof 守衛靜默吞掉 ──
const _argsObj = typeof args === 'string'
  ? (() => { try { return JSON.parse(args) } catch { return {} } })()
  : (args && typeof args === 'object' && !Array.isArray(args) ? args : {})

// ── 設定 ──
// ⚠️ 此環境傳 Workflow `args` 不可靠（物件與字串都曾沒進到 script）→ **每次跑前直接改下面 CONFIG**，
//    特別是 baseBranch 與 exclude；不要依賴 args 覆寫。標 ★ 的是每次任務最常要改的。
const CONFIG = {
  promptsDir  : 'C:/Users/MaxL/.claude/agent-prompts',  // 通用 prompts：implement.md / review.md / merge.md（未改）
  // 專案編碼標準（相對路徑：已 tracked，build 的隔離 worktree 與主 worktree 都讀得到）。
  // 前提：CODING_STANDARDS.md 需存在於 baseBranch 上（本檔隨 feat 合進 main 後即成立）。
  standards   : 'docs/CODING_STANDARDS.md',
  branchPrefix: 'slice/issue-',
  baseBranch  : 'main',   // ★build 從此分支開、且應等於你「當前 checked-out 的分支」（merge.md 合進當前分支）
  adversarial : true,     // 對抗驗證開（只擋 critical/high）
  autoMerge   : false,    // 安全預設：只備妥分支等人合。★要「鏈式自動完成下游」須設 true（false 時 loop 只跑一輪）
  only        : null,     // null = 每輪做 bd ready 全部；或填 ['<bd-id>', ...] 只做這些
  exclude     : [],       // ★HITL／不可自動做的 id 填這（每輪跳過，且不會讓迴圈卡住）
  maxRounds   : 5,        // 迴圈安全上限
  skipPlan    : false,    // 配 only：跳過 bd ready 直接 build
  ..._argsObj,
}
const MODELS = { plan:'haiku', build:'sonnet', verify:'opus', merge:'opus', note:'haiku', ...(_argsObj.models ? _argsObj.models : {}) }

// 開跑就印出「實際生效」的設定 —— 萬一覆寫沒套進去，第一行就現形（不再靜默跑預設）
log(`effective config → only=${JSON.stringify(CONFIG.only)} · adversarial=${CONFIG.adversarial} · autoMerge=${CONFIG.autoMerge} · base=${CONFIG.baseBranch} · standards=${CONFIG.standards}`)

const PLAN_SCHEMA = { type:'object', required:['issues'], properties:{
  issues:{ type:'array', items:{ type:'object', required:['id','branch'], properties:{
    id:{type:'string'}, title:{type:'string'}, type:{type:'string'}, branch:{type:'string'} } } } } }
const VERDICT_SCHEMA = { type:'object', required:['verdict','blockers'], properties:{
  verdict:{ type:'string', enum:['pass','changes-requested'] },
  blockers:{ type:'array', items:{ type:'object', required:['severity'], properties:{
    file:{type:'string'}, line:{type:'number'}, issue:{type:'string'},
    severity:{ type:'string', enum:['critical','high','medium','low'] } } } } } }

// build：同一 worktree 內 claim → 從 baseBranch 開分支 → implement → 自我精簡
const buildPrompt = (i) => `你在一個隔離 git worktree 內，獨自負責 issue ${i.id}（${i.title || 'untitled'}）。
重要：worktree 預設可能停在過時 base（origin/${CONFIG.baseBranch}），務必先從本地 ${CONFIG.baseBranch} 開分支，才帶得上前面已 merge 的依賴與 ADR。
1) 原子認領：bd update ${i.id} --claim
2) 從 ${CONFIG.baseBranch} 開新分支：git switch -c ${i.branch} ${CONFIG.baseBranch}
3) 實作：讀 ${CONFIG.promptsDir}/implement.md 照做。代入 {{ISSUE_ID}}=${i.id}、{{ISSUE_TITLE}}=${i.title || ''}、{{BRANCH}}=${i.branch}、{{STANDARDS}}=${CONFIG.standards}。遵守與你所改檔案相關的 Accepted docs/adr/* 與 CONTEXT.md。
4) 自我精簡：再讀 ${CONFIG.promptsDir}/review.md 照做（對你的改動 in-place 精簡並 commit）。
範圍紀律：只動這片需要的檔；絕不刪除/還原其他 slice 的成果、不刪 ADR/CONTEXT/CODING_STANDARDS、不刪既有測試。
回傳：改了哪些檔、git diff ${CONFIG.baseBranch}..${i.branch} 檔案清單、typecheck/test 是否全綠。`

// verify：獨立、唯讀；嚴重度標記，只有 critical/high 擋 merge
const verifyPrompt = (i) => `唯讀對抗式驗證 issue ${i.id}：執行 git diff ${CONFIG.baseBranch}..${i.branch}，盡力找正確性與安全 bug，並對照 ${CONFIG.standards} 與相關 Accepted ADR 檢查違規。
若 diff 顯示它刪除/還原了既有成果（其他 slice、ADR、基礎設施），標 critical（多半代表 base 拿錯了）。
每個 blocker 標 severity：critical/high＝會壞/不安全/刪到別人成果（擋 merge）；medium/low＝小毛病（回報不擋）。
不要改 code、不要 commit。回 verdict（pass＝無 critical/high；否則 changes-requested）與 blockers（file,line,issue,severity）。`

// note：build+verify 完成後，把 implementer 摘要 + reviewer 結論留言到 bead（用 --actor 區分角色；不改 code、不 commit）
const commentPrompt = (i, r) => `你的唯一任務：把 slice ${i.id} 的階段成果留言到對應 bead，寫完即止——不要改任何檔案、不要 commit、不要 close。
分支：${i.branch}
請執行兩筆 bd 留言，各用 --actor 標角色；內容含特殊字元時一律用 --stdin 餵入（避免 shell 解析）：

① 實作者（bd comment ${i.id} --actor slice-implementer --stdin）——留言內容為以下實作摘要：
=== IMPLEMENTER ===
${String(r?.build ?? '(無摘要)').slice(0, 2000)}
=== /IMPLEMENTER ===

② 審查者（bd comment ${i.id} --actor slice-reviewer --stdin）——留言內容為以下審查結論：
=== REVIEWER ===
verdict=${r?.v?.verdict ?? 'n/a'}；擋 merge 的 blocker ${(r?.blocking ?? []).length} 個。
${JSON.stringify(r?.blocking ?? [], null, 2)}
=== /REVIEWER ===

只留這兩筆，不要做其他事。`

// merge：批次、跑一次，合進 baseBranch
const mergePrompt = (list) => `讀 ${CONFIG.promptsDir}/merge.md 照做，合併進 ${CONFIG.baseBranch}。代入：
{{BRANCHES}}=${list.map(i => i.branch).join(' ')}
{{ISSUE_IDS}}=${list.map(i => i.id).join(' ')}
回傳合併與關閉結果。`

// ── 鏈式迴圈：plan(bd ready) → build → 閘門 → merge → 重新 plan，直到沒有可做的。
//    每輪 merge 會 bd close，下游（如 mcc 依賴 hkb）才會在下一輪 bd ready 解鎖被撿起。──
const EXCLUDE   = new Set((CONFIG.exclude ?? []).map(String))     // HITL：每輪都跳過
const ONLY      = CONFIG.only ? new Set(CONFIG.only.map(String)) : null
const attempted = new Set()   // 試過就不再撿（不論過不過閘門）→ 卡關的 slice 不會無限重跑
const lbl       = (i) => i.title ? `${i.id} · ${i.title}` : i.id  // 進度面板帶標題
const rounds    = []
let round = 0

while (round < (CONFIG.maxRounds ?? 5)) {
  round++

  // ① PLAN：bd ready（確定性）→ 濾掉 epic / exclude / 已試過 / 不在 ONLY 內
  let todo
  if (CONFIG.skipPlan && ONLY) {
    todo = [...ONLY].map(id => ({ id, title: '', type: 'task', branch: CONFIG.branchPrefix + id }))
  } else {
    phase('Plan')
    const plan = await agent(
      `執行 bd ready --json 取得目前「未被阻擋」的 issue（bd 已算好依賴，不要自己推）。
把每筆整理成 {id, title, type, branch}，branch = "${CONFIG.branchPrefix}" + 該 id（去掉不適合分支名的字元）。
排除 type==='epic'（epic 是 PRD/容器，不是可實作的 slice）。只回傳 ready 且非 epic 的。`,
      { label: `plan r${round}(bd ready)`, phase: 'Plan', schema: PLAN_SCHEMA, model: MODELS.plan })
    todo = (plan?.issues ?? []).filter(i => i.type !== 'epic')   // 程式層硬擋：epic 絕不進 build
  }
  todo = todo.filter(i => !attempted.has(i.id) && !EXCLUDE.has(i.id) && (!ONLY || ONLY.has(i.id)))

  if (!todo.length) { log(`r${round}: 沒有可做的 issue（已排除 ${[...EXCLUDE].join(',') || '無'}），結束迴圈`); break }
  todo.forEach(i => attempted.add(i.id))   // 標記為已嘗試（避免卡關 slice 無限重跑）
  log(`r${round}: 要做 ${todo.length} 個 → ${todo.map(lbl).join(', ')}`)

  // ② BUILD（每 issue 並行：build+review 同 worktree → verify 唯讀嚴重度閘門 → note 留言回 bead）
  phase('Build')
  const built = await pipeline(
    todo,
    (issue)     => agent(buildPrompt(issue), { label:`build:${lbl(issue)}`, phase:'Build', isolation:'worktree', model: MODELS.build }),
    (b, issue)  => CONFIG.adversarial
      ? agent(verifyPrompt(issue), { label:`verify:${lbl(issue)}`, phase:'Build', schema: VERDICT_SCHEMA, model: MODELS.verify })
          .then(v => ({ build: b, v, blocking: (v?.blockers ?? []).filter(x => x.severity === 'critical' || x.severity === 'high') }))
      : { build: b, v: { verdict: 'skipped', blockers: [] }, blocking: [] },
    // 確定性留言（非 worktree → 寫進正本 bd DB）。原樣回傳；留言失敗不擋 merge。
    async (r, issue) => {
      await agent(commentPrompt(issue, r), { label:`note:${lbl(issue)}`, phase:'Build', model: MODELS.note }).catch(() => null)
      return r
    },
  )

  // ③ 閘門：build 完成 ∧（未開驗證 或 無 critical/high blocker）
  const eligible = todo.map((issue, i) => ({ issue, r: built[i] }))
    .filter(x => x.r && (!CONFIG.adversarial || (x.r.v && x.r.blocking.length === 0)))
  const okIds = new Set(eligible.map(e => e.issue.id))
  const notPassed = todo.filter(i => !okIds.has(i.id)).map(i => i.id)
  log(`r${round}: ${eligible.length}/${todo.length} 過閘門${CONFIG.adversarial ? '（只擋 critical/high）' : ''}` +
      (notPassed.length ? `；未過：${notPassed.join(', ')}` : ''))

  // ④ MERGE（每輪合一次：合進 feat + bd close → 解鎖下游，下一輪 bd ready 才撿得到）
  let merge = null
  if (eligible.length && CONFIG.autoMerge) {
    phase('Merge')
    merge = await agent(mergePrompt(eligible.map(e => e.issue)), { label: `merge r${round}`, phase: 'Merge', model: MODELS.merge })
  }
  rounds.push({ round, planned: todo.map(i => i.id), merged: eligible.map(e => e.issue.id), notPassed, merge })

  // autoMerge:false → 不 close → 下游永遠不解鎖 → 跑一輪就停（不空轉）
  if (!CONFIG.autoMerge) { log('autoMerge:false：只備妥分支、跑一輪即停'); break }
}

return {
  rounds  : rounds.length,
  merged  : rounds.flatMap(r => r.merged),
  attempted: [...attempted],
  excluded: [...EXCLUDE],
  detail  : rounds,
}
