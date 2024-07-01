import { describe, it, test, expect } from 'vitest'

describe("describe arrow function", () => {
    test("foo", () => {
        expect(true).to.equal(true);
    });

    it("bar(error)", () => {
        expect(true).to.equal(false);
    });
});

describe("describe vanilla function", function() {
    test("foo", () => {
        console.log("do test");
    });
    it("bar", () => {
        console.log("do test");
    });
});
