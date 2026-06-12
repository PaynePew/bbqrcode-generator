import js from '@eslint/js'
import globals from 'globals'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import tseslint from 'typescript-eslint'

export default tseslint.config(
  { ignores: ['dist', 'coverage'] },
  {
    files: ['**/*.{ts,tsx}'],
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    languageOptions: {
      ecmaVersion: 2022,
      globals: { ...globals.browser, ...globals.node },
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      // eslint-plugin-react-hooks v6 ships new correctness rules. Enable the two
      // that catch real bugs — synchronous setState inside an effect (cascading
      // renders) and reading/writing refs during render (impure render). The rest
      // of v6's `recommended-latest` set is React-Compiler optimisation lint
      // (immutability/purity/use-memo) — a separate, larger adoption, left off here.
      'react-hooks/set-state-in-effect': 'error',
      'react-hooks/refs': 'error',
      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
      // TypeScript resolves identifiers; no-undef is redundant and noisy for TS.
      'no-undef': 'off',
    },
  },
)
