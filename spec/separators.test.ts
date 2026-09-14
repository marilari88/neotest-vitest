import { describe, expect, it } from 'vitest';

describe('outer > suite', () => {
  describe('inner (suite)', () => {
    it('adds 1 + 2', () => {
      expect(1 + 2).toBe(3);
    });
    it('adds 1 + 20', () => {
      expect(1 + 20).toBe(21);
    });
  });
});
