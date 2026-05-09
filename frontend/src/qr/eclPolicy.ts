export type ECL = 'L' | 'M' | 'Q' | 'H'

export function applyEclPolicy(hasLogo: boolean, userEcl: ECL): { ecl: ECL; isLocked: boolean } {
  if (hasLogo) return { ecl: 'H', isLocked: true }
  return { ecl: userEcl, isLocked: false }
}
