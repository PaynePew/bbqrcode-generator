import { UAParser } from 'ua-parser-js'

export interface ParsedUA {
  browser: string
  os: string
  device: string
}

export function parse(rawUa: string): ParsedUA {
  const parser = new UAParser(rawUa)
  const result = parser.getResult()

  const browser = result.browser.name ?? ''
  const os = result.os.name ?? ''
  const device = result.device.type ?? ''

  return { browser, os, device }
}
