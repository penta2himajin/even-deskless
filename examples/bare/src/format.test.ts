import { describe, expect, it } from 'vitest'
import { formatCounterLabel, READY_MARKER } from './format.ts'

describe('formatCounterLabel', () => {
  it('renders tap count', () => {
    expect(formatCounterLabel(0)).toBe('taps: 0')
    expect(formatCounterLabel(3)).toBe('taps: 3')
  })
})

describe('READY_MARKER', () => {
  it('matches the deskless smoke contract', () => {
    expect(READY_MARKER).toBe('[even-deskless] ready')
  })
})
