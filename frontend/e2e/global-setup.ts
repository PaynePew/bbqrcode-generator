import { execFileSync } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { z } from 'zod'

// The mint helper's stdout contract (one JSON line). Validating it turns a
// garbage/traceback stdout into a clear error instead of an opaque cookie
// failure surfacing later as a confusing logged-out assertion.
const mintedCookieSchema = z.object({
  name: z.string(),
  value: z.string(),
  uid: z.number(),
})

// Mint a real session cookie by running the Python helper against the dev DB,
// then persist it as Playwright storageState so every test starts authenticated
// without touching Google (bead 8vd). SECRET MUST match the running backend's,
// or the signature won't verify — so we require it rather than defaulting, which
// would silently mask a secret mismatch as a confusing logged-out failure.
async function globalSetup(): Promise<void> {
  const here = dirname(fileURLToPath(import.meta.url))
  const repoRoot = resolve(here, '..', '..')

  const secret = process.env.SECRET
  if (!secret) {
    throw new Error(
      'SECRET must be set to the same value the running backend uses so the ' +
        'minted cookie verifies. Refusing to default it (a mismatch fails as a ' +
        'confusing logged-out assertion). See frontend/e2e/README.md.',
    )
  }

  const env = {
    ...process.env,
    // The helper imports `backend.*`; make the repo root importable regardless
    // of how Python resolves sys.path for a bare script invocation.
    PYTHONPATH: repoRoot,
    SECRET: secret,
    DATABASE_URL:
      process.env.DATABASE_URL ??
      'postgresql://postgres:postgres@localhost:5432/qr_codes',
  }

  let cookie: z.infer<typeof mintedCookieSchema>
  try {
    const raw = execFileSync('python', ['scripts/mint_session_cookie.py'], {
      cwd: repoRoot,
      env,
      encoding: 'utf-8',
    })
    cookie = mintedCookieSchema.parse(JSON.parse(raw))
  } catch (error) {
    throw new Error(
      `Failed to mint session cookie (is Postgres up and SECRET matching the backend?): ${String(error)}`,
    )
  }

  const storageState = {
    cookies: [
      {
        name: cookie.name,
        value: cookie.value,
        domain: 'localhost',
        path: '/',
        expires: -1,
        httpOnly: true,
        secure: false,
        sameSite: 'Lax' as const,
      },
    ],
    origins: [],
  }

  const statePath = resolve(here, '.auth', 'state.json')
  mkdirSync(dirname(statePath), { recursive: true })
  writeFileSync(statePath, JSON.stringify(storageState, null, 2))
}

export default globalSetup
