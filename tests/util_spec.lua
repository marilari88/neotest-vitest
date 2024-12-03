local util = require("neotest-vitest.util")

describe("parse json reporter to result", function()
  it("test", function()
    local json = {
      success = true,
      testResults = {
        {
          assertionResults = {
            {
              ancestorTitles = { "", "describe arrow function" },
              fullName = " describe arrow function foo",
              status = "passed",
              title = "foo",
              failureMessages = {},
            },

            {
              ancestorTitles = { "", "describe arrow function" },
              fullName = " describe arrow function bar(error)",
              status = "skipped",
              title = "bar(error)",
              failureMessages = {},
            },
            {
              ancestorTitles = { "", "describe vanilla function" },
              fullName = " describe vanilla function bar",
              status = "skipped",
              title = "bar",
              failureMessages = {},
            },
          },

          name = "spec/basic.test.ts",
        },
      },
    }
    local result = util.parsed_json_to_results(json, nil, nil)
    local expected_result = {
      ["spec/basic.test.ts::describe arrow function::bar(error)"] = {
        short = "bar(error): skipped",
        status = "skipped",
      },
      ["spec/basic.test.ts::describe arrow function::foo"] = {
        short = "foo: passed",
        status = "passed",
      },
      ["spec/basic.test.ts::describe vanilla function::bar"] = {
        short = "bar: skipped",
        status = "skipped",
      },
    }
    assert.is.same(expected_result, result)
  end)
  it("namespace", function()
    local json = {
      success = false,
      testResults = {
        {
          assertionResults = {
            {
              ancestorTitles = { "", "describe arrow function" },
              duration = 2,
              failureMessages = {},
              fullName = " describe arrow function foo",
              status = "passed",
              title = "foo",
            },
            {
              ancestorTitles = { "", "describe arrow function" },
              duration = 3,
              failureMessages = { "expected true to equal false" },
              fullName = " describe arrow function bar(error)",
              location = {
                column = 43,
                line = 8,
              },
              status = "failed",
              title = "bar(error)",
            },
            {
              ancestorTitles = { "", "describe vanilla function" },
              failureMessages = {},
              fullName = " describe vanilla function bar",
              status = "skipped",
              title = "bar",
            },
          },
          message = "",
          name = "spec/basic.test.ts",
          status = "failed",
        },
      },
    }
    local result = util.parsed_json_to_results(json, nil, nil)
    local expected_result = {
      ["spec/basic.test.ts::describe arrow function::bar(error)"] = {
        errors = {
          {
            column = 43,
            line = 7,
            message = "expected true to equal false",
          },
        },
        location = {
          column = 43,
          line = 8,
        },
        short = "bar(error): failed\nexpected true to equal false",
        status = "failed",
      },
      ["spec/basic.test.ts::describe arrow function::foo"] = {
        short = "foo: passed",
        status = "passed",
      },
      ["spec/basic.test.ts::describe vanilla function::bar"] = {
        short = "bar: skipped",
        status = "skipped",
      },
    }
    assert.is.same(expected_result, result)
  end)

  it("file", function()
    local json = {
      success = false,
      testResults = {
        {
          assertionResults = {
            {
              ancestorTitles = { "", "describe arrow function" },
              duration = 2,
              failureMessages = {},
              fullName = " describe arrow function foo",
              status = "passed",
              title = "foo",
            },
            {
              ancestorTitles = { "", "describe arrow function" },
              duration = 2,
              failureMessages = { "expected true to equal false" },
              fullName = " describe arrow function bar(error)",
              location = {
                column = 43,
                line = 8,
              },
              status = "failed",
              title = "bar(error)",
            },
            {
              ancestorTitles = { "", "describe vanilla function" },
              duration = 0,
              failureMessages = {},
              fullName = " describe vanilla function bar",
              status = "passed",
              title = "bar",
            },
          },
          message = "",
          name = "spec/basic.test.ts",
          status = "failed",
        },
      },
    }
    local result = util.parsed_json_to_results(json, nil, nil)
    local expected_result = {
      ["spec/basic.test.ts::describe arrow function::bar(error)"] = {
        errors = {
          {
            column = 43,
            line = 7,
            message = "expected true to equal false",
          },
        },
        location = {
          column = 43,
          line = 8,
        },
        short = "bar(error): failed\nexpected true to equal false",
        status = "failed",
      },
      ["spec/basic.test.ts::describe arrow function::foo"] = {
        short = "foo: passed",
        status = "passed",
      },
      ["spec/basic.test.ts::describe vanilla function::bar"] = {
        short = "bar: passed",
        status = "passed",
      },
    }
    assert.is.same(expected_result, result)
  end)
end)
