import { describe, it, expect } from 'vitest'
import { applyEclPolicy, type ECL } from './eclPolicy'

describe('applyEclPolicy', () => {
  const ecls: ECL[] = ['L', 'M', 'Q', 'H']

  describe('when hasLogo is true', () => {
    for (const userEcl of ecls) {
      it(`forces ECL to H and locks (userEcl=${userEcl})`, () => {
        expect(applyEclPolicy(true, userEcl)).toEqual({ ecl: 'H', isLocked: true })
      })
    }
  })

  describe('when hasLogo is false', () => {
    for (const userEcl of ecls) {
      it(`returns userEcl=${userEcl} unlocked`, () => {
        expect(applyEclPolicy(false, userEcl)).toEqual({ ecl: userEcl, isLocked: false })
      })
    }
  })
})
