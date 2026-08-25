/** Pure helpers for the bare example (unit-tested without Hub). */

export function formatCounterLabel(count: number): string {
  return `taps: ${count}`
}

export const READY_MARKER = '[even-deskless] ready'
