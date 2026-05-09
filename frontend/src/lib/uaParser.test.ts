import { describe, it, expect } from 'vitest'
import { parse } from './uaParser'

describe('parse', () => {
  it('returns browser, os, and device fields', () => {
    const result = parse('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
    expect(result).toHaveProperty('browser')
    expect(result).toHaveProperty('os')
    expect(result).toHaveProperty('device')
  })

  it('parses Chrome on macOS correctly', () => {
    const result = parse('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
    expect(result.browser).toContain('Chrome')
    expect(result.os).toContain('macOS')
  })

  it('parses Firefox on Windows correctly', () => {
    const result = parse('Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/119.0')
    expect(result.browser).toContain('Firefox')
    expect(result.os).toContain('Windows')
  })

  it('returns empty strings for unknown user agent', () => {
    const result = parse('')
    expect(typeof result.browser).toBe('string')
    expect(typeof result.os).toBe('string')
    expect(typeof result.device).toBe('string')
  })

  it('handles null-like input gracefully', () => {
    const result = parse('unknown-bot/1.0')
    expect(result).toHaveProperty('browser')
    expect(result).toHaveProperty('os')
    expect(result).toHaveProperty('device')
  })
})
