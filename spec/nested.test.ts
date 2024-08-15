import { describe, it, test, expect } from 'vitest'

describe("first level", () => {
    describe("second level", () => {
        it("foo", () => {
            expect(true).to.equal(true);
        });
        it("bar(error)", () => {
            expect(true).to.equal(false);
        });
    });
});

describe("A", () => {
    it("foo", () => {
        expect(true).to.equal(true);
    });
    it("bar(error)", () => {
        expect(true).to.equal(false);
    });
});

